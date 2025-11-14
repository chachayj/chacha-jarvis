# vue3 프론트엔드 


# 최초 세팅
```
npm install -g create-vue@3.8.0

create-vue vue

- 실행 예시 및 세팅

Vue.js - The Progressive JavaScript Framework

✔ Add TypeScript? … No / Yes
✔ Add JSX Support? … No / Yes
✔ Add Vue Router for Single Page Application development? … No / Yes
✔ Add Pinia for state management? … No / Yes
✔ Add Vitest for Unit Testing? … No / Yes
✔ Add an End-to-End Testing Solution? › Cypress
✔ Add ESLint for code quality? … No / Yes
✔ Add Prettier for code formatting? … No / Yes

Scaffolding project in /root/chacha-jarvis/frontend/web/vue...

Done. Now run:

  cd vue
  npm install
  npm run format
  npm run dev

```

## Project Setup

```sh
npm install
```

### Compile and Hot-Reload for Development

```sh
npm run dev
```

### Type-Check, Compile and Minify for Production

```sh
npm run build
```

### Run Unit Tests with [Vitest](https://vitest.dev/)

```sh
npm run test:unit
```

### Run End-to-End Tests with [Cypress](https://www.cypress.io/)

```sh
npm run test:e2e:dev
```


### Lint with [ESLint](https://eslint.org/)

```sh
npm run lint
```


# libs
```
cesium 설치를 위해 기존 vite 호환성 맞추기.

npm uninstall vite-plugin-cesium
npm install vite-plugin-cesium@1.2.23 --save-dev --legacy-peer-deps


