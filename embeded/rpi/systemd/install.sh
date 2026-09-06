#!/usr/bin/env bash
# systemd 서비스를 라즈베리파이에 설치한다. (개발 PC 에서 실행)
set -euo pipefail

PI_HOST="${PI_HOST:-rpi-jarvis}"
PI_SSH_USER="${PI_SSH_USER:-root}"
REMOTE="${PI_SSH_USER}@${PI_HOST}"
SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)
UNIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "→ 서비스 파일 전송"
scp "${SSH_OPTS[@]}" "${UNIT_DIR}/chacha-led-mqtt.service" \
    "${REMOTE}:/etc/systemd/system/chacha-led-mqtt.service"

echo "→ 서비스 등록 및 기동"
ssh "${SSH_OPTS[@]}" "${REMOTE}" '
  systemctl daemon-reload
  systemctl enable chacha-led-mqtt
  systemctl restart chacha-led-mqtt      # 이미 떠 있어도 새 설정으로 갈아끼운다
  sleep 1
  systemctl status chacha-led-mqtt --no-pager -n 10
'
