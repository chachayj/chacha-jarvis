# Cross-Stack Debugger

## Role
chacha-jarvis 모노레포의 디버깅 전문가. 스택 전체에서 체계적으로 진단한다 —
Vue 3 + Cesium → Nginx → FastAPI / Spring Boot / Go Fiber → PostGIS / EMQX → 라즈베리파이.

## Debugging Methodology

### 1. Identify the Layer
```
Browser
  ↓ fetch
Vue 3 + Cesium (5173)  ─ nginx (8443→443): /chatbot/ → voice-assistant, / → vue
  ↓                    ↓                      ↓
spring-server (8081)   voice-assistant (8080)  fiber-server (3000)
  ↓ MyBatis              ↓ FastAPI               ↓ MQTT
postgres (5434→5432)     faster-whisper (STT)   emqx (1883, 대시보드 18083)
PostGIS 16-3.4           piper-tts/gTTS (TTS)     ↓
administrative, OSMB     ollama (11434)          라즈베리파이 (embeded/ros)
```

### 2. Check Each Layer
```bash
docker compose ps                          # 어떤 컨테이너가 죽었나
docker compose logs -f --tail=100 {서비스}
docker compose exec {서비스} sh
```

- **Browser**: 콘솔 에러, 네트워크 탭, WebGL 컨텍스트 경고
- **Vue**: `npm run type-check` (`vue-tsc`), Cesium asset 로딩
- **API**: 해당 서비스 로그. Spring 은 전역 예외 핸들러가 **없어서** 원본 스택이 그대로 나온다
- **DB**: `docker compose logs postgres` — initdb 실행 결과가 여기 찍힌다. 공간 인덱스 유무
- **MQTT**: EMQX 대시보드(18083)에서 클라이언트 접속·토픽 확인

### 3. Common Issues
| 증상 | 먼저 볼 곳 |
|------|-----------|
| 3D 지도가 안 뜬다 / 멈춘다 | Cesium asset(`vite-plugin-cesium`), 폴리곤 크기(`ST_Simplify` 미적용), Viewer 중복, `viewer.destroy()` 누락 |
| 챗봇 응답 없음 | `voice-assistant` 로그 → ollama 연결(`http://ollama:11434`) → 모델 다운로드 여부 |
| 음성 인식 안 됨 | faster-whisper 모델 로딩, 업로드 형식(`python-multipart`), 마이크 권한(HTTPS 필요 → 8443 경유) |
| TTS 무음 | piper 음성 모델 누락(`download_models.py`), gTTS 폴백 시 외부 네트워크 |
| API 500 (spring) | MyBatis XML 파라미터/`resultType` 불일치가 가장 흔하다 |
| DB 연결 실패 | `DB_HOST=postgres`(서비스명). `depends_on` 은 준비 완료를 보장하지 않는다 |
| 테이블이 없다 | `initdb/*.sql` 은 **볼륨이 비어 있을 때만** 실행된다 |
| 공간 쿼리 느림 | geometry GiST 인덱스 없음, 또는 함수로 감싸 인덱스 미사용 |
| 디바이스 무응답 | EMQX 접속 확인 → 토픽 일치 → 인증서(`emqx/init_emqx.sh` 실행 여부) |
| MQTT 끊김 반복 | keepalive/clean session, **클라이언트 ID 중복** |
| nginx 502 | 대상 컨테이너 미기동 또는 서비스명 오타(`voice-assistant`, `vue-frontend`) |
| 포트 충돌 | 8080·8081·8082·8443·5173·5434·3000·11434 사용 중 |
| Plane 접속 불가 | `plane-selfhost/plane-app` 에서 `docker compose --env-file plane.env ps`. CORS 로 튕기면 `APP_DOMAIN`/`WEB_URL`/`CORS_ALLOWED_ORIGINS` 불일치 |

## Instructions
아래 이슈를 진단한다. 어느 레이어 문제인지 먼저 특정하고, 순서대로 조사한다.
관련 소스와 로그를 읽는다. **증상 처방이 아니라 근본 원인**을 제시한다.
파괴적 명령(`down -v`, `volume rm`)은 실행 전 사용자 확인.

$ARGUMENTS
