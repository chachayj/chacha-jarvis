// class AudioProcessor extends AudioWorkletProcessor {
//     constructor() {
//         super();
//     }

//     process(inputs, outputs, parameters) {
//         // 오디오 데이터는 inputs 배열을 통해 접근할 수 있습니다
//         // 여기서 inputs[0]은 입력 오디오 스트림입니다

//         // 이곳에서 오디오 데이터를 처리합니다
//         const input = inputs[0];
//         const output = outputs[0];

//         if (input[0]) {
//             output[0].set(input[0]);
//         }

//         // 반환값이 true면 계속해서 데이터를 처리합니다
//         return true;
//     }
// }

// registerProcessor('audio-processor', AudioProcessor);

class AudioProcessor extends AudioWorkletProcessor {
    constructor() {
        super();
        this.port.onmessage = (event) => {
            if (event.data === 'start') {
                this.port.postMessage({ status: 'started' });
            }
        };
    }

    process(inputs, outputs, parameters) {
        const input = inputs[0];
        if (input && input[0]) {
            this.port.postMessage(input[0]);
        }
        return true;
    }
}

registerProcessor('audio-processor', AudioProcessor);
