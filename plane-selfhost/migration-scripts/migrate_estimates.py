#!/usr/bin/env python3
"""
Estimate 이관 (세션 인증)

estimate 는 내부 API 에만 있어 세션 로그인이 필요하다(plane_session.py).

두 단계다:
  1. estimate 정의 + 포인트 생성 → 프로젝트에 연결
  2. 작업 항목의 estimate_point 값 복원 (PROJB 69건, PROJA 56건)

2단계는 공개 API v1 의 work-item PATCH 로 한다 — estimate_point 는 그쪽에서 받는다.

사용:
    python3 scripts/migrate_estimates.py --dry-run
    python3 scripts/migrate_estimates.py
"""

import argparse
import json
import sys
import time
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from plane_session import Session, rows_of, WORKSPACE  # noqa: E402

REPO = Path(__file__).resolve().parent.parent
DUMP = REPO / "migration-dump"
STATE = DUMP / "_migration_state.json"
EST_STATE = DUMP / "_estimates_state.json"
EST_DUMP = DUMP / "estimates.json"

SELFHOST_V1 = "http://192.0.2.10:8080/api/v1"
UA = "plane-migrate/1.0 (+internal tooling)"
THROTTLE = 1.1

SH_PROJECTS = {
    "PROJB": "<PROJB_ID_DST>",
    "PROJA": "<PROJA_ID_DST>",
    "PROJC": "<PROJC_ID_SRC>",
}


def v1_token() -> str:
    for line in (Path.home() / ".config/plane-migrate/selfhost.env").read_text(encoding="utf-8").splitlines():
        if line.startswith("PLANE_SELFHOST_TOKEN="):
            return line.split("=", 1)[1].strip()
    sys.exit("PLANE_SELFHOST_TOKEN 없음")


V1_TOKEN = v1_token()


def v1(method: str, path: str, body=None):
    payload = json.dumps(body).encode("utf-8") if body is not None else None
    headers = {"X-API-Key": V1_TOKEN, "Accept": "application/json", "User-Agent": UA}
    if payload:
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(SELFHOST_V1 + path, data=payload, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read().decode("utf-8")
            return r.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", "replace")
        try:
            return e.code, json.loads(raw)
        except Exception:
            return e.code, {"raw": raw[:250]}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if not EST_DUMP.exists():
        sys.exit(f"estimate 덤프가 없습니다: {EST_DUMP}\n  dump_estimates.py 를 먼저 실행하세요")

    est_dump = json.loads(EST_DUMP.read_text(encoding="utf-8"))
    items_state = json.loads(STATE.read_text(encoding="utf-8"))
    st = json.loads(EST_STATE.read_text(encoding="utf-8")) if EST_STATE.exists() else {}

    s = Session()
    code, me = s.call("GET", "/api/users/me/")
    print(f"세션 로그인 — {me.get('email')}")

    for ident, data in est_dump.items():
        if ident not in SH_PROJECTS:
            continue
        est = data.get("estimate")
        points = data.get("points", [])
        if not est:
            continue

        sh_pid = SH_PROJECTS[ident]
        used = data.get("_used_count", 0)
        print(f"\n=== {ident} — {est['name']} ({est['type']}), 포인트 {len(points)}개, 사용 {used}건 ===")

        if args.dry_run:
            for p in sorted(points, key=lambda x: x.get("key", 0)):
                print(f"    key={p.get('key')} value={p.get('value')}")
            continue

        pst = st.setdefault(ident, {"estimate_id": None, "points": {}})

        # ---- 1. estimate 정의 생성 (내부 API) ----
        if not pst["estimate_id"]:
            # 내부 API 는 estimate 를 중첩 객체로 받는다 (plane/app/views/estimate/base.py):
            #   estimate = request.data.get("estimate")
            #   estimate_points = request.data.get("estimate_points", [])
            # 평면 구조로 보내면 500 이 난다.
            body = {
                "estimate": {"name": est["name"], "type": est["type"]},
                "estimate_points": [
                    {"key": p.get("key"), "value": p.get("value")}
                    for p in sorted(points, key=lambda x: x.get("key", 0))
                ],
            }
            code, res = s.call("POST", s.ws(f"/projects/{sh_pid}/estimates/"), body)
            time.sleep(THROTTLE)
            if code not in (200, 201) or not isinstance(res, dict):
                print(f"  ⚠ estimate 생성 실패 → HTTP {code} {str(res)[:250]}")
                continue
            eid = res.get("id") or (res.get("estimate") or {}).get("id")
            pst["estimate_id"] = eid
            print(f"  estimate 생성 {eid}")

            # 생성된 포인트를 value 기준으로 매핑.
            # 포인트는 별도 엔드포인트가 아니라 estimate 객체의 points 배열에 들어있다.
            code, elist = s.call("GET", s.ws(f"/projects/{sh_pid}/estimates/"))
            time.sleep(THROTTLE)
            new_points = []
            for e in rows_of(elist):
                if e.get("id") == eid:
                    new_points = e.get("points", [])
                    break
            new_by_value = {str(p.get("value")): p.get("id") for p in new_points}
            for p in points:
                nid = new_by_value.get(str(p.get("value")))
                if nid:
                    pst["points"][p["id"]] = nid
            print(f"  포인트 매핑 {len(pst['points'])}/{len(points)}")
            EST_STATE.write_text(json.dumps(st, ensure_ascii=False, indent=2), encoding="utf-8")

        # ---- 2. 작업 항목의 estimate_point 복원 (공개 API v1) ----
        bulk = json.loads((DUMP / f"{ident}.bulk.json").read_text(encoding="utf-8"))
        imap = items_state.get(ident, {}).get("items", {})
        pst.setdefault("applied", {})
        targets = [it for it in bulk["work_items"] if it.get("estimate_point")]
        done = fail = 0

        for n, it in enumerate(targets, 1):
            if it["id"] in pst["applied"]:
                continue
            new_iid = imap.get(it["id"])
            new_pid = pst["points"].get(it["estimate_point"])
            if not (new_iid and new_pid):
                continue
            code, res = v1("PATCH", f"/workspaces/{WORKSPACE}/projects/{sh_pid}/work-items/{new_iid}/",
                           {"estimate_point": new_pid})
            time.sleep(THROTTLE)
            if code in (200, 201):
                pst["applied"][it["id"]] = new_pid
                done += 1
            else:
                fail += 1
                print(f"  ⚠ 항목 실패 [{it.get('sequence_id')}] → HTTP {code} {str(res)[:150]}")
            if n % 25 == 0:
                EST_STATE.write_text(json.dumps(st, ensure_ascii=False, indent=2), encoding="utf-8")
                print(f"  {n}/{len(targets)}  적용 {done} 실패 {fail}")

        EST_STATE.write_text(json.dumps(st, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"  항목 값 적용 {len(pst['applied'])}/{len(targets)} (실패 {fail})")

    print("\n완료")


if __name__ == "__main__":
    main()
