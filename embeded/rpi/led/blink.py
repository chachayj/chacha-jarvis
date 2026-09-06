#!/usr/bin/env python3
"""01. LED 깜빡이기 — gpiozero 버전

엘레파츠 고급키트 예제 01(led.py)을 gpiozero 로 다시 쓴 것.
원본은 RPi.GPIO 를 쓰지만 gpiozero 는 sudo 가 필요 없고,
종료 시 핀 정리가 자동이며 라즈베리파이 5 에서도 동작한다.

배선:
    GPIO21(물리 40번) -> 저항 220~330옴 -> LED 긴다리(+)
    LED 짧은다리(-)   -> GND(물리 39번)

실행:
    python3 blink.py                 # 기본값: GPIO21, 0.5초 간격
    python3 blink.py --pin 21 --interval 0.2
"""

import argparse
from signal import pause

from gpiozero import LED


def main() -> None:
    parser = argparse.ArgumentParser(description="LED 깜빡이기")
    parser.add_argument("--pin", type=int, default=21, help="BCM 핀 번호 (기본 21)")
    parser.add_argument(
        "--interval", type=float, default=0.5, help="점멸 간격(초) (기본 0.5)"
    )
    args = parser.parse_args()

    led = LED(args.pin)

    print(f"LED 점멸 시작 — BCM {args.pin}번, {args.interval}초 간격")
    print("종료하려면 Ctrl+C")

    # blink 는 백그라운드 스레드에서 동작하므로 pause 로 메인을 붙잡아 둔다
    led.blink(on_time=args.interval, off_time=args.interval)

    try:
        pause()
    except KeyboardInterrupt:
        print("\n종료합니다")
    finally:
        led.off()   # gpiozero 가 자동 정리하지만 의도를 명시해 둔다


if __name__ == "__main__":
    main()
