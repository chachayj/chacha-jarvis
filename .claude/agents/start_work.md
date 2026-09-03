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

## 이 레포는 monorepo (서브모듈 구성)

실제 코드는 `apps/backend/*`, `apps/frontend/*` 서브모듈 안에 있다. 코드 커밋은 **해당 서브모듈 안에서** 이루어진다. root 레포는 Claude Code 설정 + 배포관리 레이어다.

| 서브모듈 | 스택 | 대상 티켓 성격 |
|----------|------|----------------|
| `apps/backend/backend_api` | Spring Boot / Java 21 (운영 v1) | CAD 변환 API 백엔드 |
| `apps/backend/backend_api_v2` | Spring Boot / Java 21 (신규 v2) | CAD 변환 API 백엔드 |
| `apps/backend/license-server` | Spring Boot / Java 21 (JWT, S3) | 라이선스 서버 |
| `apps/frontend/upload_frontend_v2` | React / TypeScript (CRA) | 업로드/뷰어 FE |
| `apps/frontend/web-frontend` | React / TypeScript (CRA) | 뷰어 FE |
| `apps/frontend/admin-frontend` | React / TypeScript (CRA) | 관리 FE |
| `apps/frontend/license-manager-frontend` | React / TypeScript (스캐폴드) | 라이선스 관리 FE |

**작업 전 대상 서브모듈을 먼저 결정한다.** 티켓 내용/사용자 안내를 보고 어느 서브모듈인지 판단하고, 애매하면 사용자에게 확인한다.

---

## 전체 흐름

```
/start_work PROJA-{번호}
  ↓
Step 1: Plane 티켓 조회
Step 2: 대상 서브모듈 결정 + 브랜치 생성 (feature/PROJA-{번호})
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
Step 9: [done_work] git diff → CHANGELOG.md Edit → git commit (해당 서브모듈 안에서)
  ↓
완료 보고
```

---

## 절차

### Step 1: Plane 이슈 조회

```
mcp__plane__retrieve_work_item_by_identifier(
  work_item_identifier: "PROJA-{번호}"
)
```

- 인자 없으면 사용자에게 티켓 번호 요청.
- 조회된 정보를 main에 표시:

```
티켓: PROJA-{번호}
제목: {제목}
상태: {현재 상태}
설명: {description 요약}
```

### Step 2: 대상 서브모듈 결정 + 브랜치 생성

1. 티켓 내용으로 대상 서브모듈 판단 (위 표 참고). 애매하면 사용자에게 확인.
2. 브랜치명: `feature/PROJA-{번호}` (이 형식 절대 위반 금지)
3. **브랜치는 대상 서브모듈 안에서** 생성한다:

```bash
cd apps/{backend|frontend}/{대상 서브모듈}
git branch --show-current
```

- 서브모듈 기본 브랜치가 `develop`이면: `git checkout develop && git pull origin develop && git checkout -b feature/PROJA-{번호}`
- `main`만 있으면 `main` 기준. 다른 브랜치이면 사용자에게 확인 후 진행.

### Step 3: Plane 상태 → In Progress

```
mcp__plane__update_work_item(
  project_id: "<PROJA_ID_SRC>",
  work_item_id: {이슈 UUID},
  state: "<PROJD_ID_SRC>"
)
```

### Step 4: finder 역할 — 관련 파일 탐색 (메인이 직접)

대상 서브모듈 안에서 티켓 키워드로 탐색:

- Spring Boot(BE): `apps/backend/{모듈}/src/main/java/**`, `src/main/resources/application/mappers/**`, Flyway `src/main/resources/application/flyway/release/`
- React(FE): `apps/frontend/{모듈}/src/{pages,components,api,store,models}/**`

`Glob`/`Grep`/`Bash`(find/rg)로 직접 탐색. 결과 목록을 main에 표시.

### Step 5: analyst 역할 — 코드 구조 분석 (메인이 직접 Read)

Step 4에서 식별된 파일들을 `Read`로 직접 확인한다.

- 큰 파일은 `offset`/`limit`으로 부분 Read.
- 읽은 내용은 메인 컨텍스트에 누적된다 → **Step 8에서 재Read 불필요**.
- 분석 결과를 main에 정리 (의존 관계, 데이터 흐름, 영향 범위).

### Step 6: planner 역할 — 계획 작성 (메인이 직접)

- 변경 단위, 순서, 영향도, 구체적 수정 위치, DB 변경 시 Flyway 마이그레이션 필요 여부를 정리.
- plan을 plan 파일에 저장 (plan mode 사용 시 자동).

### Step 7: ExitPlanMode — 사용자 plan 승인

`ExitPlanMode` 도구로 사용자에게 plan을 제시하고 승인 대기.

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

수정 순서(BE 기준): Entity/DTO → Repository(JPA/QueryDSL) → Service → Controller → Flyway 마이그레이션(엔티티 변경 시) → MyBatis XML.
`./gradlew build`, `npm run build` 등 빌드는 **사용자가 직접 실행**. `build/` 산출물 직접 수정 금지.

수정 완료 후 변경 파일 목록을 main에 정리해서 표시.

### 컨펌 게이트 2: done_work 진입 전

`AskUserQuestion`으로 명시적 확인: "done_work 단계를 진행할까요? (CHANGELOG + commit)" yes/no.
- yes → Step 9, no → 멈춤.

### Step 9: done_work — CHANGELOG + commit (메인이 직접)

`changelog_writer`, `commit_writer` 호출 금지. 메인이 직접:

1. 대상 서브모듈 안에서 `git status` + `git diff`로 변경 확인
2. 서브모듈에 `CHANGELOG.md`(또는 `changelog/`)가 있으면 Unreleased 섹션에 항목 Edit 추가
3. 커밋 메시지 작성 (한국어, `[PROJA-{번호}]` prefix, 컨벤션은 `git log` 참고)
4. **서브모듈 안에서** `git add` + `git commit` 실행
5. 커밋 후 `git status`로 검증
6. (선택) root 레포에서 서브모듈 포인터 갱신이 필요하면 사용자에게 안내 (root에서 `git add {서브모듈경로}` 후 커밋)

### 결과 보고

```
완료!

- 티켓: PROJA-{번호} — {제목}
- 대상 서브모듈: apps/{...}
- 브랜치: feature/PROJA-{번호}
- 변경 파일: {목록}
- 커밋: {해시} — {메시지 요약}

다음 단계 (선택):
- /publish_work — 브랜치 머지 준비
- /code-reviewer — 코드 리뷰
- root 서브모듈 포인터 갱신 필요 시 안내
```

---

## 한계

- **컨텍스트 압축 발생 시**: 매우 큰 작업에서 압축이 일어나면 일부 Read 결과 휘발 → 부분 재Read 필요할 수 있음.
- **대파일 (1000줄+)**: 필요한 부분만 limit/offset으로 부분 Read.
- **컨펌 게이트에서 'no'**: 그 단계 이후는 진행하지 않고 사용자 대기.
