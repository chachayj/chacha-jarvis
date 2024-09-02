document.addEventListener('DOMContentLoaded', (event) => {
    async function loadModel() {
        try {
            // TensorFlow.js 모델 로드
            const model = await tf.loadLayersModel('/static/model/model.json');
            console.log('Model loaded successfully');
            return model;
        } catch (error) {
            console.error('Error loading model:', error);
        }
    }

    async function makePrediction(model) {
        try {
            // 예제 입력 데이터 생성
            const inputTensor = tf.tensor([[[[0.1]]]], [1, 64, 37, 1]);  // 실제 입력 데이터에 맞게 조정

            // 예측 수행
            const prediction = model.predict(inputTensor);
            const result = await prediction.array();

            // 결과를 HTML에 표시
            document.getElementById('result').innerText = `Prediction: ${result}`;
        } catch (error) {
            console.error('Error making prediction:', error);
        }
    }

    document.getElementById('predictButton').addEventListener('click', async () => {
        const model = await loadModel();
        if (model) {
            await makePrediction(model);
        }
    });
});
