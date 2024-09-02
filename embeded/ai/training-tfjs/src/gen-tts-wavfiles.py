import os
import numpy as np
import librosa
from gtts import gTTS
from scipy.io.wavfile import write

# 기본 텍스트 음성 생성
def generate_text_to_speech(text, file_path):
    tts = gTTS(text=text, lang='ko')
    tts.save(file_path)

# 노이즈 추가
def add_noise(samples, noise_level=0.005):
    noise = np.random.normal(0, noise_level, len(samples))
    noisy_samples = samples + noise
    return np.clip(noisy_samples, -1.0, 1.0)  # 데이터 범위 클리핑

# 피치 조정
def change_pitch(samples, sr, pitch_factor):
    return librosa.effects.pitch_shift(samples, sr=sr, n_steps=pitch_factor)

# WAV 파일 저장
def save_as_wav(samples, sr, file_path):
    # 16-bit PCM WAV 파일로 저장
    scaled_samples = np.int16(samples / np.max(np.abs(samples)) * 32767)  # -32767 ~ 32767 범위로 스케일링
    write(file_path, sr, scaled_samples)

# 텍스트와 파일 경로 설정
texts = {
    "jarvis": "자비스",
    "annyeong": "안녕",
    "hey": "헤이"
}

base_audio_paths = {text: f"{text}_base.wav" for text in texts}
output_folder = "augmented_audio"

# 기본 음성 파일 생성
for text, path in base_audio_paths.items():
    generate_text_to_speech(texts[text], path)

# 출력 폴더 생성
if not os.path.exists(output_folder):
    os.makedirs(output_folder)

# 음성 파일 생성 및 변형
for text, base_path in base_audio_paths.items():
    y, sr = librosa.load(base_path, sr=None)
    for i in range(100):  # 각 텍스트별로 100개의 음성 파일 생성
        file_name = f"{output_folder}/{text}_{i}.wav"
        
        # 노이즈 추가
        noisy_samples = add_noise(y) if i % 2 == 0 else y
        
        # 피치 조정
        pitch_factor = np.random.uniform(-2, 2)  # -2에서 2까지 랜덤 피치 조정
        pitched_samples = change_pitch(noisy_samples, sr, pitch_factor)
        
        # 파일 저장
        save_as_wav(pitched_samples, sr, file_name)
        print(f"Saved {file_name}")

# 잡음 파일 생성
for i in range(100):  # 100개의 잡음 파일 생성
    noise = np.random.normal(0, 0.005, 16000)  # 1초 길이의 잡음 생성
    file_name = f"{output_folder}/noise_{i}.wav"
    save_as_wav(noise, 16000, file_name)
    print(f"Saved {file_name}")

print("모든 음성 파일 생성 완료")
