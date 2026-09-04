# chacha-jarvis — Claude 프로젝트 지식베이스

이 파일은 Claude Code가 자동으로 읽는 프로젝트 컨텍스트입니다.
팀원 모두가 Claude Code로 이 레포를 열면 동일한 컨텍스트를 공유합니다.

사람이 읽는 사용 가이드는 `docs/claude-plane-guide.md` 입니다.

---

## ⚠️ 세션 시작 즉시 적용되는 절대 규칙 (어떤 상황에서도 예외 없음)

### 🚨 규칙 0 — 워크플로우 명령에서 sub-agent 호출 금지 + 파일 중복 Read 금지

**`/start_work`, `/do_work`, `/done_work` 워크플로우 명령은 메인이 직접 모든 단계를 수행한다. sub-agent 호출 0회.**

- finder, analyst, planner, devops, architect, changelog_writer, commit_writer 등 어떤 sub-agent도 Agent 도구로 호출하지 않는다
- 메인이 직접 Glob/Grep/Read/Edit/Write/Bash로 처리한다
- 이유: sub-agent는 새 컨텍스트에서 시작 → 메인 대화 히스토리 접근 불가 → 같은 파일 반복 Read로 토큰 폭증
- 한 세션에서 같은 파일은 한 번만 Read한다

**`/start_work`는 단일 명령으로 plan → do_work → done_work까지 같은 세션에서 끝까지 진행한다.**

- plan 승인 후 do_work 진입 직전, do_work 완료 후 done_work 진입 직전 — 두 지점에 사용자 컨펌 게이트 (`AskUserQuestion`) 필수
- 'no'면 그 단계 이후 진행하지 않고 사용자 추가 지시 대기

**각 단계 직전 Step 헤더 출력 필수** — 형식: `**Step N: {단계명}** ({설명})`

자세한 규칙: `.claude/rules/agent-behavior.md`

---

## 프로젝트 개요

**AI 비서로 라즈베리파이 디바이스(전구·모터·센서)를 제어하는 IoT 시스템.** 모노레포.

2025-11-04 부터 버전 2 진행 중 — 3D 엔진(Cesium) + OSM 도입, 음성 챗봇, Ollama 모델 교체,
라즈베리파이 작업 및 도커 컴포즈화.

### 디렉터리와 스택

| 경로 | 스택 | 역할 |
|------|------|------|
| `backend/spring_server` | Spring Boot 3.2.6 / Java 17 / Gradle / MyBatis / PostgreSQL | 행정구역 API 서버 (`com.chacha`) |
| `backend/flask_server` | Python Flask | 웹앱 호스팅 (`src/app.py`) |
| `backend/go_fiber_server` | Go 1.22.5 / Fiber | robot server — 라즈베리파이 MQTT + 날씨 |
| `frontend/web/vue` | Vue 3 / TypeScript / Vite / Pinia / Cesium / Cypress / Vitest | 3D map 프론트 |
| `frontend/web/html` | 정적 HTML (V1 잔존) | 구버전 |
| `voice-assistant` | FastAPI + faster-whisper + piper-tts/gTTS → Ollama | 음성 챗봇 (STT→LLM→TTS) |
| `embeded/ai` | TensorFlow.js (`training-tfjs`) | 엣지 AI 학습 |
| `embeded/ros` | rospy | 로봇 제어 |
| `postgres` | PostgreSQL (`initdb/`, `schema/{OSMB,administrative}`) | DB 초기화·스키마 |
| `emqx` | EMQX | MQTT 브로커 |
| `nginx` | Nginx | 리버스 프록시 (self-signed 인증서) |
| `shellscripts/{dev,prod}` | Bash / systemd / nginx conf | 서버 접속·배포·세팅 스크립트 |
| `plane-selfhost/plane-app` | 공식 Plane 도커 이미지 v1.4.2 | 스크럼 티켓 도구 |

**MariaDB·QueryDSL·Flyway·JPA·React 는 이 레포에 없다.** (다른 프로젝트 스택이다)
Spring 은 MyBatis(`src/main/resources/mapper/*.xml`) + PostgreSQL 조합을 쓴다.
프론트는 React 가 아니라 **Vue 3** 다.

### 포트 맵

| 포트 | 서비스 |
|------|--------|
| 1883 / 18083 | EMQX MQTT / 대시보드 |
| 3000 | go_fiber_server (robot server) |
| 5173 | vue-frontend (3D map) |
| 5434 | postgres (호스트 노출, 컨테이너 내부 5432) |
| 8080 | voice-assistant (chatbot) |
| 8081 | spring-server |
| 8443 | nginx (HTTPS) |
| 11434 | ollama |
| **8082 / 4430** | **Plane** (HTTP / HTTPS) |

포트를 새로 잡을 때 이 표를 먼저 확인할 것. 8080 은 이미 chatbot 이 쓴다.

### 기동

```bash
docker compose down --remove-orphans
docker compose up -d --build
```

Plane 은 root compose 에 없다 — `plane-selfhost/plane-app` 에서 따로 띄운다 (아래).

---

## Plane — 이 레포는 공식 도커 이미지 v1.4.2 를 이 PC 에서 돌린다

**운영 스택은 `plane-selfhost/plane-app` 하나다.** 공식 이미지를 무수정으로 받아 쓴다.

| | 값 |
|---|---|
| 이미지 | 공식 `artifacts.plane.so/makeplane/plane-*:v1.4.2` |
| 접속 | `http://localhost:8082` (HTTPS 4430) |
| `PULL_POLICY` | `if_not_present` |
| 데이터 | Docker named volume (`plane-app_pgdata` 등) |

Plane 소스를 직접 빌드하는 방식은 쓰지 않는다. 공식 이미지를 무수정으로 쓰므로
업그레이드가 `APP_RELEASE` 태그 교체로 끝나고 AGPL 소스 제공 의무도 생기지 않는다.
정상 여부는 `docker compose ps` — 컨테이너 이름이 `plane-app-*` 이어야 한다.

### 기동 / 정지

```bash
cd plane-selfhost/plane-app
docker compose --env-file plane.env up -d      # 기동
docker compose --env-file plane.env ps         # 상태
docker compose --env-file plane.env logs -f    # 로그
docker compose --env-file plane.env down       # 정지 (데이터는 남는다)
```

- `plane.env` 는 시크릿을 담아 **`.gitignore` 로 추적 제외**되어 있다. 템플릿은 `plane.env.example`.
- 데이터는 named volume 이라 폴더로 보이지 않는다 — `docker volume ls | grep plane-app`.
- **`docker compose down -v` 는 데이터를 전부 지운다.** 평소엔 `down` 만.
- 포트를 바꿀 때는 `LISTEN_HTTP_PORT`·`APP_DOMAIN`·`WEB_URL`·`CORS_ALLOWED_ORIGINS`
  **네 개를 같이** 고쳐야 한다. 하나만 고치면 로그인 후 CORS 로 튕긴다.
- `POSTGRES_PASSWORD` 는 첫 기동 때 DB 에 굳는다. 이미 기동한 뒤 바꾸면 api 가 뜨지 않는다.

### 업그레이드

공식 이미지 무수정이므로 태그만 올린다.

```bash
# plane.env 의 APP_RELEASE 수정 후
docker compose --env-file plane.env pull
docker compose --env-file plane.env up -d      # migrator 가 DB 마이그레이션 수행
```

### ⚠️ setup.sh 옵션 1(Install) / 5(Upgrade) 실행 금지

이 두 옵션은 Plane 공식 릴리즈에서 `docker-compose.yaml` 과 `plane.env` 를 새로 받아
덮어쓴다. 맞춰 둔 포트(8082)·버전(v1.4.2)·시크릿이 전부 초기화된다.

- 기동/정지는 위 `docker compose` 명령을 직접 쓴다
- 업그레이드는 위 절차를 쓴다
- `setup.sh` 는 2(Start) / 3(Stop) / 4(Restart) / 6(Logs) / 7(Backup) 만

---

## 티켓과 브랜치

### ⚠️ 프로젝트·prefix 미확정 (2026-09-03 기준)

이 PC 의 Plane 인스턴스는 **아직 기동/프로젝트 생성이 안 된 상태**다.
프로젝트를 만들 때 정하는 identifier 가 곧 티켓 prefix 이자 브랜치 이름이 된다.

- 기존 커밋 히스토리는 `[CHACH-*]` 형식 → prefix `CHACH` 로 만들면 히스토리와 이어진다
- 확정되면 이 섹션과 `.claude/rules/agent-behavior.md` 의 브랜치 규칙을 같이 갱신할 것
- 확정 전에는 `/start_work` 의 Step 1(Plane 조회)·Step 3(상태 변경)이 동작하지 않는다.
  이 경우 사용자에게 프로젝트 생성이 필요하다고 알리고 지시를 기다린다.

### 규약

| | 형식 | 예 |
|---|---|---|
| 브랜치 | `feature/{PREFIX}-{번호}` | `feature/CHACH-31` |
| 커밋 메시지 | `[{PREFIX}-{번호}] {type} : {설명}` | `[CHACH-25] feat : 스프링 부트, 그레들 초기 셋업` |
| 티켓 상태 | Backlog → In Progress (Step 3) → Done (머지 후) | |

`type` 은 히스토리에서 `feat`, `fix`, `chore` 를 쓴다.
브랜치는 **반드시 `feature/` 접두어를 붙인다** (`CHACH-31` 단독 사용 금지).

**CHANGELOG 운영 원칙**: 개발 중에는 `## Unreleased` 섹션에 누적,
`/release_changelog` 에서만 버전 확정. 이 레포에는 아직 `CHANGELOG.md` 가 없다 —
`/done_work` 첫 실행 시 새로 만든다.

---

## Plane 접속 — 토큰은 각자 자기 것을 쓴다

자격 증명은 레포가 아니라 **각자 로컬 홈** `~/.config/plane-chacha/selfhost.env`
(권한 600) 에 둔다. 이 파일은 git 추적 대상이 아니다.

```bash
PLANE_SELFHOST_URL=http://localhost:8082
PLANE_SELFHOST_WORKSPACE=<워크스페이스 slug>
PLANE_SELFHOST_PROJECT_ID=<프로젝트 UUID>
PLANE_SELFHOST_TOKEN=<자기 API 토큰>
PLANE_DEV_USER_ID=<자기 멤버 UUID>     # 담당자 자동 지정용
```

최초 1회 세팅은 `/plane_user_setup` 스킬로 한다.
손으로 하려면 Plane 웹 → 우측 상단 프로필 → **Settings → API Tokens** → 새 토큰 발급.

**담당자는 매번 묻지 않는다** — `PLANE_DEV_USER_ID` 를 그대로 쓴다.
팀원마다 자기 UUID 를 한 번만 넣어두면 그 PC 의 Claude 는 항상 그 사람을 담당자로 찍는다.

### ⚠️ created_by 는 토큰 주인으로 고정된다

**`created_by` 는 API 토큰 주인으로 자동 기록되며 API 로 바꿀 수 없다** (실측 확인).
남의 토큰을 쓰면 만든 티켓이 전부 그 사람 이름으로 남는다.

### API 호출

```bash
set -a; source ~/.config/plane-chacha/selfhost.env; set +a
curl -s -H "X-API-Key: $PLANE_SELFHOST_TOKEN" \
  "$PLANE_SELFHOST_URL/api/v1/workspaces/$PLANE_SELFHOST_WORKSPACE/projects/$PLANE_SELFHOST_PROJECT_ID/issues/"
```

| 종류 | 경로 | 인증 |
|------|------|------|
| 공개 REST API | `/api/v1/...` | `X-API-Key` 헤더 |
| 내부 API (page·estimate 등 공개 API 에 없는 것) | `/api/...` | 세션 로그인 필요 — `X-API-Key` 안 통함 |

> self-host 에는 **Plane MCP 서버가 없다** (SaaS 전용 기능). 티켓은 REST API 로 다룬다.
> 이 레포에는 `.mcp.json` 이 없다.

---

## 라이선스 (AGPL-3.0)

Plane Community Edition 은 AGPL-3.0. 라이선스 키가 필요 없고 무료다.

**이 레포는 공식 이미지를 무수정으로 쓰므로 소스 제공 의무가 생기지 않는다.**
의무는 "코드를 수정해서 네트워크로 제공할 때" 발생한다(§13 Remote Network Interaction).

| 상황 | 판단 |
|------|------|
| 공식 이미지 무수정 사용 (현재) | ✅ 추가 의무 없음 |
| 코드 수정 후 사내 팀원만 사용 | ⚠️ fork 를 사내에 두고 팀원 접근 가능하게 유지하면 충족 |
| 외부 협력사에 계정 발급 | ⚠️ 그들에게도 소스 제공 의무 발생 |
| 다른 회사에 서비스처럼 제공 | ⛔ 소스 제공 의무 + 상표 문제 |

**Plane 코드를 고치기 전에 설정·환경변수·웹훅·REST API 로 되는지 먼저 확인할 것.**
소스를 고치면 업그레이드가 태그 교체에서 수동 재적용으로 바뀌고 보안 패치 추적이 늦어진다.

---

## 저장 규칙

- 사용자가 "저장해", "기억해", "업데이트해" 라고 하면 내용에 맞는 파일을 업데이트할 것
  (규칙/지침은 이 파일, 사용법/운영은 `docs/claude-plane-guide.md`)
- **절대로 auto-memory(`~/.claude/projects/.../memory/MEMORY.md`)에 저장하지 말 것**
  → 이 레포는 git으로 팀 공유가 목적
- **민감 정보(비밀번호, API 키, 토큰)는 이 파일에 쓰지 말 것.**
  이 레포는 public 이다. 자격 증명은 `~/.config/plane-chacha/selfhost.env` 에만 둔다.
- `plane-selfhost/plane-app/plane.env` 는 추적 제외 대상이다 — 커밋하지 말 것
