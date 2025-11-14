<template>
  <div id="cesiumContainer"></div>
</template>

<script setup lang="ts">
import { onMounted, onBeforeUnmount, defineEmits, defineExpose } from "vue";
import * as Cesium from "cesium";
import "./3DMap.css";

let viewer: Cesium.Viewer | null = null;
const emit = defineEmits(["ready"]);

function initCesium() {
  Cesium.Ion.defaultAccessToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJqdGkiOiJhNjdkYmUyZi00MWE2LTQ4NmYtYmUyOC1iMjIyY2I3ZjM3MjEiLCJpZCI6MzYwMzE0LCJpYXQiOjE3NjMxMDIwNDN9._3ffQkyAs8iESSYsShZcssDdLoHZUym2OB28Xnhs_n0";

  viewer = new Cesium.Viewer("cesiumContainer", {
    terrain: Cesium.Terrain.fromWorldTerrain(),
    baseLayerPicker: false,
    animation: false,
    timeline: false,
    geocoder: false,
    homeButton: false,
    sceneModePicker: false,
    fullscreenButton: true,
  });

  // 기본 지도
  viewer.imageryLayers.addImageryProvider(
    new Cesium.OpenStreetMapImageryProvider({ url: "https://a.tile.openstreetmap.org/" })
  );

  // 준비 완료 이벤트
  emit("ready", viewer);
}

function destroyCesium() {
  if (viewer && !viewer.isDestroyed()) viewer.destroy();
}

defineExpose({ viewer });

onMounted(initCesium);
onBeforeUnmount(destroyCesium);
</script>
