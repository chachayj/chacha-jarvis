# 03. Ubuntu 24.04 재설치 + ROS 2 Jazzy 설치

> 작성일: 2026-09-06 / 대상: Raspberry Pi 4 Model B 8GB (arm64)
> 공식 문서: <https://docs.ros.org/en/jazzy/Installation.html>

## 1. 왜 OS 를 갈아엎는가

현재 파이는 **Raspberry Pi OS (Debian 12 Bookworm)** 다.
여기서는 ROS 를 apt 한 방으로 깔 수 없다.

| 선택지 | 판단 |
| --- | --- |
| ROS 1 Noetic | ⛔ Debian 12 arm64 바이너리 자체가 없음 + 2025-05 EOL |
| ROS 2 on Bookworm | ⚠️ Tier 3 — 소스 빌드만 가능. SD카드에서 수 시간 + 의존성 지옥 |
| 도커로 ROS 2 | ⚠️ 가능하지만 GPIO·카메라 접근에 device 매핑/권한 설정이 번거로움 |
| **Ubuntu 24.04 + ROS 2 Jazzy** | ✅ **채택.** Tier 1 공식 지원, apt 설치, 2029-05 까지 |

## 2. ⚠️ 재설치 전 체크리스트

**SD카드를 굽는 순간 기존 내용이 전부 사라진다.** 아래를 먼저 처리한다.

- [ ] 파이 안에 남길 파일이 있는지 확인 후 백업
      ```bash
      ssh root@rpi-jarvis 'ls -la /home/chacha'
      scp -r root@rpi-jarvis:/home/chacha ./rpi-backup/
      ```
- [ ] [Tailscale admin 콘솔](https://login.tailscale.com/admin/machines) 에서 **기존 `rpi-jarvis` 노드 삭제**
      (안 지우면 새 노드가 `rpi-jarvis-1` 로 등록된다 → [01. 원격 접속 §5](01-remote-access.md))
- [ ] 파이에 **물리 접근 수단 확보** (모니터+키보드, 또는 같은 공유기 WiFi 의 폰/노트북)
      재설치 직후엔 Tailscale 이 없어 원격 접속이 불가능하다
- [ ] WiFi SSID / 비밀번호 확인 (유선이 없으므로 필수)

## 3. Ubuntu Server 24.04 굽기

**Raspberry Pi Imager** 를 쓴다 (윈도우에 설치).

1. Device: `Raspberry Pi 4`
2. OS: `Other general-purpose OS` → `Ubuntu` → **`Ubuntu Server 24.04 LTS (64-bit)`**
   - Desktop 이 아니라 **Server** 를 고른다. 로봇 노드에 GUI 는 불필요하고 자원만 먹는다
3. Storage: 해당 microSD
4. ⚙️ **설정(톱니)에서 아래를 미리 넣는다** — 이걸 해두면 첫 부팅부터 SSH 가 된다
   - 호스트명: `rpi-jarvis`
   - SSH 사용 설정 → 비밀번호 인증 허용
   - 사용자명 / 비밀번호 설정 (예: `chacha`)
   - **WiFi SSID / 비밀번호 / 국가(KR) 설정** ← 유선이 없으므로 필수

> 첫 부팅은 `cloud-init` 이 도는 관계로 2~3분 걸린다. 바로 SSH 가 안 돼도 조금 기다린다.

## 4. 첫 부팅 후 기본 세팅

```bash
# 같은 공유기 WiFi 의 기기에서 접속 (IP 는 공유기 관리페이지에서 확인)
ssh chacha@<파이IP>

sudo apt update && sudo apt full-upgrade -y
sudo apt install -y curl git vim
```

### Tailscale 재설치

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --ssh --hostname=rpi-jarvis
```

여기까지 하면 개발 PC 에서 다시 원격으로 붙을 수 있다.

```bash
# 개발 PC 에서
tailscale status
ssh chacha@rpi-jarvis 'lsb_release -a'
```

## 5. ROS 2 Jazzy 설치

### 5-1. 로케일

```bash
sudo apt install -y locales
sudo locale-gen en_US en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export LANG=en_US.UTF-8
```

### 5-2. apt 소스 등록

ROS 2 는 `ros2-apt-source` deb 패키지로 저장소를 등록한다.
(과거의 `apt-key` 방식은 폐기되었다.)

```bash
sudo apt install -y software-properties-common curl
sudo add-apt-repository universe
sudo apt update

export ROS_APT_SOURCE_VERSION=$(
  curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest \
  | grep -F "tag_name" | awk -F\" '{print $4}'
)
curl -L -o /tmp/ros2-apt-source.deb \
  "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo $VERSION_CODENAME)_all.deb"
sudo apt install -y /tmp/ros2-apt-source.deb
sudo apt update
```

### 5-3. 설치

```bash
sudo apt install -y ros-jazzy-ros-base ros-dev-tools
```

- `ros-jazzy-ros-base` — GUI 없는 최소 구성. **로봇 본체용은 이걸 쓴다**
- `ros-jazzy-desktop` — rviz2·rqt 포함. 파이에는 불필요 (개발 PC 쪽에 깔 것)

### 5-4. 환경 등록

```bash
echo "source /opt/ros/jazzy/setup.bash" >> ~/.bashrc
source ~/.bashrc
printenv ROS_DISTRO        # jazzy 가 나와야 함
```

### 5-5. 동작 검증

터미널 두 개로 확인한다.

```bash
# 터미널 A
ros2 run demo_nodes_cpp talker

# 터미널 B
ros2 run demo_nodes_py listener
```

`I heard: [Hello World: 1]` 이 찍히면 성공이다.

```bash
ros2 topic list
ros2 node list
```

## 6. 이 프로젝트용 추가 패키지

```bash
# MQTT 브리지용
sudo apt install -y python3-paho-mqtt

# GPIO (Ubuntu 에는 Raspberry Pi OS 기본 라이브러리가 없다)
sudo apt install -y python3-lgpio python3-gpiozero i2c-tools

# 워크스페이스 빌드 도구
sudo apt install -y python3-colcon-common-extensions
```

> `gpiozero` 는 Ubuntu 에서 백엔드로 `lgpio` 를 쓴다. `RPi.GPIO` 는 Pi 5 에서 동작하지 않으니
> 처음부터 `gpiozero` + `lgpio` 조합으로 간다.

### I2C / SPI 활성화

Ubuntu 에는 `raspi-config` 가 없으므로 직접 편집한다.

```bash
sudo nano /boot/firmware/config.txt
```

```ini
dtparam=i2c_arm=on
dtparam=spi=on
```

```bash
sudo usermod -aG i2c,spi,gpio,dialout $USER
sudo reboot
```

재부팅 후 `ls /dev/i2c-1` 로 확인한다.

## 7. 워크스페이스 초기화

```bash
mkdir -p ~/jarvis_ws/src
cd ~/jarvis_ws
colcon build
echo "source ~/jarvis_ws/install/setup.bash" >> ~/.bashrc
```

이후 `mqtt_bridge_node` 등 패키지를 `src/` 아래에 만든다.

## 8. 완료 후 갱신할 문서

- [ ] [02. 하드웨어 스펙](02-hardware-spec.md) — OS/소프트웨어 섹션을 Ubuntu 기준으로 갱신
- [ ] [README](../README.md) 로드맵 1단계 ✅ 로 변경
- [ ] 루트 `CLAUDE.md` 의 `embeded/ros` 스택 표기 갱신
