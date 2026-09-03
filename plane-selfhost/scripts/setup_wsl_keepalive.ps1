<#
.SYNOPSIS
  WSL2 배포판이 VSCode/터미널 종료와 함께 내려가지 않도록 keepalive 예약 작업을 등록한다.

.DESCRIPTION
  WSL2는 마지막 사용자 프로세스가 끝나면 몇 초 뒤 VM을 통째로 내린다.
  VSCode Remote-WSL 창이 그 배포판의 유일한 사용처였다면, 창을 닫는 순간
  안에서 돌던 Docker 컨테이너(Plane 포함)까지 전부 같이 죽는다.
  systemd=true 나 restart:always 로는 막을 수 없다 — VM 자체가 사라지기 때문이다.

  이 스크립트는 wsl.exe 로 `sleep infinity` 프로세스를 상주시켜
  WSL VM이 항상 "사용 중"으로 유지되게 만든다.

  ── 과거 버그 (2026-09-02 발견/수정) ──────────────────────────────────────────
  setup_windows_wsl_autostart.sh 가 등록하던 태스크의 인자는 다음과 같았다.

      -d Ubuntu -- bash -c 'while true; do sleep 3600; done'

  Windows는 작은따옴표를 인용부호로 처리하지 않는다. 따라서 bash -c 에는
  `while` 한 단어만 전달되고 나머지는 별개 인자가 되어, bash가 문법 오류로
  즉시 종료했다(LastTaskResult=1). 즉 keepalive는 등록된 이후 단 한 번도
  살아 있던 적이 없었고, 그동안 WSL이 유지된 건 순전히 VSCode 덕분이었다.

  그래서 인용부호가 아예 필요 없는 `sleep infinity` 로 대체한다.

  ── 전제 조건 ────────────────────────────────────────────────────────────────
  LogonType 이 Interactive 이므로 부팅 후 자동 복구는 Windows 자동 로그인
  (AutoAdminLogon=1) 에 의존한다. 자동 로그인을 끄면 부팅 후 사람이 로그인하기
  전까지 WSL이 뜨지 않는다. 확인:
      reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon

  WSL을 세션 0(S4U/SYSTEM)에서 띄우는 방식은 배포판 등록이 사용자 레지스트리에
  묶여 있어 안정적이지 않다. Interactive + 자동 로그인 조합을 유지할 것.

.PARAMETER Distro
  대상 WSL 배포판 이름. 기본 Ubuntu. (wsl -l -v 로 확인)

.PARAMETER WslUser
  WSL 안에서 keepalive를 실행할 사용자. 이 데탑은 기본 사용자가 root 다.

.PARAMETER Remove
  keepalive 예약 작업(신/구 이름 모두)을 제거한다.

.PARAMETER Status
  등록/실행 상태만 출력하고 아무것도 변경하지 않는다.

.EXAMPLE
  # 등록 (관리자 PowerShell)
  powershell -ExecutionPolicy Bypass -File setup_wsl_keepalive.ps1

.EXAMPLE
  # 상태 확인만
  powershell -ExecutionPolicy Bypass -File setup_wsl_keepalive.ps1 -Status

.EXAMPLE
  # 원복
  powershell -ExecutionPolicy Bypass -File setup_wsl_keepalive.ps1 -Remove
#>

[CmdletBinding()]
param(
    [string]$Distro  = 'Ubuntu',
    [string]$WslUser = 'root',
    # 지정하면 LogonType=Password 로 등록한다. (해당 Windows 계정의 비밀번호)
    # Interactive 로 등록하면 태스크가 "그것을 시작한 로그온 세션"에 묶이기 때문에,
    # SSH로 접속해 Start-ScheduledTask 로 시작하면 SSH 연결이 끊기는 순간
    # 콘솔 제어 이벤트가 전달되어 wsl.exe 가 STATUS_CONTROL_C_EXIT(0xC000013A)로 죽는다.
    # 실측(2026-09-02)으로 확인된 함정이므로, 원격에서 세팅한다면 반드시 이 옵션을 쓸 것.
    [string]$Password,
    [switch]$Remove,
    [switch]$Status
)

$ErrorActionPreference = 'Stop'

$TaskName   = "WSL-Keepalive-$Distro"
# 같은 버그를 가진 구버전 태스크. 남겨두면 1분마다 실패만 반복하므로 함께 정리한다.
$LegacyName = 'WSL-Keepalive'

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    [OK] $msg" -ForegroundColor Green }
function Write-Warn2($msg){ Write-Host "    [!!] $msg" -ForegroundColor Yellow }
function Die($msg)        { Write-Host "`n[에러] $msg" -ForegroundColor Red; exit 1 }

# ---------------------------------------------------------------- 상태 출력
function Show-Status {
    Write-Step "현재 상태"

    foreach ($name in @($TaskName, $LegacyName)) {
        $task = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
        if (-not $task) {
            Write-Host "    $name : 없음"
            continue
        }
        $info = Get-ScheduledTaskInfo -TaskName $name -ErrorAction SilentlyContinue
        Write-Host "    $name :"
        Write-Host "        State          : $($task.State)   (상시 기동이면 Running 이어야 정상)"
        Write-Host "        LogonType      : $($task.Principal.LogonType) / $($task.Principal.UserId)"
        Write-Host "        Arguments      : $($task.Actions[0].Arguments)"
        # 267009 = 0x41301 (SCHED_S_TASK_RUNNING). 실행 중이라는 뜻이며 정상이다.
        # 상시 기동 태스크는 끝나지 않으므로 0이 아니라 이 값이 나오는 게 맞다.
        $rcNote = switch ($info.LastTaskResult) {
            0      { '(정상 종료)' }
            267009 { '(실행 중 - 정상)' }
            1      { '<- 실행 즉시 실패. 인자의 인용부호를 의심할 것' }
            default { '<- 실행 실패' }
        }
        Write-Host "        LastRunTime    : $($info.LastRunTime)"
        Write-Host "        LastTaskResult : $($info.LastTaskResult)  $rcNote"
    }

    Write-Host "`n    WSL 배포판 상태:"
    $env:WSL_UTF8 = 1
    wsl.exe -l -v | ForEach-Object { Write-Host "        $_" }

    $auto = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction SilentlyContinue).AutoAdminLogon
    Write-Host "`n    AutoAdminLogon  : $auto  $(if ($auto -ne '1') { '<- 꺼져 있으면 부팅 후 자동 복구 안 됨' })"
}

if ($Status) { Show-Status; exit 0 }

# ---------------------------------------------------------------- 관리자 권한 확인
$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Die "관리자 권한이 필요합니다. PowerShell을 '관리자 권한으로 실행' 후 다시 시도하세요."
}

# ---------------------------------------------------------------- 제거 모드
if ($Remove) {
    Write-Step "WSL keepalive 예약 작업 제거"
    foreach ($name in @($TaskName, $LegacyName)) {
        if (Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue) {
            Stop-ScheduledTask     -TaskName $name -ErrorAction SilentlyContinue
            Unregister-ScheduledTask -TaskName $name -Confirm:$false
            Write-Ok "'$name' 제거"
        } else {
            Write-Ok "'$name' 없음 (건너뜀)"
        }
    }
    Write-Warn2 "이제 WSL은 마지막 세션이 끝나면 다시 내려갑니다."
    Show-Status
    exit 0
}

# ---------------------------------------------------------------- 사전 점검
Write-Step "사전 점검"

$env:WSL_UTF8 = 1
$distros = (wsl.exe -l -q) -replace "`0", '' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
if ($distros -notcontains $Distro) {
    Die "WSL 배포판 '$Distro' 를 찾을 수 없습니다. 확인: wsl -l -v (발견: $($distros -join ', '))"
}
Write-Ok "배포판 '$Distro' 확인"

# sleep infinity 가 실제로 되는지 확인한다. (busybox sleep은 infinity를 못 받는다)
wsl.exe -d $Distro -u $WslUser -- sleep 0.1
if ($LASTEXITCODE -ne 0) {
    Die "WSL에서 명령을 실행하지 못했습니다 (사용자: $WslUser). 확인: wsl -d $Distro -u $WslUser -- whoami"
}
Write-Ok "WSL 명령 실행 확인 (사용자: $WslUser)"

# ---------------------------------------------------------------- 구버전 태스크 정리
if (Get-ScheduledTask -TaskName $LegacyName -ErrorAction SilentlyContinue) {
    Write-Step "구버전 태스크 '$LegacyName' 정리"
    Stop-ScheduledTask       -TaskName $LegacyName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $LegacyName -Confirm:$false
    Write-Ok "제거 완료 (동일한 작은따옴표 버그를 갖고 있었음)"
}

# ---------------------------------------------------------------- 등록
Write-Step "keepalive 예약 작업 등록: $TaskName"

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Stop-ScheduledTask       -TaskName $TaskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Ok "기존 태스크 제거 후 재등록"
}

# 인용부호가 필요 없는 형태로만 인자를 구성한다. (과거 버그 재발 방지)
$argument = "-d $Distro -u $WslUser -- sleep infinity"

$action = New-ScheduledTaskAction -Execute 'wsl.exe' -Argument $argument

# AtStartup: 부팅 시 / AtLogOn: 자동 로그인 완료 시. 둘 다 걸어 어느 쪽이든 뜨게 한다.
$triggers = @(
    (New-ScheduledTaskTrigger -AtStartup),
    (New-ScheduledTaskTrigger -AtLogOn)
)

# SSH 세션에서는 $env:USERDOMAIN 이 비어 있을 수 있고, 그러면 계정을 SID로 매핑하지 못해
# Register-ScheduledTask 가 0x80070534 로 실패한다.
# WindowsIdentity 는 어느 세션에서든 DOMAIN\User 형태를 정확히 돌려준다.
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
Write-Ok "실행 계정: $currentUser"

if (-not $Password) {
    Write-Warn2 "LogonType=Interactive 로 등록합니다."
    Write-Warn2 "SSH 등 원격 세션에서 이 태스크를 수동 시작하면 연결 종료 시 함께 죽습니다."
    Write-Warn2 "원격에서 세팅 중이라면 -Password 옵션을 사용하세요."
}

$principal = New-ScheduledTaskPrincipal `
    -UserId   $currentUser `
    -LogonType Interactive `
    -RunLevel  Highest

# ExecutionTimeLimit 0 = 무제한(계속 실행). 죽으면 1분 뒤 최대 999회까지 되살린다.
# 배터리 관련 기본값(True)은 노트북에서 keepalive를 멈추게 하므로 반드시 해제한다.
$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -RestartCount 999 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -MultipleInstances IgnoreNew `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable

$desc = "WSL2가 VSCode 종료와 함께 내려가지 않도록 sleep infinity 프로세스를 상주시킨다."

if ($Password) {
    # -User/-Password 는 -Principal 과 함께 쓸 수 없다. 이 조합이 LogonType=Password 를 만든다.
    # 로그온 세션에 묶이지 않으므로 SSH로 시작해도 연결 종료 시 죽지 않는다.
    Register-ScheduledTask -TaskName $TaskName `
        -Action $action -Trigger $triggers -Settings $settings `
        -User $currentUser -Password $Password -RunLevel Highest `
        -Description $desc -Force | Out-Null
    Write-Ok "등록 완료 (LogonType=Password / 로그온 세션과 무관): wsl.exe $argument"
} else {
    Register-ScheduledTask -TaskName $TaskName `
        -Action $action -Trigger $triggers -Principal $principal -Settings $settings `
        -Description $desc -Force | Out-Null
    Write-Ok "등록 완료 (LogonType=Interactive): wsl.exe $argument"
}

# ---------------------------------------------------------------- 즉시 시작 + 검증
Write-Step "즉시 시작 및 검증"

Start-ScheduledTask -TaskName $TaskName
Start-Sleep -Seconds 5

$task = Get-ScheduledTask -TaskName $TaskName
$info = Get-ScheduledTaskInfo -TaskName $TaskName

if ($task.State -eq 'Running') {
    Write-Ok "태스크 State=Running"
} else {
    Write-Warn2 "태스크 State=$($task.State), LastTaskResult=$($info.LastTaskResult)"
    Write-Warn2 "Running이 아니면 keepalive가 동작하지 않는 것입니다. 인자와 WSL 사용자를 확인하세요."
}

# State=Running 만으로는 부족하다. WSL 안에 실제로 프로세스가 있는지 봐야 한다.
$proc = wsl.exe -d $Distro -u $WslUser -- pgrep -af infinity
if ($proc) {
    Write-Ok "WSL 상주 프로세스 확인: $proc"
} else {
    Write-Warn2 "WSL 안에 sleep infinity 프로세스가 없습니다. keepalive가 동작하지 않습니다."
}

if (-not $Password) {
    Write-Warn2 ""
    Write-Warn2 "이 세션이 SSH 등 원격 로그온 세션이라면, 연결을 끊는 순간 이 프로세스도 함께 죽습니다."
    Write-Warn2 "연결을 끊었다가 다시 접속해 아래로 반드시 재확인하세요:"
    Write-Warn2 "    wsl -d $Distro -u $WslUser -- pgrep -af infinity"
}

Show-Status

Write-Host "`n==> 확인 방법" -ForegroundColor Cyan
Write-Host "    1. VSCode Remote-WSL 창을 모두 닫는다"
Write-Host "    2. 2분쯤 기다린 뒤 다른 PC에서 : curl -I http://192.0.2.10:8080/"
Write-Host "    3. 200이 나오면 성공. (예전에는 이 시점에 WSL이 내려가 접속 불가였다)"
Write-Host ""
Write-Host "    주의: wsl --shutdown 은 keepalive 프로세스까지 강제로 죽인다." -ForegroundColor Yellow
Write-Host "          실행했다면 아래로 되살릴 것:" -ForegroundColor Yellow
Write-Host "          schtasks /run /tn `"$TaskName`"" -ForegroundColor Yellow
Write-Host ""
