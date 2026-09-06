#!/usr/bin/env python3
"""08. 볼 스위치(기울기 감지) — gpiozero 버전

엘레파츠 고급키트 예제 08(tilt_ball_switch.py)을 gpiozero 로 다시 쓴 것.

동작:
    - 빨간 LED : 0.5초 간격으로 계속 점멸 (동작 중 표시)
    - 볼 스위치가 기울어지면 -> 파란 LED 1초 점등

배선:
    볼 스위치  BCM 16 (물리 36번)  + GND
    빨강 LED   BCM 24 (물리 18번) -> 저항 -> LED -> GND
    파랑 LED   BCM 23 (물리 16번) -> 저항 -> LED -> GND

실행:
    python3 tilt_ball_switch.py
"""

import argparse
from signal import pause

from gpiozero import LED, Button


def main() -> None:
    parser = argparse.ArgumentParser(description="볼 스위치로 LED 제어")
    parser.add_argument("--switch", type=int, default=16, help="볼 스위치 BCM 핀")
    parser.add_argument("--led-red", type=int, default=24, help="빨강 LED BCM 핀")
    parser.add_argument("--led-blue", type=int, default=23, help="파랑 LED BCM 핀")
    args = parser.parse_args()

    led_red = LED(args.led_red)
    led_blue = LED(args.led_blue)

    # 원본은 GPIO.PUD_DOWN + FALLING 인터럽트를 썼다.
    # gpiozero 는 pull_up=False 가 내부 풀다운이고, bounce_time 으로 채터링을 걸러낸다.
    tilt = Button(args.switch, pull_up=False, bounce_time=0.1)

    def on_tilt() -> None:
        print("기울기 감지 -> 파랑 LED 1초")
        led_blue.blink(on_time=1, off_time=0, n=1, background=True)

    tilt.when_pressed = on_tilt

    led_red.blink(on_time=0.5, off_time=0.5)   # 동작 중 표시

    print(f"대기 중 — 스위치 BCM{args.switch} / 빨강 BCM{args.led_red} / 파랑 BCM{args.led_blue}")
    print("보드를 기울여 보세요. 종료하려면 Ctrl+C")

    try:
        pause()
    except KeyboardInterrupt:
        print("\n종료합니다")
    finally:
        led_red.off()
        led_blue.off()


if __name__ == "__main__":
    main()
