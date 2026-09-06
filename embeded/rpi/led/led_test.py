#!/usr/bin/env python3
"""LED 배선 확인용 대화형 테스트

blink.py 로 안 될 때, 배선 문제인지 코드 문제인지 가르기 위한 도구.
켜기/끄기를 수동으로 시켜보고 눈으로 확인한다.

실행:
    python3 led_test.py              # BCM 21
    python3 led_test.py --pin 24
"""

import argparse

from gpiozero import LED, PWMLED


def main() -> None:
    parser = argparse.ArgumentParser(description="LED 배선 확인")
    parser.add_argument("--pin", type=int, default=21, help="BCM 핀 번호")
    args = parser.parse_args()

    print(f"BCM {args.pin}번 LED 테스트")
    print("명령: on / off / blink / fade / q(종료)\n")

    led = LED(args.pin)
    pwm = None      # fade 를 쓸 때만 만든다 (LED 와 동시에 못 잡는다)

    while True:
        try:
            cmd = input("> ").strip().lower()
        except (EOFError, KeyboardInterrupt):
            print()
            break

        if cmd in ("q", "quit", "exit"):
            break

        if cmd == "on":
            if pwm:
                pwm.close(); pwm = None; led = LED(args.pin)
            led.on()
            print("  켜짐 — 불이 들어왔나요?")

        elif cmd == "off":
            if pwm:
                pwm.close(); pwm = None; led = LED(args.pin)
            led.off()
            print("  꺼짐")

        elif cmd == "blink":
            if pwm:
                pwm.close(); pwm = None; led = LED(args.pin)
            led.blink(on_time=0.3, off_time=0.3)
            print("  점멸 중 — 다른 명령을 입력하면 멈춥니다")

        elif cmd == "fade":
            led.close()
            pwm = PWMLED(args.pin)
            pwm.pulse(fade_in_time=1, fade_out_time=1)
            print("  밝기 변화 중 — 서서히 밝아졌다 어두워지면 PWM 정상")

        elif cmd == "":
            continue

        else:
            print("  알 수 없는 명령. on / off / blink / fade / q")

    if pwm:
        pwm.close()
    else:
        led.off()
    print("종료했습니다")


if __name__ == "__main__":
    main()
