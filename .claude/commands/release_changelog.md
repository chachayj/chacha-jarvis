대상 서브모듈의 `CHANGELOG.md`(또는 `changelog/CHANGELOG.md`)의 `## Unreleased` 섹션을 릴리스 버전으로 승격한다.

## 원칙

- **릴리스 직전**에만 실행. 대상 서브모듈 안에서 실행.
- 일반적으로 `develop`/`main` 또는 release 브랜치에서 실행 권장.
- `Unreleased`가 비어 있으면 릴리스를 만들지 않는다.

## 절차

### 1단계: 현재 상태 확인 (대상 서브모듈 안에서)

```bash
git branch --show-current
git status -s
```

changelog 파일에서: `## Unreleased` 존재/항목 여부, 최신 릴리스 버전 확인.

- 작업트리가 깨끗하지 않으면 안내 후 종료.
- `Unreleased` 없거나 비어 있으면 안내 후 종료.

### 2단계: 릴리스 버전 결정

사용자에게 patch/minor/major/explicit 및 라벨을 요청.
- patch `v1.2.3`→`v1.2.4`, minor→`v1.3.0`, major→`v2.0.0`
- 날짜는 오늘(`YYYY-MM-DD`), 최종 제목은 항상 `vX.Y.Z` 형식.

### 3단계: 릴리스 섹션 생성

- 기존 `## Unreleased` 내용을 새 릴리스 섹션으로 변환.
- 제목: 라벨 없음 `## v{version} ({YYYY-MM-DD})`, 라벨 있음 `## v{version} ({YYYY-MM-DD}) - {label}`
- `# Changelog` 바로 아래 **새 빈 `## Unreleased`** 재생성.
- 새 릴리스 섹션은 빈 Unreleased 아래, 기존 최신 버전 위.

### 4단계: 커밋 가이드 (서브모듈 안에서)

```bash
git add {changelog 경로}
git commit -m "docs: release changelog v{version}"
# 전용 릴리스 티켓이 있으면: [PROJA-{번호}] docs: release changelog v{version}
```

### 5단계: 결과 보고

```
릴리스 changelog 작성 완료! (서브모듈: apps/{...})
- 이전 최신: v{latest} → 신규: v{version}
- 다음: 배포 또는 태그 생성
```
