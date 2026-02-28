@echo off
REM Helper batch to pull latest itzg/minecraft-server image and start compose stack on Windows
setlocal enabledelayedexpansion
echo [info] Pulling latest itzg/minecraft-server image...
docker pull itzg/minecraft-server:latest








endlocalecho [info] Done.docker compose up -decho [info] Starting Minecraft crossplay container stack...)    docker image rm %%i >nul 2>&1for /f "delims=" %%i in ('docker image ls --filter "reference=itzg/minecraft-server" --filter "dangling=true" -q') do (:: prune unused itzg images (only those with the same repo)
:: the filter syntax differs slightly from bash but the effect is