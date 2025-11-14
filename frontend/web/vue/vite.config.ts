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
  },
})
