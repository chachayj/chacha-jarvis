import os
import numpy as np
import librosa
import tensorflow as tf
from gtts import gTTS
from scipy.io.wavfile import write
import subprocess
from keras.saving import save_model



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

# WAV 파일을 스펙트로그램으로 변환
def audio_to_spectrogram(audio_path):
    y, sr = librosa.load(audio_path, sr=16000)  # 샘플링 레이트 16kHz
    spectrogram = librosa.feature.melspectrogram(y=y, sr=sr, n_mels=64, fmax=8000)
    log_spectrogram = np.log(spectrogram + 1e-9)  # 스펙트로그램을 로그 스케일로 변환
    return log_spectrogram

# 데이터 전처리 및 저장
text = "자비스"
base_audio_path = "jarvis_base.wav"
output_folder = "augmented_audio"

# 기본 음성 파일 생성
generate_text_to_speech(text, base_audio_path)

# 기본 음성 파일 로드
y, sr = librosa.load(base_audio_path, sr=None)

# 출력 폴더 생성
if not os.path.exists(output_folder):
    os.makedirs(output_folder)

# 음성 파일 생성 및 변형
for i in range(100):  # 100개의 음성 파일 생성
    file_name = f"{output_folder}/jarvis_{i}.wav"
    
    # 노이즈 추가
    noisy_samples = add_noise(y) if i % 2 == 0 else y
    
    # 피치 조정
    pitch_factor = np.random.uniform(-2, 2)  # -2에서 2까지 랜덤 피치 조정
    pitched_samples = change_pitch(noisy_samples, sr, pitch_factor)
    
    # 파일 저장
    save_as_wav(pitched_samples, sr, file_name)
    print(f"Saved {file_name}")

print("모든 음성 파일 생성 완료")

# 스펙트로그램으로 변환
spectrograms = []
for i in range(100):
    audio_path = f"{output_folder}/jarvis_{i}.wav"
    spectrogram = audio_to_spectrogram(audio_path)
    spectrograms.append(spectrogram)

# 스펙트로그램을 텐서로 변환
X = np.array(spectrograms)
y = np.ones(len(X))  # 레이블 (여기서는 단일 클래스를 가정)

# 데이터 차원 조정
X = np.expand_dims(X, axis=-1)  # (num_samples, height, width, channels)
X = X / np.max(X)  # 정규화

# # 모델 정의 h5

# model = tf.keras.Sequential([
#     tf.keras.layers.Input(shape=(X.shape[1], X.shape[2], 1)),  # Input 레이어로 변경
#     tf.keras.layers.Conv2D(32, (3, 3), activation='relu'),
#     tf.keras.layers.MaxPooling2D((2, 2)),
#     tf.keras.layers.Conv2D(64, (3, 3), activation='relu'),
#     tf.keras.layers.MaxPooling2D((2, 2)),
#     tf.keras.layers.Conv2D(128, (3, 3), activation='relu'),
#     tf.keras.layers.MaxPooling2D((2, 2)),
#     tf.keras.layers.Flatten(),
#     tf.keras.layers.Dense(128, activation='relu'),
#     tf.keras.layers.Dense(1, activation='sigmoid')  # Binary classification
# ])

# 모델 정의 (예시로 간단한 모델을 사용)
model = tf.keras.Sequential([
    tf.keras.layers.Input(shape=(64, 64, 1)),
    tf.keras.layers.Conv2D(32, (3, 3), activation='relu'),
    tf.keras.layers.MaxPooling2D((2, 2)),
    tf.keras.layers.Conv2D(64, (3, 3), activation='relu'),
    tf.keras.layers.MaxPooling2D((2, 2)),
    tf.keras.layers.Conv2D(128, (3, 3), activation='relu'),
    tf.keras.layers.MaxPooling2D((2, 2)),
    tf.keras.layers.Flatten(),
    tf.keras.layers.Dense(128, activation='relu'),
    tf.keras.layers.Dense(1, activation='sigmoid')
])

# 모델 컴파일
model.compile(optimizer='adam', loss='binary_crossentropy', metrics=['accuracy'])

# 모델 학습
model.fit(X, y, epochs=10, batch_size=16, validation_split=0.2)

# 모델을 HDF5 형식으로 저장
# model.save('tfjs_model/keras_model/jarvis_model.h5')

# 모델을 Keras 형식으로 저장
save_model(model, 'tfjs_model/keras_model/jarvis_model.keras')

# model.save('tfjs_model/keras_model/jarvis_model.keras')  # .keras 형식으로 저장할 경우 주석 해제

print("모델을 HDF5 형식으로 저장했습니다.")

base_dir = os.path.dirname(__file__)
# TensorFlow.js 모델로 변환
tfjs_model_path = os.path.join(base_dir, '../tfjs_model/layers_model')
# keras_model_path = os.path.join(base_dir, '../tfjs_model/keras_model/jarvis_model.h5')
keras_model_path = os.path.join(base_dir, '../tfjs_model/keras_model/jarvis_model.keras')  # .keras로 변경할 경우 주석 해제

# 모델 로드
loaded_model = tf.keras.models.load_model(keras_model_path)
print("모델이 성공적으로 로드되었습니다.")

loaded_model.summary()


import h5py

# HDF5 파일 내용 확인
try:
    # with h5py.File('tfjs_model/keras_model/jarvis_model.h5', 'r') as f:
    with h5py.File('tfjs_model/keras_model/jarvis_model.keras', 'r') as f:
        print("HDF5 file content:")
        for key in f.keys():
            print(key)
except Exception as e:
    print(f"Error: {e}")



# # 변환 명령어 실행
subprocess.run([
    'tensorflowjs_converter',
    '--input_format=keras',
    '--output_format=tfjs_layers_model',
    keras_model_path,
    tfjs_model_path
], check=True)

print("Conversion to TensorFlow.js format completed.")