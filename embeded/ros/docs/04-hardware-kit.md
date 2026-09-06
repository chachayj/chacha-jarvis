# 04. 보유 하드웨어 키트 구성 및 스펙

> 정리일: 2026-09-06
> 대상: KEYES 라즈베리파이 고급키트 (엘레파츠 판매, 품번 `EPXHTPVH` / `SMP0046`)

## 1. 구매 내역

| 상품 | 품번 | 내용 |
| --- | --- | --- |
| [라즈베리파이4 8GB 스타트 키트](https://www.eleparts.co.kr/goods/view?no=9470248) | `EPXTPUAC` | 본체 + 기본 액세서리 (케이스·어댑터·SD) |
| [KEYES 라즈베리파이 고급키트](https://www.eleparts.co.kr/goods/view?no=4190268) | `EPXHTPVH` | 센서·액추에이터 모듈 일체 + 빵판 |
| [라즈베리파이 카메라모듈 V2](https://www.eleparts.co.kr/goods/view?no=3824792) | `EPXGRC7G` | Sony IMX219 8MP, CSI 접속 |

## 2. ⭐ 공식 예제 저장소 — "없다던 그 설명서"

이 키트는 종이 설명서가 없고 해외 판매처(dx.com) 매뉴얼 링크도 끊겨 있다.
[라즈베리파이 공식 포럼](https://forums.raspberrypi.com/viewtopic.php?t=125166) 에도 같은 문의가 올라와 있다.

**대신 엘레파츠가 예제 코드와 한글 설명을 GitHub 에 공개해 두었다.**

- 저장소: <https://github.com/eleparts/raspi-AdvancedKit>
- 블로그: [엘레파츠 네이버 블로그 — 고급키트 시리즈](https://blog.naver.com/PostSearchList.nhn?blogId=elepartsblog&categoryNo=0&range=all&SearchText=%EB%9D%BC%EC%A6%88%EB%B2%A0%EB%A6%AC%ED%8C%8C%EC%9D%B4+%EA%B3%A0%EA%B8%89+%ED%82%A4%ED%8A%B8)
  → **회로 배선 사진이 블로그에만 있다.** 부품을 꽂기 전에 해당 회차 글을 먼저 볼 것

```bash
# 파이에서
git clone https://github.com/eleparts/raspi-AdvancedKit
cd raspi-AdvancedKit
```

## 3. 모듈 전체 인덱스

핀 번호는 전부 **BCM 기준**이며, 예제 코드에 하드코딩된 값이다.

| # | 모듈 | 칩/부품 | 인터페이스 | 예제 핀 (BCM) | 예제 |
| --- | --- | --- | --- | --- | --- |
| 01 | LED | 단색 LED | GPIO 출력 | `21` | [블로그](https://blog.naver.com/elepartsblog/221502439701) |
| 02 | RGB LED | 3색 LED (공통 애노드) | PWM ×3 (2kHz) | R`11` G`9` B`10` | [블로그](https://blog.naver.com/elepartsblog/221504611388) |
| 03 | 서보모터 | SG90 계열 | PWM (50Hz) | `23` | [블로그](https://blog.naver.com/elepartsblog/221506211679) |
| 04 | DC 모터 | 모터 드라이버 경유 | GPIO ×2 | A`23` B`24` | [블로그](https://blog.naver.com/elepartsblog/221508416424) |
| 05 | 스텝모터 | 28BYJ-48 + ULN2003 | GPIO ×4 | `8,9,10,11` | [블로그](https://blog.naver.com/elepartsblog/221510191478) |
| 06 | 피에조 부저 | 수동 부저 | PWM | 부저`24` 스위치`16` | [블로그](https://blog.naver.com/elepartsblog/221511803979) |
| 07 | 스위치 | 택트 스위치 | GPIO 입력 | 스위치`16` LED`24` | [블로그](https://blog.naver.com/elepartsblog/221514191890) |
| 08 | 볼 스위치 | 기울기 감지 | GPIO 입력 | 스위치`16` LED`24`,`23` | [블로그](https://blog.naver.com/elepartsblog/221515617750) |
| 09 | 로터리 엔코더 | 회전 노브 | GPIO ×2 | CLK`17` DT`18` | [블로그](https://blog.naver.com/elepartsblog/221517364404) |
| 10 | 터치 키패드 | TTP229 | 2-wire | SCL`21` SDO`20` | [블로그](https://blog.naver.com/elepartsblog/221519528879) |
| 11 | 조이스틱 | 2축 아날로그 + **PCF8591** | **I2C** `0x48` | — | [블로그](https://blog.naver.com/elepartsblog/221521607450) |
| 12 | RTC 모듈 | DS1307/DS3231 계열 | I2C | — | [블로그](https://blog.naver.com/elepartsblog/221523134383) |
| 13 | 온습도 센서 | **DHT11** | 1-Wire | `2` | [블로그](https://blog.naver.com/elepartsblog/221525069011) |
| 14 | 가스 센서 | **MQ-5** | GPIO 입력(DO) | 센서`23` LED`25` | [블로그](https://blog.naver.com/elepartsblog/221528526035) |
| 15 | 3축 가속도 | **ADXL345** | I2C `0x53` | — | [블로그](https://blog.naver.com/elepartsblog/221532166120) |
| 16 | 초음파 센서 | **HC-SR04** | GPIO ×2 | TRIG`23` ECHO`24` | [블로그](https://blog.naver.com/elepartsblog/221533957300) |
| 17 | 7세그먼트 | FND + **74HC595** | 시프트 레지스터 | Ds`4` STCP`5` SHCP`6` | [블로그](https://blog.naver.com/elepartsblog/221536332502) |
| 18 | 4자리 7세그먼트 | 4-digit FND | GPIO ×7 | `4,5,6,7,8,9,10` | [블로그](https://blog.naver.com/elepartsblog/221543759456) |
| 19 | OLED | **SSD1306** 0.96" 128×64 | I2C `0x3C` | SDA`2` SCL`3` | [블로그](https://blog.naver.com/elepartsblog/221551346359) |
| 20 | IR 수신기 | 38kHz 수신 모듈 | LIRC | `18` | [블로그](https://blog.naver.com/elepartsblog/221558430782) |
| 21 | 블루투스 | **HC-06** | UART (TX/RX) | — | [블로그](https://blog.naver.com/elepartsblog/221560476657) |
| — | 카메라 | **Sony IMX219** 8MP | CSI 리본 | — | 별도 구매품 |
| — | RFID | **RC522 / MFRC522** | SPI | — | ⚠️ 아래 5장 참조 |

## 4. 사전 설정 — 이거부터 켜야 한다

측정 결과 **I2C·SPI 가 전부 꺼져 있다.** 11·12·15·19번(I2C)과 RFID(SPI)를 쓰려면 필수다.

```bash
sudo raspi-config
# Interface Options → I2C → Enable
# Interface Options → SPI → Enable
# Interface Options → Serial Port → (블루투스/HC-06 쓸 때만) Enable
sudo reboot
```

재부팅 후 확인:

```bash
ls /dev/i2c-1 /dev/spidev0.*     # 생겨 있어야 한다
sudo apt install -y i2c-tools
i2cdetect -y 1                    # 연결한 I2C 모듈 주소가 뜬다
```

> ⚠️ `i2c-20`·`i2c-21` 은 HDMI DDC 버스라 **전 주소가 응답하는 것처럼 보인다.**
> 진짜 센서는 `i2c-1` 에서 확인한다. → [02. 하드웨어 스펙](02-hardware-spec.md)

## 5. ⚠️ RFID(RC522) 예제는 저장소에 없다

상품 설명에는 "NFC, RFID" 가 포함이라고 되어 있으나
**엘레파츠 저장소의 21개 예제에 RFID 항목이 없다.** 블로그에도 해당 회차가 없다.

RC522 는 범용 부품이라 외부 자료로 진행하면 된다.

```bash
sudo raspi-config      # SPI Enable 필수
sudo apt install -y python3-spidev
pip3 install mfrc522 --break-system-packages
```

- 라이브러리: [`pi-rc522`](https://github.com/ondryaso/pi-rc522) 또는 [`mfrc522`](https://github.com/pimylifeup/MFRC522-python)
- 참고: [SunFounder MFRC522 문서](https://docs.sunfounder.com/projects/davinci-kit/en/latest/c_pi5/2.2.7_mfrc522_rfid_module.html)

**RC522 는 3.3V 전용이다. 5V 를 물리면 모듈이 손상된다.**

## 6. ⚠️ 예제 코드가 2019년 기준이라 그대로는 안 되는 것들

저장소 예제는 2019년 라즈비안 시절에 작성되었다. 현재 OS(Bookworm)에서 아래를 조정해야 한다.

| 예제에 적힌 것 | 현재 해야 할 것 | 이유 |
| --- | --- | --- |
| `sudo pip3 install <패키지>` | `pip3 install <패키지> --break-system-packages`<br>또는 `apt install python3-<패키지>` | Bookworm 은 PEP 668 적용 → `externally-managed-environment` 오류 |
| `apt install python-dev` | `apt install python3-dev` | Python 2 패키지는 제거됨 |
| `sudo python setup.py install` | `pip3 install .` | setup.py 직접 실행은 폐기됨 |
| `sudo nano /boot/config.txt` | `sudo nano /boot/firmware/config.txt` | Bookworm 에서 부트 파티션 경로 변경 |
| `import smbus` | `import smbus2` | `smbus` 는 미설치. `smbus2` 가 이미 깔려 있음 |
| `Adafruit_Python_DHT` | `adafruit-circuitpython-dht` 또는 `pigpio` | 원본 저장소가 **아카이브(지원 종료)** 됨 |

> 이미 설치된 라이브러리는 [02. 하드웨어 스펙 §6](02-hardware-spec.md) 참조.
> `gpiozero`·`RPi.GPIO`·`lgpio`·`pigpio`·`smbus2`·`picamera2`·`pyserial` 전부 있다.
> **`paho-mqtt` 만 없다** — MQTT 연동 시 설치 필요.

## 6-1. 저항 구성 (실측 확인)

키트의 저항은 **포장 스트립 색으로 구분**돼 있다. 저항 자체의 색 띠와 헷갈리기 쉽다.

| 스트립 색 | 수량 | 저항값 | 색 띠 | 주 용도 |
| --- | --- | --- | --- | --- |
| 🔵 파랑 | **8개** | **220Ω** ✅검증 | 빨강-빨강-갈색 | **LED 전류 제한** |
| 🔴 빨강 / 🟢 초록 | 5개씩 | **1kΩ** | 갈색-검정-**빨강** | 분압, 신호 보호 |
| 🔴 빨강 / 🟢 초록 | 5개씩 | **10kΩ** | 갈색-검정-**주황** | 버튼 풀업/풀다운 |

> 빨강·초록 스트립은 둘 다 5개라 수량으로 구분되지 않는다.
> **세 번째 띠**를 보면 된다 — 빨강이면 1kΩ, 주황이면 10kΩ.

### ⚠️ LED 에는 반드시 파랑 스트립(220Ω)을 쓴다

실제로 초록 스트립(1k 또는 10k)을 꽂아 LED 가 어둡게 켜진 사례가 있었다.
파랑 스트립(220Ω)으로 교체하니 **밝기가 눈에 띄게 올라가는 것을 실물로 확인했다.**
**위험하지는 않지만**(저항이 클수록 전류가 줄어 안전하다) 밝기가 크게 떨어진다.

GPIO 3.3V, LED 순전압 약 2V 기준 전류:

| 저항 | 전류 | 밝기 |
| --- | --- | --- |
| 220Ω | 6mA | ✅ 정상 |
| 1kΩ | 1.3mA | 어둡지만 보임 |
| 10kΩ | 0.13mA | 거의 안 보임 |
| **저항 없음** | 과전류 | 💀 **LED·GPIO 손상** |

### 색 띠 읽는 법

**금색·은색 띠를 오른쪽에 두고** 왼쪽부터 읽는다. (금·은은 오차 표시)

| 색 | 값 | 색 | 값 |
| --- | --- | --- | --- |
| 검정 | 0 | 초록 | 5 |
| 갈색 | 1 | 파랑 | 6 |
| 빨강 | 2 | 보라 | 7 |
| 주황 | 3 | 회색 | 8 |
| 노랑 | 4 | 흰색 | 9 |

- **4띠**: 숫자 · 숫자 · ×배수 · 오차
- **3띠**: 숫자 · 숫자 · ×배수 (오차 ±20%)
- 배수: 검정 ×1, 갈색 ×10, 빨강 ×100, 주황 ×1k, 노랑 ×10k

저항은 **방향이 없다.** 거꾸로 꽂아도 무관하다.

## 7. 🔥 초보자 필수 안전 수칙

### 7-1. GPIO 는 3.3V 다. 5V 를 넣으면 파이가 죽는다

특히 **HC-SR04 초음파 센서(16번)** 가 위험하다.
5V 로 동작하며 `ECHO` 핀으로 **5V 를 출력**하는데, 이걸 GPIO 에 직결하면 핀이 손상된다.

```
HC-SR04 ECHO ──[ 1kΩ ]──┬── GPIO (3.3V 로 분압됨)
                         │
                       [ 2kΩ ]
                         │
                        GND
```

저항 2개로 분압(voltage divider)해서 연결한다. 키트에 저항이 들어 있다.

### 7-2. 모터를 GPIO 에 직결하지 않는다

파이 GPIO 핀 하나의 허용 전류는 약 16mA(전체 합계 50mA)다.
DC 모터·스텝모터는 수백 mA 를 먹으므로 **반드시 드라이버 보드(ULN2003 등)를 경유**한다.

### 7-3. 배선은 전원을 끄고 한다

```bash
sudo poweroff
```

완전히 꺼진 뒤 어댑터를 뽑고 배선한다.

### 7-4. 3.3V 전용 모듈

| 모듈 | 전원 |
| --- | --- |
| RC522 (RFID) | **3.3V 전용** |
| SSD1306 (OLED) | 3.3V |
| ADXL345 | 3.3V |
| HC-SR04 | 5V (ECHO 분압 필수) |
| DHT11 | 3.3V / 5V 모두 가능 |

## 8. 난이도 순 진행 추천

| 순서 | 모듈 | 이유 |
| --- | --- | --- |
| 1 | **01. LED** | 배선 2가닥. 성공/실패가 눈에 바로 보인다 |
| 2 | **07. 스위치** | 입력 개념. LED 와 묶어서 동작 확인 |
| 3 | **06. 부저** | PWM 개념 도입 |
| 4 | **19. OLED** | I2C 첫 경험. `i2cdetect` 로 주소 확인하는 흐름을 익힌다 |
| 5 | **13. DHT11** | 센서 값 읽기 → 이후 MQTT telemetry 로 연결 |
| 6 | **16. 초음파** | 분압 회로 실습 |
| 7 | **RFID (RC522)** | SPI + 외부 라이브러리 |
| 8 | 03·04·05 모터류 | 드라이버·전원 분리 개념 필요 |

## 9. 이 프로젝트와의 연결

1단계 목표는 **01.LED 를 MQTT 로 켜고 끄는 것**이다.
이미 구축된 `Go Fiber robot server → EMQX` 파이프라인 끝에 파이를 붙이면,
챗봇에서 "불 켜줘" → 실제 LED 점등이 된다.

```
[챗봇] → [go_fiber_server] → [EMQX] → /Robot_Control_Command/{id} → [파이] → GPIO 21 LED
```

→ 로드맵은 [README](../README.md) 참조.

## 10. 부록 — 모듈별 배선도 직링크

네이버 블로그는 스크립트 기반이라 열람이 불편할 수 있다.
배선도 이미지는 CDN 직링크로 바로 볼 수 있어 아래에 정리해 둔다.
(저장소 각 폴더의 `README.md` 에 삽입된 이미지와 동일하다.)

| # | 모듈 | 배선도 |
| --- | --- | --- |
| 01 | LED | [그림 1](https://blogfiles.pstatic.net/MjAxOTA0MDFfMTE5/MDAxNTU0MDc4NjYzNzAx.RjTr-_Uziw45l2dEqR10W1ylxV0KWT6hDKgdcxPuHMgg.8UUVfboDLBn-d2mxvrFG4ldxSjqYJobnbNe_y9ajwM8g.PNG.elepartsblog/4.PNG?type=w2)  |
| 02 | RGB_LED | [그림 1](https://blogfiles.pstatic.net/MjAxOTA0MDNfMTY5/MDAxNTU0Mjc4Mzc5Njc2.szjY2EdJf7oR8U7ffp6uH4LLihp5PfytvkZvkn9z39gg.AuahOqKYFw4eYR-5VO7bmFQOTgboxumMUEj3hMCWfqwg.PNG.elepartsblog/1.PNG?type=w2) [그림 2](https://blogfiles.pstatic.net/MjAxOTA0MDNfMjky/MDAxNTU0Mjc4Nzc4OTE2.NnBoz2HF74ANnZcEGm_85XBqrdf1mcH6Qye8ySBZDUMg.GUjtz195pypSHnM3SXg7JcTvGAZSS-2adp2pZDfaFXcg.JPEG.elepartsblog/RGB.jpg?type=w2)  |
| 03 | Servo_motor | [그림 1](https://blogfiles.pstatic.net/MjAxOTA0MDVfMjk3/MDAxNTU0NDM4OTk2MTc1.BW2Hj_aSAHvE0gR0_QIzJyw-yRuKiF-AoPhjJ54p1rcg.sUJcy-tmGMoHgPNcBNMMaGHCpXQyoVqIMgT14S1VdvIg.PNG.elepartsblog/1.PNG?type=w2)  |
| 04 | DC_motor | [그림 1](https://blogfiles.pstatic.net/MjAxOTA0MDhfMTc1/MDAxNTU0Njk5NTIxODMx.hdBdEL11jW_O1Alj9VWefIF_swYKxA3covD8j4syhDMg.okpC8Zcba7-LyW5zlX0JRM9V1XRARkUJL01s_d2oPQcg.PNG.elepartsblog/2.PNG?type=w2)  |
| 05 | Step_motor | [그림 1](https://blogfiles.pstatic.net/MjAyMDA5MjhfMTUy/MDAxNjAxMjc3ODM5MjYz.BVU4qh6lQHkp-USnUoupIJUBmTSTaK0VlPXuXfcsFt4g.8uJbDX8elOirW7C82wk9J7YMVGpBVDRzURLAsCkH9IYg.PNG.elepartsblog/3.png?type=w2)  |
| 06 | Piezo_buzzer | [그림 1](https://blogfiles.pstatic.net/MjAxOTA0MTJfMTgg/MDAxNTU1MDM0Nzg4Mjc0.6gECj6t_K5Nj63cmW8ae-ojAVPELHu-ouuDfFGy4M8sg.FBAjZ2BCga7rjtmKPgDbINnn6G8pqhLommiqpBs8kpMg.PNG.elepartsblog/1.PNG?type=w2)  |
| 07 | Switch | [그림 1](https://blogfiles.pstatic.net/MjAxOTA0MTVfNTcg/MDAxNTU1MzExNDQxOTE5.N5OX1BGuGxqMCG5z_-Iycx6jM-ucQU-Bbdg17reniU0g.ElgkKhgsZm4FAU5sb2WbfSMP8ABdnlNYkbmMNh8NGTog.PNG.elepartsblog/3.PNG?type=w2)  |
| 08 | Tilt_ball_switch | [그림 1](https://blogfiles.pstatic.net/MjAxOTA0MTdfMjgg/MDAxNTU1NDYwMzA3OTA4.yyTMQM7t_UT04oPm-El-NSyphGlNHOR7wZ3JyrvEhNYg.JeO2Tt0isf3CrLZbItkaSdm8PyrkJ3mMkOFxc87ZRyYg.PNG.elepartsblog/2.PNG?type=w2)  |
| 09 | Rotary_encoder | [그림 1](https://blogfiles.pstatic.net/MjAxOTA0MTlfMzIg/MDAxNTU1NjMyMDYxMTc3.GpQB2gq_c-0UCT1opthra7-xKMwWQ92GVCAnQShq_y0g.o5c6gDu-HfDrKDHHwKR1t_nS9nY1NXWo-qa_0Q-BwuEg.PNG.elepartsblog/2.PNG?type=w2)  |
| 10 | Touch_keypad | [그림 1](https://blogfiles.pstatic.net/MjAxOTA0MjJfMjYx/MDAxNTU1ODkxODE4Njg0._Eb2OEykCK7-IOn-24anpHm_0miNEvRUza5Hs6kHPosg.k65BONY1gpkm1iynsw0-lIlsUqykDu1tl6OZd6cJwAkg.PNG.elepartsblog/2.PNG?type=w2)  |
| 11 | Joystick | [그림 1](https://blogfiles.pstatic.net/MjAxOTA0MjRfMjcx/MDAxNTU2MDg5MzIzNjkz.bnNgNCE-QXfmueZiHXizWtdlR1oPTF3EMzQ93xu9_Skg.ESqm1W6brEFmxHGINdygU0VvOO__yP161XPhKgAmgNgg.PNG.elepartsblog/2.PNG?type=w2)  |
| 12 | RTC_module | [그림 1](https://blogfiles.pstatic.net/MjAxOTA0MjZfMTcg/MDAxNTU2MjUxMjcxMzgw.J4z-wwxU_0MMlhJRQ4y0kVbSEPm0AtMWZ9CSs9VKNkkg.m2bphplJogQRETZ9yDPj45hbPFvD1DsjRZAG2wSK0S4g.JPEG.elepartsblog/8.jpg?type=w2)  |
| 13 | DHT11 | [그림 1](https://blogfiles.pstatic.net/MjAxOTA0MjlfMTY3/MDAxNTU2NTAwMDA4NDgx.Av6EbvwOMICIlTZP5XB62Qwak0XCGEHZSh9NcNS3jJMg.sYhG_NjwiVal9QNUa9fDohET7YY3ZT9inTorZMHh-xgg.PNG.elepartsblog/2.PNG?type=w2)  |
| 14 | Gas_sensor | [그림 1](https://blogfiles.pstatic.net/MjAxOTA1MDNfOTAg/MDAxNTU2ODQzMDc3ODMz.PZNsW8JYzxsy9anONDNDxaX3PllORvqGJW_gtvsreLsg.Mg7lMeWjY-vw_TCQdVtb8f0QgH65jpBkqnNEzpi8uAQg.PNG.elepartsblog/3.PNG?type=w2)  |
| 15 | 3-Axis_accelerometer | [그림 1](https://blogfiles.pstatic.net/MjAxOTA1MDhfMTU3/MDAxNTU3MjczOTQ1NDMz.NgPa31Cb9ysLPwsua_F6PWLZD1axfMztRzqfpIJR6cIg.0mIzRBRUnfUDXsVSzNHsINgVXdcvbvhAsf9l6UC2IaUg.PNG.elepartsblog/2.PNG?type=w2)  |
| 16 | Ultrasonic_sensors | [그림 1](https://blogfiles.pstatic.net/MjAxOTA1MTBfMTIg/MDAxNTU3NDQ3ODI2MDQx.1wmfCX0WNo8d5jHOw36lA2olOvcChRcIGV8WrBsTCdkg.1GIvPybxbjrPdEISB0oNlPQLoCMprvmA_5igxbWgEYYg.PNG.elepartsblog/3.PNG?type=w2)  |
| 17 | FND(7segment) | [그림 1](https://blogfiles.pstatic.net/MjAxOTA1MTNfMjM4/MDAxNTU3NzI2MzUxMzEz.2lLHFTnHHcA2wp9vwj5AV9mRZvwvpZ5mnEwJ9fi0QCQg.cWlZInhNLmcU4G5YRj3UJZ4P0zj1eYLKJee7_vEcP7Mg.PNG.elepartsblog/4.PNG?type=w2)  |
| 18 | 4Digit_FND | [그림 1](https://blogfiles.pstatic.net/MjAxOTA1MjJfOTkg/MDAxNTU4NDg3ODE1MjE1.nNMX1tQ9wEU10GOGJdwrT-otcSczkhY0pI_986Uy5Fsg.Sx6JWe_p67-cAMKYUrPtgkLDhPllfl7pcXRTADzTK3og.PNG.elepartsblog/3.PNG?type=w2)  |
| 19 | OLED_module | (블로그 본문 참조) |
| 20 | IR-remote | [그림 1](https://blogfiles.pstatic.net/MjAxOTA2MDdfMjAw/MDAxNTU5ODk1NTcwMjY4.qkdgOVPLJ7hkjRQTfYRBj_zAX4lUkW9QnpSYkQil5VQg.ZUC1Qmy6JO6tQwXmWkWCTH3Z4CzMJyt0sQu3RptG72Ag.PNG.elepartsblog/10.PNG?type=w2)  |
| 21 | Bluetooth | [그림 1](https://blogfiles.pstatic.net/MjAxOTA2MTJfMTgy/MDAxNTYwMzI1MTM3MDIz.3DDAqExLU9iPUg_iwywkGyirG-zyQhNHinwj_VI9Nq8g.gOOUf0N9IZw2QLPLPpDUG74po_vt5H7ylGcW-Zl_Tr4g.PNG.elepartsblog/9.PNG?type=w2)  |
