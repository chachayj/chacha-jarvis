#!/usr/bin/env python3
"""
SaaS 페이지 덤프 (MCP 경유)

페이지는 공개 REST API v1 에 엔드포인트가 없다. 내부 API 에만 있고 그건
세션 인증 전용이라 API 키가 안 통한다.

그런데 Plane 이 운영하는 MCP 서버(mcp.plane.so)에는 page 도구가 있다.
MCP 는 JSON-RPC over HTTP 라 스크립트에서 직접 부를 수 있다 —
그래서 읽기는 MCP 로 해결한다.

결과: migration-dump/pages.json

주의: MCP 는 SaaS 에만 연결돼 있다. self-host 에는 MCP 서버가 없으므로
(소스에도 없음) 쓰기는 세션 로그인 스크립트가 담당한다.
"""

import json
import sys
import time
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DUMP = REPO / "migration-dump"
OUT = DUMP / "pages.json"

# SaaS 프로젝트. PROJA 는 페이지가 0개라 넣어도 무해하다.
PROJECTS = {
    "PROJB": "<PROJB_ID_SRC>",
    "PROJA": "<PROJA_ID_SRC>",
    "PROJC": "<PROJC_ID_DST>",
}

THROTTLE = 0.6


def mcp_config() -> tuple[str, dict]:
    cfg = json.loads((REPO / ".mcp.json").read_text(encoding="utf-8"))["mcpServers"]["plane"]
    headers = dict(cfg["headers"])
    headers.update({
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
        "User-Agent": "plane-migrate/1.0 (+internal tooling)",
    })
    return cfg["url"], headers


URL, HEADERS = mcp_config()
_id = 0


def rpc(method: str, params=None):
    global _id
    _id += 1
    body = json.dumps({"jsonrpc": "2.0", "id": _id, "method": method,
                       "params": params or {}}).encode("utf-8")
    req = urllib.request.Request(URL, data=body, headers=HEADERS, method="POST")
    with urllib.request.urlopen(req, timeout=90) as r:
        raw = r.read().decode("utf-8")
    # 서버가 SSE 로 답할 때가 있다 — data: 줄만 골라낸다.
    if raw.lstrip().startswith("event:") or "\ndata: " in raw:
        for line in raw.splitlines():
            if line.startswith("data: "):
                raw = line[6:]
                break
    return json.loads(raw)


def call_tool(name: str, args: dict):
    res = rpc("tools/call", {"name": name, "arguments": args})
    if "error" in res:
        raise RuntimeError(res["error"])
    content = res.get("result", {}).get("content", [])
    for c in content:
        if c.get("type") == "text":
            data = json.loads(c["text"])
            # 서버 버전에 따라 {"result": {...}} 로 한 겹 더 감싸기도 하고
            # 결과를 그대로 주기도 한다. 둘 다 받는다.
            if isinstance(data, dict) and "result" in data and "results" not in data:
                return data["result"]
            return data
    return None


def main():
    rpc("initialize", {"protocolVersion": "2024-11-05", "capabilities": {},
                       "clientInfo": {"name": "plane-migrate", "version": "1"}})

    out = json.loads(OUT.read_text(encoding="utf-8")) if OUT.exists() else {}
    total = 0

    # 워크스페이스 페이지 + 프로젝트별 페이지
    scopes = [("__workspace__", None)] + list(PROJECTS.items())

    for label, pid in scopes:
        args = {"action": "list", "per_page": 100}
        if pid:
            args["project_id"] = pid
        listing = call_tool("page", args)
        time.sleep(THROTTLE)
        rows = (listing or {}).get("results", [])
        print(f"\n=== {label} — 페이지 {len(rows)}개 ===")

        for p in rows:
            pid_key = p["id"]
            if pid_key in out:
                total += 1
                continue
            args = {"action": "retrieve", "page_id": pid_key}
            if pid:
                args["project_id"] = pid
            full = call_tool("page", args)
            time.sleep(THROTTLE)
            if not full:
                print(f"  ⚠ 본문 실패: {p.get('name')}")
                continue
            full["_scope"] = label
            full["_project_id"] = pid
            out[pid_key] = full
            total += 1
            html = full.get("description_html") or ""
            print(f"  {str(full.get('name'))[:44]:46} {len(html):>7} bytes")
            OUT.write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")

    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")

    # 본문에 박힌 이미지·첨부 컴포넌트 집계 — 이관 시 asset 재업로드가 필요한 대상이다.
    imgs = sum((full.get("description_html") or "").count("<image-component") for full in out.values())
    atts = sum((full.get("description_html") or "").count("<attachment-component") for full in out.values())
    print(f"\n페이지 {total}개 저장 → {OUT}")
    print(f"본문 내 이미지 컴포넌트 {imgs}개 · 첨부 컴포넌트 {atts}개")


if __name__ == "__main__":
    main()
