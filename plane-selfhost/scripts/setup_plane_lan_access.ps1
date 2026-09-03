<#
.SYNOPSIS
  WSL2 안에서 도는 Plane을 사내망(LAN)에서 접속 가능하게 만든다.

.DESCRIPTION
  설치 대상 데탑(192.0.2.10, Windows + WSL2)에서 **관리자 권한 PowerShell**로 실행한다.

  WSL2는 기본이 NAT이라 WSL 안의 컨테이너가 8080을 열어도
  LAN의 다른 PC에서 192.0.2.10:8080 으로 접속되지 않는다.
  이 스크립트는 두 가지 해결책 중 하나를 적용한다.

    portproxy (기본, 권장) : netsh portproxy + 방화벽 인바운드 규칙.
                             WSL 재시작 불필요 → 돌고 있는 GitLab Runner/크론을 죽이지 않는다.
                             단 WSL IP가 재부팅마다 바뀌므로 -RegisterTask로 부팅 시 자동 갱신 등록 필요.

    mirrored (옵트인)      : .wslconfig에 networkingMode=mirrored 기록.
                             구조적으로 더 깔끔하지만 적용에 `wsl --shutdown`이 필요하고,
                             Windows 11 22H2+ 에서만 동작한다.
                             ⚠️ 이 데탑 WSL 안에서 GitLab Runner + poll_plane_cycle.py 크론이
                                돌고 있으므로 shutdown 시 함께 중단된다. 반드시 확인 후 사용할 것.

.PARAMETER Port
  외부에 열 포트. 기본 8080 (plane-image/.env 의 LISTEN_HTTP_PORT 와 일치해야 함).

.PARAMETER Mode
  portproxy (기본) | mirrored

.PARAMETER RegisterTask
  부팅 시 portproxy를 자동 갱신하도록 Task Scheduler에 등록한다. (portproxy 모드 전용)

.PARAMETER Remove
  이 스크립트가 만든 portproxy / 방화벽 규칙 / 예약 작업을 제거한다.

.EXAMPLE
  # 최초 세팅 (권장) — portproxy + 방화벽 + 부팅 시 자동 갱신
  powershell -ExecutionPolicy Bypass -File setup_plane_lan_access.ps1 -RegisterTask

.EXAMPLE
  # 현재 상태만 확인
  powershell -ExecutionPolicy Bypass -File setup_plane_lan_access.ps1 -WhatIfOnly

.EXAMPLE
  # 원복
  powershell -ExecutionPolicy Bypass -File setup_plane_lan_access.ps1 -Remove
#>

[CmdletBinding()]
param(
    [int]$Port = 8080,
    [ValidateSet('portproxy', 'mirrored')]
    [string]$Mode = 'portproxy',
    [switch]$RegisterTask,
    [switch]$Remove,
    [switch]$WhatIfOnly
)

$ErrorActionPreference = 'Stop'

$RuleName = "Plane LAN $Port"
$TaskName = "PlaneLanPortProxy$Port"

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    [OK] $msg" -ForegroundColor Green }
function Write-Warn2($msg){ Write-Host "    [!!] $msg" -ForegroundColor Yellow }
function Die($msg)        { Write-Host "`n[에러] $msg" -ForegroundColor Red; exit 1 }

# ---------------------------------------------------------------- 관리자 권한 확인
$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Die "관리자 권한이 필요합니다. PowerShell을 '관리자 권한으로 실행' 후 다시 시도하세요."
}

# ---------------------------------------------------------------- WSL 확인
function Get-WslIp {
    # 부팅 직후 예약 작업으로 실행되면 WSL이 아직 안 떠 있을 수 있으므로 재시도한다.
    param([int]$Retries = 10, [int]$DelaySec = 15)

    for ($i = 1; $i -le $Retries; $i++) {
        $raw = (wsl hostname -I) 2>$null
        if ($raw) {
            $ip = ($raw.Trim() -split '\s+')[0]
            if ($ip -match '^\d{1,3}(\.\d{1,3}){3}$') { return $ip }
        }
        if ($i -lt $Retries) {
            Write-Host "    WSL 준비 대기 중... ($i/$Retries)"
            Start-Sleep -Seconds $DelaySec
        }
    }
    Die "WSL에서 IP를 가져오지 못했습니다. WSL이 실행 중인지 확인하세요 (wsl -l -v)."
}

# ---------------------------------------------------------------- 현재 상태 출력
function Show-Status {
    Write-Step "현재 상태"

    $hostIps = (Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object { $_.IPAddress -notmatch '^(127\.|169\.254\.)' } |
        Select-Object -ExpandProperty IPAddress) -join ', '
    Write-Host "    Windows IP      : $hostIps"

    # 상태 표시용이므로 재시도 없이 한 번만 본다
    try { Write-Host "    WSL IP          : $(Get-WslIp -Retries 1)" } catch { Write-Host "    WSL IP          : (확인 불가)" }

    $wslConfig = Join-Path $env:USERPROFILE '.wslconfig'
    if (Test-Path $wslConfig) {
        $mirrored = (Get-Content $wslConfig -Raw) -match 'networkingMode\s*=\s*mirrored'
        Write-Host "    .wslconfig      : 있음 (mirrored=$mirrored)"
    } else {
        Write-Host "    .wslconfig      : 없음 (NAT 기본값)"
    }

    Write-Host "    portproxy       :"
    $pp = netsh interface portproxy show v4tov4 | Out-String
    if ($pp -match "\s$Port\s") { Write-Host $pp } else { Write-Host "      (포트 $Port 규칙 없음)" }

    $fw = Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue
    Write-Host "    방화벽 규칙     : $(if ($fw) { "'$RuleName' 있음 (Enabled=$($fw.Enabled))" } else { '없음' })"

    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    Write-Host "    예약 작업       : $(if ($task) { "'$TaskName' 있음 ($($task.State))" } else { '없음' })"
}

if ($WhatIfOnly) { Show-Status; exit 0 }

# ---------------------------------------------------------------- 제거 모드
if ($Remove) {
    Write-Step "Plane LAN 접속 설정 제거 (포트 $Port)"

    netsh interface portproxy delete v4tov4 listenport=$Port listenaddress=0.0.0.0 2>$null | Out-Null
    Write-Ok "portproxy 규칙 제거"

    if (Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue) {
        Remove-NetFirewallRule -DisplayName $RuleName
        Write-Ok "방화벽 규칙 '$RuleName' 제거"
    } else { Write-Ok "방화벽 규칙 없음 (건너뜀)" }

    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Ok "예약 작업 '$TaskName' 제거"
    } else { Write-Ok "예약 작업 없음 (건너뜀)" }

    Show-Status
    exit 0
}

# ---------------------------------------------------------------- mirrored 모드
if ($Mode -eq 'mirrored') {
    Write-Step "mirrored networking 설정"

    # mirrored는 Windows 11 (build 22000+) 부터 지원한다.
    $build = [int](Get-CimInstance Win32_OperatingSystem).BuildNumber
    if ($build -lt 22000) {
        Die @"
mirrored 모드는 Windows 11 (build 22000+) 에서만 동작합니다.
현재 빌드: $build (Windows 10)

이 데탑(192.0.2.10)은 Windows 10 19045 이므로 mirrored를 쓸 수 없습니다.
기본값인 portproxy 모드를 사용하세요:

    .\setup_plane_lan_access.ps1 -RegisterTask
"@
    }

    Write-Warn2 "이 모드는 적용에 'wsl --shutdown'이 필요합니다."
    Write-Warn2 "이 데탑 WSL에서는 GitLab Runner(win-wsl-runner)와"
    Write-Warn2 "poll_plane_cycle.py 크론이 동작 중이며, shutdown 시 함께 중단됩니다."
    Write-Warn2 "WSL 자동시작 트리거가 AtLogOn이라 재로그인 전까지 자동 복구되지 않을 수 있습니다."
    $ans = Read-Host "`n    계속하시겠습니까? (yes 입력 시에만 진행)"
    if ($ans -ne 'yes') { Write-Host "    취소했습니다."; exit 0 }

    $wslConfig = Join-Path $env:USERPROFILE '.wslconfig'
    if (Test-Path $wslConfig) {
        Copy-Item $wslConfig "$wslConfig.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
        Write-Ok "기존 .wslconfig 백업"
        $content = Get-Content $wslConfig -Raw
        if ($content -match 'networkingMode\s*=') {
            $content = $content -replace 'networkingMode\s*=\s*\w+', 'networkingMode=mirrored'
        } elseif ($content -match '\[wsl2\]') {
            $content = $content -replace '\[wsl2\]', "[wsl2]`r`nnetworkingMode=mirrored"
        } else {
            $content += "`r`n[wsl2]`r`nnetworkingMode=mirrored`r`n"
        }
        Set-Content $wslConfig $content -Encoding ASCII
    } else {
        Set-Content $wslConfig "[wsl2]`r`nnetworkingMode=mirrored`r`n" -Encoding ASCII
    }
    Write-Ok ".wslconfig 에 networkingMode=mirrored 기록"

    # mirrored 여도 Windows 방화벽 인바운드는 필요하다
    if (-not (Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName $RuleName -Direction Inbound -Action Allow `
            -Protocol TCP -LocalPort $Port -Profile Any | Out-Null
        Write-Ok "방화벽 인바운드 규칙 '$RuleName' 생성"
    } else { Write-Ok "방화벽 규칙 이미 있음" }

    Write-Host "`n    적용하려면 아래를 수동 실행하세요 (자동 실행하지 않습니다):" -ForegroundColor Yellow
    Write-Host "      wsl --shutdown" -ForegroundColor Yellow
    Write-Host "    이후 WSL을 다시 띄우고 컨테이너를 기동하세요:" -ForegroundColor Yellow
    Write-Host "      wsl -d Ubuntu -- bash -lc 'cd /home/plane/plane/plane-image && docker compose up -d'" -ForegroundColor Yellow

    Show-Status
    exit 0
}

# ---------------------------------------------------------------- portproxy 모드 (기본)
Write-Step "portproxy 모드로 LAN 접속 설정 (포트 $Port)"

$wslIp = Get-WslIp
Write-Ok "WSL IP 감지: $wslIp"

# 기존 규칙 제거 후 재등록 (멱등)
netsh interface portproxy delete v4tov4 listenport=$Port listenaddress=0.0.0.0 2>$null | Out-Null
netsh interface portproxy add v4tov4 `
    listenport=$Port listenaddress=0.0.0.0 `
    connectport=$Port connectaddress=$wslIp | Out-Null
Write-Ok "portproxy 등록: 0.0.0.0:$Port -> ${wslIp}:$Port"

if (-not (Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName $RuleName -Direction Inbound -Action Allow `
        -Protocol TCP -LocalPort $Port -Profile Any | Out-Null
    Write-Ok "방화벽 인바운드 규칙 '$RuleName' 생성"
} else {
    Write-Ok "방화벽 규칙 '$RuleName' 이미 있음"
}

# ---------------------------------------------------------------- 부팅 시 자동 갱신 등록
if ($RegisterTask) {
    Write-Step "부팅 시 portproxy 자동 갱신 등록"

    $scriptPath = $MyInvocation.MyCommand.Path
    if (-not $scriptPath) { Die "스크립트 경로를 확인할 수 없어 예약 작업을 등록하지 못했습니다." }

    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }

    $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
        -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -Port $Port"

    # WSL이 완전히 올라온 뒤 실행되도록 지연을 준다.
    # Windows 10 일부 빌드에서는 트리거 객체에 Delay를 직접 설정할 수 없다.
    # 그 경우 Get-WslIp의 재시도 로직(최대 10회 x 15초)이 대신 커버한다.
    $trigger = New-ScheduledTaskTrigger -AtStartup
    try {
        $trigger.Delay = 'PT90S'
        Write-Ok "트리거 지연 90초 설정"
    } catch {
        Write-Warn2 "이 Windows 빌드는 트리거 Delay 설정을 지원하지 않습니다."
        Write-Warn2 "→ 스크립트 내 WSL 대기 재시도(최대 150초)로 대체합니다."
    }
    # SYSTEM(세션 0)에서는 WSL 배포판을 조회하지 못한다.
    # WSL 배포판 등록이 사용자 레지스트리에 묶여 있기 때문이다.
    # 실측(2026-09-02): SYSTEM으로 등록된 이 태스크는 Get-WslIp 재시도를 150초 모두 소진한 뒤
    # LastTaskResult=1 로 실패했다. 즉 부팅 시 portproxy가 갱신된 적이 없었다.
    # → 현재 사용자 + Interactive 로 등록한다. netsh에 관리자 권한이 필요하므로 Highest 유지.
    #   (Interactive 이므로 부팅 후 자동 복구는 Windows 자동 로그인에 의존한다)
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $principal = New-ScheduledTaskPrincipal -UserId $currentUser -LogonType Interactive -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
        -Principal $principal -Settings $settings `
        -Description "WSL IP는 재부팅마다 바뀌므로 부팅 시 Plane용 portproxy를 재등록한다." | Out-Null

    Write-Ok "예약 작업 '$TaskName' 등록 (부팅 후 90초 지연, $currentUser / Interactive / 최고 권한)"
} else {
    Write-Warn2 "WSL IP는 재부팅마다 바뀝니다. 부팅 후에도 유지하려면 -RegisterTask 로 다시 실행하세요."
}

Show-Status

Write-Host "`n==> 확인 방법" -ForegroundColor Cyan
Write-Host "    이 데탑에서 : curl -I http://localhost:$Port/"
Write-Host "    팀원 PC에서 : curl -I http://192.0.2.10:$Port/"
Write-Host ""
