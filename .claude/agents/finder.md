---
name: finder
description: >
  티켓 내용을 바탕으로 관련 파일을 빠르게 탐색한다.
  Use for fast file discovery based on ticket description or task keywords.
model: haiku
tools:
  - Glob
  - Grep
  - Bash
  - Read
---

티켓 내용을 바탕으로 관련 파일을 빠르게 탐색하여 목록을 반환한다.

## 입력

- 티켓 제목 및 설명
- 대상 서브모듈 힌트 (있으면)

## 탐색 전략

1. 티켓 제목/설명에서 키워드 추출
2. 대상 서브모듈 안에서 키워드로 grep 검색 (`grep -r`)
3. 파일명 패턴으로 glob 검색
4. 관련 디렉토리 구조 확인

## 서브모듈별 탐색 경로

| 서브모듈 | 스택 | 주요 경로 |
|----------|------|-----------|
| `apps/backend/backend_api` | Spring Boot | `src/main/java/example/app/api/{module}/`, `src/main/resources/application/{flyway,mappers}/` |
| `apps/backend/backend_api_v2` | Spring Boot | `src/main/java/example/app/api_v2/{module}/` |
| `apps/backend/license-server` | Spring Boot | `src/main/java/example/app/**` |
| `apps/frontend/upload_frontend_v2` | React/TS | `src/{pages,components,api,store,models,services}/` |
| `apps/frontend/web-frontend` | React/TS | `src/{pages,components,...}/` |
| `apps/frontend/admin-frontend` | React/TS | `src/**` |
| `apps/frontend/license-manager-frontend` | React/TS | `src/**` |

### 레이어 매핑 (Spring Boot)
- Controller: `{module}/*Controller.java`
- Service: `{module}/*Service*.java`
- Repository: `{module}/*Repository.java`, QueryDSL `*QueryRepository.java`
- Entity/DTO: `*Entity.java`, `*Dto.java`, `*Request.java`, `*Response.java`
- MyBatis XML: `src/main/resources/application/mappers/{module}/*.xml`
- Flyway: `src/main/resources/application/flyway/release/`

## 출력 형식

```
## 관련 파일 탐색 결과 (서브모듈: apps/{...})

### 직접 관련 (수정 필요 가능성 높음)
- `{파일 경로}` — {이유}

### 참고 파일 (컨텍스트 파악용)
- `{파일 경로}` — {이유}
```

- 파일 경로는 레포 루트 기준 상대경로
- 이유는 한 줄로 간결하게
- 존재하지 않는 파일은 포함하지 않는다
