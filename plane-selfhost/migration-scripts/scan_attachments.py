#!/usr/bin/env python3
"""
SaaS 첨부파일 스캔

작업 항목에는 첨부 개수 필드가 없어서 항목마다 조회해야 한다.
560건 × 1.1초 ≈ 10분. 중간 저장하므로 끊겨도 이어받는다.

결과: migration-dump/{IDENT}.attachments.json
"""

import json
import sys
import time
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

BASE = "https://api.plane.so/api/v1"
WORKSPACE = "my-saas-workspace"
DUMP = Path(__file__).resolve().parent.parent / "migration-dump"
THROTTLE = 1.1

PROJECTS = {
    "PROJB": "<PROJB_ID_SRC>",
    "PROJA": "<PROJA_ID_SRC>",
    "PROJC": "<PROJC_ID_DST>",
}

HEADERS = {
    "Accept": "application/json",
    # Cloudflare가 Python 기본 UA를 Error 1010으로 막는다.
    "User-Agent": "plane-migrate/1.0 (+internal tooling)",
}


def token() -> str:
    env = Path.home() / ".config/plane-migrate/selfhost.env"
    for line in env.read_text(encoding="utf-8").splitlines():
        if line.startswith("PLANE_SAAS_TOKEN="):
            return line.split("=", 1)[1].strip()
    sys.exit("PLANE_SAAS_TOKEN 없음")


TOKEN = token()


def get(path: str, retries: int = 4):
    h = dict(HEADERS, **{"X-API-Key": TOKEN})
    for attempt in range(1, retries + 1):
        try:
            with urlopen(Request(f"{BASE}{path}", headers=h), timeout=45) as r:
                return json.loads(r.read().decode("utf-8"))
        except HTTPError as e:
            if e.code == 429:
                time.sleep(10 * attempt)
                continue
            if e.code == 404:
                return None
            raise RuntimeError(f"HTTP {e.code} {path}")
        except URLError:
            if attempt == retries:
                raise
            time.sleep(3 * attempt)
    return None


def main():
    grand = 0
    for ident, pid in PROJECTS.items():
        bulk = json.loads((DUMP / f"{ident}.bulk.json").read_text(encoding="utf-8"))
        items = bulk["work_items"]
        out_path = DUMP / f"{ident}.attachments.json"
        found = json.loads(out_path.read_text(encoding="utf-8")) if out_path.exists() else {}

        print(f"\n=== {ident} ({len(items)}건) — 기존 {len(found)}건 조회됨 ===")
        base = f"/workspaces/{WORKSPACE}/projects/{pid}"
        n_att = 0

        for n, it in enumerate(items, 1):
            iid = it["id"]
            if iid in found:
                n_att += len(found[iid])
                continue
            data = get(f"{base}/work-items/{iid}/attachments/")
            time.sleep(THROTTLE)
            rows = data if isinstance(data, list) else (data or {}).get("results", [])
            found[iid] = rows
            n_att += len(rows)
            if rows:
                print(f"  [{it.get('sequence_id')}] {len(rows)}개 — {str(it.get('name'))[:40]}")
            if n % 50 == 0:
                out_path.write_text(json.dumps(found, ensure_ascii=False, indent=2), encoding="utf-8")
                print(f"  {n}/{len(items)}  (첨부 누적 {n_att})")

        out_path.write_text(json.dumps(found, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"  → {ident}: 첨부 {n_att}개")
        grand += n_att

    print(f"\n전체 첨부 {grand}개")


if __name__ == "__main__":
    main()
