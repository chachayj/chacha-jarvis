현재 브랜치의 변경사항을 분석하여 레포 루트 `CHANGELOG.md` 의 `## Unreleased` 섹션에 누적한다.

## 원칙

- 이 커맨드는 **세멘틱 버전을 결정하지 않는다**. 버전 확정은 `/release_changelog`에서만 수행.
- 개발 중에는 변경사항을 `Unreleased`에 누적만 한다.
- **커밋된 변경사항만** 대상. 일반적으로 `/commit_message_write` 이후 실행.
- 이 레포는 단일 레포다 — changelog 도 루트에서 하나로 관리한다.

## 절차

### 1단계: 현재 상태 확인

이 레포의 기본 브랜치는 **`dev`** 다 (`origin/HEAD -> origin/dev`).

```bash
git branch --show-current
git log dev..HEAD --oneline --no-merges
git diff dev..HEAD --stat
```

- 비교 결과가 비어 있으면 사용자에게 base를 확인.
- 변경사항이 없으면 빈 `Unreleased`를 만들지 말고 "반영할 변경사항이 없습니다" 보고 후 종료.
- 제외 대상: changelog만 수정한 커밋, `docs : update unreleased changelog` /
  `docs : release changelog` 커밋, stash에만 있는 변경.
- 각 커밋 메시지에서 `[영문대문자-숫자]` 패턴(예: `CHACH-25`) 추출.

### 2단계: 티켓 정보 조회 (REST API)

**self-host 에는 Plane MCP 가 없다.** `mcp__plane__*` 를 쓰지 않는다.

```bash
set -a; source ~/.config/plane-chacha/selfhost.env; set +a
curl -s -H "X-API-Key: $PLANE_SELFHOST_TOKEN" \
  "$PLANE_SELFHOST_URL/api/v1/workspaces/$PLANE_SELFHOST_WORKSPACE/projects/$PLANE_SELFHOST_PROJECT_ID/issues/"
```

> ⚠️ 공개 API 는 모르는 쿼리 파라미터를 조용히 무시한다. `?sequence_id=25` 로 필터링되지 않는다.
> 목록을 받아 `sequence_id` 로 코드에서 매칭한다.

env 가 없거나 Plane 이 응답하지 않으면 **커밋 메시지만으로 작성**한다 (건너뛰고 계속 진행).

### 3단계: `Unreleased` 섹션 준비

- `CHANGELOG.md` 가 없으면 새로 만든다 (이 레포에는 아직 없다):

```markdown
# Changelog

이 프로젝트의 주요 변경사항을 기록한다.
형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/) 를 따른다.

## Unreleased
```

- `# Changelog` 바로 아래 `## Unreleased`가 있으면 병합, 없으면 새로 만든다.
- 기존 릴리스 섹션은 수정하지 않는다.

### 4단계: 작성

```markdown
## Unreleased

### Features
- **[CHACH-XXX] 티켓 제목** (`커밋해시`)
  - 변경 상세

### Bug Fixes
- **[CHACH-YYY] 티켓 제목** (`커밋해시`)
  - 변경 상세
```

- 분류: `feat`→Features, `fix`→Bug Fixes, `refactor`→Changed, `chore`→Changed/Removed,
  `docs`→Documentation, 동작 깨짐→Breaking Changes
- 같은 티켓은 섹션별로 묶고 서브 불릿 누적, 커밋 해시 7자리, 한국어.
- `Unreleased` 제목에 날짜/버전 붙이지 않음.

### 5단계: 결과 보고

```
CHANGELOG 업데이트 완료!
- 반영 티켓: CHACH-XXX
- 카테고리: Features, Bug Fixes
- 버전 확정: 아직 (`/release_changelog`에서 처리)
```
