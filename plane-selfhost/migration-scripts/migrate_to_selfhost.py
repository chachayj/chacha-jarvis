#!/usr/bin/env python3
"""
SaaS 덤프 → self-host 이관

dump_saas.py 가 만든 JSON을 입력으로 self-host 인스턴스에 재생성한다.

핵심 설계
---------
재실행 안전: 모든 작업 항목에 external_id(원본 SaaS id) + external_source 를 박는다.
Plane의 공개 API는 같은 (external_source, external_id) 조합이 이미 있으면
409와 함께 기존 id를 돌려주므로, 여러 번 돌려도 중복이 생기지 않는다.

작성자·작성일 보존: Plane API는 created_at / created_by 를 request body 로 받아
serializer 저장 후 덮어쓴다(plane/api/views/issue.py). OpenAPI 스펙은 created_at 을
readOnly 로 표시하지만 실제 구현은 받는다 — 스펙이 기능을 과소 보고하는 경우다.

2-pass: 부모-자식 관계는 부모가 먼저 존재해야 하므로, 1패스에서 전부 생성하고
2패스에서 parent 를 연결한다.

사용:
    python3 scripts/migrate_to_selfhost.py --dry-run          # 계획만 출력
    python3 scripts/migrate_to_selfhost.py --project PROJC    # 8건으로 시험
    python3 scripts/migrate_to_selfhost.py                    # 전체
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

EXTERNAL_SOURCE = "plane-saas"

# SaaS 프로젝트 → self-host 프로젝트. PROJC 은 self-host 에서 identifier 가 MXSPA 다.
# PROJD 는 self-host 에 대응 프로젝트가 없어 제외한다.
PROJECT_MAP = {
    "PROJB":  "<PROJB_ID_DST>",
    "PROJA": "<PROJA_ID_DST>",
    "PROJC":  "<PROJC_ID_SRC>",  # → MXSPA
}

# self-host 에 계정이 있는 사람만 담당자·작성자로 넘길 수 있다.
# 없는 사용자를 넘기면 FK 위반이 나므로 담당자는 비우고 작성자는 토큰 소유자로 대체한다.
MAPPABLE_EMAILS = {"dev1@example.com", "dev2@example.com", "dev3@example.com"}

# self-host 의 API_KEY_RATE_LIMIT 기본값이 60/minute 이다.
# 0.3초(분당 200회)로 돌렸다가 429로 9건이 실패했으므로 1초 이상 둔다.
THROTTLE_SEC = 1.1

HEADERS_BASE = {
    "Accept": "application/json",
    "Content-Type": "application/json",
    "User-Agent": "plane-migrate/1.0 (+internal tooling)",
}


def load_token() -> str:
    env = Path.home() / ".config/plane-migrate/selfhost.env"
    if not env.exists():
        sys.exit(f"토큰 파일이 없습니다: {env}")
    for line in env.read_text(encoding="utf-8").splitlines():
        if line.startswith("PLANE_SELFHOST_TOKEN="):
            return line.split("=", 1)[1].strip()
    sys.exit("PLANE_SELFHOST_TOKEN 을 찾지 못했습니다")


TOKEN = load_token()


def call(method: str, path: str, body=None, retries: int = 5):
    """반환: (status, data). 409는 이미 존재하는 경우라 정상 흐름으로 다룬다."""
    url = f"{SELFHOST}{path}"
    payload = json.dumps(body).encode("utf-8") if body is not None else None
    headers = dict(HEADERS_BASE, **{"X-API-Key": TOKEN})

    for attempt in range(1, retries + 1):
        req = Request(url, data=payload, headers=headers, method=method)
        try:
            with urlopen(req, timeout=60) as r:
                raw = r.read().decode("utf-8")
                return r.status, (json.loads(raw) if raw else None)
        except HTTPError as e:
            raw = e.read().decode("utf-8", "replace")
            try:
                data = json.loads(raw)
            except Exception:
                data = {"raw": raw[:300]}
            if e.code == 429:
                time.sleep(15 * attempt)  # 1분 창이 지나야 풀린다
                continue
            return e.code, data
        except URLError:
            if attempt == retries:
                raise
            time.sleep(2 * attempt)
    return 0, None


def rows_of(data) -> list:
    """엔드포인트마다 응답 형태가 다르다 — members는 리스트, projects는 {results:[...]}."""
    if data is None:
        return []
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        return data.get("results", [])
    return []


class State:
    """이관 진행 상태. 중단 후 재개와 재실행 안전성을 담당한다."""

    def __init__(self):
        self.data = json.loads(STATE_FILE.read_text(encoding="utf-8")) if STATE_FILE.exists() else {}

    def get(self, project: str) -> dict:
        return self.data.setdefault(project, {"items": {}, "states": {}, "labels": {}})

    def save(self):
        STATE_FILE.write_text(json.dumps(self.data, ensure_ascii=False, indent=2), encoding="utf-8")


def build_member_map(dump: Path) -> dict:
    """SaaS user id → self-host user id. 매핑 불가한 사용자는 담지 않는다."""
    saas = json.loads((dump / "members.json").read_text(encoding="utf-8"))
    saas_id2email = {m["id"]: m.get("email", "") for m in saas}

    status, data = call("GET", f"/workspaces/{WORKSPACE}/members/")
    if status != 200:
        sys.exit(f"self-host 멤버 조회 실패: HTTP {status} {data}")
    sh_email2id = {m.get("email", ""): m.get("id") for m in rows_of(data)}

    out = {}
    for sid, email in saas_id2email.items():
        if email in MAPPABLE_EMAILS and email in sh_email2id:
            out[sid] = sh_email2id[email]
    return out


def ensure_states(project: str, sh_pid: str, saas_states: list, st: dict) -> dict:
    """SaaS 상태 → self-host 상태 id. 이름이 같으면 재사용하고 없으면 만든다."""
    status, data = call("GET", f"/workspaces/{WORKSPACE}/projects/{sh_pid}/states/")
    existing = {s["name"].lower(): s["id"] for s in rows_of(data)} if status == 200 else {}

    mapping = {}
    for s in saas_states:
        key = s["name"].lower()
        if key in existing:
            mapping[s["id"]] = existing[key]
            continue
        code, res = call("POST", f"/workspaces/{WORKSPACE}/projects/{sh_pid}/states/",
                         {"name": s["name"], "group": s["group"], "color": s.get("color", "#666")})
        time.sleep(THROTTLE_SEC)
        if code in (200, 201) and res:
            mapping[s["id"]] = res["id"]
            print(f"    상태 생성: {s['name']} ({s['group']})")
        else:
            print(f"    ⚠ 상태 생성 실패: {s['name']} → HTTP {code} {res}")
    st["states"] = mapping
    return mapping


def ensure_labels(project: str, sh_pid: str, saas_labels: list, st: dict) -> dict:
    status, data = call("GET", f"/workspaces/{WORKSPACE}/projects/{sh_pid}/labels/")
    existing = {l["name"].lower(): l["id"] for l in rows_of(data)} if status == 200 else {}

    mapping = {}
    for l in saas_labels:
        key = l["name"].lower()
        if key in existing:
            mapping[l["id"]] = existing[key]
            continue
        code, res = call("POST", f"/workspaces/{WORKSPACE}/projects/{sh_pid}/labels/",
                         {"name": l["name"], "color": l.get("color") or "#666"})
        time.sleep(THROTTLE_SEC)
        if code in (200, 201) and res:
            mapping[l["id"]] = res["id"]
            print(f"    라벨 생성: {l['name']}")
        else:
            print(f"    ⚠ 라벨 생성 실패: {l['name']} → HTTP {code} {res}")
    st["labels"] = mapping
    return mapping


def migrate_project(ident: str, dump: Path, members: dict, state: State, dry: bool):
    bulk_path = dump / f"{ident}.bulk.json"
    if not bulk_path.exists():
        print(f"[{ident}] 덤프가 없습니다 — dump_saas.py 를 먼저 실행하세요")
        return

    bulk = json.loads(bulk_path.read_text(encoding="utf-8"))
    sh_pid = PROJECT_MAP[ident]
    items = bulk["work_items"]
    st = state.get(ident)

    print(f"\n=== {ident} → self-host {sh_pid[:8]}… ({len(items)}건) ===")

    if dry:
        n_asg = sum(1 for it in items for a in (it.get("assignees") or []) if a in members)
        n_cb = sum(1 for it in items if it.get("created_by") in members)
        n_parent = sum(1 for it in items if it.get("parent"))
        print(f"  상태 {len(bulk['states'])} / 라벨 {len(bulk['labels'])} 매핑 필요")
        print(f"  담당자 보존 {n_asg} · 작성자 보존 {n_cb} · 부모연결 {n_parent}")
        print(f"  이미 이관됨: {len(st['items'])}건")
        return

    state_map = ensure_states(ident, sh_pid, bulk["states"], st)
    label_map = ensure_labels(ident, sh_pid, bulk["labels"], st)
    state.save()

    base = f"/workspaces/{WORKSPACE}/projects/{sh_pid}"

    # ---- 1패스: 작업 항목 생성 (parent 제외) ----
    created = skipped = failed = 0
    for n, it in enumerate(items, 1):
        sid = it["id"]
        if sid in st["items"]:
            skipped += 1
            continue

        body = {
            "name": it.get("name") or "(제목 없음)",
            "description_html": it.get("description_html") or "<p></p>",
            "priority": it.get("priority") or "none",
            "external_id": sid,
            "external_source": EXTERNAL_SOURCE,
        }
        if it.get("state") in state_map:
            body["state"] = state_map[it["state"]]
        if it.get("start_date"):
            body["start_date"] = it["start_date"]
        if it.get("target_date"):
            body["target_date"] = it["target_date"]
        if it.get("created_at"):
            body["created_at"] = it["created_at"]
        if it.get("created_by") in members:
            body["created_by"] = members[it["created_by"]]

        asg = [members[a] for a in (it.get("assignees") or []) if a in members]
        if asg:
            body["assignees"] = asg
        lbl = [label_map[l] for l in (it.get("labels") or []) if l in label_map]
        if lbl:
            body["labels"] = lbl

        code, res = call("POST", f"{base}/work-items/", body)
        time.sleep(THROTTLE_SEC)

        if code in (200, 201) and res:
            st["items"][sid] = res["id"]
            created += 1
        elif code == 409 and isinstance(res, dict) and res.get("id"):
            st["items"][sid] = res["id"]  # 이미 있음 — 재실행 안전장치가 동작한 것
            skipped += 1
        else:
            failed += 1
            print(f"  ⚠ 생성 실패 [{it.get('sequence_id')}] {str(it.get('name'))[:40]} → HTTP {code} {res}")

        if n % 25 == 0:
            state.save()
            print(f"  {n}/{len(items)}  생성 {created} 건너뜀 {skipped} 실패 {failed}")

    state.save()
    print(f"  1패스 완료 — 생성 {created} / 건너뜀 {skipped} / 실패 {failed}")

    # ---- 2패스: 부모-자식 연결 ----
    linked = 0
    for it in items:
        parent = it.get("parent")
        if not parent:
            continue
        child_new = st["items"].get(it["id"])
        parent_new = st["items"].get(parent)
        if not (child_new and parent_new):
            continue
        code, _ = call("PATCH", f"{base}/work-items/{child_new}/", {"parent": parent_new})
        time.sleep(THROTTLE_SEC)
        if code in (200, 201):
            linked += 1
    print(f"  2패스 완료 — 부모 연결 {linked}건")
    state.save()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--project", help="특정 프로젝트만 (PROJB/PROJA/PROJC)")
    ap.add_argument("--dry-run", action="store_true", help="계획만 출력하고 아무것도 만들지 않음")
    args = ap.parse_args()

    targets = [args.project] if args.project else list(PROJECT_MAP)
    for t in targets:
        if t not in PROJECT_MAP:
            sys.exit(f"알 수 없는 프로젝트: {t} (가능: {', '.join(PROJECT_MAP)})")

    members = build_member_map(DUMP_DIR)
    print(f"멤버 매핑 {len(members)}명 확보")

    state = State()
    start = time.time()
    for t in targets:
        migrate_project(t, DUMP_DIR, members, state, args.dry_run)
    print(f"\n완료 — {int(time.time() - start)}초")
    if not args.dry_run:
        print(f"진행 상태: {STATE_FILE}")


if __name__ == "__main__":
    main()
