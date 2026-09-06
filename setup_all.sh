#!/usr/bin/env bash
# =====================================================
# chacha-jarvis 최초 1회 세팅
#   ./setup_all.sh
# 여러 번 실행해도 안전하다 (이미 있는 건 건드리지 않는다).
# 세팅이 끝나면 ./run_all.sh 로 구동한다.
# =====================================================
set -euo pipefail

cd "$(dirname "$0")"
ROOT="$(pwd)"

say()  { printf '\n\033[1;36m▶ %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
skip() { printf '  \033[90m·\033[0m %s\n' "$*"; }
die()  { printf '\n\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

gen_pw() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import secrets; print(secrets.token_urlsafe(18).replace('-','_'))"
  else
    openssl rand -base64 24 | tr -d '\n=+/' | cut -c1-24
  fi
}

# ─── 0. 사전 조건 ────────────────────────────────────────────────────────────
say "사전 조건 확인"
command -v docker >/dev/null 2>&1 || die "docker 가 없다. README-WSL2-INSTALL.md 참조."
docker compose version >/dev/null 2>&1 || die "docker compose (v2) 플러그인이 없다."
docker info >/dev/null 2>&1 || die "docker 데몬이 안 떠 있다. Docker Desktop 을 켜거나 'sudo service docker start'."
ok "docker $(docker --version | awk '{print $3}' | tr -d ,) / compose $(docker compose version --short)"

# ─── 1. 루트 .env ───────────────────────────────────────────────────────────
say ".env 준비"
if [ -f .env ]; then
  skip ".env 가 이미 있다 (건드리지 않는다)"
else
  DB_PASS="$(gen_pw)"
  EMQX_PASS="$(gen_pw)"
  cat > .env <<EOF
# chacha-jarvis 환경변수 — setup_all.sh 가 생성. 커밋 금지 (.gitignore 대상)
DB_USER=chacha
DB_PASS=${DB_PASS}
DB_NAME=chacha_db

EMQX_DASHBOARD_USER=admin
EMQX_DASHBOARD_PASS=${EMQX_PASS}

# go_fiber_server 날씨 연동용. 없으면 /weather 계열만 실패한다.
OPEN_WEATHER_MAP_KEY=
EOF
  chmod 600 .env
  ok ".env 생성 (비밀번호 자동 생성)"
  printf '      EMQX 대시보드: admin / %s\n' "${EMQX_PASS}"
fi

# DB_PASS 가 비었거나 템플릿 그대로면 경고
if grep -qE '^DB_PASS=(<생성하세요>)?$' .env; then
  die ".env 의 DB_PASS 가 비어 있다. 값을 채워야 postgres 가 뜬다."
fi
if grep -qE '^OPEN_WEATHER_MAP_KEY=(<본인 키>)?$' .env; then
  skip "OPEN_WEATHER_MAP_KEY 가 비어 있다 — 날씨 API 만 동작하지 않는다"
fi

# ─── 2. 실행 권한 ───────────────────────────────────────────────────────────
say "스크립트 실행 권한"
chmod +x emqx/init_emqx.sh backend/go_fiber_server/wait-for-it.sh
[ -f run_all.sh ] && chmod +x run_all.sh
ok "init_emqx.sh, wait-for-it.sh"

# ─── 3. 런타임 디렉터리 (볼륨 마운트 대상) ──────────────────────────────────
say "런타임 디렉터리"
mkdir -p emqx/certs emqx/data emqx/log voice-assistant/data/tts
ok "emqx/{certs,data,log}, voice-assistant/data/tts"

# ─── 4. nginx 자체 서명 인증서 ──────────────────────────────────────────────
say "nginx TLS 인증서"
if [ -f nginx/selfsigned.key ] && [ -f nginx/selfsigned.crt ]; then
  skip "nginx/selfsigned.{crt,key} 가 이미 있다"
else
  ( cd nginx && sh generate-cert.sh >/dev/null 2>&1 )
  chmod 600 nginx/selfsigned.key
  ok "nginx/selfsigned.{crt,key} 생성 (CN=localhost, 365일)"
fi
# emqx 인증서는 컨테이너 기동 시 init_emqx.sh 가 스스로 만든다.

# ─── 5. 이미지 빌드 ─────────────────────────────────────────────────────────
say "이미지 빌드 (처음이면 10~20분 걸린다)"
docker compose build
ok "빌드 완료"

# ─── 6. Ollama LLM 모델 ─────────────────────────────────────────────────────
LLM_MODEL="${LLM_MODEL:-llama3.1:8b}"
say "Ollama 모델 ${LLM_MODEL} (약 5GB)"
docker compose up -d ollama >/dev/null
for _ in $(seq 30); do
  docker exec ollama ollama list >/dev/null 2>&1 && break
  sleep 2
done
if docker exec ollama ollama list 2>/dev/null | grep -q "^${LLM_MODEL%%:*}"; then
  skip "${LLM_MODEL} 이 이미 있다"
else
  docker exec ollama ollama pull "${LLM_MODEL}"
  ok "${LLM_MODEL} 다운로드 완료"
fi

printf '\n\033[1;32m세팅 완료.\033[0m  이제 \033[1m./run_all.sh\033[0m 로 구동한다.\n\n'
