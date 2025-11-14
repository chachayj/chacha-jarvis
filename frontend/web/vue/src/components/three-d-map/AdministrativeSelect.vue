<template>
  <div class="controls">
    <select v-model="selected.sido" @change="onChangeSido">
      <option value="">시/도 선택</option>
      <option v-for="item in sidoList" :key="item.code" :value="item.code">{{ item.name }}</option>
    </select>

    <select v-model="selected.gugun" @change="onChangeGugun" :disabled="!selected.sido">
      <option value="">구 선택</option>
      <option v-for="item in gugunList" :key="item.code" :value="item.code">{{ item.name }}</option>
    </select>

    <select v-model="selected.dong" @change="onSelectDong" :disabled="!selected.gugun">
      <option value="">동 선택</option>
      <option v-for="item in dongList" :key="item.code" :value="item.code">{{ item.name }}</option>
    </select>
  </div>
</template>

<script setup lang="ts">
import { reactive, ref } from "vue";

const emit = defineEmits(["moveTo"]);

const selected = reactive({
  sido: "",
  gugun: "",
  dong: "",
});

const sidoList = ref<any[]>([]);
const gugunList = ref<any[]>([]);
const dongList = ref<any[]>([]);

const API_BASE = "https://your-osm-api.example.com/osm";

async function fetchJson(url: string) {
  const res = await fetch(url);
  return res.ok ? res.json() : [];
}

async function loadSido() {
  sidoList.value = await fetchJson(`${API_BASE}/sido`);
}
async function onChangeSido() {
  gugunList.value = await fetchJson(`${API_BASE}/gugun?sido=${selected.sido}`);
  dongList.value = [];
  selected.gugun = "";
  selected.dong = "";
}
async function onChangeGugun() {
  dongList.value = await fetchJson(`${API_BASE}/dong?gugun=${selected.gugun}`);
  selected.dong = "";
}
async function onSelectDong() {
  const data = await fetchJson(`${API_BASE}/coord?dong=${selected.dong}`);
  if (data?.lon && data?.lat) {
    emit("moveTo", { lon: data.lon, lat: data.lat });
  }
}

loadSido();
</script>
