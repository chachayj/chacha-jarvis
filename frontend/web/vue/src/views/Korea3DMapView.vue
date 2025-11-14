<template>
  <div id="app-wrapper">
    <AdministrativeSelect @moveTo="handleMoveTo" />
    <ThreeDMap @ready="handleReady" />
  </div>
</template>

<script setup lang="ts">
import { ref } from "vue";
import * as Cesium from "cesium";
import ThreeDMap from "../components/three-d-map/3DMap.vue";
import AdministrativeSelect from "../components/three-d-map/AdministrativeSelect.vue";

const viewer = ref<Cesium.Viewer | null>(null);

function handleReady(v: Cesium.Viewer) {
  viewer.value = v;

  // 기본 3D 빌딩
  Cesium.createOsmBuildingsAsync().then((b) => v.scene.primitives.add(b));

  // 서울 중구로 초기 뷰 이동
  v.camera.flyTo({
    destination: Cesium.Cartesian3.fromDegrees(126.9978, 37.5636, 2000),
    orientation: {
      heading: 0,
      pitch: Cesium.Math.toRadians(-45),
      roll: 0,
    },
  });

  // (선택) 서울 3D 타일셋
  Cesium.Cesium3DTileset.fromIonAssetId(75343, {})
    .then((tileset) => v.scene.primitives.add(tileset))
    .catch(() => console.warn("서울 3D 타일셋 로드 실패"));
}

function handleMoveTo({ lon, lat }: { lon: number; lat: number }) {
  const v = viewer.value;
  if (!v) return;
  v.camera.flyTo({
    destination: Cesium.Cartesian3.fromDegrees(lon, lat, 2000),
    orientation: {
      heading: 0,
      pitch: Cesium.Math.toRadians(-45),
      roll: 0,
    },
  });
}
</script>
