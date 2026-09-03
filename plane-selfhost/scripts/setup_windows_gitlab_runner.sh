#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
원격 Windows PC(SSH)에서 WSL + Docker Engine + GitLab Runner를 자동 설치/등록합니다.

필수:
  --remote-host <HOST>              원격 Windows 호스트/IP
  --remote-user <USER>              원격 Windows SSH 사용자
  --gitlab-url <URL>                GitLab URL (예: https://gitlab.company.local)
  --registration-token <TOKEN>      GitLab 14.x registration token

선택:
  --ssh-port <PORT>                 SSH 포트 (기본: 22)
  --ask-ssh-password                SSH 비밀번호를 실행 중 안전하게 입력받음(권장)
  --ssh-password <PASSWORD>         SSH 비밀번호 직접 지정(비권장: 히스토리/ps 노출 가능)
  --wsl-distro <NAME>               설치할 WSL 배포판 (기본: Ubuntu)
  --runner-name <NAME>              Runner 설명/이름 (기본: windows-wsl-docker-runner)
  --runner-tags <CSV>               Runner 태그 (기본: windows,wsl,docker)
  --default-image <IMAGE>           Docker executor 기본 이미지 (기본: alpine:3.21)
  --run-untagged <true|false>       태그 없는 잡 허용 (기본: true)
  --locked <true|false>             Runner lock 여부 (기본: false)
  --pipeline-project-id <ID>        (옵션) 파이프라인 트리거 대상 프로젝트 ID
  --pipeline-trigger-token <TOKEN>  (옵션) 파이프라인 Trigger Token
  --pipeline-ref <BRANCH_OR_TAG>    (옵션) 트리거 ref (기본: dev)
  --reboot-timeout-sec <SECONDS>    재부팅 후 SSH 대기시간 (기본: 900, 최소: 300)
  --gitlab-insecure                 (옵션) GitLab HTTPS 인증서 검증 건너뜀
  --auto-login-password <PASSWORD>  (옵션) Windows 자동 로그인 비밀번호 설정
                                    부팅 후 사용자 로그인 없이 WSL crontab 자동 실행이 필요할 때 사용
  -h, --help                        도움말 출력

예시:
  bash shell-scripts/setup_windows_gitlab_runner.sh \
    --remote-host 192.0.2.10 \
    --remote-user work \
    --ask-ssh-password \
    --gitlab-url https://gitlab.company.local \
    --registration-token "GLR-xxxxx" \
    --runner-name "win-wsl-runner" \
    --runner-tags "windows,wsl,docker" \
    --run-untagged true \
    --locked false \
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
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "필수 명령어가 없습니다: $cmd"
}

normalize_bool() {
  local val="${1,,}"
  local key="$2"
  case "$val" in
    true|false) printf '%s' "$val" ;;
    *) die "$key 값은 true 또는 false 여야 합니다. 입력값: $1" ;;
  esac
}

b64() {
  printf '%s' "$1" | base64 -w0
}

REMOTE_HOST=""
REMOTE_USER=""
SSH_PORT="22"
ASK_SSH_PASSWORD="false"
SSH_PASSWORD="${SSH_PASSWORD:-}"
WSL_DISTRO="Ubuntu"
GITLAB_URL=""
REGISTRATION_TOKEN="${GITLAB_REGISTRATION_TOKEN:-}"
RUNNER_NAME="windows-wsl-docker-runner"
RUNNER_TAGS="windows,wsl,docker"
DEFAULT_IMAGE="alpine:3.21"
RUN_UNTAGGED="true"
LOCKED="false"
PIPELINE_PROJECT_ID="${PIPELINE_PROJECT_ID:-}"
PIPELINE_TRIGGER_TOKEN="${PIPELINE_TRIGGER_TOKEN:-}"
PIPELINE_REF="${PIPELINE_REF:-dev}"
GITLAB_INSECURE="false"
REBOOT_TIMEOUT_SEC="900"
AUTO_LOGIN_PASSWORD=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --remote-host)
      REMOTE_HOST="${2:-}"
      shift 2
      ;;
    --remote-user)
      REMOTE_USER="${2:-}"
      shift 2
      ;;
    --ssh-port)
      SSH_PORT="${2:-}"
      shift 2
      ;;
    --ask-ssh-password)
      ASK_SSH_PASSWORD="true"
      shift
      ;;
    --ssh-password)
      [[ $# -ge 2 && -n "${2:-}" ]] || die "--ssh-password 값이 필요합니다."
      SSH_PASSWORD="${2:-}"
      shift 2
      ;;
    --wsl-distro)
      WSL_DISTRO="${2:-}"
      shift 2
      ;;
    --gitlab-url)
      GITLAB_URL="${2:-}"
      shift 2
      ;;
    --registration-token)
      REGISTRATION_TOKEN="${2:-}"
      shift 2
      ;;
    --runner-name)
      RUNNER_NAME="${2:-}"
      shift 2
      ;;
    --runner-tags)
      RUNNER_TAGS="${2:-}"
      shift 2
      ;;
    --default-image)
      DEFAULT_IMAGE="${2:-}"
      shift 2
      ;;
    --run-untagged)
      RUN_UNTAGGED="${2:-}"
      shift 2
      ;;
    --locked)
      LOCKED="${2:-}"
      shift 2
      ;;
    --pipeline-project-id)
      PIPELINE_PROJECT_ID="${2:-}"
      shift 2
      ;;
    --pipeline-trigger-token)
      PIPELINE_TRIGGER_TOKEN="${2:-}"
      shift 2
      ;;
    --pipeline-ref)
      PIPELINE_REF="${2:-}"
      shift 2
      ;;
    --gitlab-insecure)
      GITLAB_INSECURE="true"
      shift
      ;;
    --reboot-timeout-sec)
      REBOOT_TIMEOUT_SEC="${2:-}"
      shift 2
      ;;
    --auto-login-password)
      [[ $# -ge 2 && -n "${2:-}" ]] || die "--auto-login-password 값이 필요합니다."
      AUTO_LOGIN_PASSWORD="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "알 수 없는 옵션: $1 (도움말: --help)"
      ;;
  esac
done

[[ -n "$REMOTE_HOST" ]] || die "--remote-host 는 필수입니다."
[[ -n "$REMOTE_USER" ]] || die "--remote-user 는 필수입니다."
[[ -n "$GITLAB_URL" ]] || die "--gitlab-url 는 필수입니다."
[[ -n "$REGISTRATION_TOKEN" ]] || die "--registration-token 는 필수입니다. (또는 환경변수 GITLAB_REGISTRATION_TOKEN)"

RUN_UNTAGGED="$(normalize_bool "$RUN_UNTAGGED" "--run-untagged")"
LOCKED="$(normalize_bool "$LOCKED" "--locked")"
GITLAB_INSECURE="$(normalize_bool "$GITLAB_INSECURE" "--gitlab-insecure")"
ASK_SSH_PASSWORD="$(normalize_bool "$ASK_SSH_PASSWORD" "--ask-ssh-password")"
[[ "$REBOOT_TIMEOUT_SEC" =~ ^[0-9]+$ ]] || die "--reboot-timeout-sec 는 0 이상의 정수여야 합니다."
(( REBOOT_TIMEOUT_SEC >= 300 )) || die "--reboot-timeout-sec 는 최소 300초 이상으로 설정하세요."

if [[ "$ASK_SSH_PASSWORD" == "true" && -n "$SSH_PASSWORD" ]]; then
  die "--ask-ssh-password 와 --ssh-password 는 동시에 사용할 수 없습니다."
fi

if [[ "$ASK_SSH_PASSWORD" == "true" ]]; then
  if [[ ! -t 0 ]]; then
    die "--ask-ssh-password 는 TTY 환경에서만 사용할 수 있습니다."
  fi
  read -r -s -p "원격 SSH 비밀번호 입력: " SSH_PASSWORD
  printf '\n'
  [[ -n "$SSH_PASSWORD" ]] || die "SSH 비밀번호가 비어 있습니다."
fi

if [[ "${WSL_DISTRO,,}" != ubuntu* ]]; then
  die "현재 스크립트는 Ubuntu 계열 WSL만 지원합니다. (--wsl-distro: Ubuntu 또는 Ubuntu-22.04 권장)"
fi

if [[ -n "$PIPELINE_PROJECT_ID" && -z "$PIPELINE_TRIGGER_TOKEN" ]]; then
  die "--pipeline-project-id 사용 시 --pipeline-trigger-token도 함께 지정해야 합니다."
fi
if [[ -z "$PIPELINE_PROJECT_ID" && -n "$PIPELINE_TRIGGER_TOKEN" ]]; then
  die "--pipeline-trigger-token 사용 시 --pipeline-project-id도 함께 지정해야 합니다."
fi

require_cmd ssh
require_cmd base64
require_cmd curl
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
  -o ControlPath="${TMPDIR:-/tmp}/example_runner_${$}_%C"
)
SSH_TARGET="${REMOTE_USER}@${REMOTE_HOST}"
SSH_USE_SSHPASS="false"
if [[ -n "$SSH_PASSWORD" ]]; then
  SSH_USE_SSHPASS="true"
fi

cleanup() {
  ssh_cmd -O exit "$SSH_TARGET" >/dev/null 2>&1 || true
  unset SSHPASS SSH_PASSWORD
}
trap cleanup EXIT

ssh_cmd() {
  if [[ "$SSH_USE_SSHPASS" == "true" ]]; then
    sshpass -e ssh "${SSH_OPTS[@]}" "$@"
    return
  fi
  ssh "${SSH_OPTS[@]}" "$@"
}

run_ssh_quiet() {
  ssh_cmd "$SSH_TARGET" "$@" >/dev/null 2>&1
}

run_ps() {
  local script="$1"
  local b64 tmp_file='C:\Windows\Temp\example_runner.ps1'
  b64="$(printf '%s' "$script" | base64 -w0)"

  # base64 → UTF-8 decode → .ps1 temp file (avoids CP949/UTF-8 encoding mismatch)
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

wait_for_ssh() {
  local timeout_sec="$1"
  local elapsed=0
  while (( elapsed < timeout_sec )); do
    if run_ssh_quiet "echo OK"; then
      return 0
    fi
    sleep 5
    elapsed=$((elapsed + 5))
  done
  return 1
}

wait_for_reboot_cycle() {
  log "원격 Windows 재부팅 대기 시작..."
  local went_down="false"
  local elapsed=0

  while (( elapsed < 180 )); do
    if run_ssh_quiet "echo waiting"; then
      sleep 5
      elapsed=$((elapsed + 5))
      continue
    fi
    went_down="true"
    break
  done

  if [[ "$went_down" != "true" ]]; then
    log "오프라인 구간을 감지하지 못했습니다. SSH 재접속 가능 여부를 계속 확인합니다."
  fi

  if ! wait_for_ssh "$REBOOT_TIMEOUT_SEC"; then
    die "재부팅 후 SSH 재접속에 실패했습니다."
  fi

  log "원격 Windows가 다시 SSH 응답합니다."
}

log "원격 SSH 접속 확인 중: $SSH_TARGET"
if ! wait_for_ssh 30; then
  die "SSH 접속 실패: $SSH_TARGET"
fi

DISTRO_B64="$(b64 "$WSL_DISTRO")"
GITLAB_URL_B64="$(b64 "$GITLAB_URL")"
REGISTRATION_TOKEN_B64="$(b64 "$REGISTRATION_TOKEN")"
RUNNER_NAME_B64="$(b64 "$RUNNER_NAME")"
RUNNER_TAGS_B64="$(b64 "$RUNNER_TAGS")"
DEFAULT_IMAGE_B64="$(b64 "$DEFAULT_IMAGE")"
RUN_UNTAGGED_B64="$(b64 "$RUN_UNTAGGED")"
LOCKED_B64="$(b64 "$LOCKED")"

read -r -d '' STAGE1_PS <<'PWSH' || true
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$Distro = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String("__DISTRO_B64__"))

function Test-IsAdmin {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
  throw "관리자 권한 계정으로 원격 SSH 접속해야 합니다."
}

$rebootRequired = $false
$featureNames = @(
  "Microsoft-Windows-Subsystem-Linux",
  "VirtualMachinePlatform"
)

foreach ($featureName in $featureNames) {
  $feature = Get-WindowsOptionalFeature -Online -FeatureName $featureName
  if ($feature.State -ne "Enabled") {
    Enable-WindowsOptionalFeature -Online -FeatureName $featureName -All -NoRestart | Out-Null
    Write-Host "[WSL] Enabled feature: $featureName"
    $rebootRequired = $true
  } else {
    Write-Host "[WSL] Feature already enabled: $featureName"
  }
}

# BIOS 가상화(VT-x/AMD-V) 확인 — 비활성화 시 WSL2 VM 생성 불가
# Note: Hyper-V가 이미 활성화된 경우 VirtualizationFirmwareEnabled가 false를 반환할 수 있음
#       → HypervisorPresent도 함께 확인하여 둘 중 하나라도 true면 통과
try {
  $proc = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
  $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
  $virtFirmware = [bool]$proc.VirtualizationFirmwareEnabled
  $hypervisorPresent = [bool]$cs.HypervisorPresent
  Write-Host "[WSL] VirtualizationFirmwareEnabled=$virtFirmware, HypervisorPresent=$hypervisorPresent"
  if (-not $virtFirmware -and -not $hypervisorPresent) {
    Write-Host ""
    Write-Host "============================================================"
    Write-Host "[ERROR] BIOS 가상화(VT-x/AMD-V)가 비활성화 상태입니다."
    Write-Host "  WSL2는 하드웨어 가상화가 필수입니다."
    Write-Host "  해결: PC 재부팅 → BIOS 진입 → VT-x/AMD-V 활성화 후 재실행"
    Write-Host "  참고: https://aka.ms/enablevirtualization"
    Write-Host "============================================================"
    throw "BIOS_VIRT_DISABLED"
  }
  Write-Host "[WSL] BIOS virtualization: OK"
} catch {
  if ($_.Exception.Message -eq "BIOS_VIRT_DISABLED") { throw }
  Write-Host "[WSL] BIOS 가상화 확인 불가 (계속 진행): $($_.Exception.Message)"
}

# Hyper-V 활성화 시도 (Pro/Enterprise 전용; Home에서는 VirtualMachinePlatform만으로 충분)
try {
  $hypervFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -ErrorAction SilentlyContinue
  if ($hypervFeature -and $hypervFeature.State -ne "Enabled") {
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart -ErrorAction Stop | Out-Null
    Write-Host "[WSL] Enabled feature: Microsoft-Hyper-V"
    $rebootRequired = $true
  } elseif ($hypervFeature) {
    Write-Host "[WSL] Feature already enabled: Microsoft-Hyper-V"
  } else {
    Write-Host "[WSL] Microsoft-Hyper-V not available on this edition (OK for Home)"
  }
} catch {
  Write-Host "[WSL] Hyper-V enable skipped: $($_.Exception.Message)"
}

try {
  & wsl --update 2>&1 | ForEach-Object { "$_" -replace "`0","" } | Out-Host
} catch {
  Write-Host "[WSL] wsl --update skipped: $($_.Exception.Message)"
}

function Get-DistroNames {
  $prevEAP = $ErrorActionPreference
  $ErrorActionPreference = "SilentlyContinue"
  $distroRaw = & wsl -l -q 2>$null
  $exitCode = $LASTEXITCODE
  $ErrorActionPreference = $prevEAP
  if ($exitCode -ne 0) {
    return @()
  }
  return @($distroRaw | ForEach-Object { ($_ -replace "`0","").Trim() } | Where-Object { $_ -ne "" })
}

function Import-DistroFromRootfs {
  param([string]$Name)
  $rootfsUrl = "https://cloud-images.ubuntu.com/wsl/jammy/current/ubuntu-jammy-wsl-amd64-ubuntu22.04lts.rootfs.tar.gz"
  $rootfsPath = "$env:TEMP\ubuntu-rootfs.tar.gz"
  $installDir = "C:\WSL\$Name"
  Write-Host "[WSL] Downloading Ubuntu 22.04 rootfs for --import..."
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke-WebRequest -Uri $rootfsUrl -OutFile $rootfsPath -UseBasicParsing
  if (-not (Test-Path $rootfsPath)) { throw "rootfs download failed" }
  if (-not (Test-Path $installDir)) { New-Item -ItemType Directory -Path $installDir -Force | Out-Null }
  Write-Host "[WSL] Importing distro: wsl --import $Name $installDir ..."
  $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "SilentlyContinue"
  & wsl --import $Name $installDir $rootfsPath --version 2 2>&1 | ForEach-Object { "$_" -replace "`0","" } | Out-Host
  $importExit = $LASTEXITCODE
  $ErrorActionPreference = $prevEAP
  Remove-Item $rootfsPath -Force -ErrorAction SilentlyContinue
  if ($importExit -ne 0) { throw "wsl --import failed (exit=$importExit)" }
  Write-Host "[WSL] Import complete: $Name"
}

$distros = Get-DistroNames
if ($distros -notcontains $Distro) {
  Write-Host "[WSL] Installing distro: $Distro"
  $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "SilentlyContinue"
  $installOut = & wsl --install -d $Distro --web-download 2>&1
  $installExit = $LASTEXITCODE
  $ErrorActionPreference = $prevEAP
  $installOut | ForEach-Object { "$_" -replace "`0","" } | Where-Object { $_.Trim() -ne "" }
  if ($installExit -ne 0) {
    Write-Host "[WSL] --web-download failed (exit=$installExit), retrying without it..."
    $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "SilentlyContinue"
    $installOut = & wsl --install -d $Distro 2>&1
    $ErrorActionPreference = $prevEAP
    $installOut | ForEach-Object { "$_" -replace "`0","" } | Where-Object { $_.Trim() -ne "" }
  }
  Start-Sleep -Seconds 5
  $distrosAfter = Get-DistroNames
  if ($distrosAfter -contains $Distro) {
    Write-Host "[WSL] Verified: distro '$Distro' registered after install"
  } else {
    Write-Host "[WSL] wsl --install did not register distro (headless SSH session). Falling back to wsl --import..."
    try {
      Import-DistroFromRootfs -Name $Distro
    } catch {
      Write-Host "[WSL] --import failed in Stage 1: $($_.Exception.Message). Will retry after reboot"
    }
  }
  $rebootRequired = $true
} else {
  Write-Host "[WSL] Distro already exists: $Distro"
}

try {
  & wsl --set-default-version 2 2>&1 | ForEach-Object { "$_" -replace "`0","" } | Out-Host
} catch {
  Write-Host "[WSL] set-default-version skipped: $($_.Exception.Message)"
}

Write-Output "REBOOT_REQUIRED=$($rebootRequired.ToString().ToLower())"
Write-Output "STAGE1_DONE=true"

if ($rebootRequired) {
  Write-Host "[Windows] Reboot scheduled in 15 seconds..."
  shutdown.exe /r /t 15 /c "WSL setup continuation"
}
PWSH

STAGE1_PS="${STAGE1_PS//__DISTRO_B64__/$DISTRO_B64}"

log "1/2 단계: Windows 기능(WSL) 및 배포판 준비"
STAGE1_OUT="$(run_ps "$STAGE1_PS")"
printf '%s\n' "$STAGE1_OUT"

if [[ "$STAGE1_OUT" != *"STAGE1_DONE=true"* ]]; then
  die "1단계 스크립트가 정상 완료되지 않았습니다. 원격 로그를 점검하세요."
fi

if [[ "$STAGE1_OUT" == *"REBOOT_REQUIRED=true"* ]]; then
  wait_for_reboot_cycle
else
  log "재부팅 없이 다음 단계로 진행합니다."
fi

read -r -d '' STAGE2_PS <<'PWSH' || true
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$Distro = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String("__DISTRO_B64__"))

# Pre-flight: BIOS 가상화 확인 (재부팅 후에도 여전히 비활성화면 조기 실패)
try {
  $proc = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
  $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
  $virtFirmware = [bool]$proc.VirtualizationFirmwareEnabled
  $hypervisorPresent = [bool]$cs.HypervisorPresent
  Write-Host "[WSL] VirtualizationFirmwareEnabled=$virtFirmware, HypervisorPresent=$hypervisorPresent"
  if (-not $virtFirmware -and -not $hypervisorPresent) {
    Write-Host ""
    Write-Host "============================================================"
    Write-Host "[ERROR] BIOS 가상화(VT-x/AMD-V)가 여전히 비활성화 상태입니다."
    Write-Host "  PC BIOS에 진입하여 가상화를 활성화한 후 이 스크립트를 다시 실행하세요."
    Write-Host "  참고: https://aka.ms/enablevirtualization"
    Write-Host "============================================================"
    throw "BIOS_VIRT_DISABLED"
  }
  Write-Host "[WSL] BIOS virtualization: OK"
} catch {
  if ($_.Exception.Message -eq "BIOS_VIRT_DISABLED") { throw }
  Write-Host "[WSL] BIOS 가상화 확인 불가 (계속 진행): $($_.Exception.Message)"
}

function Test-WslCommand {
  param(
    [string]$DistroName,
    [string[]]$Arguments,
    [string]$ExpectOutput = "",
    [int]$TimeoutMs = 60000
  )
  $outFile = [System.IO.Path]::GetTempFileName()
  $errFile = [System.IO.Path]::GetTempFileName()
  try {
    $proc = Start-Process -FilePath "wsl.exe" -ArgumentList $Arguments `
      -NoNewWindow -PassThru -RedirectStandardOutput $outFile -RedirectStandardError $errFile
    if ($proc.WaitForExit($TimeoutMs)) {
      if ($ExpectOutput) {
        $out = (Get-Content $outFile -Raw -ErrorAction SilentlyContinue) -replace "`0",""
        return ($out -match $ExpectOutput)
      }
      return ($proc.ExitCode -eq 0)
    }
    $proc | Stop-Process -Force -ErrorAction SilentlyContinue
    return $false
  } catch {
    return $false
  } finally {
    Remove-Item $outFile,$errFile -ErrorAction SilentlyContinue
  }
}

function Wait-DistroReady {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [int]$TimeoutSec = 300,
    [int]$PerAttemptTimeoutMs = 60000
  )

  $elapsed = 0
  while ($elapsed -lt $TimeoutSec) {
    Write-Host "[WSL] Waiting for distro '$Name' to be ready (${elapsed}s / ${TimeoutSec}s)..."
    if (Test-WslCommand -DistroName $Name `
          -Arguments @("-d",$Name,"-u","root","--","echo","WSL_READY") `
          -ExpectOutput "WSL_READY" -TimeoutMs $PerAttemptTimeoutMs) {
      Write-Host "[WSL] Distro '$Name' is ready"
      return
    }
    Start-Sleep -Seconds 5
    $elapsed += ([math]::Ceiling($PerAttemptTimeoutMs / 1000) + 5)
  }
  throw "WSL distro 준비 실패 (${TimeoutSec}s timeout): $Name"
}

function Get-DistroList {
  $prevEAP = $ErrorActionPreference
  $ErrorActionPreference = "SilentlyContinue"
  $raw = & wsl -l -q 2>$null
  $exitCode = $LASTEXITCODE
  $ErrorActionPreference = $prevEAP
  if ($exitCode -ne 0) { return @() }
  return @($raw | ForEach-Object { ($_ -replace "`0","").Trim() } | Where-Object { $_ -ne "" })
}

function Find-Distro {
  param([string]$Name, [int]$MaxAttempts = 6, [int]$IntervalSec = 10)
  for ($i = 0; $i -lt $MaxAttempts; $i++) {
    $list = Get-DistroList
    if ($list -contains $Name) { return $true }
    if ($i -eq 0 -or ($i % 3) -eq 0) {
      Write-Host "[WSL] Distro '$Name' not yet visible (attempt $($i+1)/$MaxAttempts, found: $($list -join ', '))"
    }
    Start-Sleep -Seconds $IntervalSec
  }
  return $false
}

$needInstall = $false
if (Find-Distro -Name $Distro -MaxAttempts 3 -IntervalSec 5) {
  Write-Host "[WSL] Distro '$Distro' registered. Testing responsiveness (60s timeout)..."
  if (Test-WslCommand -DistroName $Distro `
        -Arguments @("-d",$Distro,"-u","root","--","echo","DISTRO_OK") `
        -ExpectOutput "DISTRO_OK" -TimeoutMs 60000) {
    Write-Host "[WSL] Distro '$Distro' is responsive"
  } else {
    Write-Host "[WSL] Distro '$Distro' is not responding (broken state). Resetting..."
    $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "SilentlyContinue"
    & wsl --terminate $Distro 2>&1 | Out-Null
    & wsl --unregister $Distro 2>&1 | Out-Null
    $ErrorActionPreference = $prevEAP
    Start-Sleep -Seconds 3
    $needInstall = $true
  }
} else {
  $needInstall = $true
}

function Import-DistroFromRootfs {
  param([string]$Name)
  $rootfsUrl = "https://cloud-images.ubuntu.com/wsl/jammy/current/ubuntu-jammy-wsl-amd64-ubuntu22.04lts.rootfs.tar.gz"
  $rootfsPath = "$env:TEMP\ubuntu-rootfs.tar.gz"
  $installDir = "C:\WSL\$Name"
  Write-Host "[WSL] Downloading Ubuntu 22.04 rootfs for --import..."
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke-WebRequest -Uri $rootfsUrl -OutFile $rootfsPath -UseBasicParsing
  if (-not (Test-Path $rootfsPath)) { throw "rootfs download failed" }
  if (-not (Test-Path $installDir)) { New-Item -ItemType Directory -Path $installDir -Force | Out-Null }
  Write-Host "[WSL] Importing distro: wsl --import $Name $installDir ..."
  $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "SilentlyContinue"
  & wsl --import $Name $installDir $rootfsPath --version 2 2>&1 | ForEach-Object { "$_" -replace "`0","" } | Out-Host
  $importExit = $LASTEXITCODE
  $ErrorActionPreference = $prevEAP
  Remove-Item $rootfsPath -Force -ErrorAction SilentlyContinue
  if ($importExit -ne 0) { throw "wsl --import failed (exit=$importExit)" }
  Write-Host "[WSL] Import complete: $Name"
}

if ($needInstall) {
  Write-Host "[WSL] Installing distro: $Distro"
  $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "SilentlyContinue"
  $out = & wsl --install -d $Distro --web-download 2>&1
  $installExit = $LASTEXITCODE
  $ErrorActionPreference = $prevEAP
  $out | ForEach-Object { "$_" -replace "`0","" } | Where-Object { $_.Trim() -ne "" }
  if ($installExit -ne 0) {
    Write-Host "[WSL] --web-download failed, retrying without it..."
    $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "SilentlyContinue"
    $out = & wsl --install -d $Distro 2>&1
    $ErrorActionPreference = $prevEAP
    $out | ForEach-Object { "$_" -replace "`0","" } | Where-Object { $_.Trim() -ne "" }
  }
  Start-Sleep -Seconds 10
  if (-not (Find-Distro -Name $Distro -MaxAttempts 6)) {
    Write-Host "[WSL] wsl --install did not register distro (headless SSH session). Falling back to wsl --import..."
    Import-DistroFromRootfs -Name $Distro
    if (-not (Find-Distro -Name $Distro -MaxAttempts 3 -IntervalSec 5)) {
      $finalList = Get-DistroList
      Write-Host "[WSL] Available distros: $($finalList -join ', ')"
      throw "WSL distro를 찾을 수 없습니다 (--install 및 --import 모두 실패): $Distro"
    }
  }
}
Write-Host "[WSL] Found distro: $Distro"

$prevEAP = $ErrorActionPreference; $ErrorActionPreference = "SilentlyContinue"
& wsl --set-default-version 2 2>&1 | ForEach-Object { "$_" -replace "`0","" } | Out-Null
& wsl --set-default $Distro 2>&1 | ForEach-Object { "$_" -replace "`0","" } | Out-Null
$ErrorActionPreference = $prevEAP
Wait-DistroReady -Name $Distro -TimeoutSec 300 -PerAttemptTimeoutMs 60000

$wslConfScript = @'
set -euo pipefail

if [ -f /etc/wsl.conf ] && grep -q '^\[boot\]' /etc/wsl.conf; then
  if ! grep -q '^systemd=true' /etc/wsl.conf; then
    awk '
      BEGIN { in_boot=0; inserted=0 }
      /^\[boot\]/ { print; in_boot=1; next }
      /^\[/ {
        if (in_boot==1 && inserted==0) {
          print "systemd=true"
          inserted=1
        }
        in_boot=0
      }
      { print }
      END {
        if (in_boot==1 && inserted==0) {
          print "systemd=true"
        }
      }
    ' /etc/wsl.conf > /tmp/wsl.conf.new
    mv /tmp/wsl.conf.new /etc/wsl.conf
  fi
else
  {
    if [ -f /etc/wsl.conf ]; then
      cat /etc/wsl.conf
      if [ -s /etc/wsl.conf ]; then
        echo
      fi
    fi
    echo "[boot]"
    echo "systemd=true"
  } > /tmp/wsl.conf.new
  mv /tmp/wsl.conf.new /etc/wsl.conf
fi
echo "[WSL] /etc/wsl.conf ensured: systemd=true"
'@

$wslConfB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($wslConfScript))
$prevEAP = $ErrorActionPreference; $ErrorActionPreference = "SilentlyContinue"
& wsl -d $Distro -u root -- bash -lc "echo $wslConfB64 | base64 -d | bash"
if ($LASTEXITCODE -ne 0) { $ErrorActionPreference = $prevEAP; throw "wsl.conf 설정 실패 (exit=$LASTEXITCODE)" }

& wsl --shutdown
$ErrorActionPreference = $prevEAP
Start-Sleep -Seconds 4
Wait-DistroReady -Name $Distro

$installScript = @'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

decode_b64() {
  printf '%s' "$1" | base64 -d
}

GITLAB_URL="$(decode_b64 '__GITLAB_URL_B64__')"
REGISTRATION_TOKEN="$(decode_b64 '__REGISTRATION_TOKEN_B64__')"
RUNNER_NAME="$(decode_b64 '__RUNNER_NAME_B64__')"
RUNNER_TAGS="$(decode_b64 '__RUNNER_TAGS_B64__')"
DEFAULT_IMAGE="$(decode_b64 '__DEFAULT_IMAGE_B64__')"
RUN_UNTAGGED="$(decode_b64 '__RUN_UNTAGGED_B64__')"
LOCKED="$(decode_b64 '__LOCKED_B64__')"

echo "[APT] base packages install"
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https software-properties-common

install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
fi

ARCH="$(dpkg --print-architecture)"
CODENAME="$(. /etc/os-release && echo "${VERSION_CODENAME:-$UBUNTU_CODENAME}")"
if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
  echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list
fi

echo "[APT] docker engine install"
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

if [ "$(ps -p 1 -o comm=)" != "systemd" ]; then
  echo "[ERROR] systemd가 PID 1이 아닙니다. WSL systemd 활성화에 실패했습니다."
  exit 1
fi

systemctl enable docker >/dev/null 2>&1 || true
systemctl restart docker
systemctl is-active --quiet docker

echo "[APT] gitlab-runner install"
if ! command -v gitlab-runner >/dev/null 2>&1; then
  curl -fsSL https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | bash
fi
apt-get install -y gitlab-runner

if ! getent group docker >/dev/null 2>&1; then
  groupadd docker
fi
usermod -aG docker gitlab-runner || true

if [ -f /etc/gitlab-runner/config.toml ] && grep -Fq "name = \"${RUNNER_NAME}\"" /etc/gitlab-runner/config.toml; then
  echo "[Runner] '${RUNNER_NAME}' 이미 등록되어 있어 register 단계는 건너뜁니다."
else
  echo "[Runner] registering..."
  gitlab-runner register \
    --non-interactive \
    --url "${GITLAB_URL}" \
    --registration-token "${REGISTRATION_TOKEN}" \
    --executor "docker" \
    --docker-image "${DEFAULT_IMAGE}" \
    --description "${RUNNER_NAME}" \
    --tag-list "${RUNNER_TAGS}" \
    --run-untagged="${RUN_UNTAGGED}" \
    --locked="${LOCKED}" \
    --access-level="not_protected"
fi

systemctl enable gitlab-runner >/dev/null 2>&1 || true
systemctl restart gitlab-runner

echo "[Runner] verify"
gitlab-runner verify || true

echo "[Docker] info"
docker info >/dev/null
docker version | sed -n '1,12p'

echo "SETUP_DONE=true"
'@

$installB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($installScript))
$prevEAP = $ErrorActionPreference; $ErrorActionPreference = "SilentlyContinue"
& wsl -d $Distro -u root -- bash -lc "echo $installB64 | base64 -d | bash"
$wslExit = $LASTEXITCODE
$ErrorActionPreference = $prevEAP
if ($wslExit -ne 0) { throw "WSL 내부 설치 스크립트 실패 (exit=$wslExit)" }
PWSH

STAGE2_PS="${STAGE2_PS//__DISTRO_B64__/$DISTRO_B64}"
STAGE2_PS="${STAGE2_PS//__GITLAB_URL_B64__/$GITLAB_URL_B64}"
STAGE2_PS="${STAGE2_PS//__REGISTRATION_TOKEN_B64__/$REGISTRATION_TOKEN_B64}"
STAGE2_PS="${STAGE2_PS//__RUNNER_NAME_B64__/$RUNNER_NAME_B64}"
STAGE2_PS="${STAGE2_PS//__RUNNER_TAGS_B64__/$RUNNER_TAGS_B64}"
STAGE2_PS="${STAGE2_PS//__DEFAULT_IMAGE_B64__/$DEFAULT_IMAGE_B64}"
STAGE2_PS="${STAGE2_PS//__RUN_UNTAGGED_B64__/$RUN_UNTAGGED_B64}"
STAGE2_PS="${STAGE2_PS//__LOCKED_B64__/$LOCKED_B64}"

log "2/2 단계: WSL 내부 Docker + GitLab Runner 설치/등록"
_stage2_tmp="$(mktemp)"
run_ps "$STAGE2_PS" | tee "$_stage2_tmp"
STAGE2_OUT="$(<"$_stage2_tmp")"
rm -f "$_stage2_tmp"

if [[ "$STAGE2_OUT" != *"SETUP_DONE=true"* ]]; then
  die "설치 완료 플래그를 확인하지 못했습니다. 원격 로그를 점검하세요."
fi

# ── WSL Keepalive + Auto-Start: Task Scheduler 등록 ──────────────────────────
# - AtStartup: 부팅 시 WSL 자동 기동 (전원 ON → WSL 자동 시작)
# - AtLogOn  : 로그인 시 WSL 재기동 (idle 종료 후 복구)
# CI job 종료 후 WSL idle 자동 종료를 방지하고, 재부팅 후에도 자동 복구된다.
log "3/3 단계: WSL Keepalive Task Scheduler 등록 (AtStartup + AtLogOn)"
read -r -d '' KEEPALIVE_PS <<'PWSH' || true
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$Distro = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String("__DISTRO_B64__"))
$taskName = "WSL-Keepalive-$Distro"

$action    = New-ScheduledTaskAction -Execute "wsl.exe" -Argument "-d $Distro -- bash -c 'while true; do sleep 3600; done'"
$trigLogon = New-ScheduledTaskTrigger -AtLogOn
$trigBoot  = New-ScheduledTaskTrigger -AtStartup
$settings  = New-ScheduledTaskSettingsSet -ExecutionTimeLimit 0
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger @($trigBoot, $trigLogon) `
  -Settings $settings -RunLevel Highest -Force | Out-Null
Start-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
Write-Host "[Keepalive] Task '$taskName' registered (AtStartup + AtLogOn) and started"
Write-Output "KEEPALIVE_DONE=true"
PWSH

KEEPALIVE_PS="${KEEPALIVE_PS//__DISTRO_B64__/$DISTRO_B64}"
KEEPALIVE_OUT="$(run_ps "$KEEPALIVE_PS")"
printf '%s\n' "$KEEPALIVE_OUT"
if [[ "$KEEPALIVE_OUT" != *"KEEPALIVE_DONE=true"* ]]; then
  log "경고: WSL Keepalive 태스크 등록에 실패했습니다. 수동으로 등록하세요."
fi

# ── Windows 자동 로그인 설정 (옵션) ───────────────────────────────────────────
if [[ -n "$AUTO_LOGIN_PASSWORD" ]]; then
  log "옵션 단계: Windows 자동 로그인 설정 (${REMOTE_USER})"
  AUTO_LOGIN_USER_B64="$(b64 "$REMOTE_USER")"
  AUTO_LOGIN_PASS_B64="$(b64 "$AUTO_LOGIN_PASSWORD")"
  read -r -d '' AUTOLOGIN_PS <<'PWSH' || true
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$User = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String("__AUTO_LOGIN_USER_B64__"))
$Pass = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String("__AUTO_LOGIN_PASS_B64__"))
$reg  = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

Set-ItemProperty -Path $reg -Name "AutoAdminLogon"  -Value "1"   -Type String
Set-ItemProperty -Path $reg -Name "DefaultUserName" -Value $User  -Type String
Set-ItemProperty -Path $reg -Name "DefaultPassword" -Value $Pass  -Type String
# DefaultDomainName 을 비워두면 로컬 계정으로 처리됨
Set-ItemProperty -Path $reg -Name "DefaultDomainName" -Value "." -Type String

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
fi

if [[ -n "$PIPELINE_PROJECT_ID" && -n "$PIPELINE_TRIGGER_TOKEN" ]]; then
  log "옵션 단계: GitLab 파이프라인 트리거 실행"
  CURL_OPTS=(-sS -X POST)
  if [[ "$GITLAB_INSECURE" == "true" ]]; then
    CURL_OPTS+=(-k)
  fi

  TRIGGER_URL="${GITLAB_URL%/}/api/v4/projects/${PIPELINE_PROJECT_ID}/trigger/pipeline"
  TMP_RESP="$(mktemp)"
  HTTP_CODE="$(
    curl "${CURL_OPTS[@]}" "$TRIGGER_URL" \
      --form "token=${PIPELINE_TRIGGER_TOKEN}" \
      --form "ref=${PIPELINE_REF}" \
      -o "$TMP_RESP" \
      -w "%{http_code}"
  )"
  RESPONSE="$(<"$TMP_RESP")"
  rm -f "$TMP_RESP"

  if [[ ! "$HTTP_CODE" =~ ^2 ]]; then
    printf '%s\n' "$RESPONSE"
    die "파이프라인 트리거 실패 (HTTP ${HTTP_CODE})"
  fi

  printf '%s\n' "$RESPONSE"
fi

cat <<EOF

완료:
  - 원격 Windows: WSL(${WSL_DISTRO}) 준비
  - WSL 내부: Docker Engine 설치/기동
  - WSL 내부: GitLab Runner(docker executor) 설치/등록
  - Windows Task Scheduler: WSL-Keepalive-${WSL_DISTRO} 등록 (부팅/로그인 시 WSL 자동 기동)
$([ -n "$AUTO_LOGIN_PASSWORD" ] && echo "  - Windows 자동 로그인: ${REMOTE_USER} 계정으로 부팅 시 자동 로그인 설정 완료")

확인:
  1) GitLab UI > Settings > CI/CD > Runners 에 '${RUNNER_NAME}' 표시 확인
  2) 이 레포의 .gitlab-ci.yml 잡은 tag가 없으므로 run-untagged=true 이어야 수신됩니다.
  3) MR 생성 또는 dev 브랜치 push 시 파이프라인이 러너에서 실행됩니다.

EOF
