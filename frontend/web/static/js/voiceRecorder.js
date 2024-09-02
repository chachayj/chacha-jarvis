let audioChunks = [];
let mediaRecorder;
const audioPlayer = document.getElementById('audioPlayer');
const uploadForm = document.getElementById('uploadForm');
let startedRecord = false;
let pendingAPI = false;
let myvad;
let speechTimeout;

const startRecordWithTimeout = () => {
  if (!mediaRecorder) return;
  mediaRecorder.start();
  startedRecord = true;

  // 10초 후에 onSpeechEnd를 호출하는 타이머 설정
  speechTimeout = setTimeout(() => {
    // const now = new Date();
    // const koreanTime = now.toLocaleString('ko-KR', { timeZone: 'Asia/Seoul' });

    // window.appendChat('mine', "3초 지났다", koreanTime);
    // console.log("Timed out: Speech end forced");
    // console.log("myvad: ", myvad);
    myvad.options.onSpeechEnd();
    // stopRecord();
  }, 3000); // 10초(10000ms) 시간 설정
};

const stopRecordWithTimeout = () => {
  if (!mediaRecorder) return;
  mediaRecorder.stop();
  // stopRecord();
  startedRecord = false;

  // 타이머 취소
  clearTimeout(speechTimeout);
};

const startRecord = () => {
  if (!mediaRecorder) return;
  
  // 미디어 레코더의 현재 상태를 확인합니다.
  if (mediaRecorder.state === 'recording') {
    console.warn('MediaRecorder is already recording.');
    return;
  }

  // 미디어 레코더 시작
  mediaRecorder.start();
  startedRecord = true;
  document.getElementById("play-session").style.backgroundColor = "red";
  console.log('Recording started');
};


const stopRecord = () => {
  if (!mediaRecorder) return;

  // 미디어 레코더의 현재 상태를 확인합니다.
  if (mediaRecorder.state === 'inactive') {
    console.warn('MediaRecorder is not recording.');
    return;
  }

  // 미디어 레코더를 중지
  mediaRecorder.stop();
  // myvad.sp
  startedRecord = false;
  document.getElementById("play-session").style.backgroundColor = "#fff";
  console.log('Recording stopped');
};


window.toggleRecord = () => {
  if (!startedRecord) {
    startRecord();
  } else {
    stopRecord();
  }
};

window.startVAD = async () => {
  // 마이크 입력 스트림에 접근
  const stream = await navigator.mediaDevices.getUserMedia({
    audio: {
      channelCount: 2
    }
  });

  // 미디어 레코더를 마이크 입력 스트림에 바인딩
  mediaRecorder = new MediaRecorder(stream);

  // VAD 인스턴스 생성 및 콜백 함수 설정
  myvad = await vad.MicVAD.new({
    onSpeechStart: () => {
      console.log("Speech start detected");
      document.getElementById('header').style.backgroundColor = 'blue';
      startRecordWithTimeout();
    },
    onFrameProcessed: (probs) => {
      // 기타 프로세싱 작업 수행 가능
    },
    onSpeechEnd: async (audioBuffer) => {
      console.log("Speech end detected");
      stopRecordWithTimeout();
      
      // 음성 데이터를 사용하여 STT 및 LLM 작업을 수행
      console.log(" call 전에: ", audioBuffer);
      if (audioBuffer === undefined) {
        pendingAPI = false;
        document.getElementById('header').style.backgroundColor = 'green';
        console.log('pendingAPI has been reset to false');
        return
      }
      const wavBuffer = vad.utils.encodeWAV(audioBuffer);
      
      const base64 = vad.utils.arrayBufferToBase64(wavBuffer);
      console.log(" call 후에");
      const url = `data:audio/wav;base64,${base64}`;
      
      // 음성 데이터를 오디오 플레이어에 설정
      audioPlayer.src = url;
      
      // 폼 데이터를 구성
      const formData = new FormData(uploadForm);
      formData.set('audio_data', base64);

      // 마이크에 접근 권한 요청
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        
      // AudioContext 생성
      const audioContext = new (window.AudioContext || window.webkitAudioContext)();
      
      // MediaStreamAudioSourceNode 생성
      // const source = audioContext.createMediaStreamSource(stream);
      
      console.log("샘플레이팅 : ", audioContext.sampleRate)
      // 샘플레이트 값 설정 해봤으나 오히려 샘플레이트 적용해서 저장하면 기계음소리와 지지직소리가 난다.
      
      // 음성 데이터 전송 및 후속 작업 수행
      try {
        const sttResponse = await fetch('https://jarvis/stt', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ audio_data: base64, sample_rate: audioContext.sampleRate }),
        });

        const sttResult = await sttResponse.json();
        
        console.log('STT 결과: ' + sttResult.text);

        // LLM 작업 수행
        if (sttResult.text !== "음성 인식에 실패 했습니다.") {
          const llmResponse = await fetch('https://jarvis/llm', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({ userId: uuid, question: sttResult.text }),
          });

          const llmResult = await llmResponse.json();
          
          console.log('LLM 결과: ' + llmResult);
          console.log(llmResult.answer);
          const now = new Date();
          const koreanTime = now.toLocaleString('ko-KR', { timeZone: 'Asia/Seoul' });

          window.appendChat('mine', sttResult.text, koreanTime);
          window.appendChat('jarvis', llmResult.answer, koreanTime);
          
          pendingAPI = false;
          document.getElementById('header').style.backgroundColor = 'green';
          window.sendTextAndSpeak(llmResult.answer)
          console.log('pendingAPI has been reset to false');
        } else {
          pendingAPI = false;
          document.getElementById('header').style.backgroundColor = 'green';
          window.sendTextAndSpeak("음성 인식에 실패 했습니다.")
          console.log('pendingAPI has been reset to false');
        }
      } catch (error) {
        console.error('STT 중 오류 발생:', error);
        pendingAPI = false;
        document.getElementById('header').style.backgroundColor = 'green';
        window.sendTextAndSpeak("음성 인식에 실패 했습니다.")
        console.log('pendingAPI has been reset to false');
      }
    }
  });

  // VAD 시작
  myvad.start();
};
