#!/usr/bin/env python3
"""MQTT 로 LED 제어 — 볼 스위치 대신 '외부 명령'으로 동작시킨다.

EMQX 브로커의 /Robot_Control_Command/{robot_id} 토픽을 구독해,
go_fiber_server(robot server)가 발행한 명령대로 LED 를 켜고 끈다.

    [챗봇] -> [go_fiber_server] -> [EMQX] -> (이 스크립트) -> GPIO LED

페이로드는 go 서버가 map[string]string 을 JSON 으로 보낸 형태다.

    {"Command": "turn on light"}

배선:
    GPIO21(물리 40번) -> 저항 220~330옴 -> LED 긴다리(+)
    LED 짧은다리(-)   -> GND(물리 39번)

실행:
    python3 led_mqtt.py --broker 100.78.253.44
    python3 led_mqtt.py --broker 100.78.253.44 --robot-id 1 --pin 21
"""

import argparse
import json
import sys
from signal import pause

import paho.mqtt.client as mqtt
from gpiozero import LED

# paho-mqtt 1.x(데비안 apt 기본)와 2.x 를 모두 지원한다.
# 1.x 와 2.x 는 클라이언트 생성 방식과 콜백 시그니처가 다르다.
_HAS_V2_API = hasattr(mqtt, "CallbackAPIVersion")


def _make_client(client_id: str) -> mqtt.Client:
    if _HAS_V2_API:
        return mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=client_id)
    return mqtt.Client(client_id=client_id)

# 명령어 -> 동작 매핑. 챗봇이 자연어를 보낼 수 있어 키워드 포함 여부로 판단한다.
ON_WORDS = ("on", "켜", "start", "open", "enable")
OFF_WORDS = ("off", "꺼", "끄", "stop", "close", "disable")
BLINK_WORDS = ("blink", "깜빡", "flash", "toggle")


class LedController:
    def __init__(self, pin: int, robot_id: str, status_topic: str):
        self.led = LED(pin)
        self.robot_id = robot_id
        self.status_topic = status_topic
        self.state = "off"

    def apply(self, command: str) -> str:
        """명령 문자열을 해석해 LED 를 제어하고 결과 상태를 돌려준다."""
        text = command.lower()

        # 'turn off' 처럼 off 가 뒤에 붙는 경우가 있어 off 를 먼저 본다
        if any(w in text for w in BLINK_WORDS):
            self.led.blink(on_time=0.5, off_time=0.5)
            self.state = "blink"
        elif any(w in text for w in OFF_WORDS):
            self.led.off()
            self.state = "off"
        elif any(w in text for w in ON_WORDS):
            self.led.on()
            self.state = "on"
        else:
            print(f"  [무시] 해석할 수 없는 명령: {command!r}")
            return self.state

        print(f"  [적용] {command!r} -> LED {self.state}")
        return self.state


def extract_command(payload: bytes) -> str:
    """페이로드에서 명령 문자열을 뽑아낸다.

    go 서버는 JSON 을 보내지만, MQTTX 등으로 평문을 쏘는 경우도 받아준다.
    """
    text = payload.decode("utf-8", errors="replace").strip()

    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        return text  # 평문 그대로 명령으로 취급

    if isinstance(data, dict):
        # go 서버는 "Command" 키를 쓴다. 대소문자 변형도 함께 본다.
        for key in ("Command", "command", "cmd"):
            if key in data:
                return str(data[key])
        return text

    return str(data)


def main() -> None:
    parser = argparse.ArgumentParser(description="MQTT 로 LED 제어")
    parser.add_argument(
        "--broker",
        default="100.78.253.44",
        help="EMQX 주소 (기본: 개발 PC 의 Tailscale IP)",
    )
    parser.add_argument("--port", type=int, default=1883, help="MQTT 포트 (기본 1883)")
    parser.add_argument("--robot-id", default="1", help="로봇 ID (토픽에 들어간다)")
    parser.add_argument("--pin", type=int, default=21, help="LED BCM 핀 (기본 21)")
    parser.add_argument("--username", default=None, help="MQTT 사용자명 (필요 시)")
    parser.add_argument("--password", default=None, help="MQTT 비밀번호 (필요 시)")
    args = parser.parse_args()

    command_topic = f"/Robot_Control_Command/{args.robot_id}"
    status_topic = f"/Robot_Status/{args.robot_id}"

    controller = LedController(args.pin, args.robot_id, status_topic)

    # 1.x 는 (client, userdata, flags, rc), 2.x 는 properties 가 하나 더 붙는다.
    def on_connect(client, userdata, flags, reason_code, properties=None):
        if reason_code != 0:
            print(f"[연결 실패] reason_code={reason_code}")
            return
        print(f"[연결됨] {args.broker}:{args.port}")
        client.subscribe(command_topic, qos=1)
        print(f"[구독] {command_topic}")
        client.publish(status_topic, json.dumps({"state": controller.state}), qos=1)

    # 1.x 는 (client, userdata, rc), 2.x 는 인자가 더 많아 *args 로 받는다.
    def on_disconnect(client, userdata, *args):
        print(f"[연결 끊김] {args} — 자동 재연결 대기")

    def on_message(client, userdata, msg):
        command = extract_command(msg.payload)
        print(f"[수신] {msg.topic} <- {command!r}")
        state = controller.apply(command)
        # 상태를 되돌려 보낸다 (추후 Cesium 화면 표시용 telemetry 의 기초)
        client.publish(status_topic, json.dumps({"state": state}), qos=1)

    client = _make_client(f"rpi-led-{args.robot_id}")
    if args.username:
        client.username_pw_set(args.username, args.password)

    client.on_connect = on_connect
    client.on_disconnect = on_disconnect
    client.on_message = on_message

    # 예기치 않게 죽으면 브로커가 대신 상태를 알려준다
    client.will_set(status_topic, json.dumps({"state": "offline"}), qos=1, retain=False)
    client.reconnect_delay_set(min_delay=1, max_delay=30)

    print(f"브로커 접속 시도: {args.broker}:{args.port}")
    try:
        client.connect(args.broker, args.port, keepalive=30)
    except OSError as exc:
        print(f"[에러] 브로커에 접속할 수 없습니다: {exc}", file=sys.stderr)
        print("  - EMQX 가 떠 있는지 (docker compose up -d emqx)", file=sys.stderr)
        print("  - --broker 주소가 맞는지 확인하세요", file=sys.stderr)
        sys.exit(1)

    client.loop_start()
    print("대기 중 — 종료하려면 Ctrl+C")

    try:
        pause()
    except KeyboardInterrupt:
        print("\n종료합니다")
    finally:
        client.publish(status_topic, json.dumps({"state": "offline"}), qos=1)
        client.loop_stop()
        client.disconnect()
        controller.led.off()


if __name__ == "__main__":
    main()
