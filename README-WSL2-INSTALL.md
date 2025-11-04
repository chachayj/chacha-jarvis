

# ⚙️ 1️⃣ WSL2 활성화 (Windows 측)

관리자 권한 PowerShell 열기

아래 명령어 실행:

```
wsl --install -d Ubuntu-22.04
```

WSL2 기능 활성화

Ubuntu 22.04 설치

기본 WSL 버전 2 설정

재부팅 후 자동 적용


설치 완료 후 새 터미널이 열리면, 사용자 계정/비밀번호를 입력해 초기 설정합니다.


# 🧠 2️⃣ WSL2 버전 확인
```
wsl --list --verbose
```

정상 출력 예시:
```
  NAME            STATE           VERSION
* Ubuntu-22.04    Running         2
```

# 🧩 3️⃣ Ubuntu 22.04 기본 업데이트
```
sudo apt update && sudo apt upgrade -y
sudo apt install -y ca-certificates curl gnupg lsb-release
```

# 🐋 4️⃣ Docker Engine + Compose 직접 설치 (Desktop 없이)


## 🔑 GPG 키 등록

```
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

```

## 📦 리포지토리 등록

```
echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

```

## 🚀 엔진 및 Compose 설치
```
sudo apt update
sudo apt install -y docker-ce=5:28.4.0-1~ubuntu.22.04 \
                    docker-ce-cli=5:28.4.0-1~ubuntu.22.04 \
                    containerd.io=1.7.27-1 \
                    docker-buildx-plugin=0.17.1-1~ubuntu.22.04 \
                    docker-compose-plugin=2.39.2-1~ubuntu.22.04

```

## 🔒 5️⃣ 버전 고정 (자동 업데이트 방지)

```
sudo apt-mark hold docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-buildx-plugin

```

## 🔧 6️⃣ 서비스 시작 및 권한 설정

```
sudo service docker start
sudo systemctl enable docker
sudo usermod -aG docker $USER
newgrp docker

```

## 🧪 7️⃣ 설치 확인

```
docker --version
docker compose version

```

예시 출력:
```
Docker version 28.4.0, build 249d679
Docker Compose version v2.39.2

```