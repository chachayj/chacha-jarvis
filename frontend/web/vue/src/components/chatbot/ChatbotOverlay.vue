<template>
  <div class="chatbot-overlay">
    <button :disabled="isRecording" @click="recordAudio">
      <template v-if="!isRecording">🎙️ 3초 녹음</template>
      <template v-else>🔴 녹음 중...</template>
      <span v-if="isRecording" class="spinner"></span>
    </button>

    <!-- 마이크 없이 쓰는 텍스트 입력 -->
    <div class="text-row">
      <input
        v-model="textInput"
        type="text"
        placeholder="명령을 입력하세요 (예: 불 켜줘)"
        autocomplete="off"
        :disabled="isBusy"
        @keydown.enter="submitText"
      />
      <button :disabled="isBusy" @click="submitText">⌨️ 전송</button>
    </div>
    <div class="presets">
      <button v-for="p in PRESETS" :key="p" :disabled="isBusy" @click="runPreset(p)">
        {{ p }}
      </button>
    </div>

    <ChatStatus :message="status" />
    <ChatSay :text="say" />
    <ChatLog :lines="logs" />
    <audio ref="player" controls style="margin-top:10px;width:100%"></audio>
  </div>
</template>

<script setup lang="ts">
import { ref } from "vue";
import ChatStatus from "./ChatStatus.vue";
import ChatSay from "./ChatSay.vue";
import ChatLog from "./ChatLog.vue";
import * as Cesium from "cesium";
import "./Chatbot.css";

const props = defineProps<{ viewer?: Cesium.Viewer | null }>();
const emit = defineEmits<{
  moveTo: [
    {
      lon: number;
      lat: number;
      label?: string;
      provinceCode?: string;
      districtCode?: string;
    },
  ];
}>();

/**
 * 이동 명령이 가리키는 실제 행정동.
 * 좌표는 spring 의 행정구역 API 에서 조회하고, 실패하면 아래 값으로 대체한다.
 * (fallback 좌표는 2026-09-06 기준 API 응답값)
 */
const MOVE_TARGETS: Record<
  string,
  { provinceCode: string; districtCode: string; dong: string; lon: number; lat: number }
> = {
  "move-forward": {
    provinceCode: "KR-SEOUL",
    districtCode: "KR-SEOUL-SEOCHOGU",
    dong: "반포2동",
    lon: 126.99594499419572,
    lat: 37.5076722,
  },
  "move-backward": {
    provinceCode: "KR-INCHEON",
    districtCode: "KR-INCHEON-JUNGGU",
    dong: "운서동",
    lon: 126.44000761647095,
    lat: 37.4728904,
  },
};

/** 행정구역 API 에서 동 좌표를 찾는다. 실패하면 fallback 좌표를 쓴다. */
async function resolveTarget(key: string) {
  const t = MOVE_TARGETS[key];
  if (!t) return null;
  try {
    const res = await fetch(
      `/administrative/districts/centers?districtCode=${encodeURIComponent(t.districtCode)}`,
    );
    if (res.ok) {
      const data = await res.json();
      const hit = (data?.centers ?? []).find((c: any) => c.name === t.dong);
      if (hit?.longitude != null && hit?.latitude != null) {
        return {
          lon: hit.longitude,
          lat: hit.latitude,
          label: t.dong,
          provinceCode: hit.provinceCode ?? t.provinceCode,
          districtCode: t.districtCode,
        };
      }
    }
    log("ℹ️ 행정구역 API 조회 실패 — 기본 좌표 사용");
  } catch {
    log("ℹ️ 행정구역 API 연결 실패 — 기본 좌표 사용");
  }
  return {
    lon: t.lon,
    lat: t.lat,
    label: t.dong,
    provinceCode: t.provinceCode,
    districtCode: t.districtCode,
  };
}

const logs = ref<string[]>([]);
const say = ref("");
const status = ref("");
const isRecording = ref(false);
const isBusy = ref(false);
const textInput = ref("");
const player = ref<HTMLAudioElement | null>(null);

const PRESETS = ["불 켜줘", "불 꺼줘", "전진", "후진", "오늘 날씨"];

const log = (msg: string) => logs.value.push(msg);
const setStatus = (msg?: string) => (status.value = msg || "");

async function recordAudio() {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    const rec = new MediaRecorder(stream, { mimeType: "audio/webm" });
    const chunks: BlobPart[] = [];
    rec.ondataavailable = (e) => e.data.size && chunks.push(e.data);

    isRecording.value = true;
    setStatus("🎤 사용자 음성 녹음 중...");
    log("녹음 시작");

    rec.onstop = async () => {
      const blob = new Blob(chunks, { type: "audio/webm" });
      await processAudio(blob);
      isRecording.value = false;
    };

    rec.start();
    setTimeout(() => rec.stop(), 3000);
  } catch (e: any) {
    log("❌ 마이크 오류: " + e.message);
    setStatus("❌ 마이크 권한 거부됨");
  }
}

// --- 텍스트 입력 진입점 ---
async function submitText() {
  const text = textInput.value.trim();
  if (!text || isBusy.value) return;
  isBusy.value = true;
  try {
    await runPipeline(text);
    textInput.value = "";
  } finally {
    isBusy.value = false;
  }
}

function runPreset(preset: string) {
  textInput.value = preset;
  submitText();
}

// --- FastAPI 서버 호출 ---
async function processAudio(blob: Blob) {
  try {
    setStatus("🔄 음성 인식(STT) 중...");
    const fd = new FormData();
    fd.append("audio", blob, "korean.webm");
    const sttRes = await fetch("/chatbot/stt", { method: "POST", body: fd });
    const stt = await sttRes.json();
    log("STT: " + (stt.text || ""));

    // 이후는 텍스트 입력과 완전히 동일한 경로다
    await runPipeline(stt.text || "");
  } catch (e: any) {
    log("❌ 처리 실패: " + e.message);
    setStatus("❌ 오류 발생");
  }
}

/** 텍스트 한 문장을 NLU -> Action -> (지도 반응) -> TTS 파이프라인에 태운다. */
async function runPipeline(text: string) {
  if (!text) {
    log("⚠️ 입력이 비어 있습니다.");
    return;
  }
  try {
    log("입력: " + text);
    setStatus("🤔 의미 분석(NLU) 중...");
    const nluRes = await fetch("/chatbot/nlu", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ text }),
    });
    const nlu = await nluRes.json();
    log("NLU: " + JSON.stringify(nlu));

    setStatus("⚙️ 명령 실행(Action) 중...");
    const actRes = await fetch("/chatbot/action", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(nlu),
    });
    const act = await actRes.json();
    log("ACTION: " + JSON.stringify(act.result));

    // ✅ 지도 반응 로직
    // 응답 형태: { result: { chatbot: { action: "light-on" }, robot: {...} }, say: "..." }
    const mapAction = act.result?.chatbot?.action ?? act.result?.action;
    if (props.viewer && mapAction) {
      await handleMapAction(props.viewer, mapAction);
    }

    // ✅ 챗봇 음성 응답
    if (act.say) {
      say.value = "🤖 " + act.say;
      setStatus("🗣️ 음성 응답 생성(TTS) 중...");

      const ttsRes = await fetch(`/chatbot/tts?text=${encodeURIComponent(act.say)}`);
      const tts = await ttsRes.json();
      if (tts.ok && tts.url && player.value) {
        player.value.src = tts.url;
        // 자동재생이 브라우저 정책에 막혀도 파이프라인 자체는 성공으로 본다
        try {
          await player.value.play();
        } catch {
          log("ℹ️ 자동재생 차단됨 — 재생 버튼을 눌러주세요");
        }
        setStatus("✅ 완료! 음성 재생 중...");
        player.value.onended = () => setStatus("");
      }
    }
  } catch (e: any) {
    log("❌ 처리 실패: " + e.message);
    setStatus("❌ 오류 발생");
  }
}

// 🧭 지도 반응 로직
async function handleMapAction(viewer: Cesium.Viewer, action: string) {
  switch (action) {
    // 전진/후진은 카메라를 앞뒤로 미는 대신 지정된 행정동으로 이동시킨다.
    case "move-forward":
    case "move-backward": {
      const target = await resolveTarget(action);
      if (!target) break;
      log(`🧭 지도 이동: ${target.label}`);
      emit("moveTo", target);
      break;
    }
    case "light-on":
      viewer.scene.light.intensity = 1.5;
      break;
    case "light-off":
      viewer.scene.light.intensity = 0.2;
      break;
    default:
      console.log("Unhandled action:", action);
  }
}
</script>
