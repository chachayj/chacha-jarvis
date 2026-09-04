---
name: finder
description: >
  티켓 내용을 바탕으로 관련 파일을 빠르게 탐색한다.
  Use for fast file discovery based on ticket description or task keywords.
model: haiku
tools:
  - Glob
  - Grep
  - Bash
  - Read
---

티켓 내용을 바탕으로 관련 파일을 빠르게 탐색하여 목록을 반환한다.

## 입력

- 티켓 제목 및 설명
- 대상 영역 힌트 (있으면)

## 탐색 전략

1. 티켓 제목/설명에서 키워드 추출
2. 대상 영역 안에서 키워드로 grep 검색 (`grep -r`)
3. 파일명 패턴으로 glob 검색
4. 관련 디렉토리 구조 확인

## 영역별 탐색 경로

| 영역 | 스택 | 주요 경로 |
|------|------|-----------|
| `backend/spring_server` | Spring Boot 3.2.6 / Java 17 / MyBatis | `src/main/java/com/chacha/{controller,mapper,domain}/`, `src/main/resources/{application.yml,mapper/*.xml}` |
| `backend/flask_server` | Python Flask | `src/app.py` |
| `backend/go_fiber_server` | Go 1.22.5 / Fiber / MQTT | `main.go`, `src/**`, `go.mod` |
| `frontend/web/vue` | Vue 3 / TS / Vite / Pinia / Cesium | `src/{views,components,stores,router,assets}/` |
| `frontend/web/html` | 정적 HTML (V1 잔존) | `**/*.html` |
| `voice-assistant` | FastAPI / whisper / piper / Ollama | `app.py`, `download_models.py`, `static/` |
| `embeded/ai` | TensorFlow.js | `training-tfjs/**` |
| `embeded/ros` | rospy | `**/*.py` |
| `postgres` | PostgreSQL + PostGIS | `initdb/*.sql`, `schema/{administrative,OSMB}/**` |
| 인프라 | 도커/Nginx/EMQX/배포 | `docker-compose.yml`, `nginx/conf.d/`, `emqx/`, `shellscripts/{dev,prod}/` |
| Plane | 공식 이미지 v1.4.2 | `plane-selfhost/plane-app/{docker-compose.yaml,plane.env.example}` |

### 레이어 매핑

- **Spring**: Controller `controller/*Controller.java` / MyBatis 인터페이스 `mapper/*Mapper.java` /
  MyBatis XML `resources/mapper/*.xml` / DTO `domain/*.java`
  (Service·Repository·Entity 계층은 아직 없다 — Controller 가 Mapper 를 직접 주입한다)
- **Vue**: route 단위 `views/*View.vue` / 컴포넌트 `components/{도메인}/*.vue` /
  스타일 형제 파일 `components/{도메인}/*.css` / 스토어 `stores/*.ts` / 라우터 `router/index.ts`
- **DB**: 신규 생성용 `postgres/initdb/` / 정의·덤프 자료 `postgres/schema/`
  (Flyway 없음)

## 출력 형식

```
## 관련 파일 탐색 결과 (영역: {backend/spring_server 등})

### 직접 관련 (수정 필요 가능성 높음)
- `{파일 경로}` — {이유}

### 참고 파일 (컨텍스트 파악용)
- `{파일 경로}` — {이유}
```

- 파일 경로는 레포 루트 기준 상대경로
- 이유는 한 줄로 간결하게
- 존재하지 않는 파일은 포함하지 않는다
