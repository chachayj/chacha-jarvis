---
name: plane_user_setup
description: chacha-jarvis 전용 Plane 인스턴스(공식 이미지 v1.4.2, http://localhost:8082) 접속 정보를 세팅한다. 인스턴스 기동 여부를 확인하고, 본인 API 토큰·워크스페이스·프로젝트 ID를 받아 ~/.config/plane-chacha/selfhost.env 에 기록한 뒤 검증한다. 레포를 받아 최초 1회 실행하거나 계정·프로젝트를 바꿀 때 쓴다. "plane 계정 세팅", "plane 토큰 등록", "내 계정으로 바꿔줘", "/plane_user_setup" 등에 반응한다.
---

# Plane 접속 세팅 (chacha-jarvis)

`~/.config/plane-chacha/selfhost.env` 에 이 레포 전용 Plane 접속 정보를 기록한다.

## ⚠️ env 파일을 다른 레포와 공유하지 않는다

이 PC 에는 `~/.config/plane-migrate/selfhost.env` 가 이미 있을 수 있다.
그건 **다른 레포가 쓰는 별개의 Plane 인스턴스** 용이다.
이 레포는 별도 인스턴스(`localhost:8082`)를 쓰므로 **절대 그 파일을 덮어쓰지 않는다.**

| 파일 | 대상 인스턴스 |
|------|---------------|
| `~/.config/plane-chacha/selfhost.env` | **이 레포** — `http://localhost:8082` (공식 이미지 v1.4.2) |
| `~/.config/plane-migrate/selfhost.env` | 다른 레포 — 건드리지 않는다 |

## 왜 본인 토큰을 써야 하나

`created_by` 는 **API 토큰 주인으로 자동 기록되며 API 로 바꿀 수 없다.**
남의 토큰을 쓰면 만든 티켓이 전부 그 사람 이름으로 남는다.

담당자(`assignees`)는 `PLANE_DEV_USER_ID` 로 지정하며, 이 스킬이 함께 맞춰준다.

---

## 절차

### Step 1: 인스턴스가 떠 있는지 확인

```bash
curl -s -o /dev/null -w "%{http_code}\n" --max-time 8 http://localhost:8082/
```

`200` 이 아니면 아직 기동되지 않았다. 아래를 안내하고 **여기서 멈춘다.**

```bash
cd plane-selfhost/plane-app
cp plane.env.example plane.env      # plane.env 가 없을 때만
# plane.env 의 <생성하세요> 자리를 채운다 (생성 명령은 파일 끝 주석)
docker compose --env-file plane.env up -d
```

첫 기동은 이미지 pull 로 10분 내외 걸린다. 이후 `http://localhost:8082` 에서
**관리자 계정 생성 → 워크스페이스 생성 → 프로젝트 생성** 을 사람이 직접 해야 한다.

> 프로젝트를 만들 때 정하는 **identifier(prefix)** 가 곧 티켓 번호의 접두어이자
> 브랜치 이름이 된다. 기존 커밋 히스토리가 `[CHACH-*]` 이므로 `CHACH` 를 권한다.

### Step 2: 현재 상태 확인

```bash
ENV=~/.config/plane-chacha/selfhost.env
if [ -f "$ENV" ]; then
  set -a; source "$ENV" 2>/dev/null; set +a
  echo "URL         : ${PLANE_SELFHOST_URL:-(없음)}"
  echo "워크스페이스: ${PLANE_SELFHOST_WORKSPACE:-(없음)}"
  echo "프로젝트 ID : ${PLANE_SELFHOST_PROJECT_ID:-(없음)}"
  curl -s --max-time 15 -H "X-API-Key: ${PLANE_SELFHOST_TOKEN}" \
    "${PLANE_SELFHOST_URL:-http://localhost:8082}/api/v1/users/me/" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print('토큰 소유자 :', d.get('email','(확인 실패)'))"
  echo "담당자 UUID : ${PLANE_DEV_USER_ID:-(없음)}"
else
  echo "env 파일 없음 — 새로 만든다"
fi
```

### Step 3: 토큰 받기

사용자에게 이렇게 안내하고 토큰을 받는다.

> Plane 웹(http://localhost:8082) 접속 →
> **우측 상단 프로필 → Settings → API Tokens → Add API token** 으로 새 토큰을 만들어
> 값을 알려주세요. (`plane_api_` 로 시작합니다)

토큰을 받으면 **소유자를 먼저 검증한다.** 유효하지 않으면 여기서 멈추고 다시 요청한다.

```bash
TOKEN='<사용자가 준 토큰>'
curl -s --max-time 15 -H "X-API-Key: $TOKEN" \
  http://localhost:8082/api/v1/users/me/ \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
if not d.get('email'):
    print('토큰이 유효하지 않습니다:', str(d)[:150]); raise SystemExit(1)
print('OK  ', d['email'], d['id'])
"
```

**이때 나온 `id` 가 곧 담당자 UUID 다.** 따로 조회할 필요 없다.

### Step 4: 워크스페이스 slug 와 프로젝트 ID 확인

워크스페이스 slug 는 Plane 웹 URL 에서 보인다 — `http://localhost:8082/{slug}/projects/...`.
사용자에게 slug 를 물어보고, 그걸로 프로젝트 목록을 조회한다.

```bash
TOKEN='<Step 3 의 토큰>'
SLUG='<워크스페이스 slug>'
curl -s -H "X-API-Key: $TOKEN" \
  "http://localhost:8082/api/v1/workspaces/$SLUG/projects/" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
rows = d.get('results', d) if isinstance(d, dict) else d
if not rows:
    print('프로젝트가 없습니다 — Plane 웹에서 먼저 만들어야 합니다'); raise SystemExit(1)
for p in rows:
    print(f\"  {str(p.get('identifier')):>8}  {str(p.get('name')):<28} {p.get('id')}\")
"
```

프로젝트가 여러 개면 `AskUserQuestion` 으로 어느 것을 쓸지 묻는다.
하나면 그것을 쓰고 사용자에게 알린다.

### Step 5: env 기록

```bash
ENV=~/.config/plane-chacha/selfhost.env
URL='http://localhost:8082'
SLUG='<Step 4 의 slug>'
PROJECT='<Step 4 의 프로젝트 UUID>'
TOKEN='<Step 3 의 토큰>'
UUID='<Step 3 의 사용자 id>'

mkdir -p "$(dirname "$ENV")"
[ -f "$ENV" ] && cp "$ENV" "$ENV.bak-$(date +%Y%m%d-%H%M)"
touch "$ENV"

for pair in "PLANE_SELFHOST_URL=$URL" \
            "PLANE_SELFHOST_WORKSPACE=$SLUG" \
            "PLANE_SELFHOST_PROJECT_ID=$PROJECT" \
            "PLANE_SELFHOST_TOKEN=$TOKEN" \
            "PLANE_DEV_USER_ID=$UUID"; do
  key="${pair%%=*}"
  if grep -q "^$key=" "$ENV"; then
    sed -i "s|^$key=.*|$pair|" "$ENV"
  else
    echo "$pair" >> "$ENV"
  fi
done

chmod 600 "$ENV"
```

### Step 6: 검증

토큰 소유자와 담당자 UUID 가 **같은 사람**인지, 프로젝트 티켓이 조회되는지 본다.

```bash
set -a; source ~/.config/plane-chacha/selfhost.env; set +a

curl -s -H "X-API-Key: $PLANE_SELFHOST_TOKEN" \
  "$PLANE_SELFHOST_URL/api/v1/users/me/" \
  | python3 -c "
import sys, json, os
d = json.load(sys.stdin)
same = d.get('id') == os.environ.get('PLANE_DEV_USER_ID')
print('토큰 소유자 :', d.get('email'))
print('담당자 UUID :', os.environ.get('PLANE_DEV_USER_ID'))
print('일치 여부   :', 'OK' if same else '불일치 — 다시 확인 필요')
"

curl -s -H "X-API-Key: $PLANE_SELFHOST_TOKEN" \
  "$PLANE_SELFHOST_URL/api/v1/workspaces/$PLANE_SELFHOST_WORKSPACE/projects/$PLANE_SELFHOST_PROJECT_ID/issues/" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
print('티켓 조회   :', d.get('total_count', d.get('error', '접근 불가')))
"
```

`접근 불가` 로 나오면 그 사람이 해당 프로젝트 멤버가 아니다.
Plane 웹에서 초대받아야 한다고 알린다.

### Step 7: 결과 보고

무엇이 바뀌었는지 표로 알린다. 백업 파일 경로도 함께 알린다.
**토큰 값은 다시 출력하지 않는다.**

프로젝트 prefix 가 `CHACH` 가 아니면, `CLAUDE.md` 의 "티켓과 브랜치" 섹션과
`.claude/rules/agent-behavior.md` 의 브랜치 규칙을 갱신해야 한다고 알린다.

### Step 8: 사용 가이드 안내

세팅이 끝났으면 **이어서 아래를 알려준다.** 처음 받은 사람은 이걸 몰라서 헤맨다.

#### 작업 흐름

```
/start_work {번호}
```

티켓 조회 → 브랜치 생성 → 상태 In Progress → 구현 → CHANGELOG·커밋까지 한 번에 간다.
단계 사이에 컨펌 게이트가 있어 중간에 멈추고 확인할 수 있다.

- 브랜치: `feature/{PREFIX}-{번호}` (예: `feature/CHACH-42`)
- 커밋: `[{PREFIX}-{번호}] {type} : {설명}`
- 티켓 번호만 주면 된다. `/start_work 42`

#### 알아둘 것 세 가지

**하나. self-host 에는 Plane MCP 가 없다.**
`mcp__plane__*` 도구는 SaaS 전용이다. 이 레포에는 `.mcp.json` 도 없다.
티켓 조회·수정은 **REST API**(`/api/v1/...`)로 한다.

**둘. 공개 API 는 모르는 쿼리 파라미터를 조용히 무시한다.**
`?sequence_id=42` 나 `?archived=true` 를 붙여도 **필터가 안 걸린 전체 목록**이 온다.
에러도 안 난다. 목록을 받아 코드에서 직접 매칭해야 한다.

**셋. 내부 API 는 `X-API-Key` 를 받지 않는다.**
page·estimate 등 공개 API 에 없는 것은 `/api/...` 내부 API 에만 있고 세션 로그인이 필요하다.

#### 서버가 응답하지 않을 때

이 인스턴스는 **이 PC 의 도커**에서 돈다.

```bash
cd plane-selfhost/plane-app
docker compose --env-file plane.env ps
docker compose --env-file plane.env logs -f api
```

자세한 운영은 `docs/claude-plane-guide.md` 참고.

---

## 주의

- **토큰을 레포에 커밋하지 않는다.** env 는 홈 디렉토리(`~/.config/`)에 있어 git 밖이다.
- 이 스킬은 `~/.config/plane-chacha/selfhost.env` **하나만** 건드린다.
  `~/.config/plane-migrate/selfhost.env`(다른 레포용)는 건드리지 않는다.
  레포 파일을 수정하거나 커밋하지 않는다.
- Step 1 에서 인스턴스가 안 떠 있으면 기동 안내만 하고 멈춘다. 임의로 기동하지 않는다.
