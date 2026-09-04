# Claude Code × Plane 사용 가이드

이 레포에서 **Claude Code**(AI 코딩 에이전트)와 **Plane**(스크럼 티켓 도구)이
어떻게 맞물려 돌아가는지, 그리고 각자 어떻게 쓰는지를 정리한 문서다.

> 처음 받았다면 → [3. 최초 1회 세팅](#3-최초-1회-세팅) 부터 읽으면 된다.

---

## 1. 한 장 요약 — 셋의 관계

```
  ┌──────────┐   티켓 번호    ┌──────────────┐   코드 변경    ┌─────────┐
  │  Plane   │ ────────────▶ │ Claude Code  │ ────────────▶ │   git   │
  │ (무엇을) │               │  (어떻게)     │               │ (결과)  │
  └──────────┘ ◀──────────── └──────────────┘               └─────────┘
                상태/코멘트
```

| | 역할 | 이 레포에서의 위치 |
|---|---|---|
| **Plane** | 할 일을 티켓으로 쪼개고 스프린트로 관리 | 이 PC 에서 도커로 돌린다 → `http://localhost:8082` |
| **Claude Code** | 티켓을 받아 브랜치 생성 → 분석 → 구현 → 커밋 | `.claude/` 디렉터리의 규칙·에이전트·커맨드로 동작 |
| **git** | 결과물. 커밋 메시지에 티켓 번호가 박힌다 | `[TICKET-번호] type : 설명` |

핵심은 **티켓 번호가 세 곳을 꿰는 실**이라는 점이다.
`/start_work 25` 하나로 Plane 25번을 읽고, `feature/…-25` 브랜치를 만들고,
커밋 메시지에 `[…-25]`를 박고, 다시 Plane 25번을 Done 으로 옮긴다.

---

## 2. Plane 인스턴스 — 이 레포는 공식 이미지 v1.4.2 를 쓴다

Plane self-host 를 돌리는 방법은 공식 이미지를 받아 쓰는 것과 소스를 직접 빌드하는 것
두 가지인데, 이 레포는 **공식 이미지** 쪽이다.

| | `plane-selfhost/plane-app` |
|---|---|
| 이미지 | 공식 `artifacts.plane.so/makeplane/plane-*:v1.4.2` |
| 버전 고정 | `APP_RELEASE=v1.4.2` |
| `PULL_POLICY` | `if_not_present` (레지스트리에서 받음) |
| 데이터 | Docker **named volume** (`plane-app_pgdata` 등) |
| 첫 기동 | 이미지 pull 약 3~5GB, 10분 내외 |

**공식 이미지를 쓰는 이유**

1. 코드를 고치지 않으니 upstream 업그레이드가 `APP_RELEASE` 태그 한 줄 교체로 끝난다.
   소스 빌드는 새 릴리즈마다 수정을 손으로 재적용해야 해서 보안 패치 추적이 늦어진다.
2. AGPL-3.0 소스 제공 의무가 생기지 않는다 ([7절](#7-라이선스--공식-이미지를-쓰면-신경-쓸-게-거의-없다) 참고).

> 정상 여부는 `docker compose ps` 로 확인 — 컨테이너 이름이 `plane-app-*` 이어야 한다.

### 기동 / 정지

```bash
cd plane-selfhost/plane-app

docker compose --env-file plane.env up -d      # 기동 (첫 실행은 이미지 pull 대기)
docker compose --env-file plane.env ps         # 상태
docker compose --env-file plane.env logs -f    # 로그
docker compose --env-file plane.env down       # 정지 (데이터는 남는다)
```

기동 후 `http://localhost:8082` → 첫 접속 시 관리자 계정 생성 화면이 뜬다.

### 포트 — 왜 8082 인가

이 레포는 이미 여러 포트를 쓰고 있어서 Plane 이 기본값 80 을 쓰면 충돌한다.

| 포트 | 쓰는 곳 |
|------|---------|
| 1883 / 18083 | EMQX MQTT 브로커 / 대시보드 |
| 3000 | go_fiber_server (robot server) |
| 5173 | vue-frontend (3D map) |
| 5434 | postgres (호스트 노출) |
| 8080 | voice-assistant (chatbot) |
| 8081 | spring-server |
| 8443 | nginx (HTTPS) |
| 11434 | ollama |
| **8082 / 4430** | **Plane (HTTP / HTTPS)** |

포트를 바꾸려면 `plane.env` 의 `LISTEN_HTTP_PORT`, `APP_DOMAIN`, `WEB_URL`,
`CORS_ALLOWED_ORIGINS` **네 개를 같이** 고쳐야 한다. 하나만 고치면 로그인이 되다가
CORS 에러로 튕긴다.

### 데이터는 어디 있나

named volume 이라 폴더로 보이지 않는다.

```bash
docker volume ls | grep plane-app      # pgdata, uploads, redisdata, rabbitmq_data ...
```

`docker compose down` 으로는 지워지지 않는다. **`down -v` 를 쓰면 전부 날아간다.**

백업:

```bash
cd plane-selfhost/plane-app
docker compose --env-file plane.env down                       # 반드시 정지 후
docker run --rm -v plane-app_pgdata:/src -v "$PWD":/out alpine \
  tar czf /out/plane-pgdata-$(date +%F).tar.gz -C /src .
```

> Postgres 가 돌고 있는 상태로 pgdata 를 복사하면 **DB 가 깨질 수 있다.**
> 쓰기 도중의 파일을 복사하게 되기 때문이다. 무중단이 필요하면 `pg_dump` 를 쓰고
> MinIO 업로드 파일(`uploads` 볼륨)을 따로 챙긴다.

### 업그레이드

공식 이미지를 무수정으로 쓰므로 태그만 올리면 된다.

```bash
cd plane-selfhost/plane-app
# plane.env 의 APP_RELEASE 를 새 버전으로 수정
docker compose --env-file plane.env pull
docker compose --env-file plane.env up -d      # migrator 가 DB 마이그레이션 수행
```

### ⚠️ `setup.sh` 옵션 1(Install) / 5(Upgrade) 실행 금지

이 두 옵션은 Plane 공식 릴리즈에서 `docker-compose.yaml` 과 `plane.env` 를
**새로 받아 덮어쓴다.** 우리가 맞춰 둔 포트(8082)·버전(v1.4.2)·시크릿이 전부 초기화된다.

- 기동/정지는 위 `docker compose` 명령을 직접 쓴다
- 업그레이드는 위 "업그레이드" 절차를 쓴다
- `setup.sh` 는 2(Start) / 3(Stop) / 4(Restart) / 6(Logs) / 7(Backup) 만

---

## 3. 최초 1회 세팅

### 3-1. Plane 기동 + 계정 만들기

```bash
cd plane-selfhost/plane-app
cp plane.env.example plane.env          # 이미 plane.env 가 있으면 생략
# plane.env 의 <생성하세요> 자리를 채운다 (생성 명령은 파일 끝 주석에 있다)
docker compose --env-file plane.env up -d
```

`http://localhost:8082` 접속 → 관리자 계정 생성 → 워크스페이스 생성 →
프로젝트 생성. 프로젝트를 만들 때 **identifier(prefix)** 를 정하는데, 이게 곧
티켓 번호의 접두어이자 브랜치 이름이 된다.

> **⚠️ 이 레포는 아직 프로젝트·prefix 가 확정되지 않았다.**
> 기존 커밋 히스토리는 `[CHACH-*]` 형식을 쓰고 있으므로 prefix `CHACH` 로
> 만드는 것이 히스토리와 이어진다. 확정되면
> [CLAUDE.md](../CLAUDE.md) 의 "Plane 접속" 섹션과
> [.claude/rules/agent-behavior.md](../.claude/rules/agent-behavior.md) 의
> 브랜치 규칙을 같이 갱신할 것.

### 3-2. 토큰 등록

Claude 가 Plane 을 읽고 쓰려면 API 토큰이 필요하다.

```
/plane_user_setup
```

이 스킬이 토큰을 받아 `~/.config/plane-chacha/selfhost.env` (권한 600) 에 기록하고
프로젝트 접근까지 검증한다. 손으로 하려면:

1. Plane 웹 → 우측 상단 프로필 → **Settings → API Tokens** → 새 토큰 발급
2. `~/.config/plane-chacha/selfhost.env` 에 기록

```bash
PLANE_SELFHOST_URL=http://localhost:8082
PLANE_SELFHOST_WORKSPACE=<워크스페이스 slug>
PLANE_SELFHOST_PROJECT_ID=<프로젝트 UUID>
PLANE_SELFHOST_TOKEN=<발급받은 토큰>
PLANE_DEV_USER_ID=<자기 멤버 UUID>     # 담당자 자동 지정용
```

이 파일은 **레포가 아니라 각자 로컬 홈**에 있다. 한 번만 넣어두면 그 PC 의 Claude 는
계속 그 사람으로 동작한다 — `/start_work` 가 매번 담당자를 묻지 않는 이유다.

> ⚠️ **다른 레포의 env 와 섞지 말 것.**
> 이 PC 에 `~/.config/plane-migrate/selfhost.env` 가 이미 있을 수 있는데, 그건
> 다른 레포가 쓰는 **별개의 Plane 인스턴스** 용이다.
> 인스턴스가 다르니 토큰도 프로젝트도 다르다. 덮어쓰면 양쪽이 다 깨진다.
>
> | 파일 | 대상 |
> |------|------|
> | `~/.config/plane-chacha/selfhost.env` | **이 레포** — `localhost:8082` |
> | `~/.config/plane-migrate/selfhost.env` | 다른 레포 — 건드리지 않는다 |

### 3-3. ⚠️ 토큰은 반드시 자기 것으로

**`created_by` 는 API 토큰 주인으로 자동 기록되며 API 로 바꿀 수 없다.**
남의 토큰을 쓰면 만든 티켓이 전부 그 사람 이름으로 남는다.

### API 호출 방식

```bash
set -a; source ~/.config/plane-chacha/selfhost.env; set +a
curl -s -H "X-API-Key: $PLANE_SELFHOST_TOKEN" \
  "$PLANE_SELFHOST_URL/api/v1/workspaces/$PLANE_SELFHOST_WORKSPACE/projects/$PLANE_SELFHOST_PROJECT_ID/issues/"
```

| 종류 | 경로 | 인증 |
|------|------|------|
| 공개 REST API | `/api/v1/...` | `X-API-Key` 헤더 |
| 내부 API (page·estimate 등) | `/api/...` | 세션 로그인 필요 (`X-API-Key` 안 통함) |

> self-host 에는 **Plane MCP 서버가 없다** (SaaS 전용 기능). 티켓은 REST API 로 다룬다.

---

## 4. Claude Code 사용법

### 4-1. `.claude/` 디렉터리 구조

| 경로 | 무엇 |
|------|------|
| [CLAUDE.md](../CLAUDE.md) | 세션 시작 시 **자동으로 읽히는** 프로젝트 컨텍스트. 절대 규칙이 여기 있다 |
| [.claude/rules/](../.claude/rules/) | 에이전트 행동 규칙 (워크플로우 단계, 금지사항) |
| [.claude/commands/](../.claude/commands/) | 슬래시 커맨드 정의 (`/start_work` 등) |
| [.claude/agents/](../.claude/agents/) | 전문 에이전트 정의 (스택별 구현 담당) |
| [.claude/skills/](../.claude/skills/) | 스킬 (`/plane_user_setup`) |
| [.claude/settings.json](../.claude/settings.json) | 도구 권한 허용 목록 |

팀원 누구나 이 레포를 Claude Code 로 열면 **같은 컨텍스트를 공유**한다.
그래서 규칙을 고치려면 파일을 고쳐 커밋한다 — 대화로 말하고 끝내면 안 된다.

### 4-2. 워크플로우 커맨드

```
/start_work {번호}   ← 평소엔 이것만 쓰면 된다
                      plan → 구현 → 커밋까지 한 세션에서 끝까지 진행

/do_work             단독 폴백. 새 세션에서 plan 만 가지고 구현만 할 때
/done_work           단독 폴백. 별도 세션에서 CHANGELOG + commit 만 할 때
/publish_work        커밋 정리 + MR 준비
/release_changelog   Unreleased → 버전 확정
```

`/start_work` 가 밟는 단계:

```
Step 1: Plane 조회        (이슈 정보 확인)
Step 2: 브랜치 생성       (feature/{PREFIX}-{번호})
Step 3: Plane 상태 변경   (In Progress)
Step 4: 파일 탐색         (Glob/Grep)
Step 5: 코드 분석         (Read 후 구조 분석)
Step 6: 계획 작성         (plan 파일 저장)
Step 7: 사용자 plan 승인  (ExitPlanMode)
        ── 컨펌 게이트 ──
Step 8: 코드 수정         (do_work)
        ── 컨펌 게이트 ──
Step 9: CHANGELOG + 커밋  (done_work)
```

각 단계 직전에 `**Step N: {단계명}**` 헤더가 대화에 출력된다.
**컨펌 게이트 두 곳**에서 진행 여부를 묻는다 — 'no' 면 거기서 멈추고 지시를 기다린다.

### 4-3. 지켜지는 절대 규칙

| 규칙 | 이유 |
|------|------|
| 워크플로우 명령에서 **sub-agent 호출 0회** | sub-agent 는 새 컨텍스트에서 시작 → 메인 대화 히스토리 접근 불가 → 같은 파일 반복 Read 로 토큰 폭증 |
| 한 세션에서 **같은 파일 한 번만 Read** | 위와 같은 이유. Step 5 에서 읽은 파일을 Step 8 에서 다시 읽지 않는다 |
| **Step 헤더 없이 진행 금지** | 사용자가 지금 어느 단계인지 볼 수 있어야 한다 |
| `/start_work` 안에서 **새 세션 발생 금지** | 같은 conversation 의 step 으로 인라인 수행 |

자세한 건 [.claude/rules/agent-behavior.md](../.claude/rules/agent-behavior.md).

### 4-4. 전문 에이전트 (워크플로우 밖에서 명시 호출할 때만)

| 커맨드 | 담당 | 이 레포에서의 대상 |
|--------|------|--------------------|
| `/java-developer` | Spring Boot 3.2.6 / Java 17 / MyBatis | [backend/spring_server/](../backend/spring_server/) |
| `/javascript-developer` | Vue 3 + TS + Vite + Pinia + Cesium | [frontend/web/vue/](../frontend/web/vue/) |
| `/data-engineer` | PostgreSQL 스키마 / OSM 데이터 | [postgres/](../postgres/) |
| `/devops` | 도커 컴포즈 / Nginx / 배포 스크립트 | [docker-compose.yml](../docker-compose.yml), [shellscripts/](../shellscripts/) |
| `/architect` | 시스템 아키텍처 결정 | 전체 |
| `/debug` | 크로스 스택 디버깅 | 전체 |
| `/code-reviewer` | 코드 리뷰 | 전체 |

### 4-5. 자동 코드 리뷰 (기본 ON)

코드 변경이 끝나면 백그라운드로 `code-reviewer` 가 떠서 버그·엣지케이스·품질을
훑고 결과를 요약해 준다. 끄려면 "리뷰 꺼", 다시 켜려면 "리뷰 켜".

---

## 5. Plane ↔ git 연결 규약

| | 형식 | 예 |
|---|---|---|
| 브랜치 | `feature/{PREFIX}-{번호}` | `feature/CHACH-31` |
| 커밋 메시지 | `[{PREFIX}-{번호}] {type} : {설명}` | `[CHACH-25] feat : 스프링 부트, 그레들 초기 셋업` |
| 티켓 상태 | Backlog → **In Progress** (Step 3) → Done (머지 후) | |

`type` 은 히스토리에서 `feat`, `fix`, `chore` 가 쓰이고 있다.

**CHANGELOG 운영 원칙**: 개발 중에는 `## Unreleased` 섹션에 누적하고,
`/release_changelog` 에서만 버전을 확정한다.

> ⚠️ 이 레포에는 아직 `CHANGELOG.md` 가 없다. `/done_work` 가 이 파일을 기대하므로
> 첫 실행 시 새로 만들어진다.

---

## 6. 자주 밟는 함정

| 증상 | 원인 | 해결 |
|------|------|------|
| 로그인 후 화면이 안 뜨고 CORS 에러 | 포트를 바꿀 때 `APP_DOMAIN`/`WEB_URL`/`CORS_ALLOWED_ORIGINS` 중 일부만 고침 | 네 값을 모두 맞춘다 |
| `api` 컨테이너가 인증 실패로 재시작 반복 | 첫 기동 뒤에 `POSTGRES_PASSWORD` 를 바꿨다 | 비밀번호는 첫 기동 때 DB 에 굳는다. 되돌리거나 볼륨을 버린다 |
| 내가 만든 티켓이 남의 이름으로 기록됨 | 남의 API 토큰을 쓰고 있다 | `created_by` 는 변경 불가. 자기 토큰으로 교체 후 다시 만든다 |
| `/api/...` 호출이 401/403 | 내부 API 는 `X-API-Key` 를 받지 않는다 | 세션 로그인으로 호출한다 |
| 포트 8080 이 이미 사용 중 | voice-assistant 가 쓰고 있다 | Plane 은 8082 를 쓴다 |
| 설정이 원래대로 되돌아감 | `setup.sh` 1 또는 5 를 실행했다 | 2절의 `setup.sh` 경고 참고. 옵션 2/3/4/6/7 만 쓴다 |
| 데이터가 사라짐 | `docker compose down -v` 를 실행했다 | `-v` 는 볼륨까지 지운다. 평소엔 `down` 만 |

---

## 7. 라이선스 — 공식 이미지를 쓰면 신경 쓸 게 거의 없다

Plane Community Edition 은 **AGPL-3.0** 이다. 라이선스 키가 필요 없고 무료다.

의무가 생기는 지점은 **"코드를 수정해서 네트워크로 제공할 때"** 다(§13 Remote Network
Interaction). 이 레포는 **공식 이미지를 무수정으로 쓰므로 소스 제공 의무가 생기지
않는다.** 이것이 소스 빌드 대신 공식 이미지를 택한 부수 효과다.

| 상황 | 판단 |
|------|------|
| 공식 이미지 무수정 사용 | ✅ 추가 의무 없음 |
| 코드 수정 후 사내 팀원만 사용 | ⚠️ fork 를 사내에 두고 팀원 접근 가능하게 유지하면 충족 |
| 외부 협력사에 계정 발급 | ⚠️ 그들에게도 소스 제공 의무 발생 |
| 다른 회사에 서비스처럼 제공 | ⛔ 소스 제공 의무 + 상표 문제 |

**코드를 고치기 전에 설정·환경변수·웹훅·REST API 로 되는지 먼저 확인할 것.**
고친 파일이 늘어날수록 업그레이드가 무거워지고 보안 패치 추적이 늦어진다.

---

## 8. 남은 TODO

- [ ] Plane 인스턴스 첫 기동 + 관리자 계정 생성
- [ ] 워크스페이스 / 프로젝트 생성, **prefix 확정** (히스토리와 맞추려면 `CHACH`)
- [ ] `~/.config/plane-chacha/selfhost.env` 에 URL·워크스페이스·프로젝트 ID·토큰 기록
- [ ] 확정된 prefix 를 [CLAUDE.md](../CLAUDE.md) 와
      [.claude/rules/agent-behavior.md](../.claude/rules/agent-behavior.md) 에 반영
- [ ] `CHANGELOG.md` 초기 생성
