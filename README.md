# sgshsmctt
minecraft 구동을 위한 java / bedrock 함께 사용할 수 있는 서버 구동 스크립트

# require
* 이 스크립트는 windows 환경에서 테스트되었습니다. 
* 당연하겠지만.. git?
* 메모장 등 편집기
* docker - 이 서버는 docker container에서 구동됩니다. docker desktop 은 있으면 좋고 없으면 말고..
* powershell 등 쉘

# 구동 방법
* 쉘에서  docker 경로로 접근한 뒤,
* 최신 itzg/minecraft-server 이미지를 자동으로 내려받고 싶으면
  `docker/pull-and-up.sh`(또는 `bash docker/pull-and-up.sh`)를 실행하세요. 
  또는 Windows에서는 `docker/pull-and-up.bat`을 실행하면 같은 작업을 수행합니다.
  내부적으로 `docker pull` 후 `docker image prune`로 사용하지 않는 이전 이미지들을
  정리하고 `docker compose up -d`를 수행합니다.
* 그냥 기본으로 올리려면 `docker-compose up -d`도 가능합니다.
* `server.properties`는 직접 수정해서 사용하세용

# 아래는 자동 생성 내용

# sgshsmctt - AI 에이전트 가이드

이 프로젝트는 Docker를 통해 Java(Paper)와 Bedrock(Geyser) 크로스플레이를 지원하는 **Minecraft 서버 런처**입니다.

## 아키텍처

- **컨테이너 서버**: `itzg/minecraft-server` 이미지를 실행하는 단일 Docker 컨테이너
- **플러그인 시스템**: 크로스플레이를 가능하게 하는 두 가지 필수 플러그인:
  - `Geyser-Spigot.jar` - Bedrock 프로토콜을 Java 프로토콜로 변환
    - https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot 파일을 다운로드하여 교체한다
  - `floodgate-spigot.jar` - Bedrock 플레이어 인증 처리
    - https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot 파일을 다운로드하여 교체한다
- **플러그인 로딩**: `docker-compose.yml`의 커스텀 엔트리포인트가 기본 `/start` 명령을 가로채서 서버 시작 전에 `update-plugins.sh` 실행
- **설정**: `server.properties`(읽기 전용 볼륨으로 마운트)를 통해 서버 동작 제어

## 주요 워크플로우

### 서버 구동
```bash
cd docker
docker-compose up -d
```
플러그인 업데이트 스크립트 완료 후 서버가 자동으로 시작됩니다.

### 플러그인 관리
- **플러그인 추가/업데이트**: 
  1. JAR 파일을 `docker/plugins/`에 배치
  2. 컨테이너 재시작: `docker-compose restart`
  3. `update-plugins.sh`가 `/_staging/plugins` → `/data/plugins`로 자동 복사
  4. 재시작할 때마다 이전 플러그인 삭제 (클린 슬레이트)

### 서버 설정 수정
`docker/server.properties`를 직접 편집하면 다음 재시작 시 변경사항이 적용됩니다.

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

### 크로스플레이 주의사항
- Bedrock 연결을 위해 Geyser가 반드시 필요
- floodgate가 Java/Bedrock 혼합 인증 처리 (`server.properties`의 management server 설정 참조)
- 포트: `25565` (Java), `19132/udp` (Bedrock)

## 언어 및 스타일 노트

- **한글 주석**: README 및 설정 파일에서 한글 사용 — 편집 시 유지
- **Bash 규칙**: 스크립트는 간단하고 직관적인 로직 사용 (복잡한 파이프라인 없음)
- **설정 철학**: 코드 변경보다는 환경 변수 선호

## 수정 시 주의사항

1. **기능 추가**: `docker/scripts/`를 통해 컨테이너 시작 로직 구현
2. **서버 동작 변경**: `server.properties` 또는 Docker 환경 변수 편집
3. **플러그인 문제**: 코드 디버깅 전에 `docker-compose.yml` 볼륨 확인
4. **테스트**: 이미지 재빌드가 아닌 `docker-compose up -d`로 로컬 실행
