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
