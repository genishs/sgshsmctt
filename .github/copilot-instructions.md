# sgshsmctt - AI 에이전트 가이드

이 프로젝트는 Docker를 통해 Java(Purpur)와 Bedrock(Geyser) 크로스플레이를 지원하는 **Minecraft 서버 런처**입니다.

## 아키텍처

- **컨테이너 서버**: `itzg/minecraft-server:latest` 이미지를 실행하는 단일 Docker 컨테이너
- **서버 소프트웨어**: Purpur (`TYPE=PURPUR`). 버전은 `VERSION` 환경변수에 **명시적으로 고정**
- **플러그인 시스템**: 크로스플레이를 가능하게 하는 두 가지 필수 플러그인:
  - `Geyser-Spigot.jar` - Bedrock 프로토콜을 Java 프로토콜로 변환
  - `floodgate-spigot.jar` - Bedrock 플레이어 인증 처리
  - 여기에 `ViaVersion.jar`(서버보다 새로운 Java 클라이언트 허용)가 함께 설치됩니다
- **플러그인 로딩**: `docker-compose.yml`의 커스텀 엔트리포인트가 기본 `/start` 명령을 가로채서 서버 시작 전에 `update-plugins.sh` 실행
- **설정**: `server.properties`를 통해 서버 동작 제어. **읽기·쓰기로 마운트되며 서버가 기동할
  때마다 이 파일을 다시 씁니다.** 비밀값(rcon 비밀번호 등)을 담고 있어 git에서 제외되어 있고,
  형상은 `server.properties.example`로 관리합니다. `rcon.password` 는 itzg 이미지가 기동마다
  임의로 만들어 덮어쓰므로 예시 파일에서는 비워 둡니다(컨테이너 안 `rcon-cli` 는 그 값을 알아서 읽음)
- **메모리**: `MEMORY: ""`(빈 값)로 두어 JVM 이 최대 힙을 정합니다 — 아래 [메모리 설정](#메모리-설정)
- **운영 래퍼**: `docker/mc.sh`(Linux/macOS)·`docker/mc.bat`(Windows)이 compose 명령을 감쌉니다.
  명령은 `up / update / stop / start / restart / down / status / logs / console / cmd / backup`
- **문서**: `RUNNING.md` 는 빈 장비에서 접속까지의 절차서, `README.md` 는 구조·설정 참고서입니다

## 주요 워크플로우

### 서버 구동
```bash
bash docker/mc.sh up          # Windows: docker\mc.bat up — 저장소 어디서나
cd docker && docker compose up -d   # 직접 하려면
```
플러그인 업데이트 스크립트 완료 후 서버가 자동으로 시작됩니다. 기동 완료는 SSD 장비에서 재기동 1분
안팎, HDD 장비에서는 재기동 수 분·첫 기동 약 20분입니다(2026-10-03 실측). 완료 판정은
`For help, type "help"` 가 붙은 `Done` 줄로 합니다 — Geyser 도 `Done` 줄을 먼저 찍습니다.

`docker compose`는 반드시 `docker/` 폴더에서 실행해야 합니다. 저장소 루트에서 실행하려면
위치에 무관하게 동작하는 래퍼(`mc.sh` / `mc.bat`)나 `pull-and-up.sh` / `pull-and-up.bat`을 사용하세요.
래퍼 `up` 은 `server.properties` 가 없으면 예시에서 만들고, docker 가 그 자리에 폴더를 만들어 둔
상태면 기동하지 않고 알립니다.

### 메모리 설정
- `MEMORY: ""` 이면 itzg 가 `-Xms`/`-Xmx` 를 넘기지 않아 **JVM 이 컨테이너 상한의 25%**(상한이 없으면
  Docker 가 쓸 수 있는 메모리의 25%)를 최대 힙으로 잡습니다. 실행 장비가 정해질 때까지의 기본값입니다
- **`MEMORY` 줄을 지우거나 주석 처리하지 말 것.** itzg 의 `start-configuration` 이 `: "${MEMORY=1G}"`
  (콜론 없는 기본값)라서, 빈 문자열은 그대로 두지만 변수가 없으면 **1G 로 고정**합니다.
  `view-distance` 30 인 이 서버에는 부족합니다
- 값을 고정할 때는 `mem_limit` 을 힙 + 25%(itzg 권장)로, `memswap_limit` 을 `mem_limit` 과 **같게**
  둡니다. 같게 두면 컨테이너 스왑이 0 으로 잠깁니다 — JVM 힙이 스왑에 밀리면 GC 가 틱 루프를 멈추므로
  의도된 설정입니다. RAM 32GB 이상 장비 기준은 `16G` / `20g`
- 장비별 고정값은 커밋된 compose 를 바꾸지 말고 `docker/docker-compose.override.yml`(gitignore,
  템플릿은 `.example`)에 둡니다
- 장비보다 큰 고정값도 기동은 됩니다(힙을 미리 만지지 않음). JVM 은 `-Xmx` 만 보고 GC 시점을 정하므로
  나중에 호스트 메모리 벽에서 OOM killer 에 죽습니다
- Windows Docker Desktop 의 컨테이너는 WSL VM 안에서 돌고, 이 VM 은 기본으로 PC RAM 의 50% 만
  받습니다. 큰 값을 쓰려면 `.wslconfig` 의 `memory` 부터 늘려야 합니다

### 버전 업그레이드
`VERSION`이 고정값이므로 이미지를 최신화해도 마인크래프트 버전은 오르지 않습니다. 새 버전으로
올릴 때는 **Purpur가 그 버전을 지원하는지 먼저 확인**해야 합니다 (`https://api.purpurmc.org/v2/purpur`
의 `metadata.current`). Purpur는 Mojang 릴리즈보다 며칠 늦는 경우가 있어, 앞서 올리면 서버 jar를
받지 못해 컨테이너가 기동되지 않습니다. 같은 이유로 `VERSION=LATEST`를 쓰지 않습니다.
월드 데이터는 업그레이드 시 변환되며 되돌릴 수 없으므로 반드시 백업 후 진행합니다.

`update-plugins.sh`가 기동할 때마다 두 API를 조회해 뒤처짐 여부를 로그에 남깁니다. 판단 기준은
Mojang이 아니라 **Purpur 지원 버전**입니다 — Purpur가 아직 따라오지 않은 버전은 올릴 수 없으므로
경고 대상이 아닙니다. 조회 실패 시에는 경고 없이 `확인불가`로 표시하며, 어느 경우에도 기동을
막지 않습니다.

### 플러그인 관리
- **플러그인 추가/업데이트**: 
  1. JAR 파일을 `docker/plugins/`에 배치
  2. 컨테이너 재시작: `bash docker/mc.sh restart` 또는 `docker compose restart`
  3. `update-plugins.sh`가 `/_staging/plugins` → `/data/plugins`로 자동 복사
  4. 재시작할 때마다 이전 플러그인 삭제 (클린 슬레이트)

엔트리포인트는 컨테이너가 **시작될 때마다** 실행되므로 `restart`만으로 플러그인이 재설치됩니다.
`down`/`up`이나 `--force-recreate`는 `docker-compose.yml` 자체를 수정했을 때만 필요합니다.

### 서버 설정 수정
`docker/server.properties`를 직접 편집하면 다음 재시작 시 변경사항이 적용됩니다.
git에서 제외된 파일이므로, 형상으로 남겨야 하는 변경은 `server.properties.example`에도
반영하되 **비밀값은 비운 채로** 두어야 합니다.

## 핵심 구현 세부사항

### Docker 엔트리포인트 패턴
`docker-compose.yml`의 `entrypoint`는 **의도적**으로 기본 `/start` 명령을 오버라이드합니다:
```dockerfile
entrypoint: 
  - "/bin/bash"
  - "-c"
  - "bash /data/scripts/update-plugins.sh && /start"
```
**절대 제거하지 말 것**: 이것이 서버 부팅 전에 플러그인이 업데이트되도록 보장합니다.

### 플러그인 볼륨 매핑
- `./plugins:/_staging/plugins:ro` — 읽기 전용 스테이징 영역 (호스트 측)
- `update-plugins.sh`가 스테이징 → `/data/plugins` (컨테이너 측)로 복사
- 이미지를 다시 빌드하지 않고도 플러그인을 추가할 수 있습니다

### 외부 API 파싱 주의
`update-plugins.sh`는 Mojang과 GitHub의 JSON 응답을 `grep -o`로 파싱합니다. 두 API 모두
**콜론 뒤에 공백을 넣어** 응답하므로(`"key": "value"`) 패턴에 `[[:space:]]*`가 반드시 필요합니다.
이게 빠지면 조용히 빈 값이 반환되고 해당 단계가 실패해도 서버는 그냥 기동됩니다.

```bash
grep -o '"release":[[:space:]]*"[^"]*"'   # 올바름
grep -o '"release":"[^"]*"'               # 항상 빈 값
```

### 크로스플레이 주의사항
- Bedrock 연결을 위해 Geyser가 반드시 필요
- floodgate가 Java/Bedrock 혼합 인증 처리 (`server.properties`의 management server 설정 참조)
- 포트: `25565` (Java), `19132/udp` (Bedrock). RCON `25575`는 컨테이너 내부 전용으로 publish하지 않음
- Geyser는 특정 서버 버전 범위만 지원합니다. 서버가 뒤처지면
  `does not support the Java version that Geyser requires` 경고와 함께 베드락 접속이 막힙니다
- ViaVersion은 서버보다 **새로운** 클라이언트만 처리합니다. 서버가 최신일 때 뜨는
  `does not have any compatible versions` 경고는 정상입니다

## 언어 및 스타일 노트

- **한글 주석**: README 및 설정 파일에서 한글 사용 — 편집 시 유지
- **`.bat` 파일 예외**: cmd.exe가 기본 OEM 코드페이지에서 UTF-8 한글을 명령으로 오인해
  실행하므로 배치 파일은 **ASCII 전용**으로 작성합니다. 줄바꿈도 **CRLF**여야 합니다
  (LF만 있으면 cmd가 다중 행 구문을 잘못 파싱). `.gitattributes`에 규칙이 있습니다.
  그래서 `mc.bat` 의 안내 문구는 영어입니다
- **`.bat` 에서 같은 폴더의 배치를 부를 때**는 `call "%~dp0pull-and-up.bat"` 처럼 전체 경로를 씁니다.
  `NoDefaultCurrentDirectoryInExePath` 가 켜진 셸에서는 현재 폴더를 찾지 않아 이름만으로는 실패합니다
- **`.bat` 의 `( ... )` 블록 안 `echo` 에는 괄호를 쓰지 않습니다.** 블록이 그 자리에서 닫힙니다
- **`mc.bat` 에 `chcp` 를 넣지 않습니다.** 컨테이너 로그는 UTF-8 이라 한국어 Windows(CP949)에서
  `[Script]` 한글이 깨질 수 있지만, 배치 안의 `chcp 65001` 은 PowerShell 의 해독에는 영향이 없고 65001 이
  세션에 남아 한국어 시스템 메시지를 거꾸로 깨뜨립니다. 해결은 문서의 PowerShell 안내
  (`[Console]::OutputEncoding = [Text.Encoding]::UTF8`)로 합니다
- **`mc.sh` 와 `mc.bat` 은 같은 명령 집합을 유지합니다.** 한쪽에 명령을 더하면 다른 쪽과 README·RUNNING
  의 래퍼 표도 함께 고칩니다
- **Bash 규칙**: 스크립트는 간단하고 직관적인 로직 사용 (복잡한 파이프라인 없음)
- **설정 철학**: 코드 변경보다는 환경 변수 선호

## 수정 시 주의사항

1. **기능 추가**: `docker/scripts/`를 통해 컨테이너 시작 로직 구현
2. **서버 동작 변경**: `server.properties` 또는 Docker 환경 변수 편집
3. **플러그인 문제**: 코드 디버깅 전에 `docker-compose.yml` 볼륨 확인
4. **테스트**: 이미지 재빌드가 아닌 `docker compose up -d`로 로컬 실행
   (`docker-compose` v1이 아니라 v2 플러그인 문법 `docker compose`를 사용).
   Docker 가 없는 장비에서는 `docker` 를 호출 내역만 기록하는 가짜 실행 파일로 바꿔 래퍼의 명령 순서를
   확인할 수 있습니다. 실제 구동 검증은 아니므로 결과를 그렇게 구분해 적습니다
5. **백업**: 26.x 는 네더·엔드를 월드 폴더 안 `dimensions/minecraft/{overworld,the_nether,the_end}` 에
   함께 둡니다(Purpur 26.2 실측). 1.21 이하 Bukkit 계열은 `<level-name>_nether`, `<level-name>_the_end` 를
   따로 두었으므로 래퍼는 그 폴더가 있으면 함께 묶습니다. 옛 버전 데이터에서 본 폴더 구조를 새 버전에
   그대로 일반화하지 말고, 새 버전으로 띄운 월드에서 확인합니다
