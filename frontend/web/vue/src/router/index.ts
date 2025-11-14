import { createRouter, createWebHistory } from "vue-router";
import Korea3DMap from "../views/Korea3DMapView.vue";

const routes = [
  {
    path: "/",
    name: "Korea3DMap",
    component: Korea3DMap,
  },
  // 나중에 다른 페이지 추가 가능
  // { path: "/dashboard", component: Dashboard }
];

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes,
});

export default router;
