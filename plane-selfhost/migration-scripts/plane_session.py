#!/usr/bin/env python3
"""
self-host 내부 API 세션 클라이언트

페이지·뷰·estimate 는 공개 REST API v1 에 엔드포인트가 없다.
내부 API(/api/...)에만 있고 그건 BaseSessionAuthentication 만 받으므로
API 키가 통하지 않는다 — 브라우저처럼 로그인해서 세션 쿠키를 얻어야 한다.

로그인 흐름:
  GET  /auth/get-csrf-token/   csrftoken 쿠키 획득
  POST /auth/sign-in/          form (email, password, csrfmiddlewaretoken)
  → session-id 쿠키

전용 계정(migrate-bot)을 쓴다. 사람 계정 비밀번호를 스크립트에 물리지 않기 위함이다.

자격 증명은 ~/.config/plane-migrate/selfhost.env (권한 600):
  PLANE_SELFHOST_EMAIL=bot@example.com
  PLANE_SELFHOST_PASSWORD=...
"""

import http.cookiejar
import json
import sys
import urllib.parse
import urllib.request
from pathlib import Path

BASE = "http://192.0.2.10:8080"
WORKSPACE = "my-workspace"
UA = "plane-migrate/1.0 (+internal tooling)"

ENV = Path.home() / ".config/plane-migrate/selfhost.env"


def load_env() -> dict:
    if not ENV.exists():
        sys.exit(f"자격 증명 파일이 없습니다: {ENV}")
    out = {}
    for line in ENV.read_text(encoding="utf-8").splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            k, v = line.split("=", 1)
            out[k.strip()] = v.strip()
    return out


class Session:
    """세션 쿠키로 내부 API 를 호출하는 최소 클라이언트."""

    def __init__(self):
        env = load_env()
        self.email = env.get("PLANE_SELFHOST_EMAIL")
        password = env.get("PLANE_SELFHOST_PASSWORD")
        if not (self.email and password):
            sys.exit("PLANE_SELFHOST_EMAIL / PLANE_SELFHOST_PASSWORD 가 필요합니다")

        self.jar = http.cookiejar.CookieJar()
        self.op = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(self.jar))

        self.op.open(urllib.request.Request(
            f"{BASE}/auth/get-csrf-token/", headers={"User-Agent": UA}), timeout=30)
        self.csrf = next((c.value for c in self.jar if c.name == "csrftoken"), None)
        if not self.csrf:
            sys.exit("csrftoken 을 얻지 못했습니다")

        data = urllib.parse.urlencode({
            "email": self.email, "password": password,
            "csrfmiddlewaretoken": self.csrf,
        }).encode()
        self.op.open(urllib.request.Request(
            f"{BASE}/auth/sign-in/", data=data, method="POST", headers={
                "User-Agent": UA,
                "Content-Type": "application/x-www-form-urlencoded",
                "Referer": f"{BASE}/",
                "X-CSRFTOKEN": self.csrf,
            }), timeout=30)

        if not any(c.name == "session-id" for c in self.jar):
            sys.exit("로그인 실패 — 이메일/비밀번호와 워크스페이스 멤버십을 확인하세요")

    def call(self, method: str, path: str, body=None):
        """반환: (status, data). 내부 API 는 /api/... 경로다 (v1 아님)."""
        payload = json.dumps(body).encode("utf-8") if body is not None else None
        headers = {
            "User-Agent": UA,
            "Accept": "application/json",
            "Referer": f"{BASE}/",
            "X-CSRFTOKEN": self.csrf,
        }
        if payload:
            headers["Content-Type"] = "application/json"
        req = urllib.request.Request(BASE + path, data=payload, method=method, headers=headers)
        try:
            with self.op.open(req, timeout=90) as r:
                raw = r.read().decode("utf-8")
                return r.status, (json.loads(raw) if raw else None)
        except urllib.error.HTTPError as e:
            raw = e.read().decode("utf-8", "replace")
            try:
                return e.code, json.loads(raw)
            except Exception:
                return e.code, {"raw": raw[:300]}

    def ws(self, path: str) -> str:
        return f"/api/workspaces/{WORKSPACE}{path}"


def rows_of(data) -> list:
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        return data.get("results", [])
    return []


if __name__ == "__main__":
    s = Session()
    code, me = s.call("GET", "/api/users/me/")
    print(f"로그인 OK — {me.get('email')} (HTTP {code})")
