#!/usr/bin/env bash
#
# Plane self-host 접속 상태 점검 스크립트
#
# 어느 계층에서 막히는지 단계별로 짚어준다:
#   1) 컨테이너가 떠 있는가            (대상 데탑 WSL 안에서만 확인 가능)
#   2) WSL 내부에서 localhost 접속되는가 (대상 데탑 WSL 안에서만 확인 가능)
#   3) LAN에서 192.0.2.10 접속되는가  (어느 PC에서든 확인 가능)
#
# 사용법:
#   bash shell-scripts/check_plane_access.sh                 # 기본값으로 점검
#   bash shell-scripts/check_plane_access.sh --host 192.0.2.10 --port 8080
#   bash shell-scripts/check_plane_access.sh --lan-only      # LAN 접속만 확인 (팀원 PC용)

set -uo pipefail

HOST="192.0.2.10"
PORT="8080"
LAN_ONLY="false"
COMPOSE_DIR="${COMPOSE_DIR:-/home/plane/plane/plane-image}"

usage() {
  # shebang 다음 줄부터 이어지는 주석 블록만 출력한다
  awk 'NR==1 { next }
       /^#/  { sub(/^# ?/, ""); print; next }
       { exit }' "$0"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)     HOST="${2:?--host 값이 필요합니다}"; shift 2 ;;
    --port)     PORT="${2:?--port 값이 필요합니다}"; shift 2 ;;
    --dir)      COMPOSE_DIR="${2:?--dir 값이 필요합니다}"; shift 2 ;;
    --lan-only) LAN_ONLY="true"; shift ;;
    -h|--help)  usage ;;
    *) echo "알 수 없는 옵션: $1" >&2; exit 2 ;;
  esac
done

GREEN=$'\033[32m'; RED=$'\033[31m'; YEL=$'\033[33m'; CYA=$'\033[36m'; RST=$'\033[0m'
ok()   { echo "    ${GREEN}[OK]${RST}   $*"; }
fail() { echo "    ${RED}[FAIL]${RST} $*"; }
warn() { echo "    ${YEL}[!!]${RST}   $*"; }
step() { echo; echo "${CYA}==> $*${RST}"; }

FAILED=0

# ------------------------------------------------------------ 1) 컨테이너 상태
if [[ "$LAN_ONLY" == "false" ]]; then
  step "1) 컨테이너 상태 ($COMPOSE_DIR)"
  if ! command -v docker >/dev/null 2>&1; then
    warn "docker 명령이 없습니다. 이 머신은 설치 대상이 아닌 것 같습니다 → --lan-only 로 실행하세요."
  elif [[ ! -d "$COMPOSE_DIR" ]]; then
    warn "$COMPOSE_DIR 가 없습니다. 설치 대상 데탑이 아니거나 클론 경로가 다릅니다 (--dir 로 지정)."
  else
    ps_out="$(cd "$COMPOSE_DIR" && docker compose ps 2>&1)"
    echo "$ps_out" | sed 's/^/      /'
    running="$(cd "$COMPOSE_DIR" && docker compose ps --status running -q 2>/dev/null | wc -l)"
    if [[ "$running" -gt 0 ]]; then
      ok "실행 중인 컨테이너 ${running}개"
      # v1.2.1에서는 plane-space가 unhealthy로 뜨는 게 정상이었으나 v1.4.2에서 고쳐졌다.
      # 지금도 unhealthy면 접속 자체는 되더라도 한 번 확인해볼 만하다.
      echo "$ps_out" | grep -qi 'plane-space.*unhealthy' && \
        warn "plane-space가 unhealthy입니다 (v1.2.1에서는 정상이었음. 접속되면 대개 무해)"
    else
      fail "실행 중인 컨테이너가 없습니다 → cd $COMPOSE_DIR && docker compose up -d"
      FAILED=1
    fi
  fi

  # ---------------------------------------------------------- 2) 로컬 접속
  step "2) WSL 내부 localhost 접속"
  if curl -fsS -o /dev/null -m 10 "http://localhost:${PORT}/" 2>/dev/null; then
    ok "http://localhost:${PORT}/ 응답"
  else
    fail "http://localhost:${PORT}/ 응답 없음 → 컨테이너/포트 설정 확인"
    FAILED=1
  fi

  api_code="$(curl -s -o /dev/null -w '%{http_code}' -m 10 "http://localhost:${PORT}/api/instances/" 2>/dev/null)"
  if [[ "$api_code" == "200" ]]; then
    ok "http://localhost:${PORT}/api/instances/ → 200"
  else
    fail "http://localhost:${PORT}/api/instances/ → ${api_code:-무응답} (200이어야 정상)"
    FAILED=1
  fi
fi

# ------------------------------------------------------------ 3) LAN 접속
step "3) LAN 접속 (http://${HOST}:${PORT})"
if curl -fsS -o /dev/null -m 10 "http://${HOST}:${PORT}/" 2>/dev/null; then
  ok "http://${HOST}:${PORT}/ 응답 — 팀원들이 접속 가능합니다"
else
  fail "http://${HOST}:${PORT}/ 응답 없음"
  FAILED=1
  echo
  warn "WSL2는 기본이 NAT이라 이 단계가 자주 막힙니다. 대상 데탑에서 관리자 PowerShell로:"
  echo "        powershell -ExecutionPolicy Bypass -File shell-scripts\\setup_plane_lan_access.ps1 -RegisterTask"
  echo
  warn "이미 설정했는데도 막히면 재부팅으로 WSL IP가 바뀐 것일 수 있습니다. 같은 명령을 다시 실행하세요."
fi

api_code="$(curl -s -o /dev/null -w '%{http_code}' -m 10 "http://${HOST}:${PORT}/api/instances/" 2>/dev/null)"
if [[ "$api_code" == "200" ]]; then
  ok "http://${HOST}:${PORT}/api/instances/ → 200"
else
  fail "http://${HOST}:${PORT}/api/instances/ → ${api_code:-무응답}"
  FAILED=1
fi

# ------------------------------------------------------------ 결과
echo
if [[ "$FAILED" -eq 0 ]]; then
  echo "${GREEN}모든 점검 통과.${RST} 접속 URL: http://${HOST}:${PORT}"
else
  echo "${RED}실패한 항목이 있습니다.${RST} 위 안내를 확인하세요."
fi
exit "$FAILED"
