# chacha-jarvis-embeded-ai-training-tfjs

tensorflow.js 파일을 커스텀 러닝 시키기위해 

여러 버전의 "헤이, 스텔라"의 멘트가 들어가는 음성 (wav)파일 노이즈, 피치, 톤 다양하게 100개 생성 및 러닝 시키는 툴

(러닝 모델의 인식률이 좋지 않아서 현재는 미사용)

python3 와 nodejs를 사용한다. 

python3 툴을 이용해 tensorflow 커스텀 러닝 모델을 생성

'model.h5'

해당 모델을 js파일로 변환.


# bash
```
python3 --version

```

tensorfolwjs는 python 12를 현재 지원하지 않는다.

brew install python@3.9

python3.9 -m venv venv

# venv (for MacOs)
```
python3 -m venv venv

-- 활성화

source new-venv/bin/activate
source venv/bin/activate

-- 비활성화 

deactivate

```

# 1. install requirments
```
pip3 install -r requirements.txt
```

# 2. run
```

python3 ./src/gen-tts-wavfiles.py

output => text "hey, jarvis"를 음성 (wav)파일 노이즈, 피치, 톤 다양하게 100개 생성

```





```

python3 ./src/generate_and_train.py

output => text "hey, jarvis"를 음성 (wav)파일 노이즈, 피치, 톤 다양하게 100개 생성, model 학습 10회, ./saved_model/jarvis_model 경로에 학습 모델 output 출력


tensorflowjs_converter --input_format=tf_saved_model --output_format=tfjs_graph_model ./saved_model/jarvis_model ./tfjs_model/graph_model



python3 ./src/convert_saved_to_keras.py

tensorflowjs_converter --input_format=tf_saved_model --output_format=tfjs_layers_model ./saved_model/jarvis_model ./tfjs_model/layers_model

python3 ./src/convert.py

```

# TensorFlow 모델을 TensorFlow.js 모델로 변환하기

# nodejs setup
```
node -v
v16.20.2

npm -v
8.19.4

npm init -y

(venv 활성화되야 함 python 필요.)
npm install @tensorflow/tfjs-node 



sudo npm install -g @tensorflow/tfjs

npm install --save-dev @tensorflow/tfjs-converter

sudo npm install -g @tensorflow/tfjs-converter

npm install --save-dev @tensorflow/tfjs @tensorflow/tfjs-node

sudo npm install -g @tensorflow/tfjs

npm install @tensorflow/tfjs






npx tensorflowjs_converter --input_format=keras stella_model.h5 stella_model_tfjs

```



```
tensorflowjs_converter --input_format=keras --output_format=tfjs_graph_model stella_model.keras ./tfjs_model


tensorflowjs_converter --input_format=keras --output_format=tfjs_graph_model stella_model.h5 ./tfjs_model


```



1. 음성 파일 전처리
음성 파일을 TensorFlow에서 사용할 수 있는 형태로 변환해야 합니다. 일반적으로 음성 파일을 2D 스펙트로그램 형태로 변환한 후, TensorFlow 모델에 입력으로 사용합니다.

2. 모델 훈련
TensorFlow를 사용하여 음성 인식 모델을 훈련시키는 방법을 설명합니다.

1. 음성 데이터 생성 및 전처리
기존의 음성 파일 생성 코드를 사용하고, 음성 파일을 스펙트로그램으로 변환하여 TensorFlow 모델에 입력할 수 있는 형태로 변환합니다.

2. 모델 훈련 코드
다음 코드는 TensorFlow를 사용하여 음성 데이터로 모델을 학습시키는 방법을 설명합니다. 스펙트로그램을 텐서로 변환하여 모델을 훈련시킵니다.




--- test training/browser-fft
https://github.com/tensorflow/tfjs-models/blob/master/speech-commands/training/browser-fft/training_custom_audio_model_in_python.ipynb

curl -o ./tmp/tfjs-sc-model/metadata.json -fsSL https://storage.googleapis.com/tfjs-models/tfjs/speech-commands/v0.3/browser_fft/18w/metadata.json

curl -o ./tmp/tfjs-sc-model/model.json -fsSL https://storage.googleapis.com/tfjs-models/tfjs/speech-commands/v0.3/browser_fft/18w/model.json

curl -o ./tmp/tfjs-sc-model/group1-shard1of2 -fSsL https://storage.googleapis.com/tfjs-models/tfjs/speech-commands/v0.3/browser_fft/18w/group1-shard1of2

curl -o ./tmp/tfjs-sc-model/group1-shard2of2 -fsSL https://storage.googleapis.com/tfjs-models/tfjs/speech-commands/v0.3/browser_fft/18w/group1-shard2of2

curl -o ./tmp/tfjs-sc-model/sc_preproc_model.tar.gz -fSsL https://storage.googleapis.com/tfjs-models/tfjs/speech-commands/conversion/sc_preproc_model.tar.gz

cd tmp/tfjs-sc-model

tar xzvf sc_preproc_model.tar.gz

-- output
x sc_preproc_model/
x sc_preproc_model/assets/
x sc_preproc_model/variables/
x sc_preproc_model/variables/variables.data-00000-of-00001
x sc_preproc_model/variables/variables.index
x sc_preproc_model/saved_model.pb

cd ..
mkdir -p tmp/speech_commands_v0.02 

cd ..
curl -o tmp/speech_commands_v0.02/speech_commands_v0.02.tar.gz -fSsL http://download.tensorflow.org/data/speech_commands_v0.02.tar.gz

cd  ./tmp/speech_commands_v0.02 && tar xzf speech_commands_v0.02.tar.gz

# Load the preprocessing model, which transforms audio waveform into 
# spectrograms (2D image-like representation of sound).
# This preprocessing model replicates WebAudio's AnalyzerNode.getFloatFrequencyData
# (https://developer.mozilla.org/en-US/docs/Web/API/AnalyserNode/getFloatFrequencyData).
# It performs short-time Fourier transform (STFT) using a length-2048 Blackman
# window. It opeartes on mono audio at the 44100-Hz sample rate.

