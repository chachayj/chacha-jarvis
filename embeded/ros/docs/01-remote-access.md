# 01. 라즈베리파이 원격 접속 (Tailscale)

> 측정·구축일: 2026-09-06

개발 PC(WSL2)에서 라즈베리파이에 SSH 로 붙기 위한 구성. **회선이 달라도 붙는다.**

## 1. 문제 — 같은 집인데 서로 안 보였다

파이에 `172.30.1.22` 가 할당돼 있는데 WSL2 에서도, 윈도우에서도 닿지 않았다.

### 진단 결과

| | 개발 PC (윈도우) | 라즈베리파이 |
| --- | --- | --- |
| IP | `175.213.xx.xxx/24` — **공인 IP** | `172.30.1.22/24` — 사설 IP |
| 게이트웨이 | `175.213.xx.254` (통신사 장비) | 공유기 (`172.30.1.x` 대역) |
| 인터페이스 | 유선 Realtek GbE **only** (무선랜 없음) | `wlan0` (WiFi) |

결정적 근거 두 가지:

1. 윈도우 라우팅 테이블에 `172.30.1.0/24` 경로가 **아예 없음**
2. 윈도우에서 직접 `Test-Connection 172.30.1.22` → `False`
   → WSL2 설정 문제가 아니라 **윈도우 자체가 못 감**

`172.30.1.x` 는 KT 공유기의 기본 LAN 대역이다.
즉 **PC 랜선은 공유기를 거치지 않고 모뎀/ONT 앞단에서 딴 것**이고, 파이는 공유기에 물려 있다.
같은 집이지만 라우터 기준 안/밖으로 갈려 서로 보이지 않았다.

### 왜 Tailscale 인가

| 대안 | 판단 |
| --- | --- |
| PC 랜선을 공유기 LAN 포트로 이동 | 가장 간단하지만 PC 의 공인 IP 를 잃음 |
| 공유기 포트포워딩 | 인터넷에 SSH 를 여는 셈 → 보안상 부적합 |
| **Tailscale** | ✅ 채택. 회선 무관, 포트포워딩·공인 IP 불필요 |

WireGuard 기반 메시 VPN 이라 양쪽이 **아웃바운드 인터넷만 되면** 붙는다.
좌표 서버를 통해 NAT 홀펀칭으로 P2P 직결을 시도하고, 실패하면 DERP 릴레이(443)로 자동 폴백한다.
나중에 **집 밖에서 로봇에 접속하는 시나리오**로 그대로 확장된다.

## 2. 설치

### 개발 PC (WSL2 / Ubuntu)

WSL2 에서 네이티브로 돌리려면 `/dev/net/tun` 과 systemd 가 필요하다. 먼저 확인한다.

```bash
ls -l /dev/net/tun          # 있어야 함
cat /etc/wsl.conf           # [boot] systemd=true 여야 함
```

`systemd=true` 가 없으면 `/etc/wsl.conf` 에 추가하고 `wsl --shutdown` 후 재기동한다.

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --hostname=wsl-chacha-dev
```

출력되는 인증 URL 을 브라우저에서 열어 로그인한다.

### 라즈베리파이

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --ssh --hostname=rpi-jarvis
```

- 설치 스크립트가 arm64/armhf 를 자동 판별한다
- `--ssh` 를 붙이면 **Tailscale SSH** 가 켜져 SSH 키·비밀번호 설정이 불필요해진다
- **반드시 PC 와 같은 계정으로 로그인**해야 서로 보인다

## 3. 검증

```bash
tailscale status
```

```
100.78.253.44   wsl-chacha-dev   linux   -
100.107.41.54   rpi-jarvis       linux   -
```

```bash
ping -c 3 rpi-jarvis      # 또는 100.x 주소
ssh root@rpi-jarvis 'uname -a'
```

> 첫 패킷만 400ms 대(릴레이)로 나오다가 이후 한 자릿수 ms 로 떨어지면
> **홀펀칭이 성공해 P2P 직결로 전환된 것**이다. 정상이다.

## 4. 자주 밟는 함정

### `tailnet policy does not permit you to SSH as user "pi"`

Tailscale SSH 는 tailnet ACL 의 `ssh` 규칙을 따른다.
기본 정책에서 통과하는 계정으로 붙거나, admin 콘솔에서 ACL 의 `users` 를 열어준다.

```bash
ssh root@rpi-jarvis        # 기본 정책에서 통과
```

### 인증 URL 이 안 뜨고 멈춘 것처럼 보임

`tailscale up` 은 인증 완료까지 블로킹된다. 백그라운드로 돌리고 로그에서 URL 만 뽑아도 된다.

```bash
setsid nohup tailscale up --hostname=<name> > /tmp/ts-up.log 2>&1 < /dev/null &
grep 'https://login' /tmp/ts-up.log
```

### `Needs login` 에서 안 넘어감

`systemctl status tailscaled` 로 데몬이 `active (running)` 인지 먼저 확인한다.

## 5. ⚠️ OS 재설치 시 재등록 절차

**파이의 OS 를 갈아엎으면 Tailscale 노드 정보가 전부 사라진다.**
(Ubuntu 24.04 재설치가 예정돼 있으므로 반드시 아래를 따른다.)

1. 재설치 **전**, [admin 콘솔](https://login.tailscale.com/admin/machines) 에서 기존 `rpi-jarvis` 노드를 **삭제**한다
   - 삭제하지 않으면 새 노드가 `rpi-jarvis-1` 같은 이름으로 등록된다
2. OS 재설치 후 파이에서 SSH 를 먼저 켠다
   ```bash
   sudo systemctl enable --now ssh
   ```
3. 위 [2. 설치](#2-설치) 의 라즈베리파이 절차를 그대로 반복한다
4. `tailscale status` 로 재확인

> 재설치 직후에는 Tailscale 이 없으므로 파이에 **물리적으로 접근**(모니터+키보드)하거나,
> 같은 공유기 WiFi 에 붙은 폰/노트북에서 `172.30.1.22` 로 SSH 해야 한다.

## 6. 참고: 노드 정보

| 노드 | Tailscale IP | 역할 |
| --- | --- | --- |
| `wsl-chacha-dev` | `100.78.253.44` | 개발 PC (WSL2 / Ubuntu 26.04) |
| `rpi-jarvis` | `100.107.41.54` | 라즈베리파이 4 |

`100.64.0.0/10` (CGNAT) 대역이라 tailnet 내부에서만 유효하다. 외부에 노출되는 주소가 아니다.
