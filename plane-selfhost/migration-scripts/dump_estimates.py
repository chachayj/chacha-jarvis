#!/usr/bin/env python3
"""
SaaS estimate 덤프 (MCP 경유)

estimate 는 공개 REST API v1 에 없고 내부 API(/api/...)는 세션 전용이다.
SaaS 세션은 없으므로 읽기는 MCP 의 project_estimate 도구로 한다.

결과: migration-dump/estimates.json
"""

import json
import sys
import time
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DUMP = REPO / "migration-dump"
OUT = DUMP / "estimates.json"

PROJECTS = {
    "PROJB": "<PROJB_ID_SRC>",
    "PROJA": "<PROJA_ID_SRC>",
    "PROJC": "<PROJC_ID_DST>",
}

THROTTLE = 0.6
_id = 0


def mcp():
    cfg = json.loads((REPO / ".mcp.json").read_text(encoding="utf-8"))["mcpServers"]["plane"]
    h = dict(cfg["headers"])
    h.update({"Content-Type": "application/json",
              "Accept": "application/json, text/event-stream",
              "User-Agent": "plane-migrate/1.0 (+internal tooling)"})
    return cfg["url"], h


URL, HEADERS = mcp()


def rpc(method: str, params=None):
    global _id
    _id += 1
    body = json.dumps({"jsonrpc": "2.0", "id": _id, "method": method,
                       "params": params or {}}).encode("utf-8")
    with urllib.request.urlopen(
            urllib.request.Request(URL, data=body, headers=HEADERS, method="POST"), timeout=90) as r:
        raw = r.read().decode("utf-8")
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
    for c in res.get("result", {}).get("content", []):
        if c.get("type") != "text":
            continue
        try:
            data = json.loads(c["text"])
        except json.JSONDecodeError:
            # estimate 가 없는 프로젝트는 JSON 이 아니라 사람이 읽는 오류 문구를 준다.
            return {"_error": c["text"][:200]}
        # 서버 버전에 따라 한 겹 더 감싸기도 한다
        if isinstance(data, dict) and "result" in data and "results" not in data:
            return data["result"]
        return data
    return None


def main():
    rpc("initialize", {"protocolVersion": "2024-11-05", "capabilities": {},
                       "clientInfo": {"name": "plane-migrate", "version": "1"}})

    out = {}
    for ident, pid in PROJECTS.items():
        est = call_tool("project_estimate", {"action": "retrieve", "project_id": pid})
        time.sleep(THROTTLE)
        if not est or not est.get("id"):
            why = (est or {}).get("_error", "")
            print(f"{ident:8} estimate 없음 {('— ' + why) if why else ''}")
            continue
        points = call_tool("project_estimate", {"action": "list_points",
                                                "project_id": pid,
                                                "estimate_id": est["id"]}) or []
        time.sleep(THROTTLE)
        if isinstance(points, dict):
            points = points.get("results", [])

        # 실제 사용 건수 — 정의만 옮겨도 의미가 있는지 판단 근거가 된다
        used = 0
        bulk_path = DUMP / f"{ident}.bulk.json"
        if bulk_path.exists():
            bulk = json.loads(bulk_path.read_text(encoding="utf-8"))
            used = sum(1 for it in bulk["work_items"] if it.get("estimate_point"))

        out[ident] = {"estimate": est, "points": points, "_used_count": used}
        vals = ", ".join(str(p.get("value")) for p in sorted(points, key=lambda x: x.get("key", 0)))
        print(f"{ident:8} {est['name']} ({est['type']}) — 포인트 {len(points)}개 [{vals}], 사용 {used}건")

    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\n→ {OUT}")


if __name__ == "__main__":
    main()
