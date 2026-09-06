#!/usr/bin/env python3
"""채팅처럼 명령을 입력해 로봇(라즈베리파이)을 제어하는 CLI.

챗봇을 거치지 않고 직접 MQTT 로 명령을 쏘는 개발용 도구다.
go_fiber_server 와 같은 토픽/페이로드 형식을 쓰므로,
이걸로 되면 챗봇 경로도 그대로 동작한다.

    (이 CLI) ─publish─> [EMQX] ─> /Robot_Control_Command/{id} ─> [파이] ─> LED
                          <─ /Robot_Status/{id} ─ 상태 회신

실행:
    python3 cli.py                          # localhost 브로커
    python3 cli.py --broker 100.78.253.44
"""

import argparse
import json
import sys
import threading

import paho.mqtt.client as mqtt

_HAS_V2_API = hasattr(mqtt, "CallbackAPIVersion")

HELP = """
사용법 — 하고 싶은 말을 그냥 입력하세요.

  불 켜줘 / on / turn on light      LED 켜기
  불 꺼줘 / off / turn off light    LED 끄기
  깜빡 / blink                      LED 점멸

  /help    도움말
  /raw {"Command": "..."}           JSON 을 그대로 발행
  /topic   현재 토픽 확인
  /quit    종료
"""


def _make_client(client_id: str) -> mqtt.Client:
    if _HAS_V2_API:
        return mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=client_id)
    return mqtt.Client(client_id=client_id)


def main() -> None:
    parser = argparse.ArgumentParser(description="채팅형 로봇 제어 CLI")
    parser.add_argument("--broker", default="localhost", help="EMQX 주소")
    parser.add_argument("--port", type=int, default=1883, help="MQTT 포트")
    parser.add_argument("--robot-id", default="1", help="로봇 ID")
    parser.add_argument("--username", default=None)
    parser.add_argument("--password", default=None)
    args = parser.parse_args()

    command_topic = f"/Robot_Control_Command/{args.robot_id}"
    status_topic = f"/Robot_Status/{args.robot_id}"

    ready = threading.Event()

    def on_connect(client, userdata, flags, reason_code, properties=None):
        if reason_code != 0:
            print(f"[연결 실패] reason_code={reason_code}")
            return
        client.subscribe(status_topic, qos=1)
        ready.set()

    def on_message(client, userdata, msg):
        text = msg.payload.decode("utf-8", errors="replace")
        try:
            state = json.loads(text).get("state", text)
        except json.JSONDecodeError:
            state = text
        # 입력 프롬프트를 지우고 출력한 뒤 다시 그린다
        print(f"\r\033[K  ← 로봇 상태: {state}\n> ", end="", flush=True)

    client = _make_client(f"chat-cli-{args.robot_id}")
    if args.username:
        client.username_pw_set(args.username, args.password)
    client.on_connect = on_connect
    client.on_message = on_message

    try:
        client.connect(args.broker, args.port, keepalive=30)
    except OSError as exc:
        print(f"[에러] 브로커 접속 실패: {exc}", file=sys.stderr)
        print("  EMQX 가 떠 있는지 확인: docker compose up -d emqx", file=sys.stderr)
        sys.exit(1)

    client.loop_start()

    if not ready.wait(timeout=10):
        print("[에러] 브로커 연결 시간 초과", file=sys.stderr)
        client.loop_stop()
        sys.exit(1)

    print(f"[연결됨] {args.broker}:{args.port}")
    print(f"[발행] {command_topic}")
    print(f"[구독] {status_topic}")
    print(HELP)

    try:
        while True:
            try:
                line = input("> ").strip()
            except (EOFError, KeyboardInterrupt):
                print()
                break

            if not line:
                continue

            if line in ("/quit", "/exit", "/q"):
                break
            if line == "/help":
                print(HELP)
                continue
            if line == "/topic":
                print(f"  발행: {command_topic}\n  구독: {status_topic}")
                continue
            if line.startswith("/raw "):
                payload = line[5:].strip()
                client.publish(command_topic, payload, qos=1)
                print(f"  → (raw) {payload}")
                continue
            if line.startswith("/"):
                print("  알 수 없는 명령. /help 를 보세요")
                continue

            # go_fiber_server 와 동일한 페이로드 형식
            payload = json.dumps({"Command": line}, ensure_ascii=False)
            client.publish(command_topic, payload, qos=1)
            print(f"  → {payload}")

    finally:
        client.loop_stop()
        client.disconnect()
        print("종료했습니다")


if __name__ == "__main__":
    main()
