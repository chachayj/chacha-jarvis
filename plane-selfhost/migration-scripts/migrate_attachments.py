#!/usr/bin/env python3
"""
첨부파일 이관

scan_attachments.py 로 메타데이터를 뜬 뒤 실행한다.

업로드는 3단계다 (plane/api/views/issue.py):
  1. POST   /work-items/{id}/attachments/   메타 등록 → presigned upload URL 반환
  2. PUT    presigned URL                    파일 바이트를 S3(MinIO)에 직접 올림
  3. PATCH  /attachments/{pk}/               is_uploaded=True 로 표시
3단계를 빠뜨리면 목록 조회(is_uploaded=True 필터)에 안 잡힌다.

다운로드도 같은 구조다. SaaS 첨부는 presigned URL 로 받아야 한다.

사용:
    python3 scripts/migrate_attachments.py --dry-run
    python3 scripts/migrate_attachments.py
"""

import argparse
import json
import sys
import uuid
import time
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

SAAS = "https://api.plane.so/api/v1"
SAAS_WS = "my-saas-workspace"
SELFHOST = "http://192.0.2.10:8080/api/v1"
SELFHOST_WS = "my-workspace"

DUMP = Path(__file__).resolve().parent.parent / "migration-dump"
FILES = DUMP / "files"
STATE = DUMP / "_migration_state.json"
ATT_STATE = DUMP / "_attachments_state.json"

EXTERNAL_SOURCE = "plane-saas"
THROTTLE = 1.1

SAAS_PROJECTS = {
    "PROJB": "<PROJB_ID_SRC>",
    "PROJA": "<PROJA_ID_SRC>",
    "PROJC": "<PROJC_ID_DST>",
}
SH_PROJECTS = {
    "PROJB": "<PROJB_ID_DST>",
    "PROJA": "<PROJA_ID_DST>",
    "PROJC": "<PROJC_ID_SRC>",
}

# Cloudflare 가 Python 기본 UA 를 Error 1010 으로 막는다.
UA = "plane-migrate/1.0 (+internal tooling)"


def tokens() -> tuple[str, str]:
    env = Path.home() / ".config/plane-migrate/selfhost.env"
    saas = sh = None
    for line in env.read_text(encoding="utf-8").splitlines():
        if line.startswith("PLANE_SAAS_TOKEN="):
            saas = line.split("=", 1)[1].strip()
        elif line.startswith("PLANE_SELFHOST_TOKEN="):
            sh = line.split("=", 1)[1].strip()
    if not (saas and sh):
        sys.exit("토큰 두 개가 모두 필요합니다 (PLANE_SAAS_TOKEN, PLANE_SELFHOST_TOKEN)")
    return saas, sh


SAAS_TOKEN, SH_TOKEN = tokens()


def api(base: str, token: str, method: str, path: str, body=None, retries: int = 4):
    url = f"{base}{path}"
    payload = json.dumps(body).encode("utf-8") if body is not None else None
    headers = {"X-API-Key": token, "Accept": "application/json", "User-Agent": UA}
    if payload:
        headers["Content-Type"] = "application/json"

    for attempt in range(1, retries + 1):
        try:
            with urlopen(Request(url, data=payload, headers=headers, method=method), timeout=90) as r:
                raw = r.read().decode("utf-8")
                return r.status, (json.loads(raw) if raw else None)
        except HTTPError as e:
            raw = e.read().decode("utf-8", "replace")
            try:
                data = json.loads(raw)
            except Exception:
                data = {"raw": raw[:300]}
            if e.code == 429:
                time.sleep(12 * attempt)
                continue
            return e.code, data
        except URLError:
            if attempt == retries:
                raise
            time.sleep(3 * attempt)
    return 0, None


def download(url: str, dest: Path) -> int:
    """presigned URL 은 인증 헤더 없이 받는다 — 서명이 곧 인증이다."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    with urlopen(Request(url, headers={"User-Agent": UA}), timeout=300) as r:
        data = r.read()
    dest.write_bytes(data)
    return len(data)


def s3_post_upload(url: str, fields: dict, path: Path, content_type: str) -> int:
    """
    S3 presigned POST 폼 업로드.

    PUT 이 아니다. presigned 정책(policy·signature)이 폼 필드로 오고,
    그 필드들을 file 앞에 순서대로 넣어야 서명 검증을 통과한다.
    """
    boundary = "----planeMigrate" + uuid.uuid4().hex
    body = bytearray()

    def part(name: str, value: str):
        body.extend(f"--{boundary}\r\n".encode())
        body.extend(f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode())
        body.extend(f"{value}\r\n".encode())

    for k, v in fields.items():        # 정책 필드가 file 보다 먼저 와야 한다
        part(k, str(v))

    body.extend(f"--{boundary}\r\n".encode())
    body.extend(
        f'Content-Disposition: form-data; name="file"; filename="{path.name}"\r\n'.encode()
    )
    body.extend(f"Content-Type: {content_type}\r\n\r\n".encode())
    body.extend(path.read_bytes())
    body.extend(f"\r\n--{boundary}--\r\n".encode())

    req = Request(url, data=bytes(body), method="POST", headers={
        "Content-Type": f"multipart/form-data; boundary={boundary}",
        "User-Agent": UA,
    })
    with urlopen(req, timeout=600) as r:
        return r.status


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if not STATE.exists():
        sys.exit("작업 항목 이관 상태가 없습니다 — migrate_to_selfhost.py 를 먼저 실행하세요")
    items_state = json.loads(STATE.read_text(encoding="utf-8"))
    done = json.loads(ATT_STATE.read_text(encoding="utf-8")) if ATT_STATE.exists() else {}

    plan = []
    for ident, saas_pid in SAAS_PROJECTS.items():
        f = DUMP / f"{ident}.attachments.json"
        if not f.exists():
            continue
        scanned = json.loads(f.read_text(encoding="utf-8"))
        item_map = items_state.get(ident, {}).get("items", {})
        for saas_iid, atts in scanned.items():
            for a in atts:
                if a["id"] in done:
                    continue
                new_iid = item_map.get(saas_iid)
                if not new_iid:
                    print(f"  ⚠ 대응 작업 항목 없음: {a['id']}")
                    continue
                plan.append((ident, saas_pid, saas_iid, new_iid, a))

    print(f"이관 대상 첨부 {len(plan)}개 (이미 완료 {len(done)}개)")
    for ident, _, _, _, a in plan:
        attr = a.get("attributes", {})
        size = attr.get("size") or 0
        print(f"  [{ident}] {str(attr.get('name'))[:44]:46} {size/1024:.0f}KB")
    if args.dry_run or not plan:
        return

    FILES.mkdir(parents=True, exist_ok=True)
    ok = fail = 0

    for ident, saas_pid, saas_iid, new_iid, a in plan:
        attr = a.get("attributes", {})
        name = attr.get("name") or "attachment"
        ctype = attr.get("type") or "application/octet-stream"
        size = attr.get("size") or 0
        print(f"\n[{ident}] {name}")

        # ---- 1. SaaS 에서 다운로드 (presigned URL 획득 후) ----
        local = FILES / f"{a['id']}__{name}"
        if not local.exists():
            # 상세 엔드포인트는 JSON 이 아니라 presigned URL 로 302 리다이렉트한다.
            # urlopen 이 리다이렉트를 따라가므로 그대로 파일 바이트가 온다.
            url = (f"{SAAS}/workspaces/{SAAS_WS}/projects/{saas_pid}"
                   f"/work-items/{saas_iid}/attachments/{a['id']}/")
            try:
                req = Request(url, headers={"X-API-Key": SAAS_TOKEN, "User-Agent": UA})
                with urlopen(req, timeout=300) as r:
                    data = r.read()
                local.parent.mkdir(parents=True, exist_ok=True)
                local.write_bytes(data)
                print(f"  다운로드 {len(data)/1024:.0f}KB")
            except Exception as e:
                print(f"  ⚠ 다운로드 실패: {e}")
                fail += 1
                continue
            time.sleep(THROTTLE)
        else:
            print(f"  다운로드 생략 (이미 있음 {local.stat().st_size/1024:.0f}KB)")

        # ---- 2. self-host 에 메타 등록 → presigned upload URL ----
        base = f"/workspaces/{SELFHOST_WS}/projects/{SH_PROJECTS[ident]}"
        code, res = api(SELFHOST, SH_TOKEN, "POST", f"{base}/work-items/{new_iid}/attachments/",
                        {"name": name, "type": ctype, "size": local.stat().st_size,
                         "external_id": a["id"], "external_source": EXTERNAL_SOURCE})
        time.sleep(THROTTLE)

        # 409는 같은 external_id 레코드가 이미 있다는 뜻인데, 앞선 실행이
        # 메타만 등록하고 업로드에 실패한 껍데기일 수 있다. 그 경우 목록에
        # 안 잡히므로(is_uploaded 필터) 지우고 새로 만든다.
        if code == 409 and isinstance(res, dict) and res.get("id"):
            stale = res["id"]
            dcode, _ = api(SELFHOST, SH_TOKEN, "DELETE",
                           f"{base}/work-items/{new_iid}/attachments/{stale}/")
            time.sleep(THROTTLE)
            print(f"  기존 미완료 레코드 제거 (HTTP {dcode}) — 재등록")
            code, res = api(SELFHOST, SH_TOKEN, "POST", f"{base}/work-items/{new_iid}/attachments/",
                            {"name": name, "type": ctype, "size": local.stat().st_size,
                             "external_id": a["id"], "external_source": EXTERNAL_SOURCE})
            time.sleep(THROTTLE)
        if code not in (200, 201) or not isinstance(res, dict):
            print(f"  ⚠ 메타 등록 실패 → HTTP {code} {str(res)[:200]}")
            fail += 1
            continue

        # 응답 구조: {upload_data:{url, fields:{...}}, asset_id, attachment:{...}}
        asset_id = res.get("asset_id") or (res.get("attachment") or {}).get("id")
        up = res.get("upload_data") or {}
        upload_url, fields = up.get("url"), up.get("fields") or {}

        if not (upload_url and asset_id):
            print(f"  ⚠ 업로드 정보 없음 — 응답 키: {list(res.keys())}")
            fail += 1
            continue

        # ---- 3. S3(MinIO) 에 presigned POST 폼 업로드 ----
        try:
            st = s3_post_upload(upload_url, fields, local, ctype)
            print(f"  업로드 HTTP {st}")
        except Exception as e:
            print(f"  ⚠ 업로드 실패: {e}")
            fail += 1
            continue

        # ---- 4. 완료 표시 (없으면 목록에 안 잡힌다) ----
        code, res2 = api(SELFHOST, SH_TOKEN, "PATCH", f"{base}/work-items/{new_iid}/attachments/{asset_id}/", {})
        time.sleep(THROTTLE)
        if code in (200, 204):
            done[a["id"]] = asset_id
            ok += 1
            print("  ✅ 완료")
        else:
            print(f"  ⚠ 완료 처리 실패 → HTTP {code} {str(res2)[:200]}")
            fail += 1

        ATT_STATE.write_text(json.dumps(done, ensure_ascii=False, indent=2), encoding="utf-8")

    ATT_STATE.write_text(json.dumps(done, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\n완료 {ok} / 실패 {fail}")


if __name__ == "__main__":
    main()
