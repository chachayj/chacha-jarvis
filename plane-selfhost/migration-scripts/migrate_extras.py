#!/usr/bin/env python3
"""
사이클 · 모듈 · 댓글 · 링크 이관

migrate_to_selfhost.py 가 작업 항목을 먼저 옮긴 뒤에 실행한다.
_migration_state.json 의 (SaaS 항목 id → self-host 항목 id) 매핑에 의존한다.

공개 API v1 에 없는 것:
  - 페이지(pages)  : 엔드포인트 자체가 없다. 웹앱 내부 API 전용.
  - 뷰(views)      : 마찬가지. 필요하면 수동 재생성해야 한다.

사용:
    python3 scripts/migrate_extras.py --dry-run
    python3 scripts/migrate_extras.py --project PROJC
    python3 scripts/migrate_extras.py
"""

import argparse
import json
import sys
import time
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

SELFHOST = "http://192.0.2.10:8080/api/v1"
WORKSPACE = "my-workspace"
DUMP_DIR = Path(__file__).resolve().parent.parent / "migration-dump"
STATE_FILE = DUMP_DIR / "_migration_state.json"
EXTRAS_STATE = DUMP_DIR / "_extras_state.json"

EXTERNAL_SOURCE = "plane-saas"

PROJECT_MAP = {
    "PROJB":  "<PROJB_ID_DST>",
    "PROJA": "<PROJA_ID_DST>",
    "PROJC":  "<PROJC_ID_SRC>",
}

MAPPABLE_EMAILS = {"dev1@example.com", "dev2@example.com", "dev3@example.com"}

# self-host API_KEY_RATE_LIMIT 기본값이 60/minute 이다. 0.3초로 돌렸다가 429를 맞았다.
THROTTLE_SEC = 1.1

HEADERS_BASE = {
    "Accept": "application/json",
    "Content-Type": "application/json",
    "User-Agent": "plane-migrate/1.0 (+internal tooling)",
}


def load_token() -> str:
    env = Path.home() / ".config/plane-migrate/selfhost.env"
    for line in env.read_text(encoding="utf-8").splitlines():
        if line.startswith("PLANE_SELFHOST_TOKEN="):
            return line.split("=", 1)[1].strip()
    sys.exit("PLANE_SELFHOST_TOKEN 을 찾지 못했습니다")


TOKEN = load_token()


def call(method: str, path: str, body=None, retries: int = 5):
    url = f"{SELFHOST}{path}"
    payload = json.dumps(body).encode("utf-8") if body is not None else None
    headers = dict(HEADERS_BASE, **{"X-API-Key": TOKEN})

    for attempt in range(1, retries + 1):
        try:
            with urlopen(Request(url, data=payload, headers=headers, method=method), timeout=60) as r:
                raw = r.read().decode("utf-8")
                return r.status, (json.loads(raw) if raw else None)
        except HTTPError as e:
            raw = e.read().decode("utf-8", "replace")
            try:
                data = json.loads(raw)
            except Exception:
                data = {"raw": raw[:300]}
            if e.code == 429:
                time.sleep(15 * attempt)
                continue
            return e.code, data
        except URLError:
            if attempt == retries:
                raise
            time.sleep(2 * attempt)
    return 0, None


def rows_of(data) -> list:
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        return data.get("results", [])
    return []


def member_map() -> dict:
    saas = json.loads((DUMP_DIR / "members.json").read_text(encoding="utf-8"))
    id2mail = {m["id"]: m.get("email", "") for m in saas}
    _, data = call("GET", f"/workspaces/{WORKSPACE}/members/")
    mail2id = {m.get("email", ""): m.get("id") for m in rows_of(data)}
    return {sid: mail2id[e] for sid, e in id2mail.items()
            if e in MAPPABLE_EMAILS and e in mail2id}


def migrate(ident: str, items_map: dict, members: dict, ex: dict, dry: bool):
    bulk = json.loads((DUMP_DIR / f"{ident}.bulk.json").read_text(encoding="utf-8"))
    sh_pid = PROJECT_MAP[ident]
    base = f"/workspaces/{WORKSPACE}/projects/{sh_pid}"

    items_path = DUMP_DIR / f"{ident}.items.json"
    detail = json.loads(items_path.read_text(encoding="utf-8")) if items_path.exists() else {}

    n_comments = sum(len(v.get("comments", [])) for v in detail.values())
    n_links = sum(len(v.get("links", [])) for v in detail.values())

    print(f"\n=== {ident} ===")
    print(f"  사이클 {len(bulk['cycles'])} · 모듈 {len(bulk['modules'])} · 댓글 {n_comments} · 링크 {n_links}")
    if dry:
        return

    st = ex.setdefault(ident, {"cycles": {}, "modules": {}, "comments": {}, "links": {}})
    owner = members.get(next(iter(members), None)) if members else None

    # ---------------- 사이클 ----------------
    #
    # 순서가 중요하다. Plane은 end_date가 지난 사이클을 "완료"로 보고 항목 추가도
    # 수정도 막는다(plane/api/views/cycle.py: end_date < now 이면 400).
    # 이관 대상은 대부분 과거 사이클이라 end_date를 넣어 만들면 그 즉시 잠긴다.
    #
    # 그래서: end_date 없이 생성 → 항목 추가 → 마지막에 end_date 설정.
    # 잠금 판정은 "수정 시점의 현재 end_date" 기준이므로 마지막 설정은 통과한다.
    for c in bulk["cycles"]:
        if c["id"] in st["cycles"]:
            continue
        body = {"name": c["name"], "external_id": c["id"], "external_source": EXTERNAL_SOURCE}
        if c.get("description"):
            body["description"] = c["description"]
        # start_date 와 end_date 는 "둘 다 있거나 둘 다 없거나"여야 한다.
        # 진짜 종료일을 지금 넣으면 즉시 잠기므로, 종료일만 미래로 두고 만든 뒤
        # 항목을 다 넣고 나서 진짜 날짜로 되돌린다.
        if c.get("start_date") and c.get("end_date"):
            body["start_date"] = c["start_date"]
            body["end_date"] = "2099-12-31T00:00:00Z"
        # owned_by 는 필수다. 매핑 안 되면 토큰 소유자로 대체한다.
        body["owned_by"] = members.get(c.get("owned_by"), owner)
        code, res = call("POST", f"{base}/cycles/", body)
        time.sleep(THROTTLE_SEC)
        if code in (200, 201) and res:
            st["cycles"][c["id"]] = res["id"]
        elif code == 409 and isinstance(res, dict) and res.get("id"):
            st["cycles"][c["id"]] = res["id"]
        else:
            print(f"  ⚠ 사이클 실패: {c['name']} → HTTP {code} {res}")
    print(f"  사이클 {len(st['cycles'])}/{len(bulk['cycles'])}")

    # 사이클 소속 작업 항목
    #
    # 종료일이 지난 사이클에는 항목을 못 넣는다(CYCLE_COMPLETED). 이관하는 사이클은
    # 대부분 과거 것이라 그대로는 거의 다 막힌다. 종료일을 임시로 미래로 밀어
    # 항목을 넣고 원래 날짜로 되돌린다.
    done_key = "cycle_issues"
    st.setdefault(done_key, {})
    for c in bulk["cycles"]:
        new_cid = st["cycles"].get(c["id"])
        if not new_cid or c["id"] in st[done_key]:
            continue
        ids = [items_map[i] for i in c.get("_work_items", []) if i in items_map]
        if not ids:
            st[done_key][c["id"]] = 0
            continue

        code, res = call("POST", f"{base}/cycles/{new_cid}/cycle-issues/", {"issues": ids})
        time.sleep(THROTTLE_SEC)

        if code in (200, 201, 204):
            st[done_key][c["id"]] = len(ids)
        else:
            print(f"  ⚠ 사이클 소속 실패: {c['name']} ({len(ids)}건) → HTTP {code} {res}")

    # 항목을 다 넣은 뒤에야 종료일을 설정한다. 이 순서를 지켜야 잠기지 않는다.
    st.setdefault("cycle_dates", {})
    for c in bulk["cycles"]:
        new_cid = st["cycles"].get(c["id"])
        if not new_cid or not c.get("end_date") or c["id"] in st["cycle_dates"]:
            continue
        code, res = call("PATCH", f"{base}/cycles/{new_cid}/",
                         {"start_date": c.get("start_date"), "end_date": c["end_date"]})
        time.sleep(THROTTLE_SEC)
        if code in (200, 201):
            st["cycle_dates"][c["id"]] = c["end_date"]
        else:
            print(f"  ⚠ 사이클 종료일 실패: {c['name']} → HTTP {code} {res}")

    # ---------------- 모듈 ----------------
    for m in bulk["modules"]:
        if m["id"] in st["modules"]:
            continue
        body = {"name": m["name"], "external_id": m["id"], "external_source": EXTERNAL_SOURCE}
        for k in ("description", "start_date", "target_date", "status"):
            if m.get(k):
                body[k] = m[k]
        if m.get("lead") in members:
            body["lead"] = members[m["lead"]]
        code, res = call("POST", f"{base}/modules/", body)
        time.sleep(THROTTLE_SEC)
        if code in (200, 201) and res:
            st["modules"][m["id"]] = res["id"]
        elif code == 409 and isinstance(res, dict) and res.get("id"):
            st["modules"][m["id"]] = res["id"]
        else:
            print(f"  ⚠ 모듈 실패: {m['name']} → HTTP {code} {res}")
    print(f"  모듈 {len(st['modules'])}/{len(bulk['modules'])}")

    for m in bulk["modules"]:
        new_mid = st["modules"].get(m["id"])
        if not new_mid:
            continue
        ids = [items_map[i] for i in m.get("_work_items", []) if i in items_map]
        if not ids:
            continue
        code, res = call("POST", f"{base}/modules/{new_mid}/module-issues/", {"issues": ids})
        time.sleep(THROTTLE_SEC)
        if code not in (200, 201, 204):
            print(f"  ⚠ 모듈 소속 실패: {m['name']} ({len(ids)}건) → HTTP {code} {res}")

    # ---------------- 댓글 · 링크 ----------------
    c_done = l_done = 0
    for saas_iid, d in detail.items():
        new_iid = items_map.get(saas_iid)
        if not new_iid:
            continue

        for cm in d.get("comments", []):
            if cm["id"] in st["comments"]:
                continue
            body = {
                "comment_html": cm.get("comment_html") or "<p></p>",
                "external_id": cm["id"],
                "external_source": EXTERNAL_SOURCE,
            }
            # 작업 항목과 마찬가지로 created_at / created_by 를 받는다.
            if cm.get("created_at"):
                body["created_at"] = cm["created_at"]
            if cm.get("created_by") in members:
                body["created_by"] = members[cm["created_by"]]
            code, res = call("POST", f"{base}/work-items/{new_iid}/comments/", body)
            time.sleep(THROTTLE_SEC)
            if code in (200, 201) and res:
                st["comments"][cm["id"]] = res["id"]; c_done += 1
            elif code == 409 and isinstance(res, dict) and res.get("id"):
                st["comments"][cm["id"]] = res["id"]
            else:
                print(f"  ⚠ 댓글 실패 → HTTP {code} {res}")

        for ln in d.get("links", []):
            if ln["id"] in st["links"]:
                continue
            body = {"url": ln.get("url"), "title": ln.get("title") or ""}
            code, res = call("POST", f"{base}/work-items/{new_iid}/links/", body)
            time.sleep(THROTTLE_SEC)
            if code in (200, 201) and res:
                st["links"][ln["id"]] = res["id"]; l_done += 1
            elif code == 409:
                st["links"][ln["id"]] = "dup"
            else:
                print(f"  ⚠ 링크 실패 {ln.get('url')} → HTTP {code} {res}")

    print(f"  댓글 {len(st['comments'])}/{n_comments} · 링크 {len(st['links'])}/{n_links}")
    EXTRAS_STATE.write_text(json.dumps(ex, ensure_ascii=False, indent=2), encoding="utf-8")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--project")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if not STATE_FILE.exists():
        sys.exit("작업 항목 이관 상태가 없습니다 — migrate_to_selfhost.py 를 먼저 실행하세요")
    state = json.loads(STATE_FILE.read_text(encoding="utf-8"))
    ex = json.loads(EXTRAS_STATE.read_text(encoding="utf-8")) if EXTRAS_STATE.exists() else {}

    members = member_map()
    print(f"멤버 매핑 {len(members)}명")

    targets = [args.project] if args.project else list(PROJECT_MAP)
    start = time.time()
    for t in targets:
        items_map = state.get(t, {}).get("items", {})
        if not items_map:
            print(f"[{t}] 작업 항목 매핑이 없습니다 — 건너뜀")
            continue
        migrate(t, items_map, members, ex, args.dry_run)

    print(f"\n완료 — {int(time.time() - start)}초")


if __name__ == "__main__":
    main()
