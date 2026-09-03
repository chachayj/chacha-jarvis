대상 서브모듈의 작업을 마무리한다.
커밋되지 않은 변경사항이 있으면 `/commit_message_write` → `/changelog_write` 순서로 실행한다.
changelog는 릴리스 버전이 아니라 `## Unreleased` 섹션에 누적한다.

## 현재 구현 범위

- 실제 구현 범위는 **커밋 + `Unreleased` 반영 + root 서브모듈 포인터 갱신 안내**까지다.
- push, MR 생성, Plane 상태 변경은 아래 초안으로 남기되 기본 절차에는 포함하지 않는다.

## 사용법

```
/publish_work
```

## 절차

### 1단계: 현재 상태 확인 (대상 서브모듈 안에서)

```bash
git branch --show-current
git status -s
git log develop..HEAD --oneline --no-merges 2>/dev/null || git log main..HEAD --oneline --no-merges
```

- 현재 브랜치가 `develop`/`main`이면 중단: "기본 브랜치에서는 실행할 수 없습니다. feature 브랜치에서 실행해주세요."

### 2단계: 커밋 (`/commit_message_write` 실행)

커밋되지 않은 변경(staged + unstaged + untracked)이 있으면 `/commit_message_write` 전체 절차 실행. 없으면 건너뜀.

### 3단계: Changelog 작성 (`/changelog_write` 실행)

`/changelog_write` 전체 절차 실행. changelog가 수정됐으면 별도 커밋:

```bash
git add {changelog 경로}
git commit -m "[PROJA-{번호}] docs: update unreleased changelog"
```

### 4단계: root 서브모듈 포인터 갱신 안내

서브모듈 커밋이 생겼으면 root 레포에도 포인터를 갱신해야 반영된다:

```bash
cd {root: ~/work/example-monorepo}
git add apps/{backend|frontend}/{서브모듈}
git commit -m "[PROJA-{번호}] chore: {서브모듈} 포인터 갱신"
```

이 root 커밋은 사용자 확인 후 진행.

### 5단계: 결과 보고

```
publish 완료!
- 티켓: PROJA-{번호} — {제목}
- 대상 서브모듈: apps/{...}
- 브랜치: {브랜치명}
- 커밋: {커밋 수}개
- Changelog: Unreleased 업데이트
- root 포인터 갱신: {완료/대기}
- Release: 아직 버전 미확정 (`/release_changelog`에서 처리)
```

<!-- ### (미구현) Push & MR — GITLAB_TOKEN 설정 후 활성화
git push origin {브랜치명}
# GitLab MR API: http://192.0.2.20:7000/api/v4/projects/{server_dev%2F서브모듈}/merge_requests
# Plane 상태 → Done: update_work_item(project_id: "<PROJA_ID_SRC>",
#   work_item_id: {UUID}, state: "<PROJD_ID_DST>")
-->
