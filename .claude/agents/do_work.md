---
name: do_work
description: >
  단독 실행용 폴백. 일반 작업은 /start_work 단일 명령으로 do_work 단계까지 같이 처리하므로
  이 명령은 새 세션에서 plan만 따로 가지고 와서 구현해야 할 때만 사용한다.
  Use when the user explicitly invokes /do_work in a new session without /start_work.
model: sonnet
tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
  - Grep
---

# Do Work — 단독 폴백

> **권장 흐름**: `/start_work {번호}` 한 번으로 plan → do_work → done_work까지 같은 세션에서 처리한다.
> `/do_work`는 `/start_work`와 분리된 새 세션에서 plan을 가지고 구현만 하고 싶을 때 폴백으로 사용한다.

## 핵심 원칙 (절대 위반 금지)

- **sub-agent 호출 금지**: `java-developer`, `javascript-developer`, `data-engineer` 등 어떤 sub-agent도 Agent 도구로 호출하지 않는다. 이 에이전트(메인)가 직접 Edit한다.
- **재읽기 최소화**: 같은 세션에서 이미 Read한 파일은 다시 Read하지 않는다.
- **새 세션의 경우**: plan 파일과 수정 대상 파일을 메인이 1회씩만 Read 후 Edit.
- **Step 헤더 출력 필수**.

---

## 절차

### Step 1: 작업 범위 파악

```bash
# 대상 서브모듈 안에서
git branch --show-current
```

- 브랜치명에서 티켓 번호 추출 (`feature/PROJA-{번호}`).
- 같은 세션에서 `/start_work` 직후라면 plan 결과는 컨텍스트에 있음 → 별도 Read 불필요.
- 새 세션이면 가장 최근 plan 파일 (`~/.claude/plans/`)을 Read.
- 어느 서브모듈(`apps/backend/*` 또는 `apps/frontend/*`) 작업인지 확인.

### Step 2: 코드 수정 (메인이 직접 Edit)

plan에 명시된 파일들을 메인이 직접 수정:
- 같은 세션 + 이미 Read한 파일 → Edit 직접 호출 (재Read 금지)
- 새 세션 또는 미Read 파일 → Read 1회 → Edit

BE(Spring Boot) 수정 순서: Entity/DTO → Repository → Service → Controller → Flyway 마이그레이션 → MyBatis XML.
FE(React/TS): models → api(React Query) → store(Zustand) → component → page.

빌드 산출물(`build/`, `dist/`) 직접 편집 금지. 빌드는 사용자가 직접 실행.

### Step 3: 구현 결과 보고

```
구현 완료!

대상 서브모듈: apps/{...}
변경 파일:
- {경로} — {요약}

다음 단계:
- 커밋 + 체인지로그: /done_work
- 코드 리뷰 (선택): /code-reviewer
```

---

## 주의

- 자동 리뷰/디버그 실행하지 않음 — 사용자가 명시적으로 요청할 때만.
- 빌드는 사용자가 직접 실행 (`./gradlew build`, `npm run build`).
