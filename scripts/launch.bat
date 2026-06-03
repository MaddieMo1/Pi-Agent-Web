@echo off
setlocal

for %%I in ("%~dp0..") do set "APP_DIR=%%~fI\"
set "URL=http://localhost:30141"
set "CHINA_MODE=0"

if /i "%~1"=="--cn" set "CHINA_MODE=1"
if /i "%~1"=="cn" set "CHINA_MODE=1"
if "%PI_AGENT_CN_MODE%"=="1" set "CHINA_MODE=1"

cd /d "%APP_DIR%"

if exist "%APP_DIR%config\tavily-api-key.txt" (
  set /p TAVILY_API_KEY=<"%APP_DIR%config\tavily-api-key.txt"
)

if "%CHINA_MODE%"=="1" (
  set "PI_AGENT_CN_MODE=1"
  set "NPM_CONFIG_REGISTRY=https://registry.npmmirror.com"
  set "npm_config_registry=https://registry.npmmirror.com"
  set "UV_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple"
  set "PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple"
  echo China network mode enabled.
  echo npm registry: https://registry.npmmirror.com
  echo Python package index: https://pypi.tuna.tsinghua.edu.cn/simple
  echo.
)

if not exist "package.json" (
  echo package.json was not found.
  echo.
  echo Please make sure this launcher is inside the Pi Agent Web project folder.
  echo.
  pause
  exit /b 1
)

set "MISSING_SKILLS="
for %%S in (pdf edge-tts hyperframes find-skills skill-creator tavily-search) do (
  if not exist ".agents\skills\%%S\SKILL.md" (
    echo Missing bundled skill: %%S
    set "MISSING_SKILLS=1"
  )
)

if defined MISSING_SKILLS (
  echo.
  echo Bundled project skills were not found.
  echo Please make sure the .agents\skills folder is copied with this project.
  echo.
  pause
  exit /b 1
)

echo Creating desktop shortcut...
powershell -NoProfile -ExecutionPolicy Bypass -File "%APP_DIR%scripts\create-desktop-shortcut.ps1"
if errorlevel 1 (
  echo.
  echo Desktop shortcut could not be created, but Pi Agent Web can still start.
  echo.
)
echo.

echo Checking system dependencies...
echo.
if "%CHINA_MODE%"=="1" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%APP_DIR%scripts\bootstrap-deps.ps1" -ProjectDir "%APP_DIR%." -ChinaMode
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%APP_DIR%scripts\bootstrap-deps.ps1" -ProjectDir "%APP_DIR%."
)
if errorlevel 1 (
  echo.
  echo System dependency setup failed.
  echo Please check the error above, then run this launcher again.
  echo.
  pause
  exit /b 1
)
set "PATH=%USERPROFILE%\.local\bin;%ProgramFiles%\nodejs;%ProgramFiles(x86)%\nodejs;%ProgramFiles%\Git\cmd;%ProgramFiles%\Git\bin;%PATH%"
for /d %%D in ("%APP_DIR%.pi-bootstrap\node-v*-win-*") do set "PATH=%%~fD;%PATH%"
if exist "%APP_DIR%.pi-bootstrap\PortableGit\cmd" set "PATH=%APP_DIR%.pi-bootstrap\PortableGit\cmd;%PATH%"
if exist "%APP_DIR%.pi-bootstrap\PortableGit\bin" set "PATH=%APP_DIR%.pi-bootstrap\PortableGit\bin;%PATH%"
if exist "%APP_DIR%.pi-bootstrap\PortableGit\usr\bin" set "PATH=%APP_DIR%.pi-bootstrap\PortableGit\usr\bin;%PATH%"
echo.

if not exist "node_modules\" (
  echo Pi Agent dependencies were not found.
  echo.
  echo Installing dependencies now. This may take a few minutes...
  echo npm WARN lines are usually safe. If the window title starts with Select, press Enter or Esc to continue.
  echo.
  npm install --no-audit --no-fund
  if errorlevel 1 (
    echo.
    echo Dependency installation failed.
    echo Please check the error above, then run this launcher again.
    echo.
    pause
    exit /b 1
  )
  echo.
  echo Dependencies installed successfully.
  echo.
)

echo Starting Pi Agent Web...
echo URL: %URL%
echo.

start "" /b powershell -NoProfile -ExecutionPolicy Bypass -File "%APP_DIR%scripts\wait-and-open.ps1" -Url "%URL%"

npm run dev

echo.
echo Pi Agent Web has stopped.
pause
