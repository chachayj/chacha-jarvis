# ---- Build stage ----
FROM node:20.18.0-slim

WORKDIR /app

# 캐시 최적화를 위해 package.json만 먼저 복사
COPY package*.json ./

# 의존성 설치
RUN npm install --legacy-peer-deps

# 앱 복사
COPY . .

# 기본 Vite 포트
EXPOSE 5173

# 개발 서버 실행
CMD ["npm", "run", "dev"]
