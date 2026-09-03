# 에이전트 위임 행동 규칙

## 절대 금지 사항

- **`/start_work`, `/do_work`, `/done_work` 워크플로우에서 sub-agent를 호출하는 것은 금지**
  → finder, analyst, planner, java-developer, javascript-developer, data-engineer, changelog_writer, commit_writer 등 어떤 sub-agent도 Agent 도구로 호출하지 않는다.
  → 메인이 직접 Glob/Grep/Read/Edit/Write/Bash로 모든 단계를 수행한다.
  → 이유: sub-agent는 새 컨텍스트에서 시작 → 메인 대화 히스토리 접근 불가 → 같은 파일 반복 Read로 토큰 폭증.

- **새 세션 발생 금지** (워크플로우 내에서)
  → `/start_work`에서 `/do_work`나 `/done_work`를 별도 명령으로 호출하지 않는다.
  → 같은 conversation 내 step으로 인라인 수행한다.

- **같은 파일 반복 Read 금지**
  → 한 세션에서 이미 Read한 파일은 다시 Read하지 않는다.
  → Step 5에서 읽은 파일은 Step 8 do_work에서 Edit 시 재Read 금지.
  → Edit 도구는 conversation에 Read 기록이 있으면 그대로 호출 가능하다.

- **Step 헤더 없이 진행하는 것은 금지**
  → 각 단계 시작 직전 `**Step N: {단계명}** ({설명})` 형식으로 main 대화에 출력한다.

- **Skill 도구로 워크플로우 명령을 실행하고 끝내는 것은 금지**
  → Skill 도구는 sub-context에서 실행되어 Step 헤더가 main 대화에 보이지 않는다.
  → 반드시 main 대화에서 직접 Bash/Edit/MCP 도구를 순서대로 호출해야 한다.

## 컨펌 게이트 (필수)

`/start_work` 흐름에서 다음 두 지점에 사용자 확인을 받는다:

1. **plan 승인 후 do_work 진입 전**: `AskUserQuestion`으로 "do_work 단계 진행할까요?" yes/no 확인
2. **do_work 완료 후 done_work 진입 전**: `AskUserQuestion`으로 "done_work 단계 진행할까요? (CHANGELOG + commit)" yes/no 확인

'no'면 그 단계 이후 진행하지 않고 사용자 추가 지시 대기.

## Step 헤더 표기 규칙

각 단계 직전에 반드시 출력. 형식: `**Step N: {단계명}** ({역할/설명})`

`/start_work` 표준 단계:
```
**Step 1: Plane 조회** (이슈 정보 확인)
**Step 2: 브랜치 생성** (feature/CUSTOM-{번호})
**Step 3: Plane 상태 변경** (In Progress)
**Step 4: 파일 탐색** (Glob/Grep)
**Step 5: 코드 분석** (Read 후 구조 분석)
**Step 6: 계획 작성** (plan 파일 저장)
**Step 7: 사용자 plan 승인** (ExitPlanMode)
**Step 8: 코드 수정** (do_work, Edit/Write)
**Step 9: CHANGELOG + 커밋** (done_work)
```

브랜치 네이밍 규칙: **반드시 `feature/CUSTOM-{번호}` 형식**. (`CUSTOM-{번호}` 단독 사용 금지)

티켓은 self-host Plane의 `planecustom` 프로젝트(prefix `CUSTOM`)에 있다.
`.mcp.json`의 Plane MCP는 SaaS(`my-saas-workspace`)를 가리키므로 이 프로젝트가 보이지 않는다.
**Step 1의 Plane 조회는 self-host REST API로 한다** — `http://192.0.2.10:8080/api/v1/workspaces/my-workspace/projects/<PROJECT_ID>/issues/`,
토큰은 `~/.config/plane-migrate/selfhost.env`의 `PLANE_SELFHOST_TOKEN`.

## 개발 워크플로우 커맨드 체계

```
/start_work {번호}    → 단일 명령으로 plan + do_work + done_work까지 끝까지 진행
                       (단계 사이 컨펌 게이트, sub-agent 호출 0회, 새 세션 발생 안 함)

/do_work             → 단독 폴백. 새 세션에서 plan만 가지고 구현만 할 때 사용.
/done_work           → 단독 폴백. 별도 세션에서 CHANGELOG + commit만 처리할 때 사용.
/publish_work        → 커밋 정리 + MR 준비
/release_changelog   → Unreleased → 버전 확정
```

**CHANGELOG 운영 원칙**: 개발 중에는 `Unreleased` 섹션에 누적, `/release_changelog`에서만 버전 확정.

## sub-agent 사용 시점 (예외)

워크플로우 명령 외에서 사용자가 명시적으로 요청하거나 명령을 호출할 때만:

| 커맨드/요청 | 에이전트 | 모델 |
|-------------|----------|------|
| `/code-reviewer` 또는 "리뷰해줘" | `code-reviewer` | haiku |
| `/debug` 또는 "디버그해줘" | `debug` | sonnet |
| `/commit_message_write` (단독) | `commit_writer` | sonnet |
| `/java-developer` | `java-developer` | sonnet |
| `/javascript-developer` | `javascript-developer` | sonnet |
| `/data-engineer` | `data-engineer` | haiku |
| `/devops` | `devops` | haiku |
| `/architect` | `architect` | opus |

`finder`, `analyst`, `planner`, `java-developer`, `javascript-developer`, `data-engineer`, `changelog_writer`, `commit_writer` 정의 파일은 **삭제하지 않고 보존**한다 — 사용자가 직접 Agent 호출하거나 향후 다른 용도로 쓸 수 있다. 단 워크플로우 명령에서는 호출하지 않는다.

## 자동 코드 리뷰 (기본값: ON)

코드 변경 작업이 완료될 때마다 **백그라운드 서브에이전트**(`code-reviewer`)를 자동으로 띄워 리뷰를 수행한다.

리뷰 항목:
1. 버그 가능성 및 엣지 케이스
2. 코드 품질 (예외처리 누락, 리소스 누수 등)
3. UX/동작 의도와의 일치 여부
4. 변경과 무관하지만 발견된 기존 버그

리뷰 완료 시 결과를 요약해서 사용자에게 보고하고, 수정이 필요한 항목이 있으면 고칠지 묻는다.

**자동 리뷰 끄기**: 사용자가 "리뷰 꺼", "no review", "/noreview" 라고 하면 해당 세션 동안 자동 리뷰를 건너뛴다.
**다시 켜기**: "리뷰 켜", "resume review", "/review" 라고 하면 다시 활성화한다.
