---
name: start_work
description: >
  Plane 티켓 번호를 입력받아 작업 환경 세팅 → 분석/설계 → 구현(do_work) → 커밋(done_work)까지
  단일 명령으로 끝까지 수행한다. 단계 사이에 사용자 컨펌 게이트가 있다.
  Use when the user wants to start a new task or run /start_work.
model: sonnet
tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
  - Grep
---

# Start Work — 통합 진입점

`/start_work {번호}` 한 번으로 **Plane 조회 → 브랜치 → 분석/설계 → plan 승인 → 구현 → CHANGELOG → 커밋**까지 수행한다.

## 핵심 원칙 (절대 위반 금지)

- **sub-agent 호출 금지**: `finder`, `analyst`, `planner`, `java-developer`, `javascript-developer`, `data-engineer`, `changelog_writer`, `commit_writer` **그 어떤 에이전트도 Agent 도구로 호출하지 않는다**. 이 에이전트(메인)가 모든 단계를 직접 수행한다.
- **새 세션 발생 금지**: 모든 작업이 같은 conversation 내에서 이루어져야 한다. 그래야 Read 결과가 컨텍스트에 누적되고 Edit 시 재Read가 발생하지 않는다.
- **재읽기 금지**: 같은 파일을 한 세션에서 두 번 Read하지 않는다. Step 5에서 읽은 파일은 Step 8에서 Edit할 때 재Read하지 않는다.
- **Step 헤더 출력 필수**: 각 단계 시작 직전 `**Step N: {단계명}** ({설명})` 형식으로 main 대화에 출력한다.
- **컨펌 게이트 준수**: do_work, done_work step 진입 직전에 사용자에게 yes/no 확인을 받는다. 'no'면 멈춘다.

---

## 이 레포는 단일 레포 모노레포다 (서브모듈 아님)

코드가 전부 이 레포 안에 있다. **커밋도 이 레포에서 한다.** 서브모듈은 없다.

| 영역 | 경로 | 스택 |
|------|------|------|
| Spring 백엔드 | `backend/spring_server` | Spring Boot 3.2.6 / Java 17 / Gradle / MyBatis / PostgreSQL |
| Flask 백엔드 | `backend/flask_server` | Python Flask |
| robot server | `backend/go_fiber_server` | Go 1.22.5 / Fiber / MQTT |
| 3D map 프론트 | `frontend/web/vue` | Vue 3 / TypeScript / Vite / Pinia / Cesium |
| 음성 챗봇 | `voice-assistant` | FastAPI + faster-whisper + piper-tts/gTTS → Ollama |
| 엣지 | `embeded/ai`, `embeded/ros` | TensorFlow.js, rospy |
| DB | `postgres/{initdb,schema}` | PostgreSQL (OSM·행정구역) |
| 인프라 | `docker-compose.yml`, `nginx/`, `emqx/`, `shellscripts/` | 도커 컴포즈 / Nginx / EMQX / 배포 스크립트 |

**작업 전 대상 영역을 먼저 결정한다.** 티켓 내용을 보고 판단하고, 애매하면 사용자에게 확인한다.

---

## 전체 흐름

```
/start_work {번호}
  ↓
Step 1: Plane 티켓 조회 (REST API)
Step 2: 대상 영역 결정 + 브랜치 생성 (feature/{PREFIX}-{번호})
Step 3: Plane 상태 → In Progress
Step 4: [finder 역할] Glob/Grep으로 관련 파일 탐색
Step 5: [analyst 역할] Read로 파일 내용 확인 + 코드 구조 분석
Step 6: [planner 역할] plan 작성 → plan 파일에 저장
Step 7: ExitPlanMode → 사용자 plan 승인 대기
  ↓ 승인
═══ 컨펌 게이트 1: "do_work 단계 진행할까요?" ═══
  ↓ yes
Step 8: [do_work] 메인이 직접 Edit/Write로 코드 수정 (재Read 없음)
  ↓ 구현 완료
═══ 컨펌 게이트 2: "done_work 단계 진행할까요?" ═══
  ↓ yes
Step 9: [done_work] git diff → CHANGELOG.md Edit → git commit
  ↓
완료 보고
```

---

## 절차

### Step 1: Plane 이슈 조회 (REST API)

**self-host 에는 Plane MCP 가 없다.** `mcp__plane__*` 도구를 쓰지 않는다.
이 레포의 Plane 은 `plane-selfhost/plane-app`(공식 이미지 v1.4.2)이고 접속 정보는
`~/.config/plane-chacha/selfhost.env` 에 있다.

```bash
set -a; source ~/.config/plane-chacha/selfhost.env; set +a
curl -s -H "X-API-Key: $PLANE_SELFHOST_TOKEN" \
  "$PLANE_SELFHOST_URL/api/v1/workspaces/$PLANE_SELFHOST_WORKSPACE/projects/$PLANE_SELFHOST_PROJECT_ID/issues/" \
  | python3 -c "
import sys, json, os
num = int(os.environ['TICKET'])
d = json.load(sys.stdin)
rows = d.get('results', d) if isinstance(d, dict) else d
hit = [i for i in rows if i.get('sequence_id') == num]
if not hit:
    print(f'{num} 번 티켓을 찾지 못했습니다 (총 {len(rows)}건 조회)'); raise SystemExit(1)
i = hit[0]
print('제목:', i.get('name'))
print('상태 id:', i.get('state'))
print('UUID:', i.get('id'))
print('설명:', (i.get('description_stripped') or '')[:500])
"
```

> ⚠️ **공개 API 는 모르는 쿼리 파라미터를 조용히 무시한다.** `?sequence_id=42` 를 붙여도
> 필터가 안 걸린 전체 목록이 오고 에러도 안 난다. 위처럼 **목록을 받아 코드에서 매칭**한다.

- 인자 없으면 사용자에게 티켓 번호 요청.
- env 파일이 없거나 Plane 이 응답하지 않으면 `/plane_user_setup` 을 안내하고 **여기서 멈춘다.**
- 조회 결과를 main 에 표시한다.

#### ⚠️ 프로젝트·prefix 미확정 (2026-09-03 기준)

Plane 인스턴스가 아직 기동/프로젝트 생성이 안 된 상태다.
`PLANE_SELFHOST_PROJECT_ID` 가 없으면 사용자에게 Plane 프로젝트 생성이 필요하다고
알리고 지시를 기다린다. 임의로 만들지 않는다.
기존 커밋 히스토리는 `[CHACH-*]` 형식이므로 prefix `CHACH` 를 권한다.

### Step 2: 대상 영역 결정 + 브랜치 생성

1. 티켓 내용으로 대상 영역 판단 (위 표 참고). 애매하면 사용자에게 확인.
2. 브랜치명: `feature/{PREFIX}-{번호}` (`feature/` 접두어 절대 생략 금지)

```bash
git branch --show-current
git checkout dev && git pull origin dev
git checkout -b feature/{PREFIX}-{번호}
```

이 레포의 기본 브랜치는 `dev` 다. 다른 브랜치에서 시작해야 하면 사용자에게 확인한다.

### Step 3: Plane 상태 → In Progress

프로젝트의 state 목록을 조회해 `In Progress` 의 UUID 를 찾고 PATCH 한다.

```bash
set -a; source ~/.config/plane-chacha/selfhost.env; set +a
BASE="$PLANE_SELFHOST_URL/api/v1/workspaces/$PLANE_SELFHOST_WORKSPACE/projects/$PLANE_SELFHOST_PROJECT_ID"

STATE=$(curl -s -H "X-API-Key: $PLANE_SELFHOST_TOKEN" "$BASE/states/" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin); rows = d.get('results', d) if isinstance(d, dict) else d
print(next((s['id'] for s in rows if s.get('name','').lower() == 'in progress'), ''))
")

curl -s -X PATCH -H "X-API-Key: $PLANE_SELFHOST_TOKEN" -H "Content-Type: application/json" \
  -d "{\"state\":\"$STATE\",\"assignees\":[\"$PLANE_DEV_USER_ID\"]}" \
  "$BASE/issues/{이슈 UUID}/" >/dev/null && echo "In Progress 로 변경 + 담당자 지정 완료"
```

담당자는 `PLANE_DEV_USER_ID` 를 쓴다. **매번 사용자에게 묻지 않는다.**

### Step 4: finder 역할 — 관련 파일 탐색 (메인이 직접)

티켓 키워드로 대상 영역 안에서 탐색:

- Spring: `backend/spring_server/src/main/java/com/chacha/**`, `src/main/resources/{application.yml,mapper/*.xml}`
- Flask: `backend/flask_server/src/**`, `voice-assistant/*.py`
- Go: `backend/go_fiber_server/{main.go,src/**}`
- Vue: `frontend/web/vue/src/**`
- DB: `postgres/{initdb,schema}/**`
- 인프라: `docker-compose.yml`, `nginx/conf.d/**`, `emqx/**`, `shellscripts/{dev,prod}/**`

`Glob`/`Grep`/`Bash`(find/rg)로 직접 탐색. 결과 목록을 main 에 표시.

### Step 5: analyst 역할 — 코드 구조 분석 (메인이 직접 Read)

Step 4에서 식별된 파일들을 `Read`로 직접 확인한다.

- 큰 파일은 `offset`/`limit`으로 부분 Read.
- 읽은 내용은 메인 컨텍스트에 누적된다 → **Step 8에서 재Read 불필요**.
- 분석 결과를 main 에 정리 (의존 관계, 데이터 흐름, 영향 범위).

### Step 6: planner 역할 — 계획 작성 (메인이 직접)

- 변경 단위, 순서, 영향도, 구체적 수정 위치를 정리.
- DB 변경이면 `postgres/initdb/*.sql` · `postgres/schema/**` 수정 필요 여부를 함께 판단.
  (이 레포는 Flyway 를 쓰지 않는다 — 컨테이너 초기화 SQL 기반이다)
- plan 을 plan 파일에 저장 (plan mode 사용 시 자동).

### Step 7: ExitPlanMode — 사용자 plan 승인

`ExitPlanMode` 도구로 사용자에게 plan 을 제시하고 승인 대기.

- 승인 → Step 8로 진행
- 거절/수정 요청 → Step 6으로 돌아가서 plan 재작성

### 컨펌 게이트 1: do_work 진입 전

`AskUserQuestion`으로 명시적 확인: "do_work 단계를 진행할까요? (코드 직접 수정)" yes/no.
- yes → Step 8, no → 멈춤.

### Step 8: do_work — 코드 수정 (메인이 직접 Edit, 재Read 금지)

**절대 규칙**:
- Step 5에서 이미 Read한 파일은 **다시 Read하지 않는다**. `Edit` 도구를 직접 호출한다.
- Step 5에서 안 읽은 파일이 새로 필요하면 그때만 Read한다.
- sub-agent(`java-developer`, `javascript-developer`, `data-engineer`) 호출 금지.

수정 순서:
- **Spring**: domain(DTO) → mapper 인터페이스 → mapper XML → controller
- **Vue**: types → store(Pinia) → composable → component → router
- **Go**: model → handler → route 등록

빌드는 **사용자가 직접 실행**한다 (`./gradlew build`, `npm run build`, `go build`, `docker compose up --build`).
`build/`·`dist/`·`node_modules/` 산출물은 직접 수정하지 않는다.

수정 완료 후 변경 파일 목록을 main 에 정리해서 표시.

### 컨펌 게이트 2: done_work 진입 전

`AskUserQuestion`으로 명시적 확인: "done_work 단계를 진행할까요? (CHANGELOG + commit)" yes/no.
- yes → Step 9, no → 멈춤.

### Step 9: done_work — CHANGELOG + commit (메인이 직접)

`changelog_writer`, `commit_writer` 호출 금지. 메인이 직접:

1. `git status` + `git diff` 로 변경 확인
2. `CHANGELOG.md` 의 `## Unreleased` 섹션에 항목 Edit 추가
   (이 레포에는 아직 `CHANGELOG.md` 가 없다 → 없으면 새로 만든다)
3. 커밋 메시지 작성 — **`[{PREFIX}-{번호}] {type} : {설명}`** (한국어, `type` 은 `feat`/`fix`/`chore`)
   히스토리 예: `[CHACH-25] feat : 스프링 부트, 그레들 초기 셋업`
4. `git add` + `git commit`
5. 커밋 후 `git status` 로 검증

**커밋 금지 대상**: `plane-selfhost/plane-app/plane.env`(시크릿, 추적 제외됨),
`~/.config/plane-chacha/selfhost.env`(레포 밖).

### 결과 보고

```
완료!

- 티켓: {PREFIX}-{번호} — {제목}
- 대상 영역: {backend/spring_server 등}
- 브랜치: feature/{PREFIX}-{번호}
- 변경 파일: {목록}
- 커밋: {해시} — {메시지 요약}

다음 단계 (선택):
- /publish_work — 브랜치 머지 준비
- /code-reviewer — 코드 리뷰
```

---

## 한계

- **컨텍스트 압축 발생 시**: 매우 큰 작업에서 압축이 일어나면 일부 Read 결과 휘발 → 부분 재Read 필요할 수 있음.
- **대파일 (1000줄+)**: 필요한 부분만 limit/offset으로 부분 Read.
- **컨펌 게이트에서 'no'**: 그 단계 이후는 진행하지 않고 사용자 대기.
- **Plane 미기동/프로젝트 미생성**: Step 1·3 이 동작하지 않는다. 사용자에게 알리고 멈춘다.
