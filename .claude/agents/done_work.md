---
name: done_work
description: >
  단독 실행용 폴백. 일반 작업은 /start_work 단일 명령으로 done_work 단계까지 같이 처리하므로
  이 명령은 별도 세션에서 CHANGELOG + commit만 따로 처리해야 할 때만 사용한다.
  Use when the user explicitly invokes /done_work in a separate session.
model: sonnet
tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
  - Grep
---

# Done Work — 단독 폴백

> **권장 흐름**: `/start_work {번호}` 한 번으로 plan → do_work → done_work까지 같은 세션에서 처리한다.
> `/done_work`는 별도 세션에서 CHANGELOG + commit만 따로 처리하고 싶을 때 폴백으로 사용한다.

## 핵심 원칙 (절대 위반 금지)

- **sub-agent 호출 금지**: `changelog_writer`, `commit_writer` 어떤 에이전트도 Agent 도구로 호출하지 않는다. 메인이 직접 처리.
- **재읽기 최소화**: 같은 세션에서 이미 Read한 파일은 다시 Read하지 않는다.
- **Step 헤더 출력 필수**.
- **이 레포는 단일 레포다.** 코드가 전부 이 레포 안에 있으므로 커밋도 여기서 한다. 서브모듈은 없다.

---

## 절차

### Step 1: 변경 사항 확인

```bash
git status
git diff
git diff --stat
git log -5 --oneline   # 커밋 메시지 컨벤션 참고
```

### Step 2: CHANGELOG 업데이트 (메인이 직접 Edit)

- `CHANGELOG.md` 의 `## Unreleased` 섹션에 항목 추가.
  - Added / Changed / Fixed / Removed 분류.
  - 형식은 기존 항목 따라가기. 한국어. 티켓 번호 앞에 표기.
- **이 레포에는 아직 `CHANGELOG.md` 가 없다** → 없으면 새로 만든다:

```markdown
# Changelog

이 프로젝트의 주요 변경사항을 기록한다.
형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/) 를 따른다.

## Unreleased

### Added
- [{PREFIX}-{번호}] {내용}
```

- 같은 세션에서 이미 Read한 CHANGELOG 파일은 재Read 금지.

### Step 3: 커밋 작성

커밋 메시지 컨벤션 — 이 레포의 히스토리 형식을 따른다:

- `[{PREFIX}-{번호}] {type} : {요약}` (`type` 과 `:` 사이에 공백이 있다)
- 히스토리 예: `[CHACH-25] feat : 스프링 부트, 그레들 초기 셋업`
- type 예: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`
- 한국어 요약
- 본문: 변경 동기 / 영향 범위
- 푸터: `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`

```bash
git add {파일 목록 명시}
git commit -m "$(cat <<'EOF'
[{PREFIX}-{번호}] {type} : {요약}

{본문}

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

`-A` / `.` 사용 금지 (민감 파일 우발적 포함 방지).

### Step 4: 검증

```bash
git status
git log -3 --oneline
```

### Step 5: 결과 보고

```
완료!

- 대상 영역: {backend/spring_server 등}
- 커밋: {해시} — {메시지}
- CHANGELOG: Unreleased 섹션 업데이트 ✓
```

---

## 주의

- 사용자가 푸시(`git push`) 명시 요청 없으면 푸시하지 않는다.
- 훅 (`--no-verify`) 우회 금지.
- 비밀 커밋 금지. 특히 다음은 절대 커밋하지 않는다:
  - `plane-selfhost/plane-app/plane.env` — Plane 시크릿 (`.gitignore` 로 추적 제외됨)
  - `emqx/certs/`, `nginx/selfsigned.key` — 인증서·키
  - `~/.config/plane-chacha/selfhost.env` — 레포 밖이지만 값을 레포로 옮기지 않는다
- **이 레포는 public 이다.** 커밋 전 `git diff --cached` 로 자격 증명이 섞이지 않았는지 확인한다.
