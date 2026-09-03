#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
원격 Windows PC에 WSL 자동 시작(Task Scheduler) 및 Windows 자동 로그인을 설정합니다.
WSL + Docker + GitLab Runner가 이미 설치된 환경에서 사용합니다.

필수:
  --remote-host <HOST>              원격 Windows 호스트/IP
  --remote-user <USER>              원격 Windows SSH 사용자
  --wsl-distro <NAME>               WSL 배포판 이름 (기본: Ubuntu)

선택:
  --ssh-port <PORT>                 SSH 포트 (기본: 22)
  --ask-ssh-password                SSH 비밀번호를 실행 중 안전하게 입력받음(권장)
  --ssh-password <PASSWORD>         SSH 비밀번호 직접 지정(비권장)
  --auto-login-password <PASSWORD>  Windows 자동 로그인 비밀번호
                                    부팅 후 자동 로그인 → WSL 자동 기동에 필요
  -h, --help                        도움말 출력

예시:
  bash shell-scripts/setup_windows_wsl_autostart.sh \
    --remote-host 192.0.2.10 \
    --remote-user work \
    --ask-ssh-password \
    --wsl-distro Ubuntu \
    --auto-login-password "1234"
EOF
}

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

die() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "필수 명령어가 없습니다: $1"
}

b64() {
  printf '%s' "$1" | base64 -w0
}

# ─── 파라미터 ───────────────────────────────────────────────────────────────────

REMOTE_HOST=""
REMOTE_USER=""
SSH_PORT="22"
ASK_SSH_PASSWORD="false"
SSH_PASSWORD="${SSH_PASSWORD:-}"
WSL_DISTRO="Ubuntu"
AUTO_LOGIN_PASSWORD=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --remote-host)
      REMOTE_HOST="${2:-}"; shift 2 ;;
    --remote-user)
      REMOTE_USER="${2:-}"; shift 2 ;;
    --ssh-port)
      SSH_PORT="${2:-}"; shift 2 ;;
    --ask-ssh-password)
      ASK_SSH_PASSWORD="true"; shift ;;
    --ssh-password)
      [[ $# -ge 2 && -n "${2:-}" ]] || die "--ssh-password 값이 필요합니다."
      SSH_PASSWORD="${2:-}"; shift 2 ;;
    --wsl-distro)
      WSL_DISTRO="${2:-}"; shift 2 ;;
    --auto-login-password)
      [[ $# -ge 2 && -n "${2:-}" ]] || die "--auto-login-password 값이 필요합니다."
      AUTO_LOGIN_PASSWORD="${2:-}"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      die "알 수 없는 옵션: $1 (도움말: --help)" ;;
  esac
done

[[ -n "$REMOTE_HOST" ]] || die "--remote-host 는 필수입니다."
[[ -n "$REMOTE_USER" ]] || die "--remote-user 는 필수입니다."

if [[ "$ASK_SSH_PASSWORD" == "true" && -n "$SSH_PASSWORD" ]]; then
  die "--ask-ssh-password 와 --ssh-password 는 동시에 사용할 수 없습니다."
fi
if [[ "$ASK_SSH_PASSWORD" == "true" ]]; then
  read -r -s -p "SSH 비밀번호 입력 (입력 내용 미표시): " SSH_PASSWORD
  echo
  [[ -n "$SSH_PASSWORD" ]] || die "SSH 비밀번호가 비어 있습니다."
fi

# ─── SSH 설정 ───────────────────────────────────────────────────────────────────

require_cmd ssh
require_cmd base64
if [[ -n "$SSH_PASSWORD" ]]; then
  require_cmd sshpass
  export SSHPASS="$SSH_PASSWORD"
fi

SSH_OPTS=(
  -p "$SSH_PORT"
  -o StrictHostKeyChecking=accept-new
  -o ConnectTimeout=10
  -o ServerAliveInterval=20
  -o ServerAliveCountMax=3
  -o ControlMaster=auto
  -o ControlPersist=10m
  -o ControlPath="${TMPDIR:-/tmp}/example_wsl_autostart_${$}_%C"
)
SSH_TARGET="${REMOTE_USER}@${REMOTE_HOST}"

cleanup() {
  ssh_cmd -O exit "$SSH_TARGET" >/dev/null 2>&1 || true
  unset SSHPASS SSH_PASSWORD
}
trap cleanup EXIT

ssh_cmd() {
  if [[ -n "$SSH_PASSWORD" ]]; then
    sshpass -e ssh "${SSH_OPTS[@]}" "$@"
    return
  fi
  ssh "${SSH_OPTS[@]}" "$@"
}

run_ps() {
  local script="$1"
  local b64 tmp_file='C:\Windows\Temp\example_wsl_autostart.ps1'
  b64="$(printf '%s' "$script" | base64 -w0)"

  local write_err
  write_err="$(printf '%s' "$b64" | ssh_cmd "$SSH_TARGET" \
    "powershell.exe -NoProfile -NonInteractive -Command \"[IO.File]::WriteAllText('${tmp_file}',[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String([Console]::In.ReadToEnd().Trim())),[Text.Encoding]::UTF8)\"" \
    2>&1)" || {
    printf '[ERROR] 원격 스크립트 파일 쓰기 실패: %s\n' "$write_err" >&2
    return 1
  }

  ssh_cmd "$SSH_TARGET" \
    "powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command \"try { & '${tmp_file}' } finally { Remove-Item '${tmp_file}' -ErrorAction SilentlyContinue }\"" 2>&1 || true
}

# ─── SSH 연결 확인 ──────────────────────────────────────────────────────────────

log "SSH 연결 확인: $SSH_TARGET"
ssh_cmd "$SSH_TARGET" "echo SSH_OK" | grep -q "SSH_OK" || die "SSH 접속 실패: $SSH_TARGET"

DISTRO_B64="$(b64 "$WSL_DISTRO")"

# 예약 작업을 LogonType=Password 로 등록하기 위한 Windows 계정 비밀번호.
# Interactive 로 등록하면 태스크가 "그것을 시작한 로그온 세션"에 묶여서,
# 이 스크립트처럼 SSH로 접속해 시작하는 경우 연결이 끊기는 순간 함께 죽는다.
# (실측 2026-09-02: STATUS_CONTROL_C_EXIT = 0xC000013A)
# SSH 비밀번호가 곧 Windows 계정 비밀번호이므로 그것을 우선 사용한다.
TASK_PASSWORD="${SSH_PASSWORD:-$AUTO_LOGIN_PASSWORD}"
TASK_PASS_B64="$(b64 "$TASK_PASSWORD")"
if [[ -z "$TASK_PASSWORD" ]]; then
  log "경고: 계정 비밀번호가 없어 keepalive를 Interactive로 등록합니다."
  log "      SSH 연결 종료 시 함께 죽을 수 있습니다. --ask-ssh-password 사용을 권장합니다."
fi

# ─── 1단계: WSL Keepalive + Auto-Start Task Scheduler 등록 ─────────────────────

log "1/2 단계: WSL Keepalive Task Scheduler 등록 (AtStartup + AtLogOn)"
read -r -d '' KEEPALIVE_PS <<'PWSH' || true
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$Distro   = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String("__DISTRO_B64__"))
$Password = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String("__TASK_PASS_B64__"))
$taskName = "WSL-Keepalive-$Distro"

# $env:USERDOMAIN 은 SSH 세션에서 비어 있을 수 있고, 그러면 계정을 SID로 매핑하지 못해
# Register-ScheduledTask 가 0x80070534 로 실패한다. WindowsIdentity 는 항상 정확하다.
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name

# 인자에 인용부호를 쓰지 않는다.
# Windows는 작은따옴표를 인용부호로 처리하지 않아서, 예전 인자
#   -d $Distro -- bash -c 'while true; do sleep 3600; done'
# 는 bash -c 에 `while` 한 단어만 전달되어 문법 오류로 즉시 종료됐다(LastTaskResult=1).
# 그 결과 keepalive가 한 번도 살아 있지 않았다. sleep infinity 는 인용부호가 필요 없다.
$action    = New-ScheduledTaskAction -Execute "wsl.exe" -Argument "-d $Distro -u root -- sleep infinity"
$trigBoot  = New-ScheduledTaskTrigger -AtStartup
$trigLogon = New-ScheduledTaskTrigger -AtLogOn

# 계속 실행(0=무제한) + 죽으면 1분 뒤 재시작. 배터리 기본값은 keepalive를 멈추므로 해제한다.
$settings  = New-ScheduledTaskSettingsSet -ExecutionTimeLimit 0 `
  -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) `
  -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

if ($Password) {
  # -User/-Password 조합이 LogonType=Password 를 만든다. 로그온 세션에 묶이지 않는다.
  Register-ScheduledTask -TaskName $taskName -Action $action -Trigger @($trigBoot, $trigLogon) `
    -Settings $settings -User $currentUser -Password $Password -RunLevel Highest -Force | Out-Null
  Write-Host "[Keepalive] LogonType=Password ($currentUser) - 로그온 세션과 무관하게 실행"
} else {
  $principal = New-ScheduledTaskPrincipal -UserId $currentUser -LogonType Interactive -RunLevel Highest
  Register-ScheduledTask -TaskName $taskName -Action $action -Trigger @($trigBoot, $trigLogon) `
    -Settings $settings -Principal $principal -Force | Out-Null
  Write-Host "[Keepalive] WARNING: LogonType=Interactive - SSH 연결 종료 시 함께 죽을 수 있습니다."
}

Start-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
Start-Sleep -Seconds 5

# 등록만으로는 부족하다. State가 Running이고 WSL 안에 프로세스가 실제로 있어야 한다.
$state = (Get-ScheduledTask -TaskName $taskName).State
$rc    = (Get-ScheduledTaskInfo -TaskName $taskName).LastTaskResult
$proc  = wsl.exe -d $Distro -u root -- pgrep -af infinity
Write-Host "[Keepalive] Task '$taskName' registered (AtStartup + AtLogOn), State=$state, LastTaskResult=$rc"
Write-Host "[Keepalive] WSL process: $proc"
if ($state -ne "Running" -or -not $proc) {
  Write-Host "[Keepalive] WARNING: keepalive가 동작하지 않습니다."
}
Write-Output "KEEPALIVE_DONE=true"
PWSH

KEEPALIVE_PS="${KEEPALIVE_PS//__DISTRO_B64__/$DISTRO_B64}"
KEEPALIVE_PS="${KEEPALIVE_PS//__TASK_PASS_B64__/$TASK_PASS_B64}"
KEEPALIVE_OUT="$(run_ps "$KEEPALIVE_PS")"
printf '%s\n' "$KEEPALIVE_OUT"
if [[ "$KEEPALIVE_OUT" != *"KEEPALIVE_DONE=true"* ]]; then
  log "경고: WSL Keepalive 태스크 등록에 실패했습니다. 수동으로 등록하세요."
fi

# ─── 2단계: Windows 자동 로그인 설정 (옵션) ────────────────────────────────────

if [[ -n "$AUTO_LOGIN_PASSWORD" ]]; then
  log "2/2 단계: Windows 자동 로그인 설정 (${REMOTE_USER})"
  AUTO_LOGIN_USER_B64="$(b64 "$REMOTE_USER")"
  AUTO_LOGIN_PASS_B64="$(b64 "$AUTO_LOGIN_PASSWORD")"
  read -r -d '' AUTOLOGIN_PS <<'PWSH' || true
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$User = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String("__AUTO_LOGIN_USER_B64__"))
$Pass = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String("__AUTO_LOGIN_PASS_B64__"))
$reg  = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

Set-ItemProperty -Path $reg -Name "AutoAdminLogon"    -Value "1"  -Type String
Set-ItemProperty -Path $reg -Name "DefaultUserName"   -Value $User -Type String
Set-ItemProperty -Path $reg -Name "DefaultPassword"   -Value $Pass -Type String
Set-ItemProperty -Path $reg -Name "DefaultDomainName" -Value "."  -Type String

Write-Host "[AutoLogin] 자동 로그인 설정 완료: 사용자=$User"
Write-Output "AUTOLOGIN_DONE=true"
PWSH

  AUTOLOGIN_PS="${AUTOLOGIN_PS//__AUTO_LOGIN_USER_B64__/$AUTO_LOGIN_USER_B64}"
  AUTOLOGIN_PS="${AUTOLOGIN_PS//__AUTO_LOGIN_PASS_B64__/$AUTO_LOGIN_PASS_B64}"
  AUTOLOGIN_OUT="$(run_ps "$AUTOLOGIN_PS")"
  printf '%s\n' "$AUTOLOGIN_OUT"
  if [[ "$AUTOLOGIN_OUT" != *"AUTOLOGIN_DONE=true"* ]]; then
    log "경고: 자동 로그인 설정에 실패했습니다. 수동으로 설정하세요."
  fi
else
  log "2/2 단계: --auto-login-password 미지정 → 자동 로그인 설정 건너뜀"
fi

# ─── 완료 ───────────────────────────────────────────────────────────────────────

cat <<EOF

완료:
  - WSL Task Scheduler: WSL-Keepalive-${WSL_DISTRO} 등록 (부팅/로그인 시 WSL 자동 기동)
$([ -n "$AUTO_LOGIN_PASSWORD" ] && echo "  - Windows 자동 로그인: ${REMOTE_USER} 계정으로 부팅 시 자동 로그인 설정 완료")

다음 단계 (WSL 내부 수동 설정):
  1. WSL 접속: ssh ${REMOTE_USER}@${REMOTE_HOST} 후 wsl
  2. 레포 클론: git clone http://192.0.2.20:7000/example/example-monorepo.git ~/myorg/example-monorepo
  3. env 파일 생성: cp ~/myorg/example-monorepo/scripts/poll-plane-cycle.env.example ~/poll-plane-cycle.env
  4. env 파일에 실제 값 입력 (PLANE_API_KEY, GITLAB_TOKEN 등)
  5. crontab 등록: crontab -e
     */10 * * * * source ~/poll-plane-cycle.env && cd \$REPO_PATH && python3 scripts/poll_plane_cycle.py >> /tmp/cycle_poll.log 2>&1

EOF
