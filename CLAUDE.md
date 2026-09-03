# scrum — Claude 프로젝트 지식베이스

이 파일은 Claude Code가 자동으로 읽는 프로젝트 컨텍스트입니다.
팀원 모두가 Claude Code로 이 레포를 열면 동일한 컨텍스트를 공유합니다.

---

## ⚠️ 세션 시작 즉시 적용되는 절대 규칙 (어떤 상황에서도 예외 없음)

### 🚨 규칙 0 — 워크플로우 명령에서 sub-agent 호출 금지 + 파일 중복 Read 금지

**`/start_work`, `/do_work`, `/done_work` 워크플로우 명령은 메인이 직접 모든 단계를 수행한다. sub-agent 호출 0회.**

- finder, analyst, planner, devops, architect, changelog_writer, commit_writer 등 어떤 sub-agent도 Agent 도구로 호출하지 않는다
- 메인이 직접 Glob/Grep/Read/Edit/Write/Bash로 처리한다
- 이유: sub-agent는 새 컨텍스트에서 시작 → 메인 대화 히스토리 접근 불가 → 같은 파일 반복 Read로 토큰 폭증
- 한 세션에서 같은 파일은 한 번만 Read한다

**`/start_work`는 단일 명령으로 plan → do_work → done_work까지 같은 세션에서 끝까지 진행한다.**

- plan 승인 후 do_work 진입 직전, do_work 완료 후 done_work 진입 직전 — 두 지점에 사용자 컨펌 게이트 (`AskUserQuestion`) 필수
- 'no'면 그 단계 이후 진행하지 않고 사용자 추가 지시 대기

**각 단계 직전 Step 헤더 출력 필수** — 형식: `**Step N: {단계명}** ({설명})`

자세한 규칙: `.claude/rules/agent-behavior.md`

---

## 프로젝트 개요

Plane(스크럼/프로젝트관리 도구) self-host 커뮤니티 에디션 설치·운영 레포.

**운영 스택은 `plane-selfhost/plane-src` 하나다.** 소스에서 직접 빌드한 이미지로 돌린다.

| | `plane-selfhost/plane-src` | `plane-selfhost/plane-app` |
|---|---|---|
| 상태 | **현재 운영 중** | **미사용** — `.157`에 `data`도 `.env`도 없다 |
| 이미지 | 자체 빌드 `myorg/plane-*:v1.4.2-custom.N` | 공식 pull `v1.4.2` |
| 포트 | **8080** | 8082 |
| `PULL_POLICY` | `never` | `if_not_present` |
| 데이터 | `plane-src/data/` (약 118MB) | 없음 |

> ⚠️ 서브모듈의 `README.md`에는 "실험용 스택, 포트 8081"로 적혀 있으나 **더 이상 사실이 아니다.**
> plane-src가 8080으로 승격되어 운영을 맡았고 plane-image는 비었다.
> 어느 쪽이 운영인지 헷갈리면 `docker ps`로 확인할 것 — 컨테이너 이름이 `plane-src-*`다.

- 서버는 `192.0.2.10`(`PLANE-HOST`)의 **WSL Ubuntu 안**에서 돈다. 이 레포는 그 안 `/home/plane`에 클론되어 있다.
- 데이터는 named volume이 아니라 **bind mount**(`plane-src/data/`)라 git 추적 안 함.
  컨테이너를 지우거나 이미지를 갈아끼워도, WSL이 통째로 죽었다 살아나도 데이터는 남는다.
  이관 절차는 아래 "다른 데탑으로 옮기기" 참고.

## Plane 소스 수정 워크플로우

**Plane 소스는 이 레포에 없다.** 별도 **private 레포**에 있고
`plane-selfhost/plane-src` 에 **git 서브모듈**로 붙는다.

```bash
git submodule update --init plane-selfhost/plane-src
```

이 레포는 public이라 서브모듈은 받아지지 않는다 — 접근 권한이 있어야 한다.
소스가 없어도 `.claude/`·스크립트·런북은 그대로 쓸 수 있다.

1. **수정** — 서브모듈 안 `src/` 를 직접 편집
2. **커밋 & push** — 서브모듈 레포에 먼저, 그다음 이 레포에서 포인터 커밋
3. **빌드** — `cd plane-selfhost/plane-src && docker compose -f build.yml build api web`
4. **기동** — `docker compose up -d`

- 이미지 6개 중 `plane-backend` 하나를 api·worker·beat-worker·migrator가 공유한다. API를 고치면 그 넷이 함께 바뀐다.
- 수정할 때마다 태그를 `-custom.2`, `-custom.3`으로 올리고 `.env`의 `APP_RELEASE`를 맞춘다.

### 우리 수정 목록은 커밋 로그가 곧 답이다

소스가 git으로 관리되므로 **서브모듈의 `src/`에 대한 커밋 로그가 곧 수정 목록**이다.

```bash
cd plane-selfhost/plane-src && git log --oneline -- src/
```

같은 내용이 `patches/` 에 patch 파일로도 들어 있다. 소스 없이 수정 내역만
보거나, 새 upstream에 다시 적용할 때 쓴다.

upstream과 공통 히스토리가 없어 **`git merge`로 업그레이드할 수는 없다.**
새 릴리즈를 받아 `src/`를 교체한 뒤 위 커밋 로그(또는 `patches/`)를 보며
수정을 재적용하는 수동 절차다. 자세한 건 서브모듈의 `README.md` 참고.

## 다른 데탑으로 옮기기

데이터가 bind mount라 **폴더가 곧 데이터다.** 다만 `.env`의 IP만 바꾸면 되는 게 아니고
함정이 둘 있다.

### 1. 반드시 정지하고 복사한다

Postgres가 돌고 있는 상태로 `data/pgdata`를 복사하면 **DB가 깨질 수 있다.**
쓰기 도중의 파일을 복사하게 되기 때문이다.

```bash
cd plane-selfhost/plane-src && docker compose down   # 먼저 정지
tar czf plane-backup.tar.gz /home/plane                 # 그다음 복사
```

무중단으로 하려면 `pg_dump` 논리 백업을 떠야 하는데, 그러면 MinIO 업로드 파일을
따로 챙겨야 한다. 정지하고 폴더째 옮기는 쪽이 간단하다.

### 2. 이미지는 따라오지 않는다

`PULL_POLICY=never` 인데다 이미지가 자체 빌드(`myorg/plane-*`)라 **Docker Hub에서 받을 수 없다.**
둘 중 하나를 해야 한다.

```bash
# A. 새 데탑에서 빌드 — 서브모듈에 소스가 있으므로 가능하다 (첫 빌드 10~30분)
cd plane-selfhost/plane-src && docker compose -f build.yml build

# B. 이미지를 통째로 옮기기
docker save myorg/plane-backend:$TAG myorg/plane-frontend:$TAG myorg/plane-proxy:$TAG \
            myorg/plane-space:$TAG myorg/plane-admin:$TAG myorg/plane-live:$TAG | gzip > images.tar.gz
docker load < images.tar.gz
```

### 3. `.env` 의 IP를 바꾼다

`APP_DOMAIN` / `WEB_URL` / `CORS_ALLOWED_ORIGINS` 를 새 데탑 IP로.

### 4. WSL 세팅은 안 따라온다

keepalive와 portproxy는 데이터가 아니라 **Windows 쪽 설정**이라 새로 해야 한다.
빠뜨리면 VSCode를 닫는 순간 WSL이 내려가 Plane이 통째로 죽는다.

```powershell
setup_wsl_keepalive.ps1 -Password '<계정 비번>'   # WSL 상시 기동
setup_plane_lan_access.ps1 -RegisterTask          # 8080 LAN 노출 + 부팅 시 WSL IP 갱신
```

자세한 건 `shell-scripts/README-wsl-keepalive.md`.

## ⚠️ setup.sh 옵션 1(Install) / 5(Upgrade) 실행 금지

이 두 옵션은 Plane 공식 릴리즈에서 `docker-compose.yaml`을 새로 받아 덮어쓴다.
그러면 이 레포의 bind mount 설정(`./data/pgdata`, `./data/redis`, `./data/rabbitmq`, `./data/uploads`)이
named volume 버전으로 되돌아가고 기존 데이터가 컨테이너에서 사라진 것처럼 보인다.

- 기동/정지는 **`plane-selfhost/plane-src`** 에서 `docker compose up -d` / `docker compose down` 직접 실행
- `setup.sh`는 2(Start) / 3(Stop) / 4(Restart) / 6(Logs) / 7(Backup) 만 사용
- Plane 업그레이드는 위 "Plane 소스 수정 워크플로우 → upstream 업그레이드" 절차를 따를 것 (자체 빌드라 태그만 올려서는 안 된다)

## 브랜치 네이밍 규칙

이 레포의 작업 티켓은 self-host Plane의 **`planecustom` 프로젝트(prefix `CUSTOM`)** 로 관리한다.
브랜치는 `feature/CUSTOM-{번호}` 형식을 쓴다.

- 워크스페이스: `my-workspace` (self-host, `http://192.0.2.10:8080`)
- 프로젝트 id: `<PROJECT_ID>`

> `.mcp.json`의 Plane MCP는 **SaaS(`my-saas-workspace`)** 를 가리키고 있어 `CUSTOM` 프로젝트가 보이지 않는다.
> **self-host에는 MCP 서버가 없다**(SaaS 전용 기능). self-host 티켓은 REST API로 다룰 것.

### Plane 접속 — Claude 전용 봇 계정

Claude가 self-host Plane을 다룰 때는 **`migrate-bot` 계정**을 쓴다. 사람 계정을 쓰지 않는다.

| | |
|---|---|
| 이메일 | `bot@example.com` |
| 비밀번호 | `<본인_비밀번호>` |
| API 토큰 | `plane_api_<본인_토큰>` |

> 사내망 전용 봇 계정이라 이 정보는 레포에 남겨도 되는 것으로 합의됐다.
> **다른 민감 정보(사람 계정 비밀번호, 외부 서비스 키)는 여전히 이 파일에 쓰지 말 것.**

같은 값이 `~/.config/plane-migrate/selfhost.env` (권한 600) 에도 있다. 이쪽을 우선 사용한다.

```bash
set -a; source ~/.config/plane-migrate/selfhost.env; set +a
curl -s -H "X-API-Key: $PLANE_SELFHOST_TOKEN" \
  "http://192.0.2.10:8080/api/v1/workspaces/my-workspace/projects/<PROJECT_ID>/issues/"
```

REST(`/api/v1/...`)는 `X-API-Key` 헤더로 인증한다.
내부 API(`/api/...`, estimate·page 등 공개 API에 없는 것)는 세션 로그인이 필요하며
`scripts/plane_session.py` 가 이메일·비밀번호로 처리한다.

**이 계정은 세 프로젝트 모두 접근 가능하다** (실측: PROJA 186 / PROJB 369 / CUSTOM 3건).

### ⚠️ 개발자는 봇 토큰을 자기 것으로 바꿔 쓴다

레포에 적힌 봇 계정은 **기본값**이다. 그대로 두면 만드는 티켓이 전부
`migrate-bot` 생성으로 남는다 — **`created_by` 는 API 토큰 주인으로 자동 기록되며
API로 바꿀 수 없다** (실측 확인). 그래서 **각자 자기 토큰으로 교체**해야 한다.

`~/.config/plane-migrate/selfhost.env`:

| 키 | 레포 기본값 | 개발자가 할 일 |
|----|-------------|----------------|
| `PLANE_SELFHOST_TOKEN` | 봇 API 토큰 | **자기 API 토큰으로 교체** |
| `PLANE_DEV_USER_ID` | — | **자기 멤버 UUID로 교체** (담당자 지정용) |
| `PLANE_SELFHOST_EMAIL` / `PASSWORD` | 봇 계정 | 그대로 둔다 (세션 인증·마이그레이션 전용) |

#### 개발자 최초 1회 세팅 — `/plane_user_setup`

```
/plane_user_setup
```

이 스킬이 현재 계정을 확인하고, 본인 토큰을 받아 env를 고치고, 프로젝트 접근까지
검증한 뒤 **Plane 사용 가이드**(프로젝트↔레포 매핑, 작업 흐름, API 함정)를 알려준다.
env 파일은 백업을 남기고 고치며, 레포 파일은 건드리지 않는다.

손으로 하려면:

1. Plane 웹 → 우측 상단 프로필 → **Settings → API Tokens** → 새 토큰 발급
2. env의 `PLANE_SELFHOST_TOKEN` 을 그 값으로 교체
3. env의 `PLANE_DEV_USER_ID` 를 자기 UUID(아래 표)로 교체

이 파일은 각자 로컬 홈에 있으므로 **한 번만 바꾸면 그 PC의 Claude는 계속 그 사람으로 동작한다.**
`/start_work` 가 매번 담당자를 묻지 않는 이유다.

| 멤버 | 이메일 | UUID |
|------|--------|------|
| dev1 | `dev1@example.com` | `<MEMBER_UUID_1>` |
| dev2 | `dev2@example.com` | `<MEMBER_UUID_2>` |
| dev3 | `dev3@example.com` | `<MEMBER_UUID_3>` |
| migrate-bot | `bot@example.com` | `<BOT_UUID>` — 봇. 담당자로 쓰지 말 것 |

#### 담당자는 로컬에 한 번만 세팅한다

담당자는 env의 `PLANE_DEV_USER_ID` 를 그대로 쓴다. **매번 지정하지 않는다.**
이 파일은 각자 로컬 홈(`~/.config/plane-migrate/selfhost.env`)에 있으므로,
**팀원마다 자기 UUID를 한 번만 넣어두면 그 PC의 Claude는 항상 그 사람을 담당자로 찍는다.**

```bash
# 최초 1회 — 자기 UUID 확인
set -a; source ~/.config/plane-migrate/selfhost.env; set +a
curl -s -H "X-API-Key: $PLANE_SELFHOST_TOKEN" \
  "http://192.0.2.10:8080/api/v1/workspaces/my-workspace/members/" \
  | python3 -c "
import sys, json
rows = json.load(sys.stdin)
if isinstance(rows, dict): rows = rows.get('results', [])
for m in rows:
    u = m.get('member') if isinstance(m.get('member'), dict) else m
    print(f\"{str(u.get('display_name')):12} {str(u.get('email')):26} {u.get('id')}\")
"

# env에 기록 (이미 있으면 값만 교체)
# PLANE_DEV_USER_ID=<자기 UUID>
```

위 멤버 표의 UUID는 **다른 사람에게 맡길 때만** 참고한다.

## 라이선스 (AGPL-3.0)

Plane Community Edition은 **AGPL-3.0**이다. 라이선스 키가 필요 없고 무료이며,
버전 업그레이드만으로 유료 전환되지 않는다.

**코드 수정은 허용된다.** AGPL이 명시적으로 보장하는 자유다.
문제가 되는 건 수정 자체가 아니라 **"수정본을 외부에 제공하는 것"** 이다.

핵심 조항은 §13(Remote Network Interaction):

> 프로그램을 수정했다면, 네트워크로 그것과 상호작용하는 **모든 사용자에게**
> 수정본의 소스를 받을 기회를 제공해야 한다.

의무 범위는 "전 세계 공개"가 아니라 **"그걸 쓰는 그 사용자들에게 제공"** 이다.

| 상황 | 판단 |
|------|------|
| 사내 팀원만 사용 | ✅ 사내 GitLab에 소스가 있으면 충족 — **fork를 사내에 두면 자동 준수** |
| 외부 협력사에 계정 발급 | ⚠️ 그들에게도 소스 제공 의무 발생 |
| 다른 회사에 서비스처럼 제공 | ⛔ 소스 제공 의무 + 상표 문제 |
| 수정본을 바이너리로 배포 | ⛔ 소스 동봉 의무 |

**따라서 이 레포의 실질 규칙은 "코드 수정 금지"가 아니라 다음 두 가지다:**

1. 코드를 수정하면 **fork를 반드시 사내 GitLab에 두고 팀원이 접근 가능하게 유지**한다
2. **외부(협력사·타사·고객)에 계정을 주거나 서비스처럼 제공하지 않는다**

외부 제공이 논의되는 시점에는 법무 확인을 거칠 것.
자세한 내용은 `README.md`의 라이선스 섹션과 `docs/plane-runbook.html` 참고.

### 코드 수정 시 실무 비용 (라이선스보다 이쪽이 크다)

**이미 소스 빌드로 운영 중이다**(`plane-src`, `PULL_POLICY=never`). 따라서 "코드를 고치려면
소스 빌드로 전환해야 한다"는 건 옛말이고, 수정 자체의 진입 장벽은 없다.

남은 비용은 **업그레이드**다. upstream과 공통 히스토리가 없어 `git merge`가 안 되므로,
새 릴리즈마다 `src/`를 교체하고 우리 수정을 손으로 재적용해야 한다.
**고친 파일이 늘어날수록 이 작업이 무거워지고, 보안 패치 추적이 늦어지는 것이 실질 위험이다**
(v1.4.0이 대규모 보안 배치였다).

**코드를 고치기 전에 설정·환경변수·웹훅·REST API로 되는지 먼저 확인할 것.**

## 저장 규칙

- 사용자가 "저장해", "기억해", "업데이트해" 라고 하면 내용에 맞는 파일을 업데이트할 것 (배포/패턴/지식은 별도 메모 파일, 규칙/지침은 이 파일)
- **절대로 auto-memory(`~/.claude/projects/.../memory/MEMORY.md`)에 저장하지 말 것** → 이 레포는 git으로 팀 공유가 목적
- 민감 정보(실제 비밀번호, 키)는 이 파일에 쓰지 말 것
  — **예외**: Claude 전용 봇 계정(`migrate-bot`)은 위 "Plane 접속" 섹션에 기록한다 (사내망 전용)
