# chacha-jarvis

Ai 비서를 이용한 전구, 모터, 센서 등 라즈베리 디바이스들을 제어하는 IoT 시스템 프로젝트

기존 V1 버전은 [리드미 V1](README-V1.md) 에서 참조

2025.11.04 버전 2 진행 시작 (개발 완료 시점에 버전2 완료시점 기입 예정)

3D 엔진 Cesium, OSM(OpenStreetMap) 도입과 음성 챗봇, Ollama 모델 변경 진행, 라즈베리 파이 작업 및 도커 컴포즈화 진행 + Plane 스크럼 보조 툴 도입 예정

# 사전 설치 : WSL2 + 도커 + 도커 컴포즈

root경로의 README-WSL2-INSTALL.md [리드미 WSL2 인스톨](README-WSL2-INSTALL.md) 참조.

# 구동 방법

현재 모든 세팅은 wsl 2, ubuntu 22.04 + 도커로 세팅합니다.

```
emqx certs 인증서 생성용
chmod +x emqx/init_emqx.sh
chmod +x backend/go_fiber_server/wait-for-it.sh
```


```
# 구동 커맨드

docker compose down --remove-orphans
docker compose up --build

(만약 에러가 날경우 Credential Helper 초기화)
rm ~/.docker/config.json
docker logout
docker login
```

# background 구동
```
docker compose up -d
```

# 접속 url

- 3D map front (vue3 + cesium) : http://localhost:5173/ 혹은 nginx https://localhost:8443/korea3d/
- chatbot : http://localhost:8080 혹은 nginx https://localhost:8443/chatbot/
- robot server : http://localhost:3000/
- emqx dashboard : http://localhost:18083
- plane (개별구동) : http://localhost




# 구동 및 실행 예시 영상 참조. (robot server 연동 예정)

## 3DMap + Chatbot + robot server (Mqtt)

[🎥 시연 영상 열기](https://chachayj.github.io/chacha-jarvis/)


# Chatbot (올라마 + 보이스어시스턴트)

[리드미 Chatbot](./voice-assistant/README.md) 참조.

# Robot server (go fiber server : 라즈베리py + 날씨 serve용 서버)

[리드미 MQTT + 날씨 연동용 서버 ](./backend/go_fiber_server/README.md) 참조.

# EMQX Mqtt 브로커 도커 설치

[리드미 EMQX](./emqx/README.md) 참조.

# Plane (스크럼 플래닝 툴 : 개발 계획 도구) 사용

[리드미 Plane](./plane-selfhost/README.md) 참조.

# postgresql DB 도커 설치

[리드미 postgresql](README-postgresql.md) 참조.

# 프로젝트 구조

FrontEnd, BackEnd, Embeded 3개의 영역을 폴더별로 정리하였고

하위 요소들별 폴더를 만들은 mono repo 형태이다.

# 프로젝트 running 방법

- backend flask_server를 구동시켜서 웹애플리케이션을 호스팅하며
- backend go_fiber_server를 구동시켜서 웹앱플리케이션과 상호작용을 진행.

기본적으로 온프레미스 베이스에서 구동가능하도록 구현하였으며 ec2 셋업도 가능한 프로젝트이다.

# Plane의 프로젝트 Scrum board를 통해 1주 주기 Sprint 진행 (재직이슈로 일정한 작업 맨데이를 가지진 못함.)


# 구상중인 디렉토리 구조 (안)
```
Chacha-jarvis(monorepo)/
├── backend/
│   ├── flask_server/
│   │   └── app.py
│   └── go_fiber_server/
│       └── main.go
├── embeded/
│   ├── ai/
│   │   └── training-tfjs/
│   ├── ros/
│   │   └── rospy_app.py
└── frontend/
    ├── web/
    │   ├── static/
    │   │   └── augmented_audio
    │   │   └── css
    │   │   └── img
    │   │   └── js
    │   ├── templates/
    │   │   └── index.html

```