document.addEventListener('DOMContentLoaded', () => {
    document.getElementById('trainBtn').addEventListener('click', async () => {
        document.getElementById('status').innerText = 'WAV 파일을 로드 중입니다...';

        // 음성 파일 경로 설정
        const wavFiles = [];
        const labels = ["jarvis", "annyeong", "hey", "noise"];
        labels.forEach(label => {
            for (let i = 0; i < 99; i++) {
                wavFiles.push(`static/augmented_audio/${label}_${i}.wav`);
            }
        });

        try {
            const audioBuffers = await Promise.all(wavFiles.map(file => loadWavFile(file)));
            console.log("audioBuffers: ", audioBuffers);

            // Labels에 따라 데이터 준비
            const labelMap = {
                "jarvis": [1, 0, 0, 0],
                "annyeong": [0, 1, 0, 0],
                "hey": [0, 0, 1, 0],
                "noise": [0, 0, 0, 1]
            };
            const labelsData = wavFiles.map(file => {
                const label = file.split('/')[2].split('_')[0];
                return labelMap[label];
            });

            // 훈련 데이터와 테스트 데이터 분리
            const [trainAudioBuffers, testAudioBuffers] = splitData(audioBuffers, 0.8); // 80% 훈련, 20% 테스트
            const [trainLabelsData, testLabelsData] = splitData(labelsData, 0.8);

            const model = await createAndTrainModel(trainAudioBuffers, trainLabelsData);

            document.getElementById('status').innerText = '모델 훈련 완료!';

            // 모델 평가
            await evaluateModel(model, testAudioBuffers, testLabelsData);

            document.getElementById('startListeningBtn').disabled = false;
            window.trainedModel = model;
        } catch (error) {
            console.error("오류 발생:", error);
            document.getElementById('status').innerText = '오류가 발생했습니다.';
        }
    });

    document.getElementById('startListeningBtn').addEventListener('click', () => {
        startListening();
    });

    async function loadWavFile(filename) {
        const response = await fetch(filename);
        if (!response.ok) {
            throw new Error(`파일을 로드할 수 없습니다: ${filename}`);
        }
        const arrayBuffer = await response.arrayBuffer();
        const audioContext = new (window.AudioContext || window.webkitAudioContext)();
        return await audioContext.decodeAudioData(arrayBuffer);
    }

    async function createAndTrainModel(audioBuffers, labelsData) {
        const length = 16000; // 모델이 기대하는 입력 길이
        const processedAudioData = audioBuffers.map(buffer => processAudioBuffer(buffer));

        const trainXs = tf.tensor2d(processedAudioData);
        const trainYs = tf.tensor2d(labelsData);

        const model = tf.sequential();
        model.add(tf.layers.dense({units: 128, activation: 'relu', inputShape: [length]}));
        model.add(tf.layers.dense({units: 4, activation: 'softmax'})); // 4개의 클래스 (스텔라, 안녕, 헤이, 잡음)

        model.compile({
            optimizer: 'adam',
            loss: 'categoricalCrossentropy',
            metrics: ['accuracy']
        });

        await model.fit(trainXs, trainYs, {
            epochs: 10,
            batchSize: 32
        });

        return model;
    }

    function processAudioBuffer(audioBuffer) {
        const targetSampleRate = 16000; // 모델이 기대하는 샘플 레이트
        const channelData = audioBuffer.getChannelData(0);
        const originalSampleRate = audioBuffer.sampleRate;

        // Downsample the audio data
        const downsampledData = downsample(channelData, originalSampleRate, targetSampleRate);

        // Ensure the data length matches the model input shape
        const length = targetSampleRate; // 16000 samples
        const processedData = new Float32Array(length);
        processedData.set(downsampledData.slice(0, length));

        return Array.from(processedData);
    }

    // Downsample function
    function downsample(inputData, originalSampleRate, targetSampleRate) {
        const ratio = originalSampleRate / targetSampleRate;
        const result = new Float32Array(Math.ceil(inputData.length / ratio));

        for (let i = 0; i < result.length; i++) {
            result[i] = inputData[Math.floor(i * ratio)];
        }

        return result;
    }

    async function startListening() {
        const recognizer = window.trainedModel;

        if (!recognizer) {
            alert("먼저 모델을 훈련시켜야 합니다.");
            return;
        }

        const audioContext = new (window.AudioContext || window.webkitAudioContext)();
        await audioContext.audioWorklet.addModule('static/js/audio-processor.js');
        const processor = new AudioWorkletNode(audioContext, 'audio-processor');

        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        const source = audioContext.createMediaStreamSource(stream);

        source.connect(processor);
        processor.connect(audioContext.destination);

        processor.port.onmessage = (event) => {
            const inputData = event.data;
            if (inputData) {
                const length = 16000; // 모델이 기대하는 입력 길이
                const processedData = new Float32Array(length);
                processedData.set(inputData.slice(0, length));

                const inputTensor = tf.tensor2d([Array.from(processedData)], [1, length]);

                recognizer.predict(inputTensor).array().then(array => {
                    const predictedIndex = array[0].indexOf(Math.max(...array[0]));

                    console.log("predictedIndex : ", predictedIndex)
                    const labels = ["자비스", "안녕", "헤이", "잡음"];
                    if (labels[predictedIndex] === "자비스") {
                        document.getElementById('result').innerText = "네 무엇을 도와드릴까요?";
                        playResponse();
                    } else {
                        document.getElementById('result').innerText = "다른 음성 인식 결과";
                    }
                });
            }
        };
    }

    async function evaluateModel(model, testAudioBuffers, testLabelsData) {
        const processedTestAudioData = testAudioBuffers.map(buffer => processAudioBuffer(buffer));
        const testXs = tf.tensor2d(processedTestAudioData);
        const testYs = tf.tensor2d(testLabelsData);
    
        // 평가하기
        const evaluation = await model.evaluate(testXs, testYs);
    
        // 평가 결과 출력
        const [loss, accuracy] = evaluation;
        console.log("Loss:", loss.dataSync());
        console.log("Accuracy:", accuracy.dataSync());
    }
    

    function playResponse() {
        const msg = new SpeechSynthesisUtterance("네 무엇을 도와드릴까요?");
        msg.lang = "ko-KR";
        window.speechSynthesis.speak(msg);
    }

    // Helper function to split data into training and testing sets
    function splitData(data, ratio) {
        const splitIndex = Math.floor(data.length * ratio);
        const trainData = data.slice(0, splitIndex);
        const testData = data.slice(splitIndex);
        return [trainData, testData];
    }
});
