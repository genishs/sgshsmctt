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
#
# docker-compose.yml 의 VERSION 은 고정값이라 이미지를 최신화해도 서버 버전은
# 오르지 않는다. 방치하면 최신 클라이언트가 접속하지 못하고 Geyser 도 베드락
# 접속을 처리하지 못하므로, 뒤처진 경우 기동 로그에 경고를 남긴다.
# ─────────────────────────────────────────
echo ""
echo "[Script] [1/5] 최신 Minecraft 릴리즈 버전 확인..."
# Mojang / GitHub API 응답은 콜론 뒤에 공백이 들어가므로 [[:space:]]* 를 넣어야 매칭됨
MC_LATEST=$(curl -fsSL --max-time 10 \
    "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json" 2>/dev/null \
    | grep -o '"release":[[:space:]]*"[^"]*"' | head -1 | cut -d'"' -f4 || echo "")

# Purpur 가 실제로 서버 jar 를 제공하는 최신 버전.
# Mojang 릴리즈보다 며칠 늦게 따라오므로 업그레이드 가능 판단은 이 값을 기준으로 한다.
PURPUR_LATEST=$(curl -fsSL --max-time 10 "https://api.purpurmc.org/v2/purpur" 2>/dev/null \
    | grep -o '"current":[[:space:]]*"[^"]*"' | head -1 | cut -d'"' -f4 || echo "")

MC_VERSION="${VERSION:-${MC_LATEST:-LATEST}}"
echo "[Script]   Minecraft 최신 릴리즈 : ${MC_LATEST:-확인불가}"
echo "[Script]   Purpur 지원 최신      : ${PURPUR_LATEST:-확인불가}"
echo "[Script]   서버 실행 버전        : $MC_VERSION"

# 요약 블록에서 다시 출력할 한 줄짜리 상태
VERSION_STATUS="확인불가 (버전 API 조회 실패)"
VERSION_OUTDATED=false

if [ -n "$PURPUR_LATEST" ]; then
    if [ "$MC_VERSION" = "$PURPUR_LATEST" ]; then
        if [ -n "$MC_LATEST" ] && [ "$MC_LATEST" != "$PURPUR_LATEST" ]; then
            # 서버는 Purpur 최신인데 Mojang 이 더 앞서간 상태 - 우리가 할 일은 없다
            VERSION_STATUS="최신 (Mojang $MC_LATEST 은 Purpur 지원 대기 중)"
        else
            VERSION_STATUS="최신"
        fi
    else
        VERSION_OUTDATED=true
        VERSION_STATUS="업그레이드 가능 → $PURPUR_LATEST"
    fi
fi

if [ "$VERSION_OUTDATED" = "true" ]; then
    echo ""
    echo "[Script] ┌──────────────────────────────────────────────────────────┐"
    echo "[Script] │ ⚠ 서버 버전이 뒤처져 있습니다                            │"
    echo "[Script] └──────────────────────────────────────────────────────────┘"
    echo "[Script]   현재 $MC_VERSION → Purpur 는 이미 $PURPUR_LATEST 를 지원합니다."
    echo "[Script]   방치하면 최신 클라이언트가 접속하지 못하고, Geyser 가 베드락"
    echo "[Script]   접속을 처리하지 못합니다."
    echo "[Script]"
    echo "[Script]   업그레이드: docker-compose.yml 의 VERSION 을 $PURPUR_LATEST 로 수정"
    echo "[Script]   ※ 월드 데이터가 변환되며 되돌릴 수 없으므로 먼저 백업하세요."
    echo "[Script]   자세한 절차는 README 의 '버전 업그레이드' 절 참조."
    echo ""
fi

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
echo "[Script]  서버 버전  : $MC_VERSION ($VERSION_STATUS)"
echo "[Script]  Geyser     : $([ "$GEYSER_INSTALLED" = "true" ] && echo "✓ 설치됨 (베드락 크로스플레이 가능)" || echo "✗ 미설치 (베드락 불가)")"
echo "[Script]  Floodgate  : $([ "$FLOODGATE_INSTALLED" = "true" ] && echo "✓ 설치됨" || echo "✗ 미설치")"
echo "[Script]  ViaVersion : $([ -f /data/plugins/ViaVersion.jar ] && echo "✓ 설치됨" || echo "✗ 미설치")"
echo "[Script] ======================================="
