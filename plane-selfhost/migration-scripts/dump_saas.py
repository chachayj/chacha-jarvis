#!/usr/bin/env python3
"""
Plane SaaS 무손실 덤프

SaaS 워크스페이스의 데이터를 JSON으로 통째로 떠서 파일로 보관한다.
읽기 전용이라 원본에 영향이 없고, SaaS를 해지하더라도 원본이 남는다.

이관 스크립트(migrate_to_selfhost.py)의 입력이기도 하다.

사용:
    python3 scripts/dump_saas.py                 # 전체
    python3 scripts/dump_saas.py --stage bulk    # 프로젝트 단위 리소스만 (빠름)
    python3 scripts/dump_saas.py --stage items   # 작업 항목별 하위 리소스 (느림)
    python3 scripts/dump_saas.py --project PROJB # 특정 프로젝트만

토큰:
    ~/.config/plane-migrate/selfhost.env 의 PLANE_SAAS_TOKEN
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

BASE = "https://api.plane.so/api/v1"
WORKSPACE = "my-saas-workspace"
OUT_DIR = Path(__file__).resolve().parent.parent / "migration-dump"

# 이관 대상. PROJD는 self-host에 대응 프로젝트가 없어 제외한다.
PROJECTS = {
    "PROJB": "<PROJB_ID_SRC>",
    "PROJA": "<PROJA_ID_SRC>",
    "PROJC": "<PROJC_ID_DST>",
}

# API_KEY_RATE_LIMIT 기본값이 60/minute 이므로 여유를 두고 호출 간격을 준다.
THROTTLE_SEC = 1.1


def load_token() -> str:
    env = Path.home() / ".config/plane-migrate/selfhost.env"
    if not env.exists():
        sys.exit(f"토큰 파일이 없습니다: {env}")
    for line in env.read_text(encoding="utf-8").splitlines():
        if line.startswith("PLANE_SAAS_TOKEN="):
            return line.split("=", 1)[1].strip()
    sys.exit("PLANE_SAAS_TOKEN 을 찾지 못했습니다")


TOKEN = load_token()


# Cloudflare가 Python 기본 User-Agent(Python-urllib/3.x)를 Error 1010으로 차단한다.
# 이걸 안 주면 전 요청이 403이 되는데, 인증 실패처럼 보여 원인 찾기가 어렵다.
HEADERS_BASE = {
    "Accept": "application/json",
    "User-Agent": "plane-migrate/1.0 (+internal tooling)",
}


def get(path: str, params: dict | None = None, retries: int = 4):
    """GET 요청. rate limit(429)이면 물러섰다가 재시도한다."""
    url = f"{BASE}{path}"
    if params:
        url += "?" + urlencode(params)

    headers = dict(HEADERS_BASE, **{"X-API-Key": TOKEN})
    last_err = None

    for attempt in range(1, retries + 1):
        try:
            with urlopen(Request(url, headers=headers), timeout=60) as r:
                return json.loads(r.read().decode("utf-8"))
        except HTTPError as e:
            if e.code == 429:
                wait = 10 * attempt
                print(f"    rate limit — {wait}초 대기 후 재시도 ({attempt}/{retries})")
                time.sleep(wait)
                continue
            # 404는 "그 리소스가 없다"라 정상 흐름이다. 나머지는 조용히 넘기지 않는다 —
            # 403을 None으로 삼켰다가 Cloudflare 차단을 "데이터 0건"으로 오인한 적이 있다.
            if e.code == 404:
                return None
            body = e.read().decode("utf-8", "replace")[:200]
            raise RuntimeError(f"HTTP {e.code} {path}\n  {body}") from e
        except URLError as e:
            last_err = e
            if attempt == retries:
                raise
            time.sleep(3 * attempt)

    if last_err:
        raise last_err
    return None


def get_all(path: str, params: dict | None = None) -> list:
    """커서 페이지네이션을 끝까지 따라가며 전체를 모은다."""
    out, cursor = [], None
    while True:
        p = dict(params or {})
        p["per_page"] = 100
        if cursor:
            p["cursor"] = cursor
        data = get(path, p)
        time.sleep(THROTTLE_SEC)
        if data is None:
            break
        if isinstance(data, list):
            out.extend(data)
            break
        out.extend(data.get("results", []))
        if not data.get("next_page_results"):
            break
        cursor = data.get("next_cursor")
        if not cursor:
            break
    return out


def save(name: str, obj) -> Path:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    p = OUT_DIR / name
    p.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")
    return p


def dump_bulk(targets: dict):
    """프로젝트 단위 리소스. 호출 수가 적어 빠르다."""
    print("=== [bulk] 워크스페이스 리소스 ===")
    members = get_all(f"/workspaces/{WORKSPACE}/members/")
    print(f"  멤버 {len(members)}명")
    save("members.json", members)

    for ident, pid in targets.items():
        print(f"\n=== [bulk] {ident} ===")
        base = f"/workspaces/{WORKSPACE}/projects/{pid}"
        bundle = {"identifier": ident, "project_id": pid}

        for key, path in [
            ("states", f"{base}/states/"),
            ("labels", f"{base}/labels/"),
            ("members", f"{base}/members/"),
            ("cycles", f"{base}/cycles/"),
            ("modules", f"{base}/modules/"),
        ]:
            rows = get_all(path)
            bundle[key] = rows
            print(f"  {key:10} {len(rows)}")

        items = get_all(f"{base}/work-items/")
        bundle["work_items"] = items
        print(f"  {'work_items':10} {len(items)}")

        # 사이클·모듈 소속 관계
        for cyc in bundle["cycles"]:
            cyc["_work_items"] = [
                x.get("id") for x in get_all(f"{base}/cycles/{cyc['id']}/cycle-issues/")
            ]
        for mod in bundle["modules"]:
            mod["_work_items"] = [
                x.get("id") for x in get_all(f"{base}/modules/{mod['id']}/module-issues/")
            ]
        print("  사이클·모듈 소속 관계 수집 완료")

        save(f"{ident}.bulk.json", bundle)
        print(f"  → {ident}.bulk.json")


def dump_items(targets: dict):
    """작업 항목별 하위 리소스. 항목마다 3회 호출이라 느리다."""
    for ident, pid in targets.items():
        bulk_path = OUT_DIR / f"{ident}.bulk.json"
        if not bulk_path.exists():
            print(f"[{ident}] bulk 덤프가 없습니다 — --stage bulk 를 먼저 실행하세요")
            continue

        bundle = json.loads(bulk_path.read_text(encoding="utf-8"))
        items = bundle["work_items"]
        base = f"/workspaces/{WORKSPACE}/projects/{pid}"
        total = len(items)
        print(f"\n=== [items] {ident} — {total}건 ===")

        detail, done = {}, 0
        out_path = OUT_DIR / f"{ident}.items.json"
        if out_path.exists():  # 중단 후 재개
            detail = json.loads(out_path.read_text(encoding="utf-8"))
            print(f"  기존 {len(detail)}건 이어받음")

        for it in items:
            iid = it["id"]
            done += 1
            if iid in detail:
                continue
            detail[iid] = {
                "comments": get_all(f"{base}/work-items/{iid}/comments/"),
                "links": get_all(f"{base}/work-items/{iid}/links/"),
                "activities": get_all(f"{base}/work-items/{iid}/activities/"),
            }
            if done % 20 == 0:
                save(f"{ident}.items.json", detail)  # 중간 저장
                print(f"  {done}/{total}")

        save(f"{ident}.items.json", detail)
        print(f"  → {ident}.items.json ({len(detail)}건)")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--stage", choices=["bulk", "items", "all"], default="all")
    ap.add_argument("--project", help="특정 프로젝트만 (예: PROJB)")
    args = ap.parse_args()

    targets = PROJECTS
    if args.project:
        if args.project not in PROJECTS:
            sys.exit(f"알 수 없는 프로젝트: {args.project} (가능: {', '.join(PROJECTS)})")
        targets = {args.project: PROJECTS[args.project]}

    start = time.time()
    if args.stage in ("bulk", "all"):
        dump_bulk(targets)
    if args.stage in ("items", "all"):
        dump_items(targets)

    print(f"\n완료 — {int(time.time() - start)}초")
    print(f"저장 위치: {OUT_DIR}")


if __name__ == "__main__":
    main()
