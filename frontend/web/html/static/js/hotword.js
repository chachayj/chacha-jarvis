const now = new Date();
const koreanTime = now.toLocaleString('ko-KR', { timeZone: 'Asia/Seoul' });

// VAD 및 MediaRecorder 관련 변수
let myvad;
let mediaRecorder;
let startedRecord = false;
let speechTimeout;
let pendingAPI = false;
let audioChunks = [];

// 모델 로드
async function loadModel() {
    const recognizer = speechCommands.create('BROWSER_FFT');
    await recognizer.ensureModelLoaded();
    
    // 미리 훈련된 단어 목록 표시 
    window.appendChat('jarvis', "모델이 로드되었습니다. '세븐(seven)'이라고 말해보세요.", koreanTime);
    return recognizer;
}

// 음성 합성
function playResponse(msgAnswer) {
    const msg = new SpeechSynthesisUtterance(msgAnswer);
    msg.lang = "ko-KR";
    window.speechSynthesis.speak(msg);
}

// 핫워드 감지 및 음성 인식
async function startListening() {
    const recognizer = await loadModel();

    recognizer.listen(async (result) => {
        const scores = result.scores; // 모델의 예측 점수
        const labels = recognizer.wordLabels(); // 인식 가능한 단어 목록

        labels.forEach(async (label, i) => {
            if (label === "seven" && scores[i] > 0.75) { // 임계치 0.75
                console.log("scores[i] : ", scores[i]);
                const msg = "네 무엇을 도와드릴까요? 'one'이라고 말하시면 서울의 날씨를, 'three'라고 말하시면 네이버 뉴스를 알려드릴게요.";
                window.appendChat('jarvis', msg, koreanTime);
                // playResponse(msg);
            } else if (label === "three" && scores[i] > 0.75) { // 'three' 핫워드 감지 시
                try {
                    // 날씨 정보 요청
                    const weatherResponse = await fetch('http://127.0.0.1:3000/weather/seoul', {
                        method: 'GET',
                        headers: {
                            'Content-Type': 'application/json',
                        },
                    });

                    // 날씨 데이터 파싱
                    const weatherResult = await weatherResponse.json();
                    console.log('weatherResult 결과: ', weatherResult);

                    // 날씨 정보 추출
                    const { description } = weatherResult.weather[0];
                    const { temp, feels_like, humidity, pressure } = weatherResult.main;
                    const { speed } = weatherResult.wind;

                    // 응답 메시지 생성
                    const weatherMsg = `
                        현재 서울의 날씨는 ${description}입니다.
                        기온은 ${temp}°C로 체감 온도는 ${feels_like}°C입니다.
                        습도는 ${humidity}%이며, 기압은 ${pressure} hPa입니다.
                        바람 속도는 ${speed} m/s입니다.
                    `;
                    window.appendChat('jarvis', weatherMsg, koreanTime);
                    playResponse(weatherMsg);
                } catch (error) {
                    console.error('날씨 데이터 요청 중 오류 발생:', error);
                    const errorMsg = "날씨 정보를 가져오는 데 문제가 발생했습니다.";
                    window.appendChat('jarvis', errorMsg, koreanTime);
                    playResponse(errorMsg);
                }
            }
        });
    }, {
        probabilityThreshold: 0.75, // 임계치 설정
        includeSpectrogram: false,
        overlapFactor: 0.5 // 오디오 처리 중복 비율
    });

    // 필요 시 중지하려면 recognizer.stopListening();
}

startListening();
