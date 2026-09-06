#!/usr/bin/env bash
# 이 폴더의 코드를 라즈베리파이로 전송한다.
#
#   ./sync.sh              전송만
#   ./sync.sh led/blink.py 전송 후 해당 스크립트 실행
#
# 접속은 Tailscale 을 경유한다 -> embeded/ros/docs/01-remote-access.md

set -euo pipefail

PI_HOST="${PI_HOST:-rpi-jarvis}"      # Tailscale MagicDNS 이름
PI_SSH_USER="${PI_SSH_USER:-root}"    # tailnet ACL 상 root 만 허용됨
PI_RUN_USER="${PI_RUN_USER:-chacha}"  # 파이의 일반 사용자
PI_DEST="${PI_DEST:-/home/chacha/chacha-rpi}"

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE="${PI_SSH_USER}@${PI_HOST}"

# 호스트키를 처음 볼 때 자동 수락 (Tailscale 내부망이라 안전)
SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)

echo "→ ${REMOTE}:${PI_DEST} 로 동기화"

rsync -az --delete \
  -e "ssh ${SSH_OPTS[*]}" \
  --exclude '__pycache__/' \
  --exclude '*.pyc' \
  --exclude '.venv/' \
  "${SRC_DIR}/" "${REMOTE}:${PI_DEST}/"

# root 로 보냈으므로 소유권을 실제 사용자에게 넘긴다
ssh "${SSH_OPTS[@]}" "${REMOTE}" "chown -R ${PI_RUN_USER}:${PI_RUN_USER} '${PI_DEST}'"

echo "✔ 동기화 완료"

if [ $# -gt 0 ]; then
  SCRIPT="$1"; shift
  echo "→ 실행: ${SCRIPT} $*"
  echo "─────────────────────────────────────"
  # gpiozero 는 sudo 가 필요 없다. 일반 사용자로 실행한다.
  ssh "${SSH_OPTS[@]}" -t "${REMOTE}" "cd '${PI_DEST}' && sudo -u ${PI_RUN_USER} python3 '${SCRIPT}' $*"
fi
