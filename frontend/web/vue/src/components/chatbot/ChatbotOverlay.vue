<template>
  <div class="chatbot-overlay">
    <button :disabled="isRecording" @click="recordAudio">
      <template v-if="!isRecording">🎙️ 3초 녹음</template>
      <template v-else>🔴 녹음 중...</template>
      <span v-if="isRecording" class="spinner"></span>
    </button>

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

const logs = ref<string[]>([]);
const say = ref("");
const status = ref("");
const isRecording = ref(false);
const player = ref<HTMLAudioElement | null>(null);

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

// --- FastAPI 서버 호출 ---
async function processAudio(blob: Blob) {
  try {
    setStatus("🔄 음성 인식(STT) 중...");
    const fd = new FormData();
    fd.append("audio", blob, "korean.webm");
    const sttRes = await fetch("/chatbot/stt", { method: "POST", body: fd });
    const stt = await sttRes.json();
    log("STT: " + (stt.text || ""));

    setStatus("🤔 의미 분석(NLU) 중...");
    const nluRes = await fetch("/chatbot/nlu", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ text: stt.text || "" }),
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
    if (props.viewer && act.result?.action) {
      handleMapAction(props.viewer, act.result.action);
    }

    // ✅ 챗봇 음성 응답
    if (act.say) {
      say.value = "🤖 " + act.say;
      setStatus("🗣️ 음성 응답 생성(TTS) 중...");

      const ttsRes = await fetch(`/chatbot/tts?text=${encodeURIComponent(act.say)}`);
      const tts = await ttsRes.json();
      if (tts.ok && tts.url && player.value) {
        player.value.src = tts.url;
        await player.value.play();
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
function handleMapAction(viewer: Cesium.Viewer, action: string) {
  switch (action) {
    case "move-forward":
      viewer.camera.moveForward(500);
      break;
    case "move-backward":
      viewer.camera.moveBackward(500);
      break;
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
