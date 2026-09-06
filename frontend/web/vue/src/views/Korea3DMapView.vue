<template>
  <div id="app-wrapper">
    <AdministrativeSelect ref="selectRef" @moveTo="handleMoveTo" />
    <ThreeDMap @ready="handleReady" />
    <ChatbotOverlay :viewer="viewer" @moveTo="handleMoveTo" />
  </div>
</template>

<script setup lang="ts">
import { ref } from "vue";
import * as Cesium from "cesium";
import ThreeDMap from "../components/three-d-map/3DMap.vue";
import AdministrativeSelect from "../components/three-d-map/AdministrativeSelect.vue";
import ChatbotOverlay from "../components/chatbot/ChatbotOverlay.vue";

const viewer = ref<Cesium.Viewer | null>(null);
const selectRef = ref<InstanceType<typeof AdministrativeSelect> | null>(null);

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

function handleMoveTo({
  lon,
  lat,
  label,
  provinceCode,
  districtCode,
}: {
  lon: number;
  lat: number;
  label?: string;
  provinceCode?: string;
  districtCode?: string;
}) {
  const v = viewer.value;
  if (!v) return;
  if (label) console.log(`[지도 이동] ${label} (${lon}, ${lat})`);

  // 챗봇이 이동시킨 경우엔 상단 셀렉트도 그 위치로 맞춘다.
  // 셀렉트 자신이 발생시킨 이벤트에는 코드가 없어 재귀 갱신이 일어나지 않는다.
  if (provinceCode && districtCode && label) {
    selectRef.value?.syncTo({ provinceCode, districtCode, dongName: label });
  }
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
