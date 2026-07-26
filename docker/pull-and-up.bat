@echo off
REM Helper batch to pull the latest itzg/minecraft-server image and start the compose stack.
REM Keep this file ASCII-only with CRLF line endings: cmd.exe mis-parses LF-only batch files
REM and garbles non-ASCII text under the default OEM codepage.
setlocal

REM Move to the folder holding docker-compose.yml (the location of this batch file),
REM so the script works when launched from the repository root.
cd /d "%~dp0"

echo [info] Pulling latest itzg/minecraft-server image...
docker pull itzg/minecraft-server:latest
if errorlevel 1 (
    echo [error] Image pull failed - check that Docker is running.
    endlocal
    exit /b 1
)

REM Remove only itzg images left dangling by the tag update, to reclaim disk space.
echo [info] Pruning dangling itzg images...
for /f "delims=" %%i in ('docker image ls --filter "reference=itzg/minecraft-server" --filter "dangling=true" -q') do (
    docker image rm %%i >nul 2>&1
)

echo [info] Starting Minecraft crossplay container stack...
docker compose up -d

echo [info] Done.
endlocal
