# chacha-jarvis-embeded-ros

라즈베리파이 4를 **ROS 2 노드**로 구성해, chacha-jarvis IoT 시스템의 **디바이스 계층**을 담당시키는 임베디드 SW.

기존 시스템은 `웹/챗봇 → Go Fiber robot server → EMQX(MQTT)` 까지 완성되어 있고,
이 폴더가 그 뒤를 이어받아 **EMQX → 라즈베리파이 → 실제 하드웨어** 구간을 채운다.

## 아키텍처

```
[Vue3 + Cesium] ─┐
[Voice Chatbot]  ─┴→ [Go Fiber robot server] → [EMQX (TLS)]
                                                    │
                                 /Robot_Control_Command/{robotId}
                                                    ↓
                        ┌──────────────────────────────────────┐
                        │  Raspberry Pi 4 (ROS 2 Jazzy)        │
                        │  ├─ mqtt_bridge_node    ★ 핵심        │
                        │  ├─ gpio_control_node    전구/릴레이/모터 │
                        │  ├─ sensor_publisher_node  온습도/거리   │
                        │  └─ camera_node (v4l2)                │
                        └──────────────────────────────────────┘
```

★ `mqtt_bridge_node` 가 이 모듈의 핵심이다.
**필드 프로토콜(MQTT) ↔ 로봇 미들웨어(DDS)** 브리징으로, QoS 매핑·재연결·메시지 스키마 변환을 다룬다.

## 왜 ROS 1(rospy) 이 아니라 ROS 2(rclpy) 인가

초기 구상은 `rospy` 였으나 아래 이유로 **ROS 2 Jazzy** 로 확정했다.

| 근거 | 내용 |
| --- | --- |
| ROS 1 EOL | Noetic 이 2025-05 로 지원 종료. 신규 패치·패키지 없음 |
| 바이너리 부재 | Noetic 은 Ubuntu 20.04 / Debian 10 타겟. **Debian 12 arm64 용 패키지가 존재하지 않음** |
| 채용 시장 | 현재 공고 대부분이 ROS 2 (Humble/Jazzy) 기준 |
| 지원 기간 | Jazzy 는 2029-05 까지 (Humble 은 2027-05) |

## 로드맵

| 단계 | 내용 | 상태 |
| --- | --- | --- |
| 0 | 파이 원격 접속 확보 (Tailscale) | ✅ 완료 |
| 1 | 하드웨어 키트 파악 + 배선 기초 정리 | ✅ 완료 |
| 2 | GPIO 제어 실습 (LED → 센서) — **현재 OS 유지** | ✅ LED 완료 |
| 3 | `paho-mqtt` 로 EMQX 연동 — 명령으로 LED 제어 | ✅ 완료 |
| 4 | Ubuntu 24.04 재설치 + ROS 2 Jazzy 설치 | ⬜ 보류 |
| 5 | `mqtt_bridge_node` — MQTT 명령 → ROS 2 토픽/서비스 | ⬜ |
| 6 | `gpio_control_node` — 실제 LED/릴레이 구동 (데모 영상) | ⬜ |
| 7 | 센서 → 역방향 telemetry → Go 서버 → Cesium 상태 표시 | ⬜ |
| 8 | URDF + TF + `robot_state_publisher` → SLAM / Nav2 | ⬜ |

3단계까지 가면 루트 README 의 *"robot server 연동 예정"* 이 해소된다.

> **현재 방침**: ROS 2 는 4단계로 미루고, 지금 OS(Raspberry Pi OS)에서 GPIO·MQTT 부터 진행한다.
> Raspberry Pi OS 에 GPIO 라이브러리가 이미 갖춰져 있어 학습·검증이 빠르기 때문이다.

## 문서

| 문서 | 내용 |
| --- | --- |
| [01. 원격 접속 (Tailscale)](docs/01-remote-access.md) | PC ↔ 파이가 다른 회선일 때 붙이는 방법. 설치·검증·재설치 시 재등록 |
| [02. 하드웨어 실측 스펙](docs/02-hardware-spec.md) | 파이 4 실측값, 미연결 상태 기록, I2C/SPI 활성화 |
| [03. ROS 2 Jazzy 설치](docs/03-ros2-install.md) | Ubuntu 24.04 재설치 + Jazzy 설치 절차 |
| [04. 하드웨어 키트 구성·스펙](docs/04-hardware-kit.md) | 보유 키트 21개 모듈 인덱스, 핀 배치, 예제 저장소, 안전 수칙 |
| [05. 빵판·GPIO 배선 기초](docs/05-breadboard-basics.md) | 빵판 내부 구조, 확장 보드 연결, LED 실전 배선 |
| [06. 첫 실습 — LED 켜기](docs/06-first-led.md) | 예제 01 단계별 진행. 핀 위치, 배선 체크리스트, 트러블슈팅 |
| [07. GPIO 핀맵과 방향 기준](docs/07-gpio-pinout.md) | 전체 핀맵, 헤더 방향 확정법, 점유 현황, 냉각 실측 |

## 현재 상태

- 하드웨어: **Raspberry Pi 4 Model B Rev 1.5 / 8GB / arm64**
- OS: Raspberry Pi OS 64-bit (Debian 12 Bookworm) — **당분간 유지** (ROS 2 도입 시 Ubuntu 24.04 로 교체)
- 원격 접속: Tailscale 로 확보 (`rpi-jarvis`)
- 연결된 주변장치: **LED 1개** (`GPIO17`/물리 11번, 저항 경유) — MQTT 원격 제어 동작 확인
- 보유 키트: KEYES 라즈베리파이 고급키트(`EPXHTPVH`) + 카메라 모듈 V2 → [04. 하드웨어 키트](docs/04-hardware-kit.md)
