# sgshsmctt — Minecraft Java + Bedrock 크로스플레이 서버

Docker 기반 마인크래프트 서버입니다. Java Edition과 Bedrock Edition 플레이어가 동일한 서버에서 함께 플레이할 수 있도록 설계되어 있으며, 서버 시작 시 플러그인을 자동으로 최신 버전으로 받아옵니다.

---

## 목차

1. [요구사항](#요구사항)
2. [구조](#구조)
3. [빠른 시작](#빠른-시작)
4. [플러그인 자동 설치 로직](#플러그인-자동-설치-로직)
5. [설정](#설정)
6. [포트](#포트)
7. [버전 업그레이드](#버전-업그레이드)
8. [백업](#백업)
9. [클라이언트 버전 호환](#클라이언트-버전-호환)
10. [트러블슈팅](#트러블슈팅)

---

## 요구사항

- **Docker Desktop** (Windows / macOS) 또는 Docker Engine (Linux)
- **Git** (저장소 클론 시)
- PowerShell 또는 bash 쉘
- **메모리**: 현재 `MEMORY=28G`, 컨테이너 상한 30GB로 설정되어 있습니다. 사양이 낮은
  머신에서는 [docker-compose.yml](docker/docker-compose.yml)의 `MEMORY`와 `mem_limit`을
  먼저 낮춰야 합니다.
- **디스크**: 월드 데이터 기준 수 GB + 백업본. 서버 jar와 라이브러리는 매 버전 업그레이드마다
  새로 받습니다.

---

## 구조

```
sgshsmctt/
├── docker/
│   ├── docker-compose.yml        # 서버 컨테이너 정의 (버전·메모리·포트·볼륨)
│   ├── server.properties         # 실제 서버 설정 — git 제외 (비밀값 포함)
│   ├── server.properties.example # 위 파일의 템플릿 (비밀값만 비어 있음)
│   ├── pull-and-up.sh            # 최신 이미지 pull 후 서버 기동 (Linux/macOS)
│   ├── pull-and-up.bat           # 최신 이미지 pull 후 서버 기동 (Windows)
│   ├── plugins/                  # 스테이징 플러그인 폴더 (jar 직접 배치 시 사용)
│   ├── scripts/
│   │   └── update-plugins.sh     # 서버 기동 전 플러그인 자동 설치 스크립트
│   └── data/                     # 런타임 데이터 — git 제외
├── .github/
│   └── copilot-instructions.md   # AI 에이전트용 프로젝트 가이드
├── LICENSE
└── README.md
```

git에서 제외되는 항목 ([.gitignore](.gitignore)):

| 경로 | 이유 |
|------|------|
| `docker/data/` | 월드·로그·유저 데이터 등 런타임 데이터. 서버 jar와 백업 tar도 여기 쌓입니다 |
| `docker/server.properties` | rcon 비밀번호 등 비밀값 포함. 서버가 기동할 때마다 이 파일을 다시 씁니다 |
| `docker/plugins/*.jar` | 기동 시 자동 다운로드되므로 저장소에 담지 않음 |

---

## 빠른 시작

### 최초 1회: 설정 파일 준비

`docker/server.properties`는 rcon 비밀번호 등 비밀값을 담고 있어 git에서 제외됩니다.
저장소를 새로 클론했다면 예시 파일을 복사해 두세요. 이 파일이 없으면 docker가 같은
경로에 **디렉터리를 만들어버려** 서버가 기동되지 않습니다.

```powershell
cd docker
copy server.properties.example server.properties
```

### 일반 시작

```powershell
cd docker
docker compose up -d
```

### 최신 이미지로 시작 (권장)

itzg 이미지를 최신으로 갱신하고 참조를 잃은 구버전 이미지를 정리한 뒤 서버를 기동합니다.
두 스크립트 모두 자기 위치로 이동한 뒤 compose를 실행하므로 **저장소 루트에서 실행해도** 됩니다.

**Linux / macOS:**
```bash
bash docker/pull-and-up.sh
```

**Windows:**
```bat
docker\pull-and-up.bat
```

> 이미지만 최신화할 뿐 **마인크래프트 버전은 바꾸지 않습니다.** 버전은
> `docker-compose.yml`의 `VERSION`에 고정되어 있습니다 → [버전 업그레이드](#버전-업그레이드) 참조

### 로그 확인

```powershell
docker logs -f mc-crossplay
```

서버가 완전히 기동되면 다음 메시지가 나타납니다:
```
Done (XX.XXXs)! For help, type "help"
```

---

## 플러그인 자동 설치 로직

`update-plugins.sh`가 서버 시작 전에 실행되며 아래 순서로 동작합니다.

### 1단계 — Minecraft 최신 버전 확인

Mojang 공식 API에서 현재 최신 Java Edition 릴리즈 버전을 조회합니다.

```
https://piston-meta.mojang.com/mc/game/version_manifest_v2.json
```

이 조회 결과는 **로그 출력용**입니다. 실제로 어떤 서버 jar를 받을지는 스크립트가 아니라
itzg 이미지가 `docker-compose.yml`의 `VERSION` 환경변수를 보고 결정합니다. 로그에서 두 값을
나란히 확인해 현재 버전이 최신에서 얼마나 뒤처졌는지 판단할 수 있습니다.

```
[Script]   Minecraft 최신 릴리즈 : 26.2      ← Mojang API 조회 결과
[Script]   서버 실행 버전        : 26.2      ← docker-compose.yml 의 VERSION
```

### 2단계 — Geyser 공식 릴리즈 설치 시도

GeyserMC 공식 빌드 API에서 최신 릴리즈를 다운로드합니다.

```
https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot
https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot
```

5MB 이상의 정상 파일인지 검증 후 설치합니다.

### 3단계 — Geyser CI 스냅샷 설치 시도 (공식 실패 시)

공식 빌드가 실패할 경우 GeyserMC CI 서버의 최신 빌드를 시도합니다.

```
https://ci.opencollab.dev/job/GeyserMC/job/Geyser/job/master/lastSuccessfulBuild/...
```

### 4단계 — Geyser 없이 Purpur 구동

모든 Geyser 시도가 실패하면 Geyser 없이 Java Edition 전용으로 서버를 구동합니다. 서버 자체는 정상 작동합니다.

### 5단계 — ViaVersion 설치

GitHub releases에서 ViaVersion 최신 버전을 다운로드합니다.

```
https://api.github.com/repos/ViaVersion/ViaVersion/releases/latest
```

ViaVersion은 **서버보다 새로운 클라이언트**만 받아줍니다. 구버전 클라이언트까지 허용하려면
ViaBackwards가 따로 필요합니다 → [클라이언트 버전 호환](#클라이언트-버전-호환) 참조

### 설치 결과 요약 예시

```
[Script] ============ 설치 결과 ============
[Script]  서버 버전  : 26.2
[Script]  Geyser     : ✓ 설치됨 (베드락 크로스플레이 가능)
[Script]  Floodgate  : ✓ 설치됨
[Script]  ViaVersion : ✓ 설치됨
[Script] =======================================
```

`✗ 미설치`가 뜨면 해당 단계의 다운로드가 실패한 것이며, 서버는 그 플러그인 없이 계속 기동됩니다.
Geyser가 미설치면 베드락 접속만 불가하고 Java 접속은 정상입니다.

---

## 설정

### docker-compose.yml 주요 환경변수

| 변수 | 현재값 | 설명 |
|------|--------|------|
| `TYPE` | `PURPUR` | 서버 타입. PURPUR, PAPER 등 지원 |
| `VERSION` | `26.2` | 마인크래프트 버전 — **고정값이라 직접 올려야 최신이 됩니다** |
| `MEMORY` | `28G` | JVM 힙 메모리 (서버 사양에 맞게 조정) |
| `EULA` | `TRUE` | Minecraft EULA 동의 (변경 불가) |

컨테이너 자체 설정:

| 항목 | 현재값 | 설명 |
|------|--------|------|
| `image` | `itzg/minecraft-server:latest` | `docker compose pull` 시 최신 이미지 자동 취득 |
| `restart` | `unless-stopped` | 크래시 시 자동 복구. 단 **명시적으로 stop한 컨테이너는 재부팅 후에도 자동 기동되지 않습니다** |
| `mem_limit` | `30000000000` (30GB) | 컨테이너 메모리 상한. `MEMORY`보다 여유 있게 설정 |
| `entrypoint` | `update-plugins.sh && /start` | 기본 `/start`를 가로채 플러그인 설치를 먼저 수행 |

### server.properties 주요 설정

`docker/server.properties`를 직접 편집하면 다음 재시작 시 적용됩니다. 이 파일은 컨테이너에
읽기·쓰기로 마운트되어 있어 **서버가 기동할 때마다 정규화해서 다시 씁니다** — 주석의
타임스탬프가 갱신되고, 새 버전에서 추가된 항목이 자동으로 들어옵니다. 비밀값이 담기므로
git에서는 제외되어 있습니다.

| 항목 | 현재값 | 설명 |
|------|--------|------|
| `difficulty` | `hard` | 난이도 |
| `max-players` | `20` | 최대 접속 인원 |
| `online-mode` | `true` | 정품 인증 여부 |
| `view-distance` | `30` | 시야 거리 (청크) |
| `level-name` | `2026sgshs` | 월드 폴더명. 바꾸면 **새 월드가 생성**됩니다 |
| `rcon.port` | `25575` | RCON 포트 (컨테이너 내부 전용) |

### 스테이징 플러그인 추가

`docker/plugins/` 폴더에 `.jar` 파일을 넣으면 서버 시작 시 `/data/plugins/`로 자동 복사됩니다. 스크립트가 자동 다운로드하는 Geyser/Floodgate/ViaVersion 이외의 플러그인을 추가할 때 사용합니다.

```
docker/plugins/
└── 내가원하는플러그인.jar   ← 여기에 배치
```

---

## 포트

| 포트 | 프로토콜 | 용도 |
|------|----------|------|
| `25565` | TCP | Java Edition 클라이언트 접속 |
| `19132` | UDP | Bedrock Edition 클라이언트 접속 (Geyser) |
| `25575` | TCP | RCON (서버 원격 명령, 내부용) |

방화벽/공유기에서 25565(TCP)와 19132(UDP)를 포트 포워딩해야 외부에서 접속 가능합니다.

---

## 버전 업그레이드

`VERSION`은 고정값이므로 **이미지를 최신으로 받아도 마인크래프트 버전은 그대로입니다.**
새 버전이 나오면 아래 절차로 직접 올립니다. 버전이 뒤처지면 최신 클라이언트가 접속하지
못하고, Geyser가 `server software does not support the Java version...` 경고와 함께
베드락 접속을 처리하지 못합니다.

### 1. 최신 버전 확인

```bash
# Mojang 최신 릴리즈
curl -s https://piston-meta.mojang.com/mc/game/version_manifest_v2.json | head -c 200

# Purpur가 그 버전을 지원하는지 (metadata.current 확인)
curl -s https://api.purpurmc.org/v2/purpur
```

**Purpur가 지원하기 전까지는 올리지 않습니다.** Purpur는 Mojang 릴리즈보다 며칠 늦게
따라오는 경우가 있어, 먼저 올리면 서버 jar를 못 받아 컨테이너가 기동되지 않습니다.
같은 이유로 `VERSION`에 `LATEST`를 쓰지 않고 명시적 버전을 고정합니다.

### 2. 월드 백업

버전 업그레이드 시 월드 데이터가 변환되며 **되돌릴 수 없습니다.** 반드시 먼저 백업합니다.
→ [백업](#백업)

### 3. 버전 변경 후 재기동

```bash
# docker-compose.yml 의 VERSION 값을 새 버전으로 수정한 뒤
cd docker
docker compose down
docker compose up -d
```

### 4. 확인

```bash
docker logs mc-crossplay 2>&1 | grep "This server is running"
```

```
[11:03:01 INFO]: This server is running Purpur version 26.2-2614-HEAD@3c029ce ...
```

플러그인은 매 기동마다 최신으로 다시 받으므로 별도 조치가 필요 없습니다.

---

## 백업

월드 데이터는 `docker/data/<level-name>/`에 있습니다. 서버를 **정지한 상태에서** 압축합니다.
기동 중에 뜨면 저장 중인 청크가 섞여 백업이 깨질 수 있습니다.

```bash
cd docker
docker compose stop

cd data
tar -cf b<이름><YYYYMMDD><NN>.tar 2026sgshs   # 예: bsgshs2026072601.tar

cd ..
docker compose up -d
```

백업 tar는 `docker/data/` 안에 두면 git에서 자동 제외됩니다. 다만 같은 디스크에 있으므로
디스크 장애에는 대비되지 않습니다 — 중요한 시점의 백업은 외부로 복사해 두세요.

---

## 클라이언트 버전 호환

현재 서버는 **Purpur 26.2**이며, 접속 가능 여부는 다음과 같습니다.

| 클라이언트 | 상태 | 비고 |
|-----------|------|------|
| Java 26.2 | ✅ 접속 가능 | 서버와 동일 버전 |
| Java 26.2 이후 버전 | ✅ 접속 가능 | ViaVersion이 프로토콜 변환 |
| Java 26.1.2 이하 (구버전) | ❌ 접속 불가 | ViaBackwards 필요 (미설치) |
| Bedrock | ✅ 접속 가능 | Geyser + floodgate, UDP 19132 |

설치된 플러그인:

| 플러그인 | 버전 | 역할 |
|---------|------|------|
| Geyser-Spigot | 2.11.0 | Bedrock 프로토콜 ↔ Java 프로토콜 변환 |
| floodgate | 2.2.5 | Bedrock 플레이어 인증 (정품 Java 계정 불필요) |
| ViaVersion | 5.11.0 | 서버보다 **새로운** Java 클라이언트 접속 허용 |

### ViaVersion 경고에 대해

서버가 최신 버전일 때 기동 로그에 다음 경고가 뜹니다. **정상이며 무시해도 됩니다.**

```
[ViaVersion] ViaVersion does not have any compatible versions for this server version!
[ViaVersion] ViaVersion only supports newer client versions. Use ViaBackwards to allow
             older versions (ViaRewind for 1.7/1.8) to join.
```

서버가 이미 최신이라 "변환해 줄 더 새로운 클라이언트가 없다"는 뜻입니다. 구버전 클라이언트
접속을 허용하려면 ViaBackwards를 [docker/plugins/](docker/plugins/)에 직접 배치하거나
`update-plugins.sh`에 다운로드 단계를 추가해야 합니다.

---

## 트러블슈팅

### 서버가 시작되지 않음

```powershell
docker logs mc-crossplay
```

로그에서 `[Script]` 접두사가 붙은 줄을 찾아 플러그인 설치 단계를 확인합니다.
기동 완료까지 보통 40~80초 걸리며, 그 사이 헬스체크는 `unhealthy`로 표시됩니다.

컨테이너가 곧바로 죽는다면:

```powershell
docker inspect mc-crossplay --format "{{.State.ExitCode}} OOMKilled={{.State.OOMKilled}}"
```

- `OOMKilled=true` → `MEMORY` / `mem_limit`이 머신 사양을 초과. 둘 다 낮추세요
- 종료 코드 `137` + `OOMKilled=false` → 외부에서 정지시킨 것 (`docker stop`, Docker Desktop 종료 등)
- `Resolved Purpur version ...` 에서 실패 → `VERSION`을 Purpur가 아직 지원하지 않음
  → [버전 업그레이드](#버전-업그레이드)의 지원 여부 확인 절차 참조

### 컴포즈 실행 시 `no configuration file provided`

`docker compose` 명령을 `docker/` 폴더 밖에서 실행한 경우입니다. `cd docker` 후 실행하거나,
어느 위치에서나 동작하는 `pull-and-up` 스크립트를 사용하세요.

### server.properties 자리에 폴더가 생김

`docker/server.properties`가 없는 상태로 컨테이너를 띄우면 docker가 그 경로에 **빈 디렉터리를
생성**하고 서버가 정상 기동되지 않습니다. 디렉터리를 지우고 템플릿을 복사한 뒤 다시 띄우세요.

```powershell
cd docker
docker compose down
rmdir server.properties
copy server.properties.example server.properties
docker compose up -d
```

### 접속 불가 (Java Edition)

1. 서버가 완전히 기동됐는지 확인: `Done (XX.XXXs)!` 메시지 확인
2. 포트 25565가 열려있는지 확인
3. `online-mode=true`인 경우 정품 계정으로 접속
4. **클라이언트가 서버보다 구버전이면 접속되지 않습니다** →
   [클라이언트 버전 호환](#클라이언트-버전-호환)

### 접속 불가 (Bedrock Edition)

```powershell
docker logs mc-crossplay 2>&1 | Select-String "Geyser"
```

- `Started Geyser on UDP port 19132` 가 없으면 Geyser 자체가 로드되지 않은 것입니다
- `does not support the Java version that Geyser requires (...)` 경고가 보이면
  서버 버전이 Geyser 지원 범위보다 뒤처진 것입니다 → [버전 업그레이드](#버전-업그레이드)
- 19132는 **UDP**입니다. 포트 포워딩 시 TCP로 잘못 열지 않았는지 확인하세요

### 플러그인 오류

1. `docker logs mc-crossplay | grep ERROR` 로 오류 확인
2. `docker/plugins/` 폴더의 수동 배치 플러그인이 서버 버전과 호환되는지 확인
3. 특정 플러그인을 비활성화하려면 해당 jar를 `docker/plugins/`에서 제거 후 재시작

### 서버 재시작

```powershell
cd docker
docker compose restart
```

엔트리포인트는 **컨테이너가 시작될 때마다** 실행되므로, `restart`만으로도 `update-plugins.sh`가
다시 돌면서 플러그인이 최신 버전으로 재설치됩니다.

### 컨테이너 재생성

`docker-compose.yml`을 수정했다면 재생성이 필요합니다. `restart`는 변경된 설정을 반영하지 않습니다.

```powershell
cd docker
docker compose up -d --force-recreate
```

`docker compose down` 후 `up -d`도 동일한 효과입니다. `down`은 컨테이너만 제거하며
`docker/data/`의 월드 데이터는 호스트에 남습니다.

---

## 라이선스

[LICENSE](LICENSE) 참조
