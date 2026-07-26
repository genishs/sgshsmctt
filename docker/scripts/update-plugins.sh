#!/bin/bash
set -e

echo "[Script] ===== 플러그인 자동 설정 시작 ====="

mkdir -p /data/plugins
find /data/plugins -maxdepth 1 -type f -name "*.jar" -delete || true

if [ -d "/_staging/plugins" ]; then
    cp -rf /_staging/plugins/* /data/plugins/ || true
    echo "[Script] 스테이징 플러그인 복사 완료."
fi

# ─────────────────────────────────────────
# 유틸: 파일 다운로드
# ─────────────────────────────────────────
download() {
    local url="$1" out="$2"
    echo "[Script]   → $url"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --max-time 60 "$url" -o "$out"
    else
        wget -qO "$out" "$url"
    fi
}

# ─────────────────────────────────────────
# STEP 1: 최신 마인크래프트 릴리즈 버전 확인
# ─────────────────────────────────────────
echo ""
echo "[Script] [1/5] 최신 Minecraft 릴리즈 버전 확인..."
# Mojang / GitHub API 응답은 콜론 뒤에 공백이 들어가므로 [[:space:]]* 를 넣어야 매칭됨
MC_LATEST=$(curl -fsSL --max-time 10 \
    "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json" 2>/dev/null \
    | grep -o '"release":[[:space:]]*"[^"]*"' | head -1 | cut -d'"' -f4 || echo "")

MC_VERSION="${VERSION:-${MC_LATEST:-LATEST}}"
echo "[Script]   Minecraft 최신 릴리즈 : ${MC_LATEST:-확인불가}"
echo "[Script]   서버 실행 버전        : $MC_VERSION"

# ─────────────────────────────────────────
# STEP 2 & 3: Geyser + Floodgate 설치
# (공식 릴리즈 먼저, 실패 시 CI 스냅샷)
# ─────────────────────────────────────────
GEYSER_INSTALLED=false
FLOODGATE_INSTALLED=false

OFFICIAL_GEYSER="https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot"
OFFICIAL_FLOODGATE="https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot"
CI_GEYSER="https://ci.opencollab.dev/job/GeyserMC/job/Geyser/job/master/lastSuccessfulBuild/artifact/bootstrap/spigot/build/libs/Geyser-Spigot.jar"
CI_FLOODGATE="https://ci.opencollab.dev/job/GeyserMC/job/Floodgate/job/master/lastSuccessfulBuild/artifact/bukkit/build/libs/floodgate-bukkit.jar"

try_install_geyser() {
    local geyser_url="$1"
    local floodgate_url="$2"
    local label="$3"

    echo "[Script]   [$label] Geyser 다운로드 시도..."
    if download "$geyser_url" "/data/plugins/Geyser-Spigot.jar"; then
        local size
        size=$(wc -c < /data/plugins/Geyser-Spigot.jar 2>/dev/null || echo 0)
        if [ "$size" -gt 5000000 ]; then
            GEYSER_INSTALLED=true
            echo "[Script]   ✓ Geyser [$label] 설치 완료 ($(( size / 1024 / 1024 ))MB)"
            echo "[Script]   Floodgate 다운로드 시도..."
            if download "$floodgate_url" "/data/plugins/floodgate-spigot.jar"; then
                local fsize
                fsize=$(wc -c < /data/plugins/floodgate-spigot.jar 2>/dev/null || echo 0)
                if [ "$fsize" -gt 1000000 ]; then
                    FLOODGATE_INSTALLED=true
                    echo "[Script]   ✓ Floodgate [$label] 설치 완료 ($(( fsize / 1024 / 1024 ))MB)"
                else
                    rm -f /data/plugins/floodgate-spigot.jar
                    echo "[Script]   ✗ Floodgate 파일 이상 — 미설치"
                fi
            else
                rm -f /data/plugins/floodgate-spigot.jar
                echo "[Script]   ✗ Floodgate 다운로드 실패"
            fi
            return 0
        fi
    fi
    rm -f /data/plugins/Geyser-Spigot.jar
    echo "[Script]   ✗ Geyser [$label] 설치 실패"
    return 1
}

echo ""
echo "[Script] [2/5] Geyser 공식 릴리즈 다운로드 시도..."
if ! try_install_geyser "$OFFICIAL_GEYSER" "$OFFICIAL_FLOODGATE" "공식"; then
    echo ""
    echo "[Script] [3/5] Geyser CI 스냅샷 다운로드 시도..."
    try_install_geyser "$CI_GEYSER" "$CI_FLOODGATE" "스냅샷" || true
fi

# ─────────────────────────────────────────
# STEP 4: Geyser 없이 Purpur 구동 안내
# ─────────────────────────────────────────
if [ "$GEYSER_INSTALLED" = "false" ]; then
    echo ""
    echo "[Script] [4/5] Geyser 미설치 — 베드락 크로스플레이 없이 Purpur 구동"
fi

# ─────────────────────────────────────────
# STEP 5: ViaVersion (GitHub releases)
# ─────────────────────────────────────────
echo ""
echo "[Script] [5/5] ViaVersion 설치 중..."
VIA_GH_URL=$(curl -fsSL --max-time 10 "https://api.github.com/repos/ViaVersion/ViaVersion/releases/latest" 2>/dev/null \
    | grep -o '"browser_download_url":[[:space:]]*"[^"]*\.jar"' | head -1 | cut -d'"' -f4)
if [ -n "$VIA_GH_URL" ]; then
    if download "$VIA_GH_URL" "/data/plugins/ViaVersion.jar"; then
        VIA_SIZE=$(wc -c < /data/plugins/ViaVersion.jar 2>/dev/null || echo 0)
        if [ "$VIA_SIZE" -gt 1000000 ]; then
            echo "[Script]   ✓ ViaVersion 설치 완료"
        else
            rm -f /data/plugins/ViaVersion.jar
            echo "[Script]   ✗ ViaVersion 파일 이상"
        fi
    else
        echo "[Script]   ✗ ViaVersion 다운로드 실패"
    fi
else
    echo "[Script]   ✗ ViaVersion GitHub API 응답 없음 — 건너뜀"
fi

# ─────────────────────────────────────────
# 결과 요약
# ─────────────────────────────────────────
echo ""
echo "[Script] ============ 설치 결과 ============"
echo "[Script]  서버 버전  : $MC_VERSION"
echo "[Script]  Geyser     : $([ "$GEYSER_INSTALLED" = "true" ] && echo "✓ 설치됨 (베드락 크로스플레이 가능)" || echo "✗ 미설치 (베드락 불가)")"
echo "[Script]  Floodgate  : $([ "$FLOODGATE_INSTALLED" = "true" ] && echo "✓ 설치됨" || echo "✗ 미설치")"
echo "[Script]  ViaVersion : $([ -f /data/plugins/ViaVersion.jar ] && echo "✓ 설치됨" || echo "✗ 미설치")"
echo "[Script] ======================================="
