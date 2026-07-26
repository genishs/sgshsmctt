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
7. [베드락 크로스플레이 현황](#베드락-크로스플레이-현황)
8. [트러블슈팅](#트러블슈팅)

---

## 요구사항

- **Docker Desktop** (Windows / macOS) 또는 Docker Engine (Linux)
- **Git** (저장소 클론 시)
- PowerShell 또는 bash 쉘

---

## 구조

```
sgshsmctt/
├── docker/
│   ├── docker-compose.yml        # 서버 컨테이너 정의
│   ├── server.properties         # 마인크래프트 서버 설정 (git 제외 - 비밀값 포함)
│   ├── server.properties.example # 위 파일의 예시 템플릿
│   ├── pull-and-up.sh            # 최신 이미지 pull 후 서버 기동 (Linux/macOS)
│   ├── pull-and-up.bat           # 최신 이미지 pull 후 서버 기동 (Windows)
│   ├── plugins/                  # 스테이징 플러그인 폴더 (jar 직접 배치 시 사용)
│   └── scripts/
│       └── update-plugins.sh     # 서버 기동 전 플러그인 자동 설치 스크립트
└── README.md
```

> `docker/data/`는 월드 데이터, 로그 등 서버 런타임 데이터가 저장되는 폴더로 git에서 제외됩니다.

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

itzg 이미지를 최신으로 갱신하고 불필요한 구버전 이미지를 정리한 뒤 서버를 기동합니다.

**Linux / macOS:**
```bash
bash docker/pull-and-up.sh
```

**Windows:**
```bat
docker\pull-and-up.bat
```

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

`docker-compose.yml`에 `VERSION`이 지정되어 있으면 그 버전을 사용하고, 없으면 최신 버전을 자동으로 사용합니다.

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

다양한 버전의 Java Edition 클라이언트가 접속할 수 있도록 GitHub releases에서 ViaVersion 최신 버전을 다운로드합니다.

```
https://api.github.com/repos/ViaVersion/ViaVersion/releases/latest
```

### 설치 결과 요약 예시

```
[Script] ============ 설치 결과 ============
[Script]  서버 버전  : 26.1.2
[Script]  Geyser     : ✓ 설치됨 (베드락 크로스플레이 가능)
[Script]  Floodgate  : ✓ 설치됨
[Script]  ViaVersion : ✓ 설치됨
[Script] =======================================
```

---

## 설정

### docker-compose.yml 주요 환경변수

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `TYPE` | `PURPUR` | 서버 타입. PURPUR, PAPER 등 지원 |
| `VERSION` | `26.1.2` | 마인크래프트 버전 |
| `MEMORY` | `28G` | JVM 힙 메모리 (서버 사양에 맞게 조정) |
| `EULA` | `TRUE` | Minecraft EULA 동의 (변경 불가) |

### server.properties 주요 설정

`docker/server.properties`를 직접 편집하면 다음 재시작 시 적용됩니다.

| 항목 | 현재값 | 설명 |
|------|--------|------|
| `difficulty` | `hard` | 난이도 |
| `max-players` | `20` | 최대 접속 인원 |
| `online-mode` | `true` | 정품 인증 여부 |
| `view-distance` | `30` | 시야 거리 (청크) |
| `level-name` | `2026sgshs` | 월드 폴더명 |
| `rcon.port` | `25575` | RCON 포트 |

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

## 베드락 크로스플레이 현황

Geyser는 Java Edition 서버에 Bedrock 클라이언트가 접속할 수 있도록 프로토콜을 변환해주는 플러그인입니다.

### 현재 상황 (2026년 5월 기준)

Minecraft Java Edition이 연도 기반 새 버전 체계(26.x)로 전환되면서 Geyser의 공식 지원이 아직 완료되지 않았습니다.

| 구성 | 상태 |
|------|------|
| Java 26.1.2 클라이언트 → 이 서버 | ✅ 정상 접속 |
| Bedrock 클라이언트 → 이 서버 | ❌ Geyser 미지원 (대기 중) |

스크립트는 이미 최신 Geyser를 자동으로 설치하도록 설정되어 있습니다. GeyserMC가 26.1.2 서버를 공식 지원하는 버전을 릴리즈하면 다음 서버 재시작 시 자동으로 활성화됩니다.

> Geyser 지원 진행 상황: https://github.com/GeyserMC/Geyser/issues

---

## 트러블슈팅

### 서버가 시작되지 않음

```powershell
docker logs mc-crossplay
```

로그에서 `[Script]` 접두사가 붙은 줄을 찾아 플러그인 설치 단계를 확인합니다.

### 접속 불가 (Java Edition)

1. 서버가 완전히 기동됐는지 확인: `Done (XX.XXXs)!` 메시지 확인
2. 포트 25565가 열려있는지 확인
3. `online-mode=true`인 경우 정품 계정으로 접속

### 플러그인 오류

1. `docker logs mc-crossplay | grep ERROR` 로 오류 확인
2. `docker/plugins/` 폴더의 수동 배치 플러그인이 서버 버전과 호환되는지 확인
3. 특정 플러그인을 비활성화하려면 해당 jar를 `docker/plugins/`에서 제거 후 재시작

### 서버 재시작

```powershell
cd docker
docker compose restart
```

### 서버 완전 재기동 (플러그인 재설치 포함)

```powershell
cd docker
docker compose down
docker compose up -d
```

`docker compose down && docker compose up -d`를 하면 `update-plugins.sh`가 다시 실행되어 플러그인을 최신 버전으로 재설치합니다.

---

## 라이선스

[LICENSE](LICENSE) 참조
