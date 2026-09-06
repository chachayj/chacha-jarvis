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
      <option value="">{{ dongList.length ? "동 선택" : "동 데이터 없음" }}</option>
      <option v-for="item in dongList" :key="item.code" :value="item.code">{{ item.name }}</option>
    </select>

    <span v-if="error" class="controls-error">{{ error }}</span>
  </div>
</template>

<script setup lang="ts">
import { reactive, ref } from "vue";

const props = withDefaults(defineProps<{ countryCode?: string }>(), {
  countryCode: "KR",
});

const emit = defineEmits(["moveTo"]);

/**
 * spring-server(:8081) 의 행정구역 API.
 * 상대경로로 호출한다 — vite dev server(5173) 와 nginx(8443) 가 모두
 * /administrative/* 를 spring 으로 프록시하므로 두 진입점에서 동일하게 동작한다.
 */
const API_BASE = "/administrative";

type Option = { code: string; name: string; lon?: number; lat?: number };

const selected = reactive({
  sido: "",
  gugun: "",
  dong: "",
});

const sidoList = ref<Option[]>([]);
const gugunList = ref<Option[]>([]);
const dongList = ref<Option[]>([]);
const error = ref("");

async function fetchJson<T>(url: string): Promise<T | null> {
  try {
    const res = await fetch(url);
    if (!res.ok) {
      error.value = `조회 실패 (${res.status})`;
      return null;
    }
    error.value = "";
    return (await res.json()) as T;
  } catch (e) {
    error.value = "행정구역 API 에 연결할 수 없습니다";
    console.error("[AdministrativeSelect]", url, e);
    return null;
  }
}

/** 시/도: GET /administrative/provinces?countryCode=KR */
async function loadSido() {
  const data = await fetchJson<{ provinces?: { provinceCode: string; provinceName: string }[] }>(
    `${API_BASE}/provinces?countryCode=${encodeURIComponent(props.countryCode)}`,
  );
  sidoList.value = (data?.provinces ?? []).map((p) => ({
    code: p.provinceCode,
    name: p.provinceName,
  }));
}

/** 구: GET /administrative/districts?provinceCode=KR-SEOUL */
async function onChangeSido() {
  gugunList.value = [];
  dongList.value = [];
  selected.gugun = "";
  selected.dong = "";
  if (!selected.sido) return;

  const data = await fetchJson<{ districts?: { districtCode: string; name: string }[] }>(
    `${API_BASE}/districts?provinceCode=${encodeURIComponent(selected.sido)}`,
  );
  gugunList.value = (data?.districts ?? []).map((d) => ({
    code: d.districtCode,
    name: d.name,
  }));
}

/**
 * 동: GET /administrative/districts/centers?districtCode=KR-SEOUL-SEOCHOGU
 * 응답의 centers 가 좌표(longitude/latitude)를 그대로 들고 있어 별도 좌표 조회가 없다.
 */
async function onChangeGugun() {
  dongList.value = [];
  selected.dong = "";
  if (!selected.gugun) return;

  const data = await fetchJson<{
    centers?: { osmId: number; name: string; longitude: number; latitude: number }[];
  }>(`${API_BASE}/districts/centers?districtCode=${encodeURIComponent(selected.gugun)}`);

  dongList.value = (data?.centers ?? []).map((c) => ({
    code: String(c.osmId),
    name: c.name,
    lon: c.longitude,
    lat: c.latitude,
  }));
}

function onSelectDong() {
  const hit = dongList.value.find((d) => d.code === selected.dong);
  if (hit?.lon != null && hit?.lat != null) {
    emit("moveTo", { lon: hit.lon, lat: hit.lat });
  }
}

loadSido();
</script>
