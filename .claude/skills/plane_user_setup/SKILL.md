---
name: plane_user_setup
description: self-host Plane 접속 계정을 세팅한다. 봇 계정(migrate-bot)을 그대로 쓸지 본인 API 토큰을 등록할지 선택창으로 물은 뒤 env에 기록하고 검증한다. 개발자가 레포를 받아 최초 1회 실행하거나 계정을 바꿀 때 쓴다. "plane 계정 세팅", "내 계정으로 바꿔줘", "plane 토큰 등록", "/plane_user_setup" 등에 반응한다.
---

# Plane 사용자 계정 세팅

`~/.config/plane-migrate/selfhost.env` 의 Plane 접속 계정을 정한다.

## 왜 선택해야 하나

`created_by` 는 **API 토큰 주인으로 자동 기록되며 API로 바꿀 수 없다.**

| 쓰는 계정 | 티켓 생성자에 남는 이름 | 언제 |
|-----------|------------------------|------|
| **본인 API 토큰** | 본인 | 실제로 작업할 때 (권장) |
| 봇(`migrate-bot`) | `migrate-bot` | 자동화·스크립트, 또는 개인 토큰을 아직 못 만들었을 때 |

담당자(`assignees`)는 `PLANE_DEV_USER_ID` 로 지정하며, 이 스킬이 함께 맞춰준다.

---

## 절차

### Step 1: 현재 상태 확인

**여기서 끝내지 않는다.** 상태만 파악하고 반드시 Step 2 의 선택창으로 넘어간다.

```bash
ENV=~/.config/plane-migrate/selfhost.env
if [ -f "$ENV" ]; then
  set -a; source "$ENV" 2>/dev/null; set +a
  curl -s --max-time 15 -H "X-API-Key: $PLANE_SELFHOST_TOKEN" \
    http://192.0.2.10:8080/api/v1/users/me/ \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print('현재 토큰 소유자:', d.get('email','(확인 실패)'))"
  echo "현재 담당자 UUID: ${PLANE_DEV_USER_ID:-(없음)}"
else
  echo "env 파일 없음 — 새로 만든다"
fi
```

### Step 2: 선택창 제공 (필수)

**`AskUserQuestion` 으로 반드시 물어본다.** 현재 상태가 어떻든 건너뛰지 않는다.
이미 본인 계정으로 되어 있으면 그 사실을 질문 설명에 담아 알려준다.

- header: `Plane 계정`
- 질문: `Plane 접속에 어느 계정을 쓸까요?`
- 선택지 2개:

| 라벨 | 설명 |
|------|------|
| `본인 API 토큰 등록 (권장)` | 만드는 티켓의 생성자·담당자가 본인 이름으로 남습니다. 토큰을 발급해 알려주셔야 합니다. |
| `봇 계정(migrate-bot) 사용` | 별도 준비 없이 바로 됩니다. 다만 티켓 생성자가 migrate-bot 으로 남습니다. |

선택 결과에 따라 Step 3-A 또는 3-B 로 간다.

### Step 3-A: 본인 API 토큰 등록

사용자에게 이렇게 안내하고 토큰을 받는다.

> Plane 웹(http://192.0.2.10:8080) 접속 →
> **우측 상단 프로필 → Settings → API Tokens → Add API token** 으로 새 토큰을 만들어
> 값을 알려주세요. (`plane_api_` 로 시작합니다)

토큰을 받으면 **소유자를 먼저 검증한다.** 유효하지 않으면 여기서 멈추고 다시 요청한다.

```bash
TOKEN='<사용자가 준 토큰>'
curl -s --max-time 15 -H "X-API-Key: $TOKEN" \
  http://192.0.2.10:8080/api/v1/users/me/ \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
if not d.get('email'):
    print('토큰이 유효하지 않습니다:', str(d)[:150]); raise SystemExit(1)
print('OK  ', d['email'], d['id'])
"
```

**이때 나온 `id` 가 곧 담당자 UUID 다.** 따로 조회할 필요 없다.
이 값들로 Step 4 를 수행한다.

### Step 3-B: 봇 계정 사용

봇 토큰과 봇 UUID 를 그대로 쓴다. 사용자에게 추가로 물을 것이 없다.

```
TOKEN=plane_api_<본인_토큰>
UUID=<BOT_UUID>
```

이 값들로 Step 4 를 수행한다.
**단, 티켓 생성자가 `migrate-bot` 으로 남는다는 점을 결과 보고에서 다시 알린다.**

### Step 4: env 기록

`PLANE_SELFHOST_TOKEN` 과 `PLANE_DEV_USER_ID` 두 줄만 교체한다.
`EMAIL`/`PASSWORD`(봇 세션 계정)는 **그대로 둔다.**

```bash
ENV=~/.config/plane-migrate/selfhost.env
TOKEN='<3-A 또는 3-B 의 토큰>'
UUID='<3-A 또는 3-B 의 UUID>'

mkdir -p "$(dirname "$ENV")"
[ -f "$ENV" ] && cp "$ENV" "$ENV.bak-$(date +%Y%m%d-%H%M)"

for pair in "PLANE_SELFHOST_TOKEN=$TOKEN" "PLANE_DEV_USER_ID=$UUID"; do
  key="${pair%%=*}"
  if grep -q "^$key=" "$ENV" 2>/dev/null; then
    sed -i "s|^$key=.*|$pair|" "$ENV"
  else
    echo "$pair" >> "$ENV"
  fi
done

# 세션 계정이 없으면 봇 기본값을 넣어준다 (내부 API·마이그레이션용)
grep -q '^PLANE_SELFHOST_EMAIL=' "$ENV" || cat >> "$ENV" <<'BOT'
PLANE_SELFHOST_EMAIL=bot@example.com
PLANE_SELFHOST_PASSWORD=<본인_비밀번호>
BOT

chmod 600 "$ENV"
```

### Step 5: 검증

토큰 소유자와 담당자 UUID가 **같은 사람**인지 확인하고, 프로젝트 접근도 본다.

```bash
set -a; source ~/.config/plane-migrate/selfhost.env; set +a
curl -s -H "X-API-Key: $PLANE_SELFHOST_TOKEN" \
  http://192.0.2.10:8080/api/v1/users/me/ \
  | python3 -c "
import sys, json, os
d = json.load(sys.stdin)
same = d.get('id') == os.environ.get('PLANE_DEV_USER_ID')
print('토큰 소유자 :', d.get('email'))
print('담당자 UUID :', os.environ.get('PLANE_DEV_USER_ID'))
print('일치 여부   :', 'OK' if same else '불일치 — 다시 확인 필요')
"

for p in "<PROJA_ID_DST>:PROJA" \
         "<PROJB_ID_DST>:PROJB" \
         "<PROJECT_ID>:CUSTOM"; do
  id="${p%%:*}"; n="${p##*:}"
  c=$(curl -s -H "X-API-Key: $PLANE_SELFHOST_TOKEN" \
    "http://192.0.2.10:8080/api/v1/workspaces/my-workspace/projects/$id/issues/" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('total_count', d.get('error','접근 불가')))")
  echo "  $n: $c"
done
```

프로젝트가 `접근 불가` 로 나오면 그 사람이 해당 프로젝트 멤버가 아니다.
Plane 웹에서 초대받아야 한다고 알린다.

### Step 6: 결과 보고

무엇이 바뀌었는지 표로 알린다. 백업 파일 경로도 함께 알린다.
**사람 계정 토큰 값은 다시 출력하지 않는다.**
봇 계정을 골랐다면 생성자가 봇으로 남는다는 점과, 나중에 이 스킬을 다시 돌려
본인 토큰으로 바꿀 수 있다는 점을 알린다.

### Step 7: 사용 가이드 안내

세팅이 끝났으면 **이어서 아래 가이드를 알려준다.** 처음 받은 사람은 이걸 몰라서 헤맨다.

#### Plane 접속

- **URL**: http://192.0.2.10:8080
- **워크스페이스**: `my-workspace`
- 웹 로그인은 **각자 본인 계정**으로 한다 (봇 계정으로 로그인하지 않는다)

#### 프로젝트 ↔ 레포 ↔ 티켓 prefix

| Plane 프로젝트 | prefix | 레포 | 프로젝트 UUID |
|---|---|---|---|
| `example-app` | `PROJA` | `example-monorepo` | `<PROJA_ID_DST>` |
| `example` | `PROJB` | `example-monorepo` | `<PROJB_ID_DST>` |
| `planecustom` | `CUSTOM` | `scrum` (Plane 자체 운영·커스터마이징) | `<PROJECT_ID>` |

#### 작업 흐름

```
/start_work {번호}
```

티켓 조회 → 브랜치 생성 → 상태 In Progress → 구현 → CHANGELOG·커밋까지 한 번에 간다.
단계 사이에 컨펌 게이트가 있으므로 중간에 멈추고 확인할 수 있다.

- 브랜치: `feature/{PREFIX}-{번호}` (예: `feature/PROJA-42`)
- 티켓 번호만 주면 된다. `/start_work 42`

#### 알아둘 것 두 가지

**하나. self-host 에는 Plane MCP 가 없다.**
`mcp__plane__*` 도구는 SaaS 전용이라 이 프로젝트들이 보이지 않는다.
티켓 조회·수정은 **REST API**(`/api/v1/...`)로 한다. 방법은 각 레포
`.claude/agents/start_work.md` 의 Step 1 에 있다.

**둘. 공개 API 는 모르는 쿼리 파라미터를 조용히 무시한다.**
`?sequence_id=42` 나 `?archived=true` 를 붙여도 **필터가 안 걸린 전체 목록**이 온다.
에러도 안 난다. 그래서 목록을 받아 코드에서 직접 매칭해야 한다.
(실제로 이 함정 때문에 이관 때 아카이브된 사이클 9개가 통째로 누락된 적이 있다)

#### 서버가 응답하지 않을 때

Plane 은 `192.0.2.10` 데스크톱의 **WSL Ubuntu 안**에서 돈다.
접속이 안 되면 그 PC 의 WSL 이 내려갔을 가능성이 크다.
진단·복구 절차는 `scrum` 레포의 `shell-scripts/README-wsl-keepalive.md` 참고.

---

## 주의

- **사람 계정 토큰을 레포에 커밋하지 않는다.** env 는 홈 디렉토리(`~/.config/`)에 있어 git 밖이다.
  봇 계정 정보만 예외적으로 `CLAUDE.md` 에 기본값으로 적혀 있다.
- 이 스킬은 `~/.config/plane-migrate/selfhost.env` **하나만** 건드린다.
  레포 파일을 수정하거나 커밋하지 않는다.
- Step 2 의 선택창을 건너뛰지 않는다. 이미 세팅된 사람도 계정을 바꿀 수 있어야 한다.
