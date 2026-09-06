# 02. 라즈베리파이 하드웨어 실측 스펙

> 측정일: 2026-09-06 / 측정 방법: Tailscale SSH 원격 조사
> **이 시점의 OS 는 Ubuntu 24.04 로 교체 예정이다.** 아래는 교체 전 기준 기록.

## 1. 보드

| 항목 | 값 |
| --- | --- |
| 모델 | **Raspberry Pi 4 Model B Rev 1.5** |
| SoC | Broadcom BCM2711 / Cortex-A72 4코어 @ 1.8GHz |
| 아키텍처 | **arm64 (aarch64)** |
| RAM | **8GB** (`free -h` 기준 7.6Gi) |
| 저장소 | microSD 29GB (`/dev/mmcblk0p2`, 사용 4.9G / 여유 23G) |
| 온도 | 55.0°C |
| 스로틀 | `throttled=0x0` — 전압/온도 이상 없음 |

> 8GB 모델이라 ROS 2 + Nav2 + SLAM 을 올려도 메모리 여유가 있다.
> 다만 **microSD 는 SLAM/rosbag2 기록 시 I/O 병목**이 된다. USB SSD 부팅을 고려할 것.

## 2. OS (교체 전)

| 항목 | 값 |
| --- | --- |
| 배포판 | Raspberry Pi OS 64-bit — Debian GNU/Linux 12 (bookworm) |
| 커널 | `6.6.31+rpt-rpi-v8` |
| 일반 사용자 | `chacha` (uid 1000) |

## 3. 네트워크

| 인터페이스 | 주소 | 비고 |
| --- | --- | --- |
| `wlan0` | `172.30.1.22/24` | **WiFi 로만 연결됨.** 유선 미사용 |
| `tailscale0` | `100.107.41.54/32` | 원격 접속용 → [01. 원격 접속](01-remote-access.md) |

> 로봇 제어는 지연에 민감하다. 고정 설치라면 **유선 연결을 권장**한다.

## 4. ⚠️ 연결된 주변장치 — 없음

측정 시점 기준 **파이에 센서/액추에이터가 하나도 붙어 있지 않다.**

| 버스 | 상태 |
| --- | --- |
| **GPIO I2C (`i2c-1`)** | ❌ **비활성** — `config.txt` 에 `dtparam=i2c_arm=on` 없음 |
| `i2c-20`, `i2c-21` | ⚠️ 이건 **HDMI DDC 채널**이지 GPIO 용이 아니다 |
| **SPI** | ❌ 비활성 — `dtparam=spi=on` 없음 |
| 카메라 | ❌ `No cameras available!` |
| 시리얼 | ❌ `/dev/ttyUSB*`, `/dev/ttyACM*` 없음 |
| GPIO 문자장치 | ✅ `/dev/gpiochip0`, `/dev/gpiochip1` (커널 기본) |

### 💡 `i2cdetect` 결과를 오해하지 말 것

`i2c-20` / `i2c-21` 을 스캔하면 **거의 모든 주소가 응답하는 것처럼** 보인다.

```
00:          08 09 0a 0b 0c 0d 0e 0f
10: 10 11 12 13 14 15 16 17 18 19 1a 1b 1c 1d 1e 1f
...
```

이건 장치가 잔뜩 붙은 게 아니라 **HDMI DDC 버스의 유령 응답**이다.
실제 센서를 붙일 버스는 `i2c-1` 이며, 지금은 꺼져 있어 존재하지도 않는다.

### USB

```
Bus 001 Device 002: ID 2109:3431 VIA Labs, Inc. Hub
Bus 001 Device 006: ID 25a7:fa61 Areson Technology / Elecom MR-K013 Multicard Reader
```

허브와 멀티카드 리더뿐. 아두이노·LiDAR·USB 카메라 등 없음.

## 5. I2C / SPI 활성화 방법

센서를 붙이기 전에 먼저 켜야 한다.

```bash
sudo raspi-config          # Interface Options → I2C / SPI → Enable
```

또는 부트 설정을 직접 수정한다.

```bash
sudo nano /boot/firmware/config.txt
```

```ini
dtparam=i2c_arm=on
dtparam=spi=on
enable_uart=1              # 시리얼 장치를 쓸 경우
```

재부팅 후 확인:

```bash
ls /dev/i2c-1 /dev/spidev0.*
sudo apt install -y i2c-tools
i2cdetect -y 1             # 여기서 나오는 주소가 진짜 센서다
```

> Ubuntu 로 교체하면 `raspi-config` 가 없다. `/boot/firmware/config.txt` 를 직접 편집한다.

## 6. 설치된 소프트웨어 (교체 전)

| 있음 | 없음 |
| --- | --- |
| Python 3.11.2, pip 23.0.1 | **ROS (1/2 전부)** |
| git 2.39.2, gcc 12.2.0 | docker, cmake, node, colcon |

### Python 라이브러리

Raspberry Pi OS 기본 제공분이 이미 갖춰져 있었다.

| 라이브러리 | 상태 | 용도 |
| --- | --- | --- |
| `gpiozero` | ✅ | GPIO 고수준 API (**권장**) |
| `RPi.GPIO` | ✅ | 구형 저수준 API |
| `lgpio` | ✅ | gpiozero 백엔드 (Pi 5 기본) |
| `pigpio` | ✅ | 데몬 기반, 정밀 PWM |
| `gpiod` | ✅ | libgpiod 바인딩 |
| `smbus2` | ✅ | I2C |
| `picamera2` | ✅ | 카메라 |
| `serial` (pyserial) | ✅ | UART |
| **`paho.mqtt`** | ❌ **미설치** | **MQTT 브리지에 필요** |

> ⚠️ Ubuntu 24.04 로 교체하면 위 라이브러리가 **대부분 사라진다.**
> Raspberry Pi OS 가 미리 깔아주던 것들이라 Ubuntu 에서는 직접 설치해야 한다.
> `picamera2` 는 특히 Ubuntu 에서 설치가 까다로우니 카메라를 쓸 계획이면 미리 확인할 것.

## 7. 부트 설정 (교체 전 `config.txt`)

```ini
dtparam=audio=on
camera_auto_detect=1
display_auto_detect=1
auto_initramfs=1
dtoverlay=vc4-kms-v3d
max_framebuffers=2
disable_fw_kms_setup=1
arm_64bit=1
disable_overscan=1
arm_boost=1
```

`i2c_arm`·`spi` 항목이 없다는 점에 주목 — 4장의 비활성 상태와 일치한다.

## 8. 다음 할 일

- [ ] 보유 중인 센서 부품 식별 (모델명·핀아웃 확인)
- [ ] Ubuntu 24.04 arm64 재설치 → [03. ROS 2 설치](03-ros2-install.md)
- [ ] I2C / SPI 활성화
- [ ] `paho-mqtt` 설치 후 MQTT 브리지 연결
