import { fileURLToPath, URL } from 'node:url'

import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import cesium from 'vite-plugin-cesium'  // ✅ Cesium 리소스 로더 추가

export default defineConfig({
  plugins: [
    vue(),
    cesium(), // ✅ Cesium 관련 WebWorker, Asset 복사 처리
  ],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url))
    }
  },
  server: {
    host: "0.0.0.0", // ✅ 외부 접근 허용
    port: 5173,
    proxy: {
      // 행정구역 API 는 spring-server(:8081) 가 담당한다.
      // 도커 컴포즈에서는 SPRING_API_URL=http://spring-server:8081 이 주입되고,
      // 호스트에서 npm run dev 로 띄우면 localhost:8081 로 붙는다.
      '/administrative': {
        target: process.env.SPRING_API_URL || 'http://localhost:8081',
        changeOrigin: true,
      },
      // 챗봇 API 는 voice-assistant(:8080) 가 담당한다.
      // 서버 라우트는 /nlu, /action, /tts, /audio 이고 /chatbot 프리픽스가 없으므로
      // nginx 와 동일하게 프리픽스를 떼어서 전달한다.
      '/chatbot': {
        target: process.env.CHATBOT_API_URL || 'http://localhost:8080',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/chatbot/, ''),
      },
    },
  },
})
