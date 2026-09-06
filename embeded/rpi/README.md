# chacha-jarvis-embeded-rpi

라즈베리파이 GPIO 제어 코드. **`gpiozero` 기반**이며 ROS 없이 동작한다.

> 폴더를 `ros` 와 나눈 이유: 여기 코드는 ROS 가 아니라 순수 Python 이다.
> ROS 2 패키지는 나중에 `embeded/ros/` 에 별도로 만든다.
> 문서(파이 스펙·키트 구성·배선법)는 [`embeded/ros/docs/`](../ros/docs/) 에 있다.

## 작업 방식

**코드는 이 레포에서 작성하고, 실행은 파이에서 한다.**

```
[WSL2 / 이 레포]  ──rsync over Tailscale──→  [라즈베리파이]
 embeded/rpi/                                 ~/chacha-rpi/
```

파이에서 직접 편집하지 않는다. 그래야 코드가 git 에 남는다.

### 전송 및 실행

```bash
cd embeded/rpi

./sync.sh                      # 전송만
./sync.sh led/blink.py         # 전송 후 실행
./sync.sh led/blink.py --pin 24 --interval 0.2
```

`Ctrl+C` 로 원격 실행을 중단한다.

접속은 Tailscale 을 경유한다 → [01. 원격 접속](../ros/docs/01-remote-access.md)

| 환경변수 | 기본값 | 용도 |
| --- | --- | --- |
| `PI_HOST` | `rpi-jarvis` | Tailscale MagicDNS 이름 |
| `PI_SSH_USER` | `root` | tailnet ACL 상 root 만 허용됨 |
| `PI_RUN_USER` | `chacha` | 파이에서 실제로 코드를 돌리는 계정 |
| `PI_DEST` | `/home/chacha/chacha-rpi` | 파이 쪽 경로 |

### 왜 scp 가 아니라 rsync 인가

`scp` 도 동작한다(확인 완료). 다만 `rsync` 는 **바뀐 파일만** 보내고 `--delete` 로
지운 파일도 반영해서, 코드를 반복 수정하는 지금 방식에 더 맞는다.

## 코드

| 경로 | 내용 | 핀 (BCM) |
| --- | --- | --- |
| [`led/blink.py`](led/blink.py) | LED 점멸 — 예제 01 | LED `21` |
| [`led/led_test.py`](led/led_test.py) | 대화형 배선 확인 (on/off/blink/fade) | LED `21` |
| [`tilt/tilt_ball_switch.py`](tilt/tilt_ball_switch.py) | 볼 스위치로 LED 제어 — 예제 08 | 스위치 `16` / 빨강 `24` / 파랑 `23` |
| [`mqtt/led_mqtt.py`](mqtt/led_mqtt.py) | **MQTT 로 LED 제어** (파이에서 실행) | LED `17` ✅ 실물 검증 |
| [`mqtt/cli.py`](mqtt/cli.py) | **채팅형 명령 입력 CLI** (개발 PC 에서 실행) | — |

전부 `--pin` 등 인자로 핀을 바꿀 수 있다.

## MQTT 원격 제어

볼 스위치 같은 물리 입력 없이 **외부 명령으로** LED 를 제어한다.
이미 구축된 `go_fiber_server -> EMQX` 파이프라인 끝에 파이를 붙이는 구조다.

```
[챗봇]  ─┐
[cli.py] ─┴─> [EMQX] ─ /Robot_Control_Command/{id} ─> [파이 led_mqtt.py] ─> LED
                  <─── /Robot_Status/{id} ── 상태 회신
```

### 실행 순서

```bash
# 1) 개발 PC 에서 EMQX 기동
cd ../..            # 레포 루트
docker compose up -d emqx

# 2) 파이에서 구독자 실행
cd embeded/rpi
./sync.sh mqtt/led_mqtt.py --broker 100.78.253.44

# 3) 다른 터미널에서 채팅형 CLI
python3 mqtt/cli.py
```

```
> 불 켜줘
  → {"Command": "불 켜줘"}
  ← 로봇 상태: on
> blink
  ← 로봇 상태: blink
```

한글·영어 모두 인식한다. 인식 키워드는 `led_mqtt.py` 상단 상수에 정의돼 있다.

| 명령 | 동작 |
| --- | --- |
| `불 켜줘`, `on`, `turn on light` | LED 켜기 |
| `불 꺼줘`, `off`, `turn off light` | LED 끄기 |
| `깜빡`, `blink` | LED 점멸 |
| `/raw {"Command": "..."}` | JSON 을 그대로 발행 |
| `/quit` | 종료 |

### 네트워크 경로

개발 PC 와 파이는 **서로 다른 회선**에 있다. EMQX 는 개발 PC 의 도커에서 돌고,
파이는 **Tailscale IP(`100.78.253.44`)로 접속**한다. 포트포워딩이 필요 없다.

| 항목 | 값 |
| --- | --- |
| 브로커 | 개발 PC 도커 EMQX, `0.0.0.0:1883` 바인딩 |
| 파이 접속 주소 | `100.78.253.44:1883` (평문) |
| 명령 토픽 | `/Robot_Control_Command/{robot_id}` |
| 상태 토픽 | `/Robot_Status/{robot_id}` |

> ⚠️ 현재는 **평문 1883** 을 쓴다. go 서버는 TLS(`8883`) + 클라이언트 인증서를 쓰므로,
> 실제 연동 단계에서 파이에도 `emqx/certs/cacert.pem` 을 넣고 TLS 로 전환해야 한다.

### 상시 실행 (systemd)

부팅 시 자동 기동하려면 서비스로 등록한다.

```bash
./systemd/install.sh
```

```bash
# 파이에서
systemctl status chacha-led-mqtt
journalctl -u chacha-led-mqtt -f
```

> 백그라운드 실행에 `nohup &` 를 쓰면 SSH 종료 시 프로세스가 죽는다(실측 확인).
> systemd 로 띄워야 세션과 무관하게 살아남는다.

### paho-mqtt 버전 주의

| 환경 | 버전 | API |
| --- | --- | --- |
| 개발 PC (Ubuntu 26.04) | 2.1.0 | v2 |
| 라즈베리파이 (Debian 12) | 1.6.1 | **v1** |

apt 로 설치하면 배포판마다 버전이 다르다. 두 버전은 **클라이언트 생성 방식과 콜백
시그니처가 달라서**, 코드에 호환 처리(`_make_client`)를 넣어 양쪽에서 모두 돌게 했다.

## 왜 RPi.GPIO 가 아니라 gpiozero 인가

엘레파츠 원본 예제는 `RPi.GPIO` 를 쓴다. 이 폴더는 `gpiozero` 로 다시 썼다.

| | `RPi.GPIO` | `gpiozero` |
| --- | --- | --- |
| 실행 권한 | `sudo` 필요 | **불필요** (`gpio` 그룹이면 됨) |
| 핀 정리 | `GPIO.cleanup()` 직접 호출 | 자동 |
| 라즈베리파이 5 | ❌ **동작 안 함** | ✅ 동작 |
| 코드 길이 | 길다 | 짧다 |

파이 4 에서는 둘 다 되지만, 새로 쓰는 코드는 `gpiozero` 로 통일한다.

## 환경 확인 (실측)

| 항목 | 값 |
| --- | --- |
| `gpiozero` | 2.0 (파이에 기본 설치됨) |
| 실행 계정 `chacha` 그룹 | `gpio`, `spi`, `i2c`, `dialout` 포함 → **sudo 불필요** |
| 파이 쪽 코드 경로 | `/home/chacha/chacha-rpi` |
| 예제 저장소 | `/home/chacha/raspi-AdvancedKit` (원본 참고용) |

## 다음

- [x] `paho-mqtt` 설치 후 EMQX 연동 — `/Robot_Control_Command/{id}` 구독
- [x] 채팅형 CLI 로 명령 발행 → 상태 회신까지 왕복 검증
- [x] **LED 실제 배선 후 물리 동작 확인** (2026-09-06, `GPIO17`/물리 11번 + GND 9번)
- [ ] go_fiber_server 경유 연동 (TLS 8883 + 클라이언트 인증서)
- [ ] 챗봇 "불 켜줘" → LED 점등 (루트 README 의 *"robot server 연동 예정"* 해소)

관련 문서:
[04. 하드웨어 키트](../ros/docs/04-hardware-kit.md) ·
[05. 빵판 기초](../ros/docs/05-breadboard-basics.md) ·
[06. 첫 실습 LED](../ros/docs/06-first-led.md)
