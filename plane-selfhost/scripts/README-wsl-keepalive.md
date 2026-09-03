# WSL 상시 기동 (Plane 서버 무중단 유지)

Plane self-host 서버가 도는 데탑(`192.0.2.10`, Windows 10 / user `work`)에서
**VSCode를 끄면 Plane 접속이 끊기던 문제**의 원인과 조치 기록입니다.

- 최초 발생 확인: 2026-09-02
- 대상 호스트: `192.0.2.10` (`PLANE-HOST`)
- Plane compose 경로: `/home/plane/plane/plane-src` (WSL 내부. 이 레포의 `plane/plane-image` 아님)

---

## 증상

`http://192.0.2.10:8080/` 이 갑자기 응답하지 않는다.
TCP 연결은 되는데 **HTTP 응답이 0바이트**로 타임아웃된다.

```
$ curl -sv --max-time 6 http://192.0.2.10:8080/
* Connected to 192.0.2.10 (192.0.2.10) port 8080
> GET / HTTP/1.1
* Operation timed out after 6002 milliseconds with 0 bytes received
```

TCP만 붙고 데이터가 안 오는 건, Windows portproxy(리스너)는 살아 있는데
그 뒤의 WSL VM이 통째로 내려가 전달할 대상이 없을 때 나오는 전형적인 모습이다.

---

## 원인

### 1차 원인 — WSL2는 마지막 사용자 프로세스가 끝나면 VM을 내린다

VSCode Remote-WSL 창이 그 배포판의 유일한 사용처였기 때문에,
창을 닫는 순간 WSL VM이 종료되고 그 안의 Docker 컨테이너가 전부 함께 죽었다.

`/etc/wsl.conf` 의 `systemd=true`, `systemctl enable docker`,
컨테이너의 `restart: always` **모두 이걸 막지 못한다.** VM 자체가 사라지기 때문이다.

### 2차 원인(진짜 원인) — keepalive 예약 작업이 한 번도 살아 있던 적이 없었다

이미 `WSL-Keepalive-Ubuntu` 예약 작업이 등록되어 있었지만 인자가 이랬다.

```
-d Ubuntu -- bash -c 'while true; do sleep 3600; done'
```

**Windows는 작은따옴표를 인용부호로 처리하지 않는다.**
그래서 `bash -c` 에는 `while` 한 단어만 전달되고 나머지는 별개 인자가 되어,
bash가 문법 오류로 즉시 종료했다.

진단 결과가 이를 그대로 보여준다.

| 항목 | 값 | 의미 |
|------|-----|------|
| `LastRunTime` | 2026-07-28 | 한 달 넘게 안 돎 |
| `LastTaskResult` | `1` | 실행 즉시 실패 |
| `State` | `Ready` | 실행 중이 아님 (상시 기동이면 `Running` 이어야 함) |
| `LogonType` | `Interactive` | 로그온 세션에서만 실행 |

즉 keepalive는 등록 이후 **단 한 번도 WSL을 붙잡은 적이 없었고**,
그동안 WSL이 유지된 건 순전히 VSCode가 열려 있었기 때문이다.
구버전 태스크 `WSL-Keepalive` 도 같은 버그로 2026-07-21 이후 실패 상태였다.

### 3차 원인 — portproxy 갱신 태스크도 실패하고 있었다 (재부팅 시 터질 지뢰)

`PlaneLanPortProxy8080` 예약 작업은 부팅 후 WSL IP를 읽어 portproxy를 갱신하는 역할인데,
`SYSTEM` 계정(`LogonType=ServiceAccount`)으로 등록되어 있었다.

**WSL 배포판 등록은 사용자 레지스트리에 묶여 있어 SYSTEM 계정에서는 조회되지 않는다.**
그래서 스크립트의 `Get-WslIp` 가 재시도 150초를 전부 소진한 뒤 실패로 끝났다.

| 항목 | 값 | 의미 |
|------|-----|------|
| `LastRunTime` | `1999-11-30` | Task Scheduler의 "한 번도 실행 안 됨" 기본값 |
| `LastTaskResult` | `267011` → 수동 실행 시 `1` | 실행하면 실패 |

WSL IP가 우연히 그대로였던 덕에 지금까지 드러나지 않았을 뿐,
**재부팅으로 WSL IP가 바뀌는 순간 똑같이 접속 불가가 될 상태였다.**

---

## 조치

`setup_wsl_keepalive.ps1` 로 keepalive 작업을 올바르게 재등록했다.

| 변경 | 이전 | 이후 |
|------|------|------|
| 인자 | `-- bash -c 'while true; ...'` | `-u root -- sleep infinity` (인용부호 불필요) |
| **LogonType** | `Interactive` | **`Password`** (로그온 세션에 묶이지 않음) |
| 실패 시 재시작 | `RestartCount=0` | 1분 간격 최대 999회 |
| 배터리 | `DisallowStartIfOnBatteries=True` | 해제 (배터리에서도 유지) |
| 구버전 태스크 | 방치 | 제거 |
| 검증 | 없음 | `State=Running` + WSL 내 프로세스 존재 확인 |

적용 결과:

```
State          : Running
LogonType      : Password / work
Arguments      : -d Ubuntu -u root -- sleep infinity
LastTaskResult : 267009  (실행 중 - 정상)
```

WSL 내부에서도 상주 프로세스가 확인된다.

```
$ wsl -d Ubuntu -u root -- pgrep -af infinity
235988 sleep infinity
```

### 함정 — Interactive 로 등록하고 SSH에서 시작하면 죽는다

처음에는 `LogonType=Interactive` 로 등록했고, 등록 직후 `State=Running` 도 확인했다.
**그런데 SSH 연결을 끊자 곧바로 죽었다.**

```
State          : Ready
LastTaskResult : 3221225786   (0xC000013A = STATUS_CONTROL_C_EXIT)
```

`Interactive` 태스크는 **그것을 시작한 로그온 세션에 묶인다.**
SSH로 접속해 `Start-ScheduledTask` 로 시작하면 그 SSH 세션의 자식이 되고,
연결이 끊길 때 콘솔 제어 이벤트가 전달되어 `wsl.exe` 가 종료된다.

그래서 `-User` / `-Password` 조합(= `LogonType=Password`)으로 등록한다.
이러면 로그온 세션과 무관하게 실행되어 SSH를 끊어도 살아남는다.

> **검증은 반드시 연결을 끊었다 다시 붙어서 할 것.**
> 등록 직후의 `State=Running` 은 아무것도 증명하지 못한다.
>
> ```bash
> # 접속을 끊고 새로 붙은 뒤 같은 PID가 남아 있는지 확인
> ssh work@192.0.2.10 'wsl -d Ubuntu -u root -- pgrep -af infinity'
> ```

### 왜 `sleep infinity` 인가

인용부호가 전혀 필요 없는 단일 명령이라 Windows 인자 전달 문제를 원천적으로 피한다.
같은 실수를 반복하지 않으려면 **예약 작업 인자에 따옴표를 쓰지 않는 형태**를 유지할 것.

---

## 커맨드 모음

### 상태 확인 (변경 없음)

```powershell
powershell -ExecutionPolicy Bypass -File setup_wsl_keepalive.ps1 -Status
```

핵심만 빠르게 보려면:

```powershell
Get-ScheduledTask -TaskName WSL-Keepalive-Ubuntu | Select-Object State
Get-ScheduledTaskInfo -TaskName WSL-Keepalive-Ubuntu | Select-Object LastRunTime,LastTaskResult
```

`LastTaskResult` 해석:

| 값 | 16진수 | 의미 |
|----|--------|------|
| `0` | `0x0` | 정상 종료 |
| `267009` | `0x41301` | **실행 중 — 정상** (상시 기동 태스크의 정상값) |
| `267011` | `0x41303` | 한 번도 실행된 적 없음 |
| `1` | `0x1` | 실행 즉시 실패 → **인자의 따옴표를 의심할 것** |

### 등록 / 재등록 (관리자 권한 필요)

```powershell
# 원격(SSH)에서 세팅할 때는 반드시 -Password 를 쓴다. 안 그러면 연결 종료 시 죽는다.
powershell -ExecutionPolicy Bypass -File setup_wsl_keepalive.ps1 -Password '<work 계정 비밀번호>'

# 데탑 콘솔에 직접 앉아서 실행하는 경우에만 생략 가능
powershell -ExecutionPolicy Bypass -File setup_wsl_keepalive.ps1
```

### 원복

```powershell
powershell -ExecutionPolicy Bypass -File setup_wsl_keepalive.ps1 -Remove
```

### 수동으로 즉시 되살리기

`wsl --shutdown` 은 keepalive 프로세스까지 강제로 죽인다. 실행했다면:

```cmd
schtasks /run /tn "WSL-Keepalive-Ubuntu"
```

### 원격(이 레포가 있는 PC)에서 데탑에 적용하기

SSH는 Windows OpenSSH라 **cmd 셸로 붙는다.** WSL 명령은 `wsl -d Ubuntu -- ...` 로 감싸야 한다.
cmd는 작은따옴표를 인용부호로 취급하지 않으므로, 원격 명령은 큰따옴표로 감쌀 것.

```bash
# 스크립트 전송 (BOM 포함 UTF-8로 써야 한글이 안 깨진다)
B64=$(base64 -w0 shell-scripts/setup_wsl_keepalive.ps1)
printf '%s' "$B64" | sshpass -e ssh work@192.0.2.10 \
  "powershell.exe -NoProfile -NonInteractive -Command \"[IO.File]::WriteAllText('C:/Windows/Temp/setup_wsl_keepalive.ps1',[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String([Console]::In.ReadToEnd().Trim())),[Text.Encoding]::UTF8)\""

# 실행 (chcp 65001 을 붙여야 한글 출력이 안 깨진다)
sshpass -e ssh work@192.0.2.10 \
  'chcp 65001 & powershell -NoProfile -ExecutionPolicy Bypass -File C:\Windows\Temp\setup_wsl_keepalive.ps1'
```

### Plane 수동 기동 (WSL은 떠 있는데 컨테이너만 죽은 경우)

```bash
wsl -d Ubuntu -- bash -lc "cd /home/plane/plane/plane-src && docker compose up -d"
```

---

## 장애 시 점검 순서

`192.0.2.10:8080` 이 안 될 때 위에서부터 확인한다.

```bash
# 1. WSL VM이 떠 있나  → Stopped 면 keepalive 문제
wsl -l -v

# 2. keepalive가 실제로 돌고 있나  → Running 이어야 정상
powershell -Command "Get-ScheduledTask -TaskName WSL-Keepalive-Ubuntu | Select State"

# 3. 컨테이너가 떠 있나  → restart:always 라 보통 자동 복구된다
wsl -d Ubuntu -- docker ps

# 4. WSL IP와 portproxy 대상이 일치하나  → 다르면 portproxy 갱신 필요
wsl -d Ubuntu -- hostname -I
netsh interface portproxy show v4tov4
```

---

## 전제 조건 / 주의사항

### 계정 컨텍스트 — SYSTEM은 안 되고, 사용자 계정은 된다

WSL 배포판 등록은 **사용자 레지스트리에 묶여 있다.** 따라서 계정 선택이 중요하다.

| 방식 | WSL 조회 | 로그온 세션 의존 | 실측 결과 |
|------|----------|------------------|-----------|
| `SYSTEM` / `ServiceAccount` | **불가** | 없음 | portproxy 태스크가 이걸로 등록돼 실패하고 있었음 |
| `work` / `Interactive` | 가능 | **있음** | SSH에서 시작 시 연결 종료와 함께 죽음 |
| `work` / `Password` | 가능 | 없음 | **정상 동작** (현재 keepalive 방식) |

즉 "세션 0에서는 WSL이 안 된다"가 아니라 **"실제 사용자 계정 컨텍스트가 있어야 한다"** 가 정확하다.
`Password` 방식은 세션 0에서 돌지만 `work` 계정 컨텍스트를 갖기 때문에 문제없다.

### 자동 로그인 의존성 (portproxy 태스크만 해당)

`keepalive` 는 `Password` 방식이라 자동 로그인과 무관하게 부팅 시 뜬다.
반면 **`PlaneLanPortProxy8080` 은 아직 `Interactive`** 이므로,
부팅 후 IP 갱신은 Windows 자동 로그인(`AutoAdminLogon=1`)이 켜져 있어야 성립한다.

```cmd
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon
```

자동 로그인을 끄려면 이 태스크도 `Password` 방식으로 바꿔야 한다.

### WSL IP는 재부팅마다 바뀔 수 있다

Plane은 WSL 안에서 `0.0.0.0:8080` 을 바인딩하고,
Windows는 portproxy로 LAN 트래픽을 WSL IP로 넘긴다.

```
0.0.0.0:8080  ->  172.19.98.53:8080   (WSL IP, 고정 아님)
```

WSL IP가 바뀌면 portproxy가 낡은 주소를 가리켜 접속이 끊긴다.
갱신은 `setup_plane_lan_access.ps1` 과 예약 작업 `PlaneLanPortProxy8080` 이 담당한다.

이 태스크는 **반드시 사용자 계정 + Interactive** 로 등록해야 한다 (SYSTEM 불가).
2026-09-02 에 SYSTEM → `work` / Interactive / Highest 로 변경했고, 실행 결과가
`LastTaskResult=1`(실패) 에서 `0`(성공) 으로 바뀐 것을 확인했다.

```powershell
# 갱신 태스크가 실제로 성공하는지 확인 (0 이어야 정상)
schtasks /run /tn "PlaneLanPortProxy8080"
Start-Sleep -Seconds 35
Get-ScheduledTaskInfo -TaskName PlaneLanPortProxy8080 | Select-Object LastRunTime,LastTaskResult
```

포트가 바뀌었거나 규칙이 사라졌으면 이렇게 다시 세팅한다 (관리자 권한).

```powershell
powershell -ExecutionPolicy Bypass -File setup_plane_lan_access.ps1 -RegisterTask
powershell -ExecutionPolicy Bypass -File setup_plane_lan_access.ps1 -WhatIfOnly   # 상태만 확인
```

---

## 관련 파일

| 파일 | 역할 |
|------|------|
| `setup_wsl_keepalive.ps1` | **WSL 상시 기동** 예약 작업 등록/제거/상태확인 |
| `setup_plane_lan_access.ps1` | portproxy + 방화벽으로 LAN 접속 허용, 부팅 시 IP 갱신 |
| `setup_windows_wsl_autostart.sh` | 원격에서 WSL 자동 시작 + Windows 자동 로그인 일괄 세팅 |
| `README-wsl-runner-setup.md` | GitLab Runner / Plane 사이클 자동화 포함 전체 세팅 가이드 |
