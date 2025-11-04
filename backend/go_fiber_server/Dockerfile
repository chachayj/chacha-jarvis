# ==========================================
# Go 1.22.5 + Fiber v2 (LTS)
# ==========================================
FROM golang:1.22.5

# 작업 디렉터리
WORKDIR /app

# Go 모듈 사용 설정
ENV GO111MODULE=on

# ✅ netcat 설치 (wait-for-it.sh용 emqx 기다리기)
RUN apt-get update && apt-get install -y netcat-openbsd && rm -rf /var/lib/apt/lists/*


# .env 파일이 있는 경우 복사 (선택적)
COPY .env .env

# 모듈 파일만 먼저 복사
COPY go.mod go.sum ./
RUN go mod download

# 나머지 소스 복사
COPY . .

# 빌드 (배포 시에는 go build 사용)
RUN go build -o server .

# Fiber 서버 포트
EXPOSE 3000

# 컨테이너 실행 시 명령 (배포용)
CMD ["./server"]
