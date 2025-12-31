#!/bin/bash
set -e
echo "[Script] 플러그인 강제 업데이트 시작!"

# 폴더가 없으면 에러가 날 수 있으니 강제 생성
mkdir -p /data/plugins

# 1. 기존 jar 삭제
find /data/plugins -maxdepth 1 -type f -name "*.jar" -delete || true

# 2. 스테이징 플러그인 복사(있으면)
if [ -d "/_staging/plugins" ]; then
    cp -rf /_staging/plugins/* /data/plugins/ || true
    echo "[Script] 스테이징 플러그인 복사 완료."
else
    echo "[Script] 경고: _staging 폴더가 없습니다."
fi

# 3. Geyser, Floodgate 최신 버전 자동 다운로드 (있어도 덮어씀)
download() {
    url="$1"
    out="$2"
    echo "[Script] 다운로드 시도: $url -> $out"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$out"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$out" "$url"
    else
        echo "[Script] 오류: curl 또는 wget이 필요합니다. 다운로드 건너뜁니다."
        return 1
    fi
}

GEYSER_URL="https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot"
FLOODGATE_URL="https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot"
GEYSER_OUT="/data/plugins/Geyser-Spigot.jar"
FLOODGATE_OUT="/data/plugins/floodgate-spigot.jar"

# 네트워크 문제로 인한 전체 실패 방지를 위해 실패해도 계속 진행
if download "$GEYSER_URL" "$GEYSER_OUT"; then
    echo "[Script] Geyser 다운로드 완료."
else
    echo "[Script] Geyser 다운로드 실패 — 기존 플러그인 유지(있다면)."
fi

if download "$FLOODGATE_URL" "$FLOODGATE_OUT"; then
    echo "[Script] Floodgate 다운로드 완료."
else
    echo "[Script] Floodgate 다운로드 실패 — 기존 플러그인 유지(있다면)."
fi

echo "[Script] 플러그인 업데이트 완료."