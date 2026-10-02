# sgshsmctt 실행 가이드 — 처음 받은 장비에서 접속까지

[README](README.md)가 "무엇이 어떻게 구성돼 있나"를 다루는 참고서라면, 이 문서는
**빈 장비에서 서버를 띄우고 클라이언트로 접속하기까지를 순서대로 따라가는 절차서**입니다.
Windows(Docker Desktop)와 Linux(Docker Engine) 둘 다 다룹니다. 실측 근거는 맨 끝의
[실측 기록](#실측-기록)에 있습니다.

---

## 목차

1. [준비물 확인](#1-준비물-확인)
2. [저장소 받기](#2-저장소-받기)
3. [최초 1회 설정](#3-최초-1회-설정)
4. [기동](#4-기동)
5. [정상 기동 확인](#5-정상-기동-확인)
6. [접속](#6-접속)
7. [운영 — 콘솔·정지·재시작·백업](#7-운영--콘솔정지재시작백업)
8. [자동 기동(재부팅 후)](#8-자동-기동재부팅-후)
9. [문제 해결 요약표](#9-문제-해결-요약표)
10. [부록 — 26.2 명령 문법 메모](#10-부록--262-명령-문법-메모)
11. [실측 기록](#실측-기록)

---

## 1. 준비물 확인

### Docker

| 플랫폼 | 설치 | 확인 |
|--------|------|------|
| Windows 10/11 | [Docker Desktop](https://www.docker.com/products/docker-desktop/) (WSL2 백엔드) | `docker version` 에 Server 항목이 나와야 함 |
| Ubuntu / Debian | `sudo apt install docker.io docker-compose-v2` 또는 [공식 설치](https://docs.docker.com/engine/install/) | `docker compose version` 이 v2 이어야 함 |
| macOS | Docker Desktop | `docker version` |

- **`docker compose`(v2 플러그인 문법)** 를 씁니다. 하이픈이 든 `docker-compose` v1 은 지원하지 않습니다.
- Linux 에서 `sudo` 없이 쓰려면 `sudo usermod -aG docker $USER` 후 재로그인.
- **Hyper-V / WSL2 를 쓸 수 없는 VM 안(중첩 가상화 미지원)** 에서는 Docker Desktop 이 뜨지
  않습니다. 그런 장비에서는 이 저장소로 서버를 띄울 수 없습니다.

### 메모리 — 기본은 자동입니다

커밋된 compose 파일은 메모리 값을 고정하지 않습니다. `MEMORY` 가 빈 값이라 **JVM 이 장비 메모리의
25% 를 최대 힙으로 스스로 잡고**, 컨테이너 상한도 두지 않습니다. 그래서 어느 장비에서 띄워도
메모리를 넘쳐 죽지 않습니다. 실행 장비가 정해지면 그 장비에 맞춰 값을 고정합니다
→ [3.2 메모리 값 고정](#32-메모리-값-고정-선택)

| 장비 | 자동일 때 최대 힙 | 고정할 때 권장 `MEMORY` / `mem_limit` |
|------|-------------------|----------------------------------------|
| Linux, RAM 32GB 이상 | 약 8G 이상 | `16G` / `20g` |
| Linux, RAM 16GB | 약 4G | `6G` / `8g` — 실측 컨테이너 사용량 4.1GiB, 스왑 0 ([실측 기록](#실측-기록)) |
| Linux, RAM 8GB | 약 2G | `3G`~`4G` / `5g`~`6g`, `view-distance` 는 10 정도로 |
| Windows PC 32GB (Docker Desktop) | 약 4G | WSL VM 이 기본으로 PC RAM 의 절반만 받습니다. `16G` 를 쓰려면 VM 메모리부터 늘립니다([3.2](#32-메모리-값-고정-선택)) |

> **`MEMORY` 줄을 지우거나 주석 처리하지 마세요.** 빈 값과 달리 itzg 이미지 기본값 **1G** 로
> 고정되어, `view-distance` 30 인 이 서버는 금방 힙이 모자랍니다.
>
> 반대로 **장비보다 큰 값을 고정해도 뜨긴 뜹니다.** 다만 JVM 은 `-Xmx` 만 보고 GC 시점을 정하므로
> 호스트 메모리 압박을 못 느낀 채 자라다가 **한참 뒤에 OOM killer 에 죽습니다.** "처음엔 잘
> 되다가 몇 시간 뒤 컨테이너가 사라진다"는 증상이 이것입니다.

### 네트워크

| 포트 | 프로토콜 | 용도 |
|------|----------|------|
| 25565 | TCP | Java Edition |
| 19132 | **UDP** | Bedrock Edition (Geyser) |

같은 LAN 에서는 포트 개방 없이 호스트 IP 로 바로 붙습니다. 인터넷에서 붙이려면 공유기
포트 포워딩 두 개(25565/TCP, 19132/UDP)가 필요합니다.

### 디스크

월드 데이터 수 GB + 백업본. 서버 jar·라이브러리·플러그인은 매 기동/업그레이드마다 새로 받습니다.

---

## 2. 저장소 받기

```bash
git clone https://github.com/genishs/sgshsmctt.git
cd sgshsmctt
```

받은 직후 상태:

```
sgshsmctt/
├── RUNNING.md                       ← 이 문서
├── README.md                        ← 참고서 (구조·설정·버전 업그레이드·트러블슈팅)
└── docker/
    ├── docker-compose.yml           ← 서버 정의 (버전·메모리·포트·볼륨)
    ├── docker-compose.override.yml.example  ← 장비별 메모리 고정값 템플릿
    ├── server.properties.example    ← 서버 설정 템플릿
    ├── pull-and-up.sh / .bat        ← 최신 이미지 pull 후 기동 (권장 기동 명령)
    ├── plugins/                     ← 직접 넣는 플러그인 jar (기본은 비어 있음)
    └── scripts/update-plugins.sh    ← 기동 시 Geyser·Floodgate·ViaVersion 자동 설치
```

`docker/server.properties` 와 `docker/data/` 는 git 에 없습니다. 다음 단계에서 만듭니다.

---

## 3. 최초 1회 설정

### 3.1 server.properties 만들기 (필수)

```powershell
# Windows (PowerShell / cmd)
cd docker
copy server.properties.example server.properties
```

```bash
# Linux / macOS
cd docker
cp server.properties.example server.properties
```

이 파일이 **없는 채로 기동하면 docker 가 같은 이름의 빈 디렉터리를 만들어** 서버가 뜨지 않습니다.
이미 그렇게 됐다면 [문제 해결 요약표](#9-문제-해결-요약표)를 보세요.

바꿀 만한 항목만 추리면:

| 항목 | 템플릿 값 | 설명 |
|------|-----------|------|
| `level-name` | `2026sgshs` | 월드 폴더명. **나중에 바꾸면 새 월드가 생깁니다** |
| `motd` | `아빠가 새로 열어둔 마크서버` | 서버 목록에 보이는 문구 |
| `difficulty` | `hard` | `peaceful` / `easy` / `normal` / `hard` |
| `max-players` | `20` | 동시 접속 인원 |
| `view-distance` | `30` | 시야 거리(청크). 메모리·CPU 를 가장 많이 먹는 값. 저사양이면 10~12 |
| `online-mode` | `true` | Java 정품 인증. Bedrock 은 floodgate 가 별도로 인증하므로 영향 없음 |
| `rcon.password` | (비어 있음) | **비워 두세요.** 이미지가 매 기동마다 임의 값을 만들어 채웁니다 (아래 참고) |

> **rcon 비밀번호에 대해.** itzg 이미지는 `RCON_PASSWORD` 환경변수가 없으면 **기동할 때마다
> 임의 비밀번호를 만들어 `server.properties` 의 `rcon.password` 에 써넣습니다.** 직접 적어 둔
> 값은 덮입니다. 컨테이너 안의 `rcon-cli` 는 그 값을 알아서 읽으므로 콘솔 접속에는 지장이
> 없습니다([7.1](#71-서버-콘솔에-명령-넣기)). 외부 RCON 도구로 고정 비밀번호가 필요할 때만
> `docker-compose.override.yml` 에 `RCON_PASSWORD` 를 넣으세요. RCON 포트 25575 는 컨테이너
> 밖으로 열려 있지 않습니다.

이 파일은 컨테이너에 읽기·쓰기로 마운트되어 **기동할 때마다 이미지가 정규화해서 다시 씁니다.**
주석의 타임스탬프가 바뀌고 새 버전에서 추가된 키가 들어오는 것은 정상입니다.

### 3.2 메모리 값 고정 (선택)

자동(장비 메모리의 25%)으로 충분하면 건너뜁니다. 값을 고정하는 방법은 두 가지입니다.

- **그 장비에서만 고정.** 같은 폴더에 `docker-compose.override.yml` 을 둡니다. compose 는 이
  이름의 파일이 있으면 자동으로 겹쳐 읽고, 이 파일은 git 에서 제외되어 장비마다 값이 달라도 됩니다.
- **모든 장비 공통으로 고정.** `docker-compose.yml` 의 `MEMORY` 를 바꾸고 `mem_limit` /
  `memswap_limit` 주석을 풉니다. 커밋되는 값이므로 실행 장비가 하나로 정해졌을 때 씁니다.

override 를 쓰는 경우:

```bash
cd docker
cp docker-compose.override.yml.example docker-compose.override.yml
```

템플릿 내용(RAM 32GB 이상 Linux 기준. 다른 장비 값은 파일 안 주석에 있습니다):

```yaml
services:
  mc:
    environment:
      MEMORY: "16G"
    mem_limit: 20g
    memswap_limit: 20g
```

값의 의미:

- `MEMORY` — JVM 힙(`-Xms`/`-Xmx`). 서버가 실제로 쓰는 메모리의 대부분.
- `mem_limit` — 컨테이너 전체 상한. 힙 + JVM 자체 + 네이티브 버퍼가 들어가므로 `MEMORY` 보다
  25% 정도 여유를 둡니다(itzg 권장). 넘으면 OOM killer 가 컨테이너를 죽입니다.
- `memswap_limit` — `mem_limit` 과 **같게** 둡니다. 그러면 컨테이너의 스왑 사용량이 0 으로
  잠깁니다. 의도된 설정입니다: GC 는 살아 있는 힙 전체를 훑기 때문에 힙이 스왑으로 밀리면
  틱 루프가 초~분 단위로 멈춥니다. **JVM 힙은 스왑시키지 않습니다.** 스왑을 늘려 메모리
  부족을 메우려 하지 마세요.
- 자동으로 되돌리려면 override 파일을 지웁니다. `MEMORY` 줄만 지우면 자동이 아니라 1G 가 됩니다.

**Windows(Docker Desktop)에서 큰 값을 쓰려면** WSL VM 메모리부터 늘립니다. 컨테이너는 WSL VM
안에서 돌고, 이 VM 은 기본으로 PC RAM 의 50% 만 받습니다. 32GB PC 에서 `16G` 를 쓰는 예:

```ini
# %UserProfile%\.wslconfig
[wsl2]
memory=24GB
```

저장한 뒤 PowerShell 에서 `wsl --shutdown` 을 실행하고 Docker Desktop 을 다시 켭니다.

적용된 값 확인 (기동 전에 해 보세요):

```bash
docker compose config | grep -E "MEMORY|mem_limit|memswap_limit"
```

`MEMORY` 가 빈 값이면 자동입니다. override 를 뒀다면 그 값과 `mem_limit` / `memswap_limit` 이
함께 보여야 합니다.

### 3.3 (선택) 플러그인 직접 추가

Geyser·Floodgate·ViaVersion 은 매 기동마다 자동으로 최신을 받으므로 **아무것도 넣지 않아도
크로스플레이가 됩니다.** 그 밖의 플러그인은 `docker/plugins/` 에 jar 를 넣으면 기동 시
`/data/plugins/` 로 복사됩니다. 자세한 것은 README 의 [스테이징 플러그인 추가](README.md#스테이징-플러그인-추가).

---

## 4. 기동

세 가지 방법이 있고, 어느 것이든 결과는 같습니다.

### 방법 A — pull-and-up 스크립트 (권장)

최신 itzg 이미지를 받고, 참조를 잃은 구 이미지를 정리한 뒤 기동합니다.
**저장소 루트에서 실행해도 됩니다** (스크립트가 스스로 `docker/` 로 이동).

```bash
# Linux / macOS
bash docker/pull-and-up.sh
```

```bat
:: Windows (cmd / PowerShell)
docker\pull-and-up.bat
```

### 방법 B — compose 직접

```bash
cd docker
docker compose up -d
```

`docker/` 폴더 **안에서** 실행해야 합니다. 밖에서 하면 `no configuration file provided` 가 납니다.

### 방법 C — 한 번 띄운 뒤에는 그냥 둔다

`restart: unless-stopped` 가 걸려 있어 크래시·재부팅 후 Docker 가 뜨면 컨테이너도 따라
뜹니다. 단, `docker compose stop` / `docker stop` 으로 **직접 멈춘 컨테이너는 재부팅 후에도
자동으로 뜨지 않습니다.** → [8. 자동 기동](#8-자동-기동재부팅-후)

### 첫 기동은 오래 걸립니다

첫 기동은 이미지(수백 MB) + Purpur 서버 jar + 라이브러리 + 플러그인을 전부 받고 월드를
새로 생성하므로 **회선에 따라 수 분** 걸립니다. 두 번째부터는 40~80초입니다.

---

## 5. 정상 기동 확인

### 5.1 로그 따라가기

```bash
docker logs -f mc-crossplay
```

순서대로 이런 것이 보여야 합니다.

**① 플러그인 스크립트 요약** — `[Script]` 접두사

```
[Script] ============ 설치 결과 ============
[Script]  서버 버전  : 26.2 (최신)
[Script]  Geyser     : ✓ 설치됨 (베드락 크로스플레이 가능)
[Script]  Floodgate  : ✓ 설치됨
[Script]  ViaVersion : ✓ 설치됨
[Script] =======================================
```

- `서버 버전` 괄호가 `업그레이드 가능 → 26.x` 이면 뒤처진 상태. 서버는 그대로 뜹니다.
  올리는 절차는 README 의 [버전 업그레이드](README.md#버전-업그레이드).
- `✗ 미설치` 가 있으면 그 단계 다운로드가 실패한 것. Geyser 가 미설치면 **Bedrock 만** 못 붙습니다.

**② 서버 jar 준비** — itzg 이미지

```
[init] Resolved Purpur version 26.2 to build 2632
```

**③ 서버 기동 완료**

```
[..:..:.. INFO]: This server is running Purpur version 26.2-2632-...
[..:..:.. INFO]: Done (17.795s)! For help, type "help"
```

**④ Geyser 대기** — Bedrock 접속을 받을 준비

```
[..:..:.. INFO]: [Geyser-Spigot] Started Geyser on UDP port 19132
```

`Done` 뒤에 뜨는 다음 경고는 **정상**이며 무시합니다(서버가 최신이라 변환해 줄 더 새로운
클라이언트가 없다는 뜻):

```
[ViaVersion] ViaVersion does not have any compatible versions for this server version!
```

### 5.2 상태 한 줄 확인

```bash
docker ps --filter name=mc-crossplay --format "{{.Status}}"
```

`Up 2 minutes (healthy)` 가 목표입니다. 기동 중 40~80초 동안은 `(health: starting)` 또는
`(unhealthy)` 로 보이는 것이 정상입니다.

### 5.3 메모리 실제 사용량

```bash
docker stats --no-stream mc-crossplay
```

`MEM USAGE` 가 실제 사용량입니다. 상한을 두지 않은 자동 상태에서는 `LIMIT` 칸에 Docker 가 쓸 수
있는 메모리 전체가 보입니다. 렉이 심하거나 로그에 `java.lang.OutOfMemoryError: Java heap space` 가
보이면 힙이 모자란 것이므로 값을 고정해 늘립니다([3.2](#32-메모리-값-고정-선택)). 값을 고정했다면
`MEM USAGE / LIMIT` 이 상한의 70% 를 꾸준히 넘을 때 `mem_limit` 을 늘립니다. 힙 6G 기준 실측은
4.1GiB / 8GiB 였습니다.

---

## 6. 접속

### 6.1 호스트 IP 알아내기

```powershell
# Windows
ipconfig | findstr IPv4
```

```bash
# Linux
hostname -I
```

### 6.2 Java Edition

멀티플레이 → 서버 추가 → 주소 `<호스트IP>:25565` (같은 PC 면 `localhost`).
`online-mode=true` 이므로 정품 계정이어야 합니다.

**클라이언트 버전** — 서버와 같은 26.2 또는 그 이후만 붙습니다. 그보다 오래된 클라이언트는
ViaBackwards 가 없어서 접속되지 않습니다.

### 6.3 Bedrock Edition (모바일·콘솔·Windows 스토어판)

서버 → 추가 → 주소 `<호스트IP>`, 포트 `19132`. 같은 LAN 에서는 **친구 탭 / LAN 게임**에도
자동으로 뜹니다. 정품 Java 계정이 없어도 floodgate 가 인증해 줍니다(닉네임 앞에 `.` 이 붙음).

콘솔(Switch·PS·Xbox)은 서버 주소를 직접 입력할 수 없어 별도 우회(BedrockConnect 등)가 필요합니다.
이 저장소는 그 부분을 다루지 않습니다.

### 6.4 안 붙을 때

| 증상 | 확인 |
|------|------|
| Java 만 안 붙음 | 로그에 `Done` 이 떴는지 → 클라이언트가 26.2 이상인지 → 방화벽 25565/TCP |
| Bedrock 만 안 붙음 | 로그에 `Started Geyser on UDP port 19132` 가 있는지 → **UDP** 로 열었는지 → Geyser `✗ 미설치` 아닌지 |
| 둘 다 안 붙음 | `docker ps` 에 컨테이너가 있는지 → 호스트 IP 가 맞는지 → Windows 방화벽에서 Docker Desktop 백엔드 인바운드 허용 |
| 인터넷에서 안 붙음 | 공유기 포트 포워딩 25565/TCP, 19132/UDP → 공인 IP 로 접속 |

Windows 방화벽 규칙을 직접 넣어야 할 때:

```powershell
New-NetFirewallRule -DisplayName "Minecraft Java" -Direction Inbound -Protocol TCP -LocalPort 25565 -Action Allow
New-NetFirewallRule -DisplayName "Minecraft Bedrock" -Direction Inbound -Protocol UDP -LocalPort 19132 -Action Allow
```

---

## 7. 운영 — 콘솔·정지·재시작·백업

### 7.1 서버 콘솔에 명령 넣기

**rcon-cli (권장).** 이미지에 들어 있고, 임의 생성된 rcon 비밀번호를 알아서 읽습니다.

```bash
# 대화형 콘솔 (나올 때는 Ctrl+D 또는 exit)
docker exec -i mc-crossplay rcon-cli

# 한 줄 실행
docker exec mc-crossplay rcon-cli op 플레이어이름
docker exec mc-crossplay rcon-cli list
docker exec mc-crossplay rcon-cli say 5분 뒤 재시작합니다
```

**attach.** compose 에 `tty`/`stdin_open` 이 켜져 있어 서버 콘솔에 직접 붙을 수도 있습니다.
**빠져나올 때 반드시 `Ctrl+P` `Ctrl+Q`** 를 씁니다. `Ctrl+C` 를 누르면 서버가 종료됩니다.

```bash
docker attach mc-crossplay
```

Bedrock 플레이어를 op 할 때는 닉네임 앞의 `.` 까지 포함합니다: `op .닉네임`.

### 7.2 정지 / 재시작 / 재생성

| 하고 싶은 것 | 명령 (`docker/` 안에서) | 비고 |
|--------------|-------------------------|------|
| 잠시 멈춤 | `docker compose stop` | 월드 저장 후 종료. **재부팅 후 자동으로 뜨지 않음** |
| 다시 켬 | `docker compose start` 또는 `up -d` | |
| 재시작 | `docker compose restart` | 엔트리포인트가 다시 돌아 **플러그인이 최신으로 재설치됨** |
| compose 파일 바꾼 뒤 | `docker compose up -d --force-recreate` | `restart` 는 바뀐 설정을 반영하지 않음 |
| 컨테이너 제거 | `docker compose down` | `docker/data/` 의 월드는 호스트에 남음 |
| 이미지까지 최신화 | `bash docker/pull-and-up.sh` / `docker\pull-and-up.bat` | 마인크래프트 **버전은 안 바뀜** |

### 7.3 백업

월드는 `docker/data/<level-name>/` 입니다. **정지한 상태에서** 묶습니다. 기동 중에 뜨면
저장 중인 청크가 섞여 깨질 수 있습니다.

```bash
cd docker
docker compose stop
tar -C data -cf data/bsgshs$(date +%Y%m%d)01.tar 2026sgshs
docker compose start
```

```powershell
# Windows
cd docker
docker compose stop
tar -C data -cf data\bsgshs$(Get-Date -Format yyyyMMdd)01.tar 2026sgshs
docker compose start
```

`docker/data/` 안에 두면 git 에서 자동 제외되지만 같은 디스크입니다. 중요한 시점의 백업은
바깥으로 복사하세요. 버전 업그레이드 전에는 **반드시** 백업합니다(월드 변환은 되돌릴 수 없음).

### 7.4 버전 올리기

기동 로그가 `업그레이드 가능 → 26.x` 를 알려줄 때만. 절차는 README 의
[버전 업그레이드](README.md#버전-업그레이드) — 요약하면 백업 → `VERSION` 수정 → `down`/`up -d` → 로그 확인.
**Purpur 가 아직 지원하지 않는 버전으로 올리면 서버 jar 를 못 받아 뜨지 않습니다.**

### 7.5 로그 파일

- 콘솔: `docker logs mc-crossplay` (`--since 1h`, `--tail 200` 등)
- 파일: `docker/data/logs/latest.log`, 지난 것은 날짜별 `.gz`
- 오류만: `docker logs mc-crossplay 2>&1 | grep -E "ERROR|WARN"`

---

## 8. 자동 기동(재부팅 후)

`restart: unless-stopped` 의 동작:

| 상황 | 재부팅 후 |
|------|-----------|
| `up -d` 로 띄워 놓고 재부팅 | Docker 가 뜨면 **자동 기동** |
| 크래시로 죽음 | **자동 재기동** |
| `docker compose stop` / `docker stop` 으로 직접 멈춤 | 다시 `start` / `up -d` 할 때까지 **안 뜸** |

- **Windows.** Docker Desktop 설정 → General → *Start Docker Desktop when you sign in* 을 켭니다.
  로그인해야 뜬다는 점에 유의(로그인 전에는 서버도 없음). 로그인 없이 띄우려면 Linux 로.
- **Linux.** `sudo systemctl enable docker` 만 되어 있으면 부팅 시 Docker 가 뜨고 컨테이너가
  따라 뜹니다. 별도 systemd 유닛은 필요 없습니다.

---

## 9. 문제 해결 요약표

| 증상 | 원인 | 조치 |
|------|------|------|
| `no configuration file provided` | `docker/` 밖에서 `docker compose` 실행 | `cd docker` 또는 `pull-and-up` 사용 |
| 뜨자마자 죽고 `server.properties` 가 **폴더**로 생김 | 3.1 을 건너뜀 | `down` → 폴더 삭제 → 템플릿 복사 → `up -d` |
| `OOMKilled=true` (`docker inspect mc-crossplay --format "{{.State.OOMKilled}}"`) | 고정한 `MEMORY`/`mem_limit` 이 장비를 초과 | 둘 다 낮추거나 override 를 지워 자동으로 되돌림([3.2](#32-메모리-값-고정-선택)) |
| 몇 시간 뒤 컨테이너가 사라짐 | 위와 같음. 부팅은 되지만 힙이 자라다 죽는 것 | 위와 같음 |
| 렉이 심하고 로그에 `OutOfMemoryError: Java heap space` | 힙 부족. `MEMORY` 줄이 지워져 1G 가 됐거나, 작은 장비에서 자동값(25%)이 모자람 | `MEMORY: ""` 인지 확인하고, 모자라면 값을 고정해 늘림 |
| 종료코드 137 인데 `OOMKilled=false` | 외부에서 정지(`docker stop`, Docker Desktop 종료) | 다시 `up -d` |
| `Resolved Purpur version ... 실패` | `VERSION` 을 Purpur 가 아직 지원 안 함 | Purpur 가 지원하는 버전으로 되돌림 |
| `[Script]` 요약에 `✗ 미설치` | 다운로드 실패(회선·API 장애) | `docker compose restart` 로 재시도. Geyser 없이도 Java 는 정상 |
| Geyser `does not support the Java version that Geyser requires` | 서버 버전이 Geyser 요구보다 낮음 | 버전 업그레이드 |
| 클라이언트 `Outdated client` | 클라이언트가 서버(26.2)보다 오래됨 | 클라이언트 업데이트(ViaBackwards 미설치) |
| Bedrock 만 안 됨 | UDP 를 TCP 로 열었거나 Geyser 미설치 | 19132 **UDP** 확인, 로그의 `Started Geyser` 확인 |
| 첫 기동이 5분 넘게 걸림 | 이미지·jar·월드 생성 | 정상. `docker logs -f` 로 진행 확인 |

---

## 10. 부록 — 26.2 명령 문법 메모

26.2 의 `/give` 인챈트 문법은 축약형입니다. 1.20.5~1.21.4 의 `{levels:{...}}` 래퍼는
`Malformed component` 로 실패합니다.

```
/give @s diamond_sword[minecraft:enchantments={sharpness:255}]
/give @s netherite_chestplate[minecraft:enchantments={protection:200,thorns:100}]
```

- 레벨 255 는 그대로 저장되지만 바닐라 **방어는 EPF 20(피해 감소 80%)에서 잘립니다.** 보호 200 ≠ 무적.
- 가시(thorns)는 상한이 없습니다.

---

## 실측 기록

| 일자 | 장비 | 결과 |
|------|------|------|
| 2026-09-04 | Linux VM (Ubuntu, RAM 15.9G + swap 3.8G, Docker Engine) | Purpur 26.2-2632 `Done (17.795s)`. Geyser 2.11.2 / floodgate 2.2.5 / ViaVersion 5.11.0 자동 설치. Bedrock 클라이언트가 같은 LAN 에서 UDP 19132 로 접속·플레이 확인. override 로 `MEMORY=6G`, `mem_limit=memswap_limit=8g` 적용 시 컨테이너 사용량 **4.1GiB / 8GiB, 스왑 0**. |
| 2026-09-04 | 같은 장비 | 당시 커밋값 `MEMORY=28G` 그대로도 `java -Xms28g -Xmx28g -version` 은 exit 0 — 즉 **뜬다**. `vm.overcommit_memory=1` + `USE_AIKAR_FLAGS` 기본 off(`AlwaysPreTouch` 없음)라 힙을 미리 만지지 않기 때문. 문제는 기동이 아니라 그 뒤의 성장. |
| 2026-09-04 | 같은 장비 | `docker run -m 2g --memory-swap 2g` → `memory.swap.max=0`. `memswap_limit == mem_limit` 은 스왑을 0 으로 잠근다(의도). |
