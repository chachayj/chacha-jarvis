# 06. 첫 실습 — LED 켜기 (예제 01)

> 작성일: 2026-09-06 / 소요: 10분 / 난이도: ★☆☆☆☆

가장 단순한 배선으로 GPIO 출력을 익힌다. 배선 2가닥 + 부품 2개가 전부다.

## 1. 참고 자료

| 자료 | 링크 |
| --- | --- |
| 예제 저장소 | <https://github.com/eleparts/raspi-AdvancedKit> |
| **01.LED 블로그** | <https://blog.naver.com/elepartsblog/221502439701> |
| **01.LED 배선도** | [그림 보기](https://blogfiles.pstatic.net/MjAxOTA0MDFfMTE5/MDAxNTU0MDc4NjYzNzAx.RjTr-_Uziw45l2dEqR10W1ylxV0KWT6hDKgdcxPuHMgg.8UUVfboDLBn-d2mxvrFG4ldxSjqYJobnbNe_y9ajwM8g.PNG.elepartsblog/4.PNG?type=w2) |
| 예제 코드 | `raspi-AdvancedKit/01.LED/led.py` |

> ⚠️ 블로그 글 번호를 헷갈리기 쉽다.
> `221502439701` = **01.LED (시작하기)** / `221511803979` = **06.피에조 부저**
> 전체 모듈별 링크는 [04. 하드웨어 키트 §3](04-hardware-kit.md) 표 참조.

파이에는 이미 저장소가 받아져 있다.

```bash
ls ~/raspi-AdvancedKit/01.LED
# README.md  led.py
```

## 2. 준비물

| 부품 | 비고 |
| --- | --- |
| LED 1개 | 색 무관. **다리 길이가 다르다** |
| 저항 1개 | 220Ω ~ 330Ω (빨강-빨강-갈색 / 주황-주황-갈색) |
| 점퍼선 2개 | 수-수(both male) |
| 빵판 | — |

> 저항은 **반드시** 넣는다. 없으면 LED 와 GPIO 핀이 과전류로 손상된다.

## 3. 사용하는 핀

예제 코드 `led.py` 는 **BCM 21번**을 쓴다.

```python
GPIO.setmode(GPIO.BCM)
LED = 21              # BCM P21
```

| 표기 | 값 | 위치 |
| --- | --- | --- |
| BCM 번호 | `GPIO 21` | 코드에서 쓰는 번호 |
| 물리 핀 번호 | **40번** | 40핀 헤더의 **맨 끝** |
| GND | **39번** | 40번 바로 옆 |

**39번과 40번이 나란히 붙어 있어** 배선이 가장 쉽다.
헤더 맨 끝(USB 포트 반대쪽 끝)의 마지막 두 핀이다.

> 💡 BCM 번호와 물리 핀 번호는 **다른 체계**다.
> 코드가 `GPIO.setmode(GPIO.BCM)` 이면 BCM 번호를, `GPIO.BOARD` 면 물리 번호를 쓴다.
> 터미널에서 `pinout` 명령을 치면 파이 핀맵이 그림으로 출력된다.

## 4. 배선

### 회로 구성

```
GPIO 21 (물리 40번) ──→ 저항 220Ω ──→ LED 긴다리(+) │ LED 짧은다리(−) ──→ GND (물리 39번)
```

### 빵판에 꽂기

```
   확장보드 또는 점퍼선
        │
   GPIO21 ●────────→ [ 14a ]
                     [ 14b ]───[ 저항 ]───[ 18b ]
                                           [ 18a ]──→ LED 긴다리
                                                       LED 짧은다리
                                                            │
   GND    ●────────→ [ 22a ] ←───────────────────────────────┘
```

핵심은 **"이어야 할 것끼리 같은 세로줄에 꽂는다"** 이다.
빵판 세로 5칸(a\~e)은 내부적으로 연결돼 있다 → [05. 빵판 기초](05-breadboard-basics.md)

### 확장 보드는 필수가 아니다

공식 배선도는 **파이 헤더에서 빵판으로 점퍼선을 직접 연결**한다. 확장 보드 없이도 된다.
다만 확장 보드를 쓰면 핀 이름이 인쇄돼 있어 **핀을 잘못 세는 실수를 막을 수 있다.**
처음이라면 확장 보드 사용을 권한다.

### ✅ 배선 체크리스트

- [ ] **파이 전원을 끄고** 배선했는가 (`sudo poweroff` 후 어댑터 분리)
- [ ] 저항을 넣었는가
- [ ] LED **긴 다리가 GPIO 쪽**(+), 짧은 다리가 GND 쪽인가
- [ ] 점퍼선이 끝까지 눌러 꽂혔는가
- [ ] 헤더 맨 끝 두 핀(39·40)에 꽂았는가 — 한 칸 밀리면 GPIO20/38번이 된다

## 5. 실행

```bash
cd ~/raspi-AdvancedKit/01.LED
sudo python3 led.py
```

0.5초 간격으로 LED 가 깜빡이면 성공이다. `Ctrl+C` 로 종료한다.

### 예제 코드

```python
import RPi.GPIO as GPIO
import time

GPIO.setmode(GPIO.BCM)     # BCM 번호 체계 사용
LED = 21

GPIO.setup(LED, GPIO.OUT)  # 출력 모드

while 1:
    GPIO.output(LED, GPIO.HIGH)   # 3.3V 출력 → 켜짐
    time.sleep(0.5)
    GPIO.output(LED, GPIO.LOW)    # 0V 출력 → 꺼짐
    time.sleep(0.5)
```

## 6. gpiozero 로 다시 써 보기 (권장)

예제는 `RPi.GPIO` 를 쓰지만, 현재 표준은 **`gpiozero`** 다.
더 짧고, `sudo` 없이 돌고, 종료 시 핀 정리도 자동이다. 파이에 이미 설치돼 있다.

```python
from gpiozero import LED
from signal import pause

led = LED(21)      # BCM 21
led.blink(on_time=0.5, off_time=0.5)
pause()
```

```bash
python3 blink.py   # sudo 불필요
```

> `RPi.GPIO` 는 라즈베리파이 5 에서 동작하지 않는다.
> 지금은 파이 4라 문제없지만, **새로 쓰는 코드는 `gpiozero`** 로 가는 것이 안전하다.

## 7. 안 될 때

| 증상 | 확인할 것 |
| --- | --- |
| 전혀 반응 없음 | 부품 다리가 **같은 세로줄**에 있는가 / 중앙 홈을 넘어 꽂지 않았는가 |
| LED 가 안 켜짐 | LED 방향 반대 — **긴 다리가 +** |
| 계속 켜져만 있음 | 저항이 GPIO 가 아니라 3.3V 핀에 연결됨 |
| 파이가 꺼지거나 재부팅 | **합선.** 즉시 전원 차단 후 배선 재확인 |
| `RuntimeError: No access to /dev/mem` | `sudo` 를 붙이거나 `gpiozero` 로 전환 |
| `RuntimeWarning: This channel is already in use` | 이전 실행이 정리 안 됨 — 무시해도 되고, `GPIO.cleanup()` 추가 |

### 배선을 바꾸지 않고 핀 상태만 확인

```bash
pinout        # 파이 핀맵 그림 출력
gpio readall  # (설치돼 있으면) 전 핀 상태 표
```

## 8. 다음 단계

1. **07. 스위치** — 입력 개념. 버튼으로 LED 를 켜고 끈다
2. **06. 피에조 부저** — PWM 개념 ([블로그](https://blog.naver.com/elepartsblog/221511803979))
3. **MQTT 연동** — 이 LED 를 EMQX 를 통해 원격 제어한다

```
[챗봇] → [go_fiber_server] → [EMQX] → /Robot_Control_Command/{id} → [파이] → GPIO21 LED
```

3번까지 가면 루트 README 의 *"robot server 연동 예정"* 이 해소된다.
`paho-mqtt` 설치가 필요하다 → [04. 하드웨어 키트 §6](04-hardware-kit.md)
