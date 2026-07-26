#!/bin/bash
# Helper script to ensure the latest itzg/minecraft-server image is pulled
# before bringing the compose stack up. Run this instead of `docker compose up`.

set -euo pipefail

# compose 파일이 있는 폴더(이 스크립트의 위치)로 이동
# 저장소 루트에서 `bash docker/pull-and-up.sh` 로 실행해도 동작하도록 함
cd "$(dirname "$0")"

echo "[info] Pulling latest itzg/minecraft-server image..."
docker pull itzg/minecraft-server:latest

# 이전 이미지에 연결된 컨테이너가 없다면 정리
# docker pull은 태그를 업데이트하지만 레이어는 남아있을 수 있으므로
# 쓰지 않는 이미지를 제거해 디스크 공간 확보
if docker image prune -f --filter "label=maintainer=itzg"; then
  echo "[info] Pruned unused itzg images."
fi

echo "[info] Starting Minecraft crossplay container stack..."
docker compose up -d

echo "[info] Done."
