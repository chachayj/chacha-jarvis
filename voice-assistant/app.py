import os, io, uuid, json
from fastapi import FastAPI, UploadFile, File, Query
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
import requests

OLLAMA_URL = os.getenv("OLLAMA_URL", "http://localhost:11434")
LLM_MODEL  = os.getenv("LLM_MODEL", "llama3.1:8b")
TTS_VOICE_PATH = os.getenv("TTS_VOICE_PATH", "/app/models/ko-KR.onnx")
TTS_VOICE_JSON = os.getenv("TTS_VOICE_JSON", "/app/models/ko-KR.onnx.json")

WHISPER_MODEL = os.getenv("WHISPER_MODEL", "small")
WHISPER_DEVICE = os.getenv("WHISPER_DEVICE", "cpu")
WHISPER_COMPUTE = os.getenv("WHISPER_COMPUTE", "int8")

app = FastAPI(title="Korean Voice Assistant")
app.mount("/static", StaticFiles(directory="static"), name="static")

@app.get("/")
def home():
    return FileResponse("static/index.html")

stt_model = None
def get_stt_model():
    global stt_model
    if stt_model is not None:
        return stt_model
    from faster_whisper import WhisperModel
    for ct in [WHISPER_COMPUTE, "int8", "float32"]:
        try:
            stt_model = WhisperModel(WHISPER_MODEL, device=WHISPER_DEVICE, compute_type=ct)
            print(f"[STT] Loaded {WHISPER_MODEL} on {WHISPER_DEVICE} ({ct})")
            return stt_model
        except Exception as e:
            print("[STT] load failed:", ct, e)
    raise RuntimeError("Whisper load failed")

from piper.voice import PiperVoice
tts_voice = None
try:
    if os.path.exists(TTS_VOICE_PATH) and os.path.exists(TTS_VOICE_JSON):
        tts_voice = PiperVoice.load(TTS_VOICE_PATH, TTS_VOICE_JSON)
        print("[TTS] Piper voice loaded.")
except Exception as e:
    print("[TTS] Piper voice load failed:", e)

AUDIO_DIR = "/app/data/tts"

class NLURequest(BaseModel):
    text: str

class ActionRequest(BaseModel):
    intent: str
    params: dict | None = None

@app.post("/stt")
async def stt_endpoint(audio: UploadFile = File(...)):
    model = get_stt_model()
    initial_prompt = "전진 후진 불켜 불꺼 오늘 날씨 지금 날씨 좌회전 우회전"
    content = await audio.read()
    tmp = f"/tmp/{uuid.uuid4().hex}.webm"
    with open(tmp, "wb") as f:
        f.write(content)
    segments, info = model.transcribe(
        tmp, language="ko", beam_size=1, vad_filter=True, initial_prompt=initial_prompt
    )
    text = " ".join([s.text.strip() for s in segments]).strip()
    return {"text": text}

@app.post("/nlu")
def nlu_endpoint(req: NLURequest):
    prompt = f"""
아래 한국어 발화를 지정된 JSON 스키마로만 분석해서 내보내.
설명/여분 텍스트 없이 JSON만 출력해.

스키마:
{{
  "intent": "MOVE | LIGHT | WEATHER",
  "params": {{
    "direction": "forward | backward | null",
    "power": "on | off | null",
    "timeframe": "today | now | null"
  }}
}}

규칙:
- 발화에 맞는 intent 하나만 선택.
- MOVE는 direction만, LIGHT는 power만, WEATHER는 timeframe만 채워.
- 값이 없으면 null.

발화: "{req.text}"
"""
    r = requests.post(f"{OLLAMA_URL}/voice-assistant/generate", json={
        "model": LLM_MODEL, "format": "json", "prompt": prompt
    }, timeout=120)
    r.raise_for_status()
    out = r.json().get("response", "")
    data = json.loads(out) if out else {}
    return data

def do_move(direction: str):
    return {"ok": True, "action": f"move-{direction}"}

def do_light(power: str):
    return {"ok": True, "action": f"light-{power}"}

def do_weather(timeframe: str):
    return {"ok": True, "timeframe": timeframe, "summary": "맑음, 23°C"}

@app.post("/action")
def action_endpoint(req: ActionRequest):
    intent = (req.intent or "").upper()
    p = req.params or {}
    if intent == "MOVE":
        direction = p.get("direction")
        assert direction in ("forward","backward")
        result = do_move(direction)
        say = "전진합니다." if direction=="forward" else "후진합니다."
        return {"result": result, "say": say}
    elif intent == "LIGHT":
        power = p.get("power")
        assert power in ("on","off")
        result = do_light(power)
        say = "불을 켭니다." if power=="on" else "불을 끕니다."
        return {"result": result, "say": say}
    elif intent == "WEATHER":
        timeframe = p.get("timeframe", "now")
        assert timeframe in ("today","now")
        result = do_weather(timeframe)
        say = f"{('오늘' if timeframe=='today' else '지금')} 날씨는 {result['summary']} 입니다."
        return {"result": result, "say": say}
    else:
        return JSONResponse(status_code=400, content={"ok": False, "message": "지원하지 않는 명령"})

@app.get("/tts")
def tts_endpoint(text: str = Query(..., min_length=1, max_length=500)):
    if not tts_voice:
        return JSONResponse(status_code=503, content={"ok": False, "message": "TTS 보이스가 준비되지 않았습니다."})
    os.makedirs(AUDIO_DIR, exist_ok=True)
    outfile = os.path.join(AUDIO_DIR, f"{uuid.uuid4().hex}.wav")
    with open(outfile, "wb") as f:
        for audio_bytes in tts_voice.synthesize_stream_raw(text):
            f.write(audio_bytes)
    return {"ok": True, "url": f"/audio/{os.path.basename(outfile)}"}

@app.get("/audio/{fname}")
def get_audio(fname: str):
    path = os.path.join(AUDIO_DIR, fname)
    return FileResponse(path, media_type="audio/wav")

@app.get("/healthz")
def healthz():
    return {"ok": True}
