#!/usr/bin/env bash
# =====================================================
# chacha-jarvis 전체 정지
#
#   ./stop_all.sh            전체 정지 (컨테이너 제거, 볼륨·이미지는 남긴다)
#   ./stop_all.sh core       core 서비스만 정지 (spring·postgres 는 살려둔다)
#   ./stop_all.sh pause      컨테이너를 지우지 않고 stop 만 (재개: ./run_all.sh)
#   ./stop_all.sh volumes    전체 정지 + 데이터 볼륨까지 삭제 ⚠ 되돌릴 수 없다
#   ./stop_all.sh all        위에 더해 plane-selfhost 까지 정지
#   ./stop_all.sh status     남아 있는 컨테이너 확인
# =====================================================
set -euo pipefail

cd "$(dirname "$0")"

CORE_SERVICES=(emqx ollama fiber-server voice-assistant vue-frontend nginx)

say()  { printf '\n\033[1;36m▶ %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
die()  { printf '\n\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

docker info >/dev/null 2>&1 || die "docker 데몬이 안 떠 있다."

# plane-selfhost 는 별도 compose 프로젝트다
stop_plane() {
  if [ -d plane-selfhost/plane-app ] && \
     docker compose -f plane-selfhost/plane-app/docker-compose.yml ps -q 2>/dev/null | grep -q .; then
    say "plane-selfhost 정지"
    docker compose -f plane-selfhost/plane-app/docker-compose.yml down --remove-orphans
    ok "plane 정지 완료"
  else
    warn "plane-selfhost 는 떠 있지 않다 — 건너뛴다."
  fi
}

remaining() {
  say "남아 있는 컨테이너"
  if docker compose ps -q 2>/dev/null | grep -q .; then
    docker compose ps --format 'table {{.Service}}\t{{.Status}}\t{{.Ports}}'
  else
    ok "chacha-jarvis 컨테이너 없음"
  fi
}

cmd="${1:-down}"

case "${cmd}" in
  down)
    say "전체 정지"
    docker compose down --remove-orphans
    ok "정지 완료 — 데이터 볼륨은 남는다 (비우려면: ./stop_all.sh volumes)"
    remaining
    ;;

  core)
    say "core 스택 정지: ${CORE_SERVICES[*]}"
    docker compose stop "${CORE_SERVICES[@]}"
    docker compose rm -f "${CORE_SERVICES[@]}"
    ok "core 정지 완료 — spring-server / postgres 는 그대로 둔다"
    remaining
    ;;

  pause|stop)
    say "전체 stop (컨테이너 유지)"
    docker compose stop
    ok "stop 완료 — 재개: ./run_all.sh"
    remaining
    ;;

  volumes|purge)
    warn "데이터 볼륨(postgres / emqx / ollama 모델)까지 전부 삭제한다."
    printf '  계속하려면 yes 입력: '
    read -r answer
    [ "${answer}" = "yes" ] || die "취소했다."
    say "전체 정지 + 볼륨 삭제"
    docker compose down --remove-orphans -v
    ok "볼륨까지 삭제 완료 — 다음 기동 전에 ./setup_all.sh 를 다시 돌린다"
    remaining
    ;;

  all)
    say "전체 정지 (chacha-jarvis + plane)"
    docker compose down --remove-orphans
    ok "chacha-jarvis 정지 완료"
    stop_plane
    remaining
    ;;

  status|ps)
    remaining
    ;;

  *)
    sed -n '2,13p' "$0" | sed 's/^# \?//'
    exit 1
    ;;
esac
