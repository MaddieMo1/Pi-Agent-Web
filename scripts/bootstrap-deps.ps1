param(
  [string]$ProjectDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

function Write-Step {
  param([string]$Message)
  Write-Host ""
  Write-Host "==> $Message"
}

function Write-Warn {
  param([string]$Message)
  Write-Host "WARN: $Message" -ForegroundColor Yellow
}

function Test-Command {
  param([string]$Name)
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Refresh-Path {
  $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  $localBin = Join-Path $env:USERPROFILE ".local\bin"
  $paths = @($env:Path, $machinePath, $userPath, $localBin) |
    Where-Object { $_ -and $_.Trim().Length -gt 0 }
  $env:Path = ($paths -join ";")
}

function Install-WithWinget {
  param(
    [string]$Id,
    [string]$Name
  )

  if (-not (Test-Command winget)) {
    throw "winget was not found. Install $Name manually, then run this launcher again."
  }

  Write-Step "Installing $Name with winget"
  winget install --exact --id $Id --accept-package-agreements --accept-source-agreements
  if ($LASTEXITCODE -ne 0) {
    throw "winget failed to install $Name."
  }
  Refresh-Path
}

Set-Location $ProjectDir
Refresh-Path

Write-Step "Checking Node.js and npm"
if (-not (Test-Command node) -or -not (Test-Command npm)) {
  Install-WithWinget -Id "OpenJS.NodeJS.LTS" -Name "Node.js LTS"
}

if (-not (Test-Command node) -or -not (Test-Command npm)) {
  throw "Node.js/npm still cannot be found after installation. Close this window and run the launcher again."
}

node --version
npm --version

Write-Step "Checking uv and uvx"
if (-not (Test-Command uv) -or -not (Test-Command uvx)) {
  Write-Step "Installing uv"
  powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://astral.sh/uv/install.ps1 | iex"
  if ($LASTEXITCODE -ne 0) {
    throw "uv installation failed."
  }
  Refresh-Path
}

if (-not (Test-Command uv) -or -not (Test-Command uvx)) {
  throw "uv/uvx still cannot be found after installation. Close this window and run the launcher again."
}

uv --version

Write-Step "Checking Tavily CLI"
if (-not (Test-Command tvly)) {
  uv tool install tavily-cli
  if ($LASTEXITCODE -ne 0) {
    Write-Warn "Could not install Tavily CLI automatically. Web search skill will ask for tvly when first used."
  }
  Refresh-Path
}

if (Test-Command tvly) {
  tvly --version
  if ($env:TAVILY_API_KEY) {
    Write-Step "Configuring Tavily CLI from TAVILY_API_KEY"
    tvly login --api-key $env:TAVILY_API_KEY
    if ($LASTEXITCODE -ne 0) {
      Write-Warn "Tavily login failed. Run 'tvly login' manually if tavily-search needs authentication."
    }
  } else {
    Write-Warn "Tavily CLI is installed. Run 'tvly login' once if tavily-search asks for authentication."
  }
}

Write-Step "Checking PDF helper tools"
if (-not (Test-Command pdftoppm)) {
  if (Test-Command winget) {
    winget install --exact --id "oschwartz10612.Poppler" --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
      Write-Warn "Could not install Poppler automatically. PDF rendering can still work if you install Poppler later."
    }
    Refresh-Path
  } else {
    Write-Warn "winget was not found, so Poppler was not installed. PDF rendering may need manual setup."
  }
}

Write-Step "Checking edge-tts command path"
uvx --from edge-tts edge-tts --help | Out-Null
if ($LASTEXITCODE -ne 0) {
  Write-Warn "edge-tts warm-up failed. The skill may retry with 'uvx edge-tts' when first used."
}

Write-Step "Dependency check complete"
