대상 서브모듈의 변경사항을 분석하여 그 서브모듈의 `CHANGELOG.md`(또는 `changelog/CHANGELOG.md`)의 `## Unreleased` 섹션에 누적한다.

## 원칙

- 이 커맨드는 **세멘틱 버전을 결정하지 않는다**. 버전 확정은 `/release_changelog`에서만 수행.
- 개발 중에는 변경사항을 `Unreleased`에 누적만 한다.
- **커밋된 변경사항만** 대상. 일반적으로 `/commit_message_write` 이후 실행.
- **커밋은 코드가 있는 서브모듈 안에서** 이루어지므로 changelog도 그 서브모듈 안에서 관리한다.

## 절차

### 1단계: 현재 상태 확인 (대상 서브모듈 안에서)

```bash
git branch --show-current
# 기본 브랜치와의 차이 (서브모듈에 따라 develop 또는 main)
git log develop..HEAD --oneline --no-merges 2>/dev/null || git log main..HEAD --oneline --no-merges
git diff develop..HEAD --stat 2>/dev/null || git diff main..HEAD --stat
```

- 비교 결과가 비어 있으면 사용자에게 base를 확인.
- 변경사항이 없으면 빈 `Unreleased`를 만들지 말고 "반영할 변경사항이 없습니다" 보고 후 종료.
- 제외 대상: changelog만 수정한 커밋, `docs: update unreleased changelog` / `docs: release changelog` 커밋, stash에만 있는 변경.
- 각 커밋 메시지에서 `PROJA-숫자` 패턴 추출.

### 2단계: Plane MCP에서 티켓 정보 조회

```
retrieve_work_item_by_identifier(work_item_identifier: "PROJA-{번호}")
```

티켓 번호가 커밋에 없으면 `search_work_items`로 키워드 검색.

### 3단계: `Unreleased` 섹션 준비

- 서브모듈에 changelog 파일이 없으면 `# Changelog\n\n## Unreleased\n` 로 새로 만든다.
- `# Changelog` 바로 아래 `## Unreleased`가 있으면 병합, 없으면 새로 만든다.
- 기존 릴리스 섹션은 수정하지 않는다.

### 4단계: 작성

```markdown
## Unreleased

### Features
- **[PROJA-XXX] 티켓 제목** (`커밋해시`)
  - 변경 상세

### Bug Fixes
- **[PROJA-YYY] 티켓 제목** (`커밋해시`)
  - 변경 상세
```

- 분류: `feat`→Features, `fix`→Bug Fixes, `refactor`→Changed, `chore`→Changed/Removed, `docs`→Documentation, 동작 깨짐→Breaking Changes
- 같은 티켓은 섹션별로 묶고 서브 불릿 누적, 커밋 해시 7자리, 한국어.
- `Unreleased` 제목에 날짜/버전 붙이지 않음.

### 5단계: 결과 보고

```
CHANGELOG 업데이트 완료! (서브모듈: apps/{...})
- 반영 티켓: PROJA-XXX
- 카테고리: Features, Bug Fixes
- 버전 확정: 아직 (`/release_changelog`에서 처리)
```
