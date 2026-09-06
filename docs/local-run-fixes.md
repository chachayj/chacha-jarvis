# 로컬 구동 정상화 기록 (2026-09-06)

`README.md` 의 구동 절차를 그대로 따라도 스택이 뜨지 않던 문제들을 정리한다.
세팅 자동화(`setup_all.sh` / `run_all.sh`)와 그 과정에서 드러난 버그 5건을 함께 담았다.

## 1. 세팅 자동화

| 스크립트 | 역할 |
| --- | --- |
| `setup_all.sh` | 최초 1회. 도커 확인 → `.env` 생성(비밀번호 자동) → 실행 권한 → 런타임 디렉터리 → nginx 인증서 → 이미지 빌드 → Ollama 모델 pull. 재실행해도 기존 `.env`·인증서는 건드리지 않는다. |
| `run_all.sh` | `up`(전체) / `core`(3D맵·챗봇·로봇서버·EMQX) / `status` / `logs [서비스]` / `restart` / `down`. 포트별로 열릴 때까지 대기하며 결과를 찍고, 끝에 접속 URL과 EMQX 비밀번호를 출력한다. |

`README.md` 에 빠져 있던 수동 단계도 문서에 채웠다.

- `nginx/selfsigned.key` 는 `.gitignore` 대상이라 레포에 없다. 없으면 nginx 가 뜨지 않는다 → `nginx/generate-cert.sh`
- 챗봇 NLU 는 `llama3.1:8b`(약 5GB)을 쓴다. 없으면 `/nlu` 가 실패한다 → `docker exec -it ollama ollama pull llama3.1:8b`

## 2. 고친 버그

### 2-1. fiber-server 볼륨 경로 하드코딩

`backend/go_fiber_server/docker-compose.yml`

```yaml
# before
- /root/chacha-jarvis/emqx/certs:/certs
- /root/chacha-jarvis/backend/go_fiber_server/wait-for-it.sh:/wait-for-it.sh
# after
- ../../emqx/certs:/certs
- ./wait-for-it.sh:/wait-for-it.sh
```

레포를 `/root/chacha-jarvis` 가 아닌 곳에 클론하면 `wait-for-it.sh` 가 **빈 디렉터리로** 마운트되어
`command` 가 실행 불가가 된다. 도커는 없는 경로를 디렉터리로 만들어버리므로 에러도 모호하게 난다.
상대경로는 해당 compose 파일 기준으로 풀리므로 클론 위치와 무관해진다.

### 2-2. postgres initdb 마운트 경로

`postgres/docker-compose.yml`

```yaml
# before  → postgres/postgres/initdb (존재하지 않음)
- ./postgres/initdb:/docker-entrypoint-initdb.d
# after
- ./initdb:/docker-entrypoint-initdb.d
```

`extends` 로 참조되는 파일의 상대경로는 **루트 compose 가 아니라 그 파일의 디렉터리** 기준으로 풀린다.
경로가 어긋나 initdb 디렉터리가 비어 마운트되면서 스키마·기초 데이터가 전혀 적재되지 않았다.

### 2-3. vue-frontend `vite: not found` (exit 127) 무한 재시작

`frontend/web/vue/docker-compose.yml`

```yaml
volumes:
  - .:/app
  - /app/node_modules   # 추가
```

`.:/app` 바인드 마운트가 이미지 빌드 때 설치한 `/app/node_modules` 를 덮어써서 vite 바이너리가 사라졌다.
익명 볼륨으로 해당 경로만 이미지 내용을 유지시킨다.

### 2-4. spring-server 부팅 실패 (MyBatis type alias)

`backend/spring_server/src/main/resources/application.yml`

```yaml
# before
type-aliases-package: com.chacha.domain
# after
type-aliases-package: com.chacha.entities
```

mapper XML 이 쓰는 alias 7개(`ProvinceEntity`, `BoundaryCenterEntity`, `AdministrativeDistrictEntity`,
`*QueryEntity` 4종)는 전부 `com.chacha.entities`(+`.query`) 에 있다.
`com.chacha.domain` 을 가리키고 있어 `ClassNotFoundException` → `sqlSessionFactory` 생성 실패로
컨테이너가 `RestartCount=8` 까지 크래시 루프를 돌았다. DB 인증 문제로 오해하기 쉬운 증상이다.

### 2-5. `/administrative/districts/centers` 의 `total` 이 항상 0

`backend/spring_server/.../controller/AdministrativeController.java`

```java
body.setTotal((int) service.getCentersCount(request));  // 추가
```

목록 18건을 반환하면서 `total` 은 primitive 기본값 0 으로 나갔다. 서비스에 `getCentersCount` 가
이미 있어 호출만 연결했다.

## 3. 3D 맵 시/도 선택이 비어 있던 문제

`frontend/web/vue/src/components/three-d-map/AdministrativeSelect.vue` 의 API 주소가
플레이스홀더(`https://your-osm-api.example.com/osm`)였다. 컴포넌트 최초 커밋 `eabd88d [CHACH-4]`
부터 그대로였고, 이후 `7877cda [CHACH-29]` 로 spring 행정구역 API 가 들어왔지만 프론트가 연결되지 않았다.
`fetchJson` 이 실패 시 `[]` 를 반환하도록 되어 있어 **에러 없이 조용히 빈 드롭다운**이 됐다.

### 연결한 엔드포인트

| 드롭다운 | 엔드포인트 | 응답 필드 |
| --- | --- | --- |
| 시/도 | `GET /administrative/provinces?countryCode=KR` | `provinces[].provinceCode` / `provinceName` |
| 구 | `GET /administrative/districts?provinceCode=…` | `districts[].districtCode` / `name` |
| 동 | `GET /administrative/districts/centers?districtCode=…` | `centers[].osmId` / `name` / `longitude` / `latitude` |

- 응답 필드명이 컴포넌트가 기대하던 `code`/`name` 과 달라 변환 계층을 넣었다.
- 동 응답이 좌표를 직접 들고 있어 기존의 별도 `/coord` 호출은 제거했다.
- 실패 시 조용히 비던 것을 화면 메시지로 노출하고, 동 데이터가 없는 구는 "동 데이터 없음" 으로 표시한다.

### 프록시

`vite.config.ts` 에 `/administrative` → spring 프록시를 추가했다. 컴포넌트가 상대경로로 호출하므로
**5173 직접 접속과 nginx 8443 경유가 모두** 동작하고 CORS 문제도 없다.
대상은 `SPRING_API_URL` 로 주입한다 (도커 컴포즈: `http://spring-server:8081`,
호스트 `npm run dev`: `http://localhost:8081`).

## 4. 행정구역 시드 데이터 범위

`02_base_data.sql` 은 initdb 로 정상 적재된다 (파일 의도 건수 = DB 실제 건수).
다만 시드 자체가 부분 데이터다.

| 테이블 | 건수 |
| --- | --- |
| administrative_countries | 1 |
| administrative_provinces | 3 (서울·인천·수원) |
| administrative_districts | 38 (서울 24 + 인천 10 + 수원 4) |
| administrative_district_centers | 38 |
| administrative_boundaries_by_province | 22 (동 경계) |
| administrative_boundary_centers_by_province | 22 |

**동 데이터가 있는 구는 2개뿐이다.**

| 시/도 | 구 | 동 |
| --- | --- | --- |
| 서울특별시 | 서초구 | 18 (내곡동, 반포1~4·본동, 방배1~4·본동, 서초1~4동, 양재1~2동, 잠원동) |
| 인천광역시 | 중구 | 4 (영종동, 영종1동, 용유동, 운서동) |
| 나머지 36개 구 | | 0 |

원본이 그렇다 — `postgres/schema/OSMB/datas/` 에 구 단위 덤프(서울 24 / 인천 10 / 수원 4)는 있지만
동 단위는 `_OSMB_seocho_gu_`(18), `_OSMB_incheon_junggu_`(4) 두 파일뿐이다.

동을 늘리려면 나머지 구의 OSMB 동 경계를 떠서 `postgres/schema/OSMB/datas/` 에 추가하고,
`postgres/schema/administrative/migration/administrative_from_OSMB.sql` 로
`administrative_boundaries_by_province` / `administrative_boundary_centers_by_province` 를 채운다.
그 두 테이블만 채우면 프론트는 코드 수정 없이 바로 반영된다.

## 5. 남은 이슈

- **`OPEN_WEATHER_MAP_KEY` 미설정** — `/weather/:city` 가 401 → 500. 키는 `backend/go_fiber_server/.env`
  에 넣어야 하고, Dockerfile 이 `.env` 를 COPY 하므로 `docker compose up -d --build fiber-server` 재빌드가 필요하다.
- **`/districts/centers` 의 `limit`/`offset` 무시** — `AdministrativeMapper.xml` 에서 `LIMIT`/`OFFSET` 이,
  컨트롤러에서 `body.setPaging` 이 주석 처리돼 있다. 현재 데이터가 최대 18건이라 영향은 없다.
- **`administrative_district_centers`(38건) 노출 엔드포인트 없음** — 구 선택 시 구 중심으로 카메라를
  옮기려면 이 테이블을 쓰는 API 가 필요하다.
- **piper TTS 로드 실패 로그** — `'pygoruut' is not a valid PhonemeType`. `/tts` 는 gTTS 경로만 쓰므로
  현재는 무해하다. piper 를 실제로 쓰려면 `piper-tts` 버전을 고정해야 한다.
