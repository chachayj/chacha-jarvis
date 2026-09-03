# WSL Runner & Plane 자동화 세팅 가이드

데스크탑(`192.0.2.10`, user: `work`)에 WSL 자동 시작과 Plane 사이클 감지 자동화를 세팅하는 방법입니다.

---

## 시나리오별 실행 방법

### A. 처음부터 전체 세팅 (WSL + Docker + GitLab Runner + 자동 시작)

```bash
bash shell-scripts/setup_windows_gitlab_runner.sh \
  --remote-host 192.0.2.10 \
  --remote-user work \
  --ask-ssh-password \
  --gitlab-url http://192.0.2.20:7000 \
  --registration-token "GLR-xxxxx" \
  --runner-name "win-wsl-runner" \
  --runner-tags "windows,wsl,docker" \
  --auto-login-password "1234"
```

### B. WSL + Docker + Runner는 이미 설치됨 → 자동 시작만 세팅 (지금 상황)

**Step 1: WSL 자동 시작 + Windows 자동 로그인**

```bash
bash shell-scripts/setup_windows_wsl_autostart.sh \
  --remote-host 192.0.2.10 \
  --remote-user work \
  --ask-ssh-password \
  --auto-login-password "1234"
```

**Step 2: WSL에 레포 수동 클론** (최초 1회)

```bash
# 데스크탑 SSH → WSL 진입
ssh work@192.0.2.10
wsl

# 레포 클론
git clone http://192.0.2.20:7000/example/example-monorepo.git /home/example-monorepo
exit  # WSL 나오기
exit  # SSH 나오기
```

**Step 3: env 파일 + crontab 등록**

아래 값들을 실제 값으로 교체 후 실행:

```bash
bash shell-scripts/setup_poll_plane_cron.sh \
  --remote-host 192.0.2.10 \
  --remote-user work \
  --ask-ssh-password \
  --wsl-user root \
  --repo-path /home/example-monorepo \
  --plane-api-key "여기에_Plane_API_Key" \
  --gitlab-token "여기에_GitLab_Personal_Access_Token" \
  --gitlab-project-id 279 \
  --git-user-email "ci@example.com" \
  --git-user-name "CI Bot"
```

> **`--wsl-user root`**: WSL 내부 기본 사용자가 `root`이므로 필수. Windows 계정(`work`)과 다름
>
> **Plane API Key 발급**: Plane → 오른쪽 상단 프로필 → Settings > API Tokens → 새 토큰 생성
>
> **GitLab Token 발급**: GitLab → Settings > Access Tokens → `api` scope 토큰 생성
>
> **GitLab Project ID 확인**: GitLab → `example/example-monorepo` → Settings > General → 상단 `Project ID` 숫자 (현재: `279`)

---

## 세팅 후 동작 확인

### dry-run으로 전체 흐름 테스트 (실제 git push/MR 없음)

```bash
# 데스크탑에 SSH 접속
ssh work@192.0.2.10

# WSL 진입
wsl

# dry-run 실행
source ~/poll-plane-cycle.env
cd $REPO_PATH
python3 scripts/poll_plane_cycle.py --dry-run
```

정상 출력 예시:
```
[dry-run 모드] 실제 git/GitLab 변경은 수행하지 않습니다.

이미 처리된 사이클: 0개
Plane API에서 archived 사이클 조회 중...
새 archived 사이클 1개 발견: ['사이클 4']

==================================================
처리 중: '사이클 4'
  bump type: minor
  버전: v1.2.0 | 브랜치: chore/release-v1.2.0
  [dry-run] CHANGELOG 예정: ## Unreleased → ## v1.2.0 (2026-03-23) - 사이클 4
  [dry-run] GitLab MR 예정: 'release: v1.2.0 - 사이클 4' (chore/release-v1.2.0 → dev)

완료.
```

### crontab 등록 확인

```bash
# WSL 내부에서
crontab -l
```

### 실시간 로그 확인

```bash
# WSL 내부에서
tail -f /tmp/cycle_poll.log
```

---

## 전체 자동화 흐름

```
전원 ON
  → Windows 자동 로그인 (work / 1234)
  → Task Scheduler AtLogOn 트리거
  → WSL(Ubuntu) 자동 시작
  → crontab 10분마다 실행
  → Plane API polling
  → archived 사이클 감지 시:
      CHANGELOG Unreleased → vX.Y.Z 버전 승격
      GitLab MR 생성 (chore/release-vX.Y.Z → dev)
      CI 파이프라인 통과 후 자동 머지
```

---

## 스크립트 역할 요약

| 스크립트 | 역할 |
|----------|------|
| `setup_windows_gitlab_runner.sh` | WSL + Docker + GitLab Runner 전체 설치/등록 |
| `setup_windows_wsl_autostart.sh` | WSL 자동 시작 Task Scheduler + Windows 자동 로그인만 세팅 |
| `setup_poll_plane_cron.sh` | 레포 클론 + env 파일 생성 + crontab 등록 |
