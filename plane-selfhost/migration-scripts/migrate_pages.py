#!/usr/bin/env python3
"""
페이지 이관 (세션 인증)

페이지는 공개 REST API v1 에 엔드포인트가 없다. 내부 API 전용이라
세션 로그인이 필요하다(plane_session.py).

이미지는 옮기지 않는다
-----------------------
페이지 본문의 이미지·첨부는 asset id 로 참조되는데, SaaS 에서 그 파일을
받을 경로가 없다:
  - 공개 API v1 /workspaces/{slug}/assets/{id}/  → 404
  - static 서빙 /assets/v2/static/{id}/          → 400
    (아바타·로고·커버만 허용, PAGE_DESCRIPTION 은 거부)
  - 내부 API 다운로드                             → SaaS 세션이 없음
  - MCP                                          → 페이지 asset 도구 없음

그래서 이미지·첨부 컴포넌트는 빈 상자로 남기지 않고 "원본에 있었다"는
표시로 치환한다. 나중에 수동으로 채울 때 어디에 뭐가 있었는지 알 수 있다.

사용:
    python3 scripts/migrate_pages.py --dry-run
    python3 scripts/migrate_pages.py
"""

import argparse
import json
import re
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from plane_session import Session, rows_of  # noqa: E402

DUMP = Path(__file__).resolve().parent.parent / "migration-dump"
PAGES = DUMP / "pages.json"
STATE = DUMP / "_pages_state.json"

# SaaS 프로젝트 → self-host 프로젝트
PROJECT_MAP = {
    "PROJB": "<PROJB_ID_DST>",
    "PROJA": "<PROJA_ID_DST>",
    "PROJC": "<PROJC_ID_SRC>",
}

THROTTLE = 1.1

IMG_RE = re.compile(r"<image-component\b[^>]*>(?:</image-component>)?", re.I)
ATT_RE = re.compile(r"<attachment-component\b[^>]*>(?:</attachment-component>)?", re.I)

NOTE_IMG = ('<p class="editor-paragraph-block">'
            "<em>[원본에 이미지가 있었습니다 — SaaS 이관 시 옮기지 못했습니다]</em></p>")
NOTE_ATT = ('<p class="editor-paragraph-block">'
            "<em>[원본에 첨부파일이 있었습니다 — SaaS 이관 시 옮기지 못했습니다]</em></p>")


def strip_assets(html: str) -> tuple[str, int, int]:
    """이미지·첨부 컴포넌트를 안내 문구로 치환. 반환: (html, 이미지수, 첨부수)"""
    n_img = len(IMG_RE.findall(html))
    n_att = len(ATT_RE.findall(html))
    html = IMG_RE.sub(NOTE_IMG, html)
    html = ATT_RE.sub(NOTE_ATT, html)
    return html, n_img, n_att


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if not PAGES.exists():
        sys.exit(f"페이지 덤프가 없습니다: {PAGES}\n  dump_pages.py 를 먼저 실행하세요")

    pages = json.loads(PAGES.read_text(encoding="utf-8"))
    st = json.loads(STATE.read_text(encoding="utf-8")) if STATE.exists() else {}

    # 워크스페이스 페이지는 self-host 에도 워크스페이스 페이지로,
    # 프로젝트 페이지는 대응 프로젝트로 넣는다.
    plan = []
    for pid, p in pages.items():
        scope = p.get("_scope")
        if scope == "__workspace__":
            plan.append((pid, p, None))
        elif scope in PROJECT_MAP:
            plan.append((pid, p, PROJECT_MAP[scope]))

    print(f"이관 대상 페이지 {len(plan)}개 (이미 완료 {len(st)}개)\n")

    s = None
    if not args.dry_run:
        s = Session()
        code, me = s.call("GET", "/api/users/me/")
        print(f"세션 로그인 — {me.get('email')}\n")

    ok = skip = fail = 0
    tot_img = tot_att = 0

    for pid, p, sh_pid in plan:
        name = p.get("name") or "(제목 없음)"
        html = p.get("description_html") or "<p></p>"
        html, n_img, n_att = strip_assets(html)
        tot_img += n_img
        tot_att += n_att

        marks = []
        if n_img:
            marks.append(f"이미지 {n_img}")
        if n_att:
            marks.append(f"첨부 {n_att}")
        tag = f"  ({', '.join(marks)} → 안내 문구로 치환)" if marks else ""
        scope = p.get("_scope")
        print(f"  [{scope:12}] {name[:38]:40} {len(html):>7}b{tag}")

        if args.dry_run:
            continue
        if pid in st:
            skip += 1
            continue

        # description_binary 는 넘기지 않는다.
        #
        # 모델에서 BinaryField 라 base64 문자열을 그대로 주면
        # "bytes or buffer expected, got <class 'str'>" 로 500 이 난다.
        # 게다가 이 값은 원본 이미지 asset id 를 품은 에디터 스냅샷이라,
        # 이미지를 안 옮기는 지금은 HTML 과 어긋나 오히려 해가 된다.
        # Plane 이 description_html 로부터 다시 만들어 준다.
        body = {"name": name, "description_html": html}

        path = (s.ws(f"/projects/{sh_pid}/pages/") if sh_pid else s.ws("/pages/"))
        code, res = s.call("POST", path, body)
        time.sleep(THROTTLE)

        if code in (200, 201) and isinstance(res, dict) and res.get("id"):
            st[pid] = res["id"]
            ok += 1
            STATE.write_text(json.dumps(st, ensure_ascii=False, indent=2), encoding="utf-8")
        else:
            fail += 1
            print(f"      ⚠ 실패 → HTTP {code} {str(res)[:180]}")

    if not args.dry_run:
        STATE.write_text(json.dumps(st, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"\n생성 {ok} / 건너뜀 {skip} / 실패 {fail}")
    print(f"치환된 이미지 {tot_img}개 · 첨부 {tot_att}개")


if __name__ == "__main__":
    main()
