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
    },
  },
})
