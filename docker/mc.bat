@echo off
REM sgshsmctt server helper for Windows - the same commands as mc.sh.
REM It only wraps docker compose / docker exec, and works from any folder:
REM
REM   docker\mc.bat <command> [args...]
REM
REM Keep this file ASCII-only with CRLF line endings: cmd.exe mis-parses LF-only batch files
REM and garbles non-ASCII text under the default OEM codepage (see .gitattributes).
setlocal EnableExtensions

REM Move to the folder holding docker-compose.yml (the location of this batch file).
cd /d "%~dp0"

set "CONTAINER=mc-crossplay"
set "BACKUP_DIR=backups"

set "CMD=%~1"
if "%CMD%"=="" goto :usage
if /i "%CMD%"=="help" goto :usage
if /i "%CMD%"=="-h" goto :usage
if /i "%CMD%"=="--help" goto :usage

where docker >nul 2>&1
if errorlevel 1 (
    echo [mc] docker command not found. Install and start Docker Desktop, then try again.
    exit /b 1
)

if /i "%CMD%"=="up" goto :up
if /i "%CMD%"=="update" goto :update
if /i "%CMD%"=="stop" goto :stop
if /i "%CMD%"=="start" goto :start
if /i "%CMD%"=="restart" goto :restart
if /i "%CMD%"=="down" goto :down
if /i "%CMD%"=="status" goto :status
if /i "%CMD%"=="logs" goto :logs
if /i "%CMD%"=="console" goto :console
if /i "%CMD%"=="cmd" goto :cmd
if /i "%CMD%"=="backup" goto :backup
call :usage_text
echo.
echo [mc] Unknown command: %CMD%
exit /b 1

:usage
call :usage_text
exit /b 0

:usage_text
echo Usage: docker\mc.bat ^<command^> [args...]
echo.
echo   up            Start the server. Creates server.properties from the example if missing
echo   update        Pull the latest itzg image, then start - same as pull-and-up.bat
echo   stop          Stop the server. The world is saved. It will NOT come back after a reboot
echo   start         Start a server that was stopped with "stop"
echo   restart       Restart. Plugins are downloaded again at their latest versions
echo   down          Remove the container. The world in docker\data stays
echo   status        State, memory settings and memory usage
echo   logs          Follow the log. Ctrl+C leaves the log, the server keeps running
echo   console       Server console - rcon-cli. Type exit to leave
echo   cmd ^<text^>    Run one server command.  e.g. mc.bat cmd list    mc.bat cmd op Name
echo   backup        Stop briefly and tar the world with nether/end into docker\backups
goto :eof

:up
call :ensure_props
if errorlevel 1 exit /b 1
docker compose up -d
if errorlevel 1 exit /b 1
echo [mc] Starting. Watch progress with "mc.bat logs" - the first start can take several minutes.
exit /b 0

:update
call :ensure_props
if errorlevel 1 exit /b 1
REM Full path: the current folder is not searched when NoDefaultCurrentDirectoryInExePath is set.
call "%~dp0pull-and-up.bat"
exit /b %errorlevel%

:stop
docker compose stop
exit /b %errorlevel%

:start
docker compose start
exit /b %errorlevel%

:restart
docker compose restart
exit /b %errorlevel%

:down
docker compose down
exit /b %errorlevel%

:status
docker compose ps
echo.
echo [mc] Memory settings - an empty MEMORY means the JVM takes 25%% of the memory Docker can use:
docker compose config 2>nul | findstr /c:"MEMORY" /c:"mem_limit" /c:"memswap_limit"
call :is_running
if "%RUNNING%"=="true" (
    echo.
    docker stats --no-stream %CONTAINER%
)
exit /b 0

:logs
docker logs -f --tail 100 %CONTAINER%
exit /b %errorlevel%

:console
echo [mc] Server console. Type exit to leave.
docker exec -i %CONTAINER% rcon-cli
exit /b %errorlevel%

:cmd
set "ARGS="
shift
:cmd_collect
if "%~1"=="" goto :cmd_run
set "ARGS=%ARGS% %1"
shift
goto :cmd_collect
:cmd_run
if not defined ARGS (
    echo [mc] Give the server command to run, e.g. mc.bat cmd list
    exit /b 1
)
docker exec %CONTAINER% rcon-cli%ARGS%
exit /b %errorlevel%

:backup
set "LEVEL="
if exist "server.properties" (
    for /f "tokens=1,* delims==" %%a in ('findstr /b /c:"level-name=" "server.properties"') do set "LEVEL=%%b"
)
if not defined LEVEL set "LEVEL=world"
if not exist "data\%LEVEL%\" (
    echo [mc] docker\data\%LEVEL% not found. Start the server once so the world exists, then back up.
    exit /b 1
)
REM Since 26.x the nether and the end live inside the world folder under dimensions\minecraft.
REM Worlds made by Bukkit-based servers on 1.21 or older may still have separate _nether and
REM _the_end folders, so add them when present.
set "DIRS=%LEVEL%"
if exist "data\%LEVEL%_nether\" set "DIRS=%DIRS% %LEVEL%_nether"
if exist "data\%LEVEL%_the_end\" set "DIRS=%DIRS% %LEVEL%_the_end"

set "TS="
for /f "delims=" %%t in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"') do set "TS=%%t"
if not defined TS set "TS=manual"

call :is_running
set "WAS_RUNNING=%RUNNING%"
if "%WAS_RUNNING%"=="true" (
    echo [mc] Stopping the server so no chunk is half-written...
    docker compose stop
)

if not exist "%BACKUP_DIR%\" mkdir "%BACKUP_DIR%"
set "OUT=%BACKUP_DIR%\%LEVEL%-%TS%.tar"
echo [mc] Backing up %DIRS% to docker\%OUT%
tar -C data -cf "%OUT%" %DIRS%
set "RC=%errorlevel%"

REM Start the server again even if tar failed.
if "%WAS_RUNNING%"=="true" (
    echo [mc] Starting the server again...
    docker compose start
)

if not "%RC%"=="0" (
    del /q "%OUT%" >nul 2>&1
    echo [mc] Backup FAILED - tar exit code %RC%.
    exit /b %RC%
)
echo [mc] Done: docker\%OUT%
exit /b 0

:ensure_props
REM Without server.properties Docker creates an empty FOLDER at that path and the server will not start.
if exist "server.properties\" (
    echo [mc] server.properties is a FOLDER - Docker created it because the file was missing.
    echo [mc] Run "mc.bat down", delete the folder docker\server.properties, then run "mc.bat up" again.
    exit /b 1
)
if not exist "server.properties" (
    copy /y "server.properties.example" "server.properties" >nul
    echo [mc] Created server.properties from server.properties.example.
)
exit /b 0

:is_running
set "RUNNING=false"
for /f "delims=" %%r in ('docker inspect -f "{{.State.Running}}" %CONTAINER% 2^>nul') do set "RUNNING=%%r"
goto :eof
