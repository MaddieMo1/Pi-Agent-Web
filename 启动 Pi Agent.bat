@echo off
setlocal

set "APP_DIR=%~dp0"
set "URL=http://localhost:30141"

cd /d "%APP_DIR%"

if not exist "package.json" (
  echo package.json was not found.
  echo.
  echo Please make sure this launcher is inside the Pi Agent Web project folder.
  echo.
  pause
  exit /b 1
)

set "MISSING_SKILLS="
for %%S in (tavily-search pdf edge-tts hyperframes find-skills skill-creator) do (
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
powershell -NoProfile -ExecutionPolicy Bypass -File "%APP_DIR%scripts\bootstrap-deps.ps1" -ProjectDir "%APP_DIR%."
if errorlevel 1 (
  echo.
  echo System dependency setup failed.
  echo Please check the error above, then run this launcher again.
  echo.
  pause
  exit /b 1
)
set "PATH=%USERPROFILE%\.local\bin;%ProgramFiles%\nodejs;%ProgramFiles(x86)%\nodejs;%PATH%"
echo.

if not exist "node_modules\" (
  echo Pi Agent dependencies were not found.
  echo.
  echo Installing dependencies now. This may take a few minutes...
  echo.
  npm install
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
