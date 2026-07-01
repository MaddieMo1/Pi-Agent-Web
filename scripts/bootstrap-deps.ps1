param(
  [string]$ProjectDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [switch]$ChinaMode
)

$ErrorActionPreference = "Stop"
$script:BootstrapStateDir = Join-Path $ProjectDir ".pi-bootstrap"

function Write-Step {
  param([string]$Message)
  Write-Host ""
  Write-Host "==> $Message"
}

function Write-Warn {
  param([string]$Message)
  Write-Host "WARN: $Message" -ForegroundColor Yellow
}

function Write-Info {
  param([string]$Message)
  Write-Host "INFO: $Message"
}

function Test-Command {
  param([string]$Name)
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Find-GitBash {
  $candidates = @(
    (Join-Path $env:ProgramFiles "Git\bin\bash.exe"),
    (Join-Path $env:ProgramFiles "Git\usr\bin\bash.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Git\bin\bash.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Git\usr\bin\bash.exe"),
    (Join-Path $script:BootstrapStateDir "PortableGit\bin\bash.exe"),
    (Join-Path $script:BootstrapStateDir "PortableGit\usr\bin\bash.exe")
  )

  foreach ($path in $candidates) {
    if ($path -and (Test-Path -LiteralPath $path)) {
      return $path
    }
  }

  return $null
}

function Test-NodeVersionAtLeast {
  param([version]$MinimumVersion)

  if (-not (Test-Command node)) {
    return $false
  }

  try {
    $current = [version]((node --version).TrimStart("v"))
    return $current -ge $MinimumVersion
  } catch {
    return $false
  }
}

function Refresh-Path {
  $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  $localBin = Join-Path $env:USERPROFILE ".local\bin"
  $gitCmd = Join-Path $env:ProgramFiles "Git\cmd"
  $gitBin = Join-Path $env:ProgramFiles "Git\bin"
  $portableGit = Join-Path $script:BootstrapStateDir "PortableGit"
  $portableGitCmd = Join-Path $portableGit "cmd"
  $portableGitBin = Join-Path $portableGit "bin"
  $portableGitUsrBin = Join-Path $portableGit "usr\bin"
  $portableNode = Get-ChildItem -Path $script:BootstrapStateDir -Directory -Filter "node-v*-win-*" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  $portableNodePath = if ($portableNode) { $portableNode.FullName } else { $null }
  $paths = @($env:Path, $portableNodePath, $portableGitCmd, $portableGitBin, $portableGitUsrBin, $machinePath, $userPath, $localBin, $gitCmd, $gitBin) |
    Where-Object { $_ -and $_.Trim().Length -gt 0 }
  $env:Path = ($paths -join ";")
}

function Set-PortableUvEnvironment {
  $stateDir = $script:BootstrapStateDir
  $tempDir = Join-Path $stateDir "tmp"
  $cacheDir = Join-Path $stateDir "uv-cache"

  try {
    New-Item -ItemType Directory -Force -Path $tempDir, $cacheDir | Out-Null
  } catch {
    $stateDir = Join-Path $env:LOCALAPPDATA "Pi-Agent-Web\bootstrap"
    $tempDir = Join-Path $stateDir "tmp"
    $cacheDir = Join-Path $stateDir "uv-cache"
    New-Item -ItemType Directory -Force -Path $tempDir, $cacheDir | Out-Null
  }

  $env:TEMP = $tempDir
  $env:TMP = $tempDir
  $env:UV_CACHE_DIR = $cacheDir
}

function Get-NodePlatformArch {
  if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64" -or $env:PROCESSOR_ARCHITEW6432 -eq "ARM64") {
    return "arm64"
  }
  return "x64"
}

function Install-PortableNode {
  param([version]$Version)

  $arch = Get-NodePlatformArch
  $nodeDirName = "node-v$Version-win-$arch"
  $nodeDir = Join-Path $script:BootstrapStateDir $nodeDirName
  if (Test-Path (Join-Path $nodeDir "node.exe")) {
    Refresh-Path
    return
  }

  New-Item -ItemType Directory -Force -Path $script:BootstrapStateDir | Out-Null
  $zipPath = Join-Path $script:BootstrapStateDir "$nodeDirName.zip"
  if ($ChinaMode -or $env:PI_AGENT_CN_MODE -eq "1") {
    $baseUrl = "https://npmmirror.com/mirrors/node"
  } else {
    $baseUrl = "https://nodejs.org/dist"
  }
  $url = "$baseUrl/v$Version/$nodeDirName.zip"

  Write-Step "Installing portable Node.js"
  Write-Info "Downloading $url"
  Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $zipPath
  Expand-Archive -LiteralPath $zipPath -DestinationPath $script:BootstrapStateDir -Force
  Refresh-Path
}

function Install-PortableGit {
  if ((Get-NodePlatformArch) -ne "x64") {
    Write-Warn "Portable Git fallback currently supports x64 Windows only. Install Git for Windows manually if bash is needed."
    return
  }

  $gitDir = Join-Path $script:BootstrapStateDir "PortableGit"
  if (Test-Path (Join-Path $gitDir "usr\bin\bash.exe")) {
    Refresh-Path
    return
  }

  New-Item -ItemType Directory -Force -Path $script:BootstrapStateDir | Out-Null
  $vendorDir = Join-Path $ProjectDir "vendor"
  $bundledInstaller = Get-ChildItem -Path $vendorDir -File -Filter "PortableGit-*-64-bit.7z.exe" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  $installerPath = Join-Path $script:BootstrapStateDir "PortableGit-64-bit.7z.exe"
  $urls = @(
    "https://github.com/git-for-windows/git/releases/download/v2.54.0.windows.1/PortableGit-2.54.0-64-bit.7z.exe",
    "https://sourceforge.net/projects/git-for-windows.mirror/files/v2.54.0.windows.1/PortableGit-2.54.0-64-bit.7z.exe/download"
  )

  Write-Step "Installing portable Git Bash"
  if ($bundledInstaller) {
    Write-Info "Using bundled PortableGit installer: $($bundledInstaller.FullName)"
    Copy-Item -LiteralPath $bundledInstaller.FullName -Destination $installerPath -Force
  }

  if (Test-Path $installerPath) {
    $header = [byte[]](Get-Content -LiteralPath $installerPath -Encoding Byte -TotalCount 2)
    if ($header.Length -lt 2 -or $header[0] -ne 0x4D -or $header[1] -ne 0x5A) {
      Write-Warn "Bundled PortableGit installer is not a valid Windows executable. Falling back to download."
      Remove-Item -LiteralPath $installerPath -Force
    }
  }

  if (-not (Test-Path $installerPath)) {
    foreach ($url in $urls) {
      try {
        if (Test-Path $installerPath) {
          Remove-Item -LiteralPath $installerPath -Force
        }
        Write-Info "Downloading $url"
        Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $installerPath

        $header = [byte[]](Get-Content -LiteralPath $installerPath -Encoding Byte -TotalCount 2)
        if ($header.Length -lt 2 -or $header[0] -ne 0x4D -or $header[1] -ne 0x5A) {
          Write-Warn "Downloaded file is not a valid Windows executable. Trying another source."
          Remove-Item -LiteralPath $installerPath -Force
          continue
        }
        break
      } catch {
        Write-Warn "Portable Git download attempt failed: $url"
      }
    }
  }

  if (-not (Test-Path $installerPath)) {
    Write-Warn "Portable Git installer is unavailable. Pi Agent Web can start, but bash-based tools may fail."
    return
  }

  try {
    if (Test-Path $gitDir) {
      Remove-Item -LiteralPath $gitDir -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $gitDir | Out-Null
    & $installerPath -y "-o$gitDir" | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $gitDir "usr\bin\bash.exe"))) {
      Write-Warn "Portable Git extraction failed. Pi Agent Web can start, but bash-based tools may fail."
      return
    }
  } catch {
    Write-Warn "Portable Git extraction failed. Pi Agent Web can start, but bash-based tools may fail."
    return
  }

  Refresh-Path
}

function Set-ChinaModeEnvironment {
  Write-Step "Enabling China network mode"
  $env:PI_AGENT_CN_MODE = "1"
  $env:NPM_CONFIG_REGISTRY = "https://registry.npmmirror.com"
  $env:npm_config_registry = "https://registry.npmmirror.com"
  $env:UV_INDEX_URL = "https://pypi.tuna.tsinghua.edu.cn/simple"
  $env:PIP_INDEX_URL = "https://pypi.tuna.tsinghua.edu.cn/simple"
  Write-Info "npm registry: $env:NPM_CONFIG_REGISTRY"
  Write-Info "Python package index: $env:UV_INDEX_URL"
  Write-Info "GitHub, winget sources, skills.sh, and model APIs may still need a working network or proxy."
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

function Sync-BundledSkills {
  $sourceDir = Join-Path $ProjectDir ".agents\skills"
  $targetDir = Join-Path $env:USERPROFILE ".pi\agent\skills"

  if (-not (Test-Path $sourceDir)) {
    Write-Warn "Bundled skills folder was not found: $sourceDir"
    return
  }

  Write-Step "Syncing bundled skills"
  New-Item -ItemType Directory -Force -Path $targetDir | Out-Null

  Get-ChildItem -Path $sourceDir -Directory | ForEach-Object {
    $targetSkillDir = Join-Path $targetDir $_.Name
    if (Test-Path $targetSkillDir) {
      Remove-Item -LiteralPath $targetSkillDir -Recurse -Force
    }
    Copy-Item -LiteralPath $_.FullName -Destination $targetSkillDir -Recurse -Force
    Write-Info "Synced bundled skill: $($_.Name)"
  }
}

Set-Location $ProjectDir
Refresh-Path
Set-PortableUvEnvironment

if ($ChinaMode -or $env:PI_AGENT_CN_MODE -eq "1") {
  Set-ChinaModeEnvironment
}

Sync-BundledSkills

Write-Step "Checking Node.js and npm"
$minimumNodeVersion = [version]"22.19.0"
if (-not (Test-Command node) -or -not (Test-Command npm) -or -not (Test-NodeVersionAtLeast $minimumNodeVersion)) {
  if (Test-Command winget) {
    Install-WithWinget -Id "OpenJS.NodeJS.LTS" -Name "Node.js LTS"
  } else {
    Write-Warn "winget was not found. Installing portable Node.js into this project instead."
    Install-PortableNode -Version $minimumNodeVersion
  }
}
Refresh-Path

if (-not (Test-Command node) -or -not (Test-Command npm) -or -not (Test-NodeVersionAtLeast $minimumNodeVersion)) {
  throw "Node.js/npm still cannot be found at version >= $minimumNodeVersion after installation. Close this window and run the launcher again."
}

node --version
npm --version

Write-Step "Checking Git"
if (-not (Test-Command git)) {
  if (Test-Command winget) {
    Install-WithWinget -Id "Git.Git" -Name "Git"
  } else {
    Write-Warn "winget was not found. Installing portable Git Bash into this project instead."
    Install-PortableGit
  }
}
Refresh-Path

if (Test-Command git) {
  git --version
} else {
  Write-Warn "Git is not available. Installing extra skills from GitHub may fail."
}

$gitBash = Find-GitBash
if ($gitBash) {
  & $gitBash --version | Select-Object -First 1
} else {
  Write-Warn "Git Bash is not available. Bash-based tool commands may fail."
}

Write-Step "Checking uv and uvx"
if (-not (Test-Command uv) -or -not (Test-Command uvx)) {
  if ($ChinaMode -or $env:PI_AGENT_CN_MODE -eq "1") {
    if (Test-Command winget) {
      Write-Step "Installing uv with winget"
      winget install --exact --id "astral-sh.uv" --accept-package-agreements --accept-source-agreements
      if ($LASTEXITCODE -ne 0) {
        Write-Warn "winget could not install uv. Trying the official uv installer instead."
      }
      Refresh-Path
    } else {
      Write-Warn "winget was not found. Trying the official uv installer instead."
    }
  }

  if (-not (Test-Command uv) -or -not (Test-Command uvx)) {
    Write-Step "Installing uv"
    powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://astral.sh/uv/install.ps1 | iex"
    if ($LASTEXITCODE -ne 0) {
      throw "uv installation failed."
    }
    Refresh-Path
  }
}

if (-not (Test-Command uv) -or -not (Test-Command uvx)) {
  throw "uv/uvx still cannot be found after installation. Close this window and run the launcher again."
}

uv --version

Write-Step "Checking Tavily CLI"
if (-not (Test-Command tvly)) {
  uv tool install tavily-cli
  if ($LASTEXITCODE -ne 0) {
    Write-Warn "Could not install Tavily CLI automatically. The tavily-search skill may ask for tvly when first used."
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
    Write-Info "Tavily CLI is installed. Run 'tvly login' only if web search asks for authentication."
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

Write-Step "Checking edge-tts setup"
Write-Info "edge-tts will be prepared by uvx the first time text-to-speech is used."

Write-Step "Dependency check complete"
