# scripts — SaaS → self-host 이관 도구

Plane SaaS(`my-saas-workspace`)의 데이터를 사내 self-host(`my-workspace`)로 옮기는 스크립트.

실행 순서대로:

| 스크립트 | 역할 |
|----------|------|
| `dump_saas.py` | SaaS를 JSON으로 덤프 (원본 스냅샷 겸 이관 입력) |
| `migrate_to_selfhost.py` | 작업 항목 · 상태 · 라벨 이관 |
| `migrate_extras.py` | 사이클 · 모듈 · 댓글 · 링크 이관 |
| `scan_attachments.py` | 첨부파일 메타데이터 스캔 |

토큰은 `~/.config/plane-migrate/selfhost.env` (권한 600)에서 읽는다.
레포에 커밋하지 않는다.

```
PLANE_SELFHOST_TOKEN=...
PLANE_SAAS_TOKEN=...
```

## 재실행 안전

모든 스크립트는 **여러 번 돌려도 중복이 안 생긴다.**

- 작업 항목·사이클·모듈·댓글에 `external_id`(원본 SaaS id) + `external_source=plane-saas`를 박는다.
  Plane API는 같은 조합이 이미 있으면 409와 함께 기존 id를 돌려준다.
- 진행 상태를 `migration-dump/_migration_state.json`, `_extras_state.json`에 남긴다.
- 덤프도 중간 저장하므로 끊긴 지점부터 이어받는다.

실제로 첫 이관에서 rate limit으로 9건이 실패했는데, 재실행으로 그 9건만 다시 넣었다.

## 겪은 제약 세 가지

### 1. Cloudflare가 Python 기본 User-Agent를 막는다

SaaS API 호출이 전부 403(Cloudflare Error 1010)이 됐다. 인증 실패처럼 보여서
원인 찾기가 어려웠다. `User-Agent` 헤더를 주면 해결된다.

403을 조용히 `None`으로 삼키던 코드 때문에 "데이터 0건"으로 오인했었다.
지금은 404만 정상 흐름으로 다루고 나머지는 예외를 던진다.

### 2. rate limit

self-host의 `API_KEY_RATE_LIMIT` 기본값이 `60/minute`이다.
`THROTTLE_SEC`을 0.3초(분당 200회)로 잡았다가 429로 9건이 실패했다. 1.1초로 둔다.

### 3. 완료된 사이클은 잠긴다

Plane은 `end_date < now`인 사이클에 **항목 추가도 수정도 막는다**
(`plane/api/views/cycle.py`). 이관 대상이 전부 과거 사이클이라 그대로는 다 막혔다.

시도한 순서:

1. 종료일을 미래로 PATCH → 실패 (완료된 건 수정도 막힘)
2. 종료일 없이 생성 → 실패 (`start_date`/`end_date`는 둘 다 있거나 둘 다 없어야 함)
3. **종료일만 2099년으로 두고 생성 → 항목 추가 → 진짜 날짜로 PATCH → 성공**

잠금 판정이 "수정 시점의 현재 `end_date`" 기준이라 마지막 PATCH는 통과한다.

## 보존되는 것 / 안 되는 것

`created_at`과 `created_by`는 **보존된다.** OpenAPI 스펙은 `created_at`을 `readOnly`로
표시하지만(DRF가 `auto_now_add`를 보고 추론), 실제 뷰는 serializer를 우회해
`request.data`에서 받는다. 스펙이 기능을 과소 보고하는 경우다.

| 항목 | |
|------|---|
| 작성일 `created_at` | ✅ |
| 작성자 `created_by` | ✅ self-host에 계정이 있는 사람만 |
| 담당자 · 날짜 · 우선순위 · 상태 · 라벨 · 부모자식 | ✅ |
| 댓글 (작성일·작성자 포함) · 링크 | ✅ |
| 사이클 · 모듈 + 소속 관계 | ✅ |
| 활동 내역(Activity) | ❌ 쓰기 경로 없음. 덤프에는 보관됨 |
| 작업 항목 번호 (`PROJA-190`) | ❌ 1번부터 재부여 |
| 페이지 · 뷰 | ❌ 공개 API에 엔드포인트 없음 (내부 API는 세션 인증 전용) |

## 멤버 매핑

self-host에 계정이 있는 사람만 담당자·작성자로 넘어간다. 없는 사용자를 넘기면
FK 위반이 나므로 담당자는 비우고 작성자는 토큰 소유자로 대체한다.

매핑 대상: `yjcha` · `ejshin` · `shahn`
제외: 퇴사자 2명(`jslee`·`ybkim`), 봇 2개, self-host 미초대 3명(`ikpark`·`dhjung`·`jhlee2`)

실측 결과 미초대 3명은 담당·작성 이력이 없어 손실이 0이었다.

## 프로젝트 매핑

| SaaS | self-host |
|------|-----------|
| `PROJB` | `PROJB` |
| `PROJA` | `PROJA` |
| `PROJC` | `MXSPA` (identifier 다름, 같은 프로젝트) |
| `PROJD` | 대응 프로젝트 없음 — 제외 |
