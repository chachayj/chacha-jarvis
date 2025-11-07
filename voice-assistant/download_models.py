import os
from huggingface_hub import hf_hub_download

TARGET_DIR = "/app/models"
os.makedirs(TARGET_DIR, exist_ok=True)

REPO_ID = "neurlang/piper-onnx-kss-korean"
ONNX_FN = "piper-kss-korean.onnx"
JSON_FN = "piper-kss-korean.onnx.json"

onnx_path = hf_hub_download(repo_id=REPO_ID, filename=ONNX_FN, local_dir=TARGET_DIR)
json_path = hf_hub_download(repo_id=REPO_ID, filename=JSON_FN, local_dir=TARGET_DIR)

dst_onnx = os.path.join(TARGET_DIR, "ko-KR.onnx")
dst_json = os.path.join(TARGET_DIR, "ko-KR.onnx.json")

if os.path.abspath(onnx_path) != os.path.abspath(dst_onnx):
    if os.path.exists(dst_onnx):
        os.remove(dst_onnx)
    os.rename(onnx_path, dst_onnx)

if os.path.abspath(json_path) != os.path.abspath(dst_json):
    if os.path.exists(dst_json):
        os.remove(dst_json)
    os.rename(json_path, dst_json)

print("✅ Piper Korean voice downloaded to /app/models")
