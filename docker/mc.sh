#!/bin/bash
# sgshsmctt 서버 관리 래퍼 (Linux / macOS)
#
# docker compose 명령을 외우지 않아도 서버를 켜고, 끄고, 콘솔에 명령을 넣고, 백업할 수 있게
# 한 얇은 래퍼다. 하는 일은 전부 docker compose / docker exec 호출이고, 저장소 어디서 실행해도 된다.
#
#   bash docker/mc.sh <명령> [인자...]
#
# Windows 에서는 같은 명령을 가진 docker\mc.bat 을 쓴다.

set -euo pipefail

# compose 파일이 있는 폴더(이 스크립트의 위치)로 이동
cd "$(dirname "$0")"

CONTAINER="mc-crossplay"
BACKUP_DIR="backups"

say()  { echo "[mc] $*"; }
fail() { echo "[mc] ✗ $*" >&2; exit 1; }

usage() {
    cat <<'EOF'
사용법: bash docker/mc.sh <명령> [인자...]

  up            서버 켜기. server.properties 가 없으면 예시 파일에서 만든다
  update        최신 itzg 이미지를 받은 뒤 켜기 (pull-and-up.sh 와 같다)
  stop          서버 끄기. 월드를 저장하고 멈춘다. 재부팅해도 다시 뜨지 않는다
  start         stop 으로 꺼 둔 서버를 다시 켜기
  restart       재시작. 기동 스크립트가 다시 돌아 플러그인이 최신으로 재설치된다
  down          컨테이너 제거. docker/data 의 월드는 그대로 남는다
  status        상태, 메모리 설정, 메모리 사용량
  logs          로그 따라가기. Ctrl+C 로 빠져나와도 서버는 계속 돈다
  console       서버 콘솔(rcon-cli). exit 를 입력하면 빠져나온다
  cmd <명령>    서버 명령 한 줄 실행.  예) mc.sh cmd list    mc.sh cmd op 닉네임
  backup        서버를 잠시 멈추고 월드(네더·엔드 포함)를 docker/backups/ 에 tar 로 묶는다
EOF
}

need_docker() {
    command -v docker >/dev/null 2>&1 \
        || fail "docker 명령이 없습니다. Docker 를 설치하고 실행한 뒤 다시 시도하세요."
}

is_running() {
    [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null || true)" = "true" ]
}

# server.properties 가 없는 채로 기동하면 docker 가 같은 경로에 빈 폴더를 만들어 서버가 뜨지 않는다.
ensure_server_properties() {
    if [ -d server.properties ]; then
        fail "server.properties 가 폴더로 생겨 있습니다(파일 없이 기동한 흔적). 'mc.sh down' 후 'rmdir docker/server.properties' 로 지우고 다시 'mc.sh up' 하세요."
    fi
    if [ ! -f server.properties ]; then
        cp server.properties.example server.properties
        say "server.properties 가 없어 server.properties.example 에서 만들었습니다."
    fi
}

level_name() {
    local name=""
    if [ -f server.properties ]; then
        name=$(grep -m1 '^level-name=' server.properties | cut -d= -f2- | tr -d '\r' || true)
    fi
    echo "${name:-world}"
}

backup() {
    local level ts out rc=0 was_running=false
    local dirs=()

    level=$(level_name)
    [ -d "data/$level" ] \
        || fail "docker/data/$level 이 없습니다. 서버를 한 번 띄워 월드가 생긴 뒤 백업하세요."
    # Purpur 같은 Bukkit 계열 서버는 네더·엔드를 <level>_nether, <level>_the_end 폴더에 따로 둔다
    for d in "$level" "${level}_nether" "${level}_the_end"; do
        if [ -d "data/$d" ]; then dirs+=("$d"); fi
    done

    if is_running; then
        was_running=true
        say "저장 중인 청크가 섞이지 않도록 서버를 잠시 멈춥니다..."
        docker compose stop
    fi

    mkdir -p "$BACKUP_DIR"
    ts=$(date +%Y%m%d-%H%M%S)
    out="$BACKUP_DIR/${level}-${ts}.tar"
    say "백업: ${dirs[*]} → docker/$out"
    tar -C data -cf "$out" "${dirs[@]}" || rc=$?

    # tar 가 실패해도 멈춰 둔 서버는 다시 켠다
    if [ "$was_running" = true ]; then
        say "서버를 다시 켭니다..."
        docker compose start
    fi

    if [ "$rc" -ne 0 ]; then
        rm -f "$out"
        fail "백업 실패 (tar 종료 코드 $rc). 파일 권한 문제라면 sudo 로 다시 실행하세요."
    fi
    say "✓ 완료: docker/$out ($(du -h "$out" | cut -f1))"
}

cmd="${1:-help}"
if [ $# -gt 0 ]; then shift; fi

case "$cmd" in
    help|-h|--help) usage; exit 0 ;;
esac

need_docker

case "$cmd" in
    up)
        ensure_server_properties
        docker compose up -d
        say "기동을 시작했습니다. 진행은 'mc.sh logs' 로 보세요. 첫 기동은 수 분 걸립니다."
        ;;
    update)
        ensure_server_properties
        exec bash ./pull-and-up.sh
        ;;
    stop)    docker compose stop ;;
    start)   docker compose start ;;
    restart) docker compose restart ;;
    down)    docker compose down ;;
    status)
        docker compose ps
        echo
        say "메모리 설정 (MEMORY 가 빈 값이면 JVM 자동 = Docker 가 쓸 수 있는 메모리의 25%):"
        docker compose config | grep -E 'MEMORY|mem_limit|memswap_limit' || true
        if is_running; then
            echo
            docker stats --no-stream "$CONTAINER"
        fi
        ;;
    logs)
        docker logs -f --tail 100 "$CONTAINER"
        ;;
    console)
        say "서버 콘솔입니다. 빠져나올 때는 exit 를 입력하세요."
        docker exec -i "$CONTAINER" rcon-cli
        ;;
    cmd)
        [ $# -gt 0 ] || fail "실행할 서버 명령을 주세요. 예) mc.sh cmd list"
        docker exec "$CONTAINER" rcon-cli "$@"
        ;;
    backup)
        backup
        ;;
    *)
        usage
        echo
        fail "알 수 없는 명령: $cmd"
        ;;
esac
