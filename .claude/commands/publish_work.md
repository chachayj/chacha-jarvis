현재 브랜치의 작업을 마무리한다.
커밋되지 않은 변경사항이 있으면 `/commit_message_write` → `/changelog_write` 순서로 실행한다.
changelog는 릴리스 버전이 아니라 `## Unreleased` 섹션에 누적한다.

## 현재 구현 범위

- 실제 구현 범위는 **커밋 + `Unreleased` 반영**까지다.
- push, PR 생성, Plane 상태 변경은 아래 초안으로 남기되 기본 절차에는 포함하지 않는다.

## 사용법

```
/publish_work
```

## 절차

### 1단계: 현재 상태 확인

이 레포의 기본 브랜치는 **`dev`** 다.

```bash
git branch --show-current
git status -s
git log dev..HEAD --oneline --no-merges
```

- 현재 브랜치가 `dev`이면 중단: "기본 브랜치에서는 실행할 수 없습니다. feature 브랜치에서 실행해주세요."

### 2단계: 커밋 (`/commit_message_write` 실행)

커밋되지 않은 변경(staged + unstaged + untracked)이 있으면 `/commit_message_write` 전체 절차 실행. 없으면 건너뜀.

> **이 레포는 public 이다.** 스테이징 전 다음이 섞이지 않았는지 확인한다 —
> `plane-selfhost/plane-app/plane.env`, `emqx/certs/`, `nginx/selfsigned.key`, `.pem` 키.

### 3단계: Changelog 작성 (`/changelog_write` 실행)

`/changelog_write` 전체 절차 실행. changelog가 수정됐으면 별도 커밋:

```bash
git add CHANGELOG.md
git commit -m "[{PREFIX}-{번호}] docs : update unreleased changelog"
```

### 4단계: 결과 보고

```
publish 완료!
- 티켓: {PREFIX}-{번호} — {제목}
- 브랜치: {브랜치명}
- 커밋: {커밋 수}개
- Changelog: Unreleased 업데이트
- Release: 아직 버전 미확정 (`/release_changelog`에서 처리)
```

<!-- ### (미구현) Push & PR
git push -u origin {브랜치명}
gh pr create --base dev --title "[{PREFIX}-{번호}] {제목}" --body "..."

# Plane 상태 → Done (REST API)
# set -a; source ~/.config/plane-chacha/selfhost.env; set +a
# BASE="$PLANE_SELFHOST_URL/api/v1/workspaces/$PLANE_SELFHOST_WORKSPACE/projects/$PLANE_SELFHOST_PROJECT_ID"
# STATE=$(curl -s -H "X-API-Key: $PLANE_SELFHOST_TOKEN" "$BASE/states/" | ... 'Done' 의 id 추출)
# curl -s -X PATCH -H "X-API-Key: $PLANE_SELFHOST_TOKEN" -H "Content-Type: application/json" \
#   -d "{\"state\":\"$STATE\"}" "$BASE/issues/{이슈 UUID}/"
-->
