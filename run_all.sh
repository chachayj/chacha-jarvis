#!/usr/bin/env bash
# =====================================================
# chacha-jarvis 전체 구동
#
#   ./run_all.sh            전체 스택 기동 (백그라운드) + 헬스체크
#   ./run_all.sh core       3D맵 / 챗봇 / 로봇서버 / EMQX 만 (spring·postgres 제외)
#   ./run_all.sh down       전체 정지
#   ./run_all.sh logs       전체 로그 follow
#   ./run_all.sh logs vue-frontend    특정 서비스 로그
#   ./run_all.sh status     상태 + 접속 URL
#   ./run_all.sh restart    재기동
#
# 최초 1회는 ./setup_all.sh 를 먼저 돌린다.
# =====================================================
set -euo pipefail

cd "$(dirname "$0")"

CORE_SERVICES=(emqx ollama fiber-server voice-assistant vue-frontend nginx)

say()  { printf '\n\033[1;36m▶ %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
die()  { printf '\n\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

preflight() {
  docker info >/dev/null 2>&1 || die "docker 데몬이 안 떠 있다."
  [ -f .env ] || die ".env 가 없다. ./setup_all.sh 를 먼저 실행한다."
  [ -f nginx/selfsigned.key ] || die "nginx/selfsigned.key 가 없다. ./setup_all.sh 를 먼저 실행한다."
}

# host:port 가 열릴 때까지 대기
wait_port() {
  local name="$1" port="$2" timeout="${3:-120}" i=0
  printf '  %-16s' "${name}"
  while [ "$i" -lt "$timeout" ]; do
    if (exec 3<>/dev/tcp/127.0.0.1/"${port}") 2>/dev/null; then
      exec 3>&- 2>/dev/null || true
      printf '\033[32m✓\033[0m :%s\n' "${port}"
      return 0
    fi
    sleep 1; i=$((i+1))
  done
  printf '\033[33m대기 초과\033[0m :%s  (docker compose logs %s 확인)\n' "${port}" "${name}"
  return 1
}

print_urls() {
  local emqx_user emqx_pass
  emqx_user="$(grep -E '^EMQX_DASHBOARD_USER=' .env | cut -d= -f2-)"
  emqx_pass="$(grep -E '^EMQX_DASHBOARD_PASS=' .env | cut -d= -f2-)"
  cat <<EOF

┌─ 접속 URL ─────────────────────────────────────────────────────────────
│ 3D map (vue3+cesium)   http://localhost:5173/
│                        https://localhost:8443/korea3d/   (nginx)
│ chatbot                http://localhost:8080/
│                        https://localhost:8443/chatbot/   (nginx)
│ robot server (fiber)   http://localhost:3000/
│ EMQX dashboard         http://localhost:18083/   ${emqx_user} / ${emqx_pass}
│ Ollama API             http://localhost:11434/
├─ 전체 스택일 때만 ────────────────────────────────────────────────────
│ Swagger UI             http://localhost:8081/swagger-ui/index.html
│ PostgreSQL             localhost:5434
├─ 개별 구동 ───────────────────────────────────────────────────────────
│ Plane                  http://localhost:8082/   (plane-selfhost/ 에서 따로 기동)
└────────────────────────────────────────────────────────────────────────

nginx 는 자체 서명 인증서다 — 브라우저 경고는 "고급 → 계속" 으로 넘긴다.
EOF
}

cmd="${1:-up}"

case "${cmd}" in
  up|core)
    preflight
    if [ "${cmd}" = "core" ]; then
      say "core 스택 기동: ${CORE_SERVICES[*]}"
      docker compose up -d --build "${CORE_SERVICES[@]}"
    else
      say "전체 스택 기동"
      docker compose up -d --build
    fi

    say "포트 대기"
    rc=0
    wait_port emqx           18083 90  || rc=1
    wait_port ollama         11434 60  || rc=1
    wait_port fiber-server    3000 120 || rc=1
    wait_port voice-assistant 8080 180 || rc=1
    wait_port vue-frontend    5173 180 || rc=1
    wait_port nginx           8443 60  || rc=1
    if [ "${cmd}" = "up" ]; then
      wait_port postgres      5434 90  || rc=1
      wait_port spring-server 8081 240 || rc=1
    fi

    say "컨테이너 상태"
    docker compose ps --format 'table {{.Service}}\t{{.Status}}\t{{.Ports}}'

    # Ollama 모델 확인 — 없으면 챗봇 NLU 가 실패한다
    LLM_MODEL="${LLM_MODEL:-llama3.1:8b}"
    if ! docker exec ollama ollama list 2>/dev/null | grep -q "^${LLM_MODEL%%:*}"; then
      warn "Ollama 에 ${LLM_MODEL} 이 없다 → 챗봇 응답이 실패한다."
      warn "  docker exec -it ollama ollama pull ${LLM_MODEL}"
    fi

    print_urls
    [ "${rc}" -eq 0 ] || warn "일부 서비스가 시간 내에 안 떴다. 위 상태와 로그를 확인한다."
    exit 0
    ;;

  down)
    say "전체 정지"
    docker compose down --remove-orphans
    ok "정지 완료 (데이터 볼륨은 남는다. 비우려면: docker compose down -v)"
    ;;

  restart)
    say "재기동"
    docker compose down --remove-orphans
    exec "$0" up
    ;;

  logs)
    shift || true
    docker compose logs -f --tail=100 "$@"
    ;;

  status|ps)
    docker compose ps --format 'table {{.Service}}\t{{.Status}}\t{{.Ports}}'
    print_urls
    ;;

  *)
    sed -n '2,20p' "$0" | sed 's/^# \?//'
    exit 1
    ;;
esac
