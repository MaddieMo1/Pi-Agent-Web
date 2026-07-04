param(
  [switch]$NoBrowser
)

$ErrorActionPreference = "Stop"
$ProjectDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$AuthDir = Join-Path $ProjectDir "auth-server"
$AuthUrlConfigPath = Join-Path $ProjectDir "config\maddie-auth-url.txt"
$AuthBaseUrl = "http://127.0.0.1:4000"
if (Test-Path $AuthUrlConfigPath) {
  $configuredAuthUrl = (Get-Content -LiteralPath $AuthUrlConfigPath -Raw).Trim()
  if ($configuredAuthUrl) {
    $AuthBaseUrl = $configuredAuthUrl.TrimEnd("/")
  }
}
$UseLocalAuth = $AuthBaseUrl -match "^https?://(127\.0\.0\.1|localhost)(:\d+)?$"
$MainUrl = "http://127.0.0.1:30141"
$AuthUrl = "$AuthBaseUrl/health"
$LogDir = Join-Path $ProjectDir ".maddie-logs"

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

try {
  & (Join-Path $PSScriptRoot "create-desktop-shortcut.ps1") | Out-Null
} catch {
  Write-Warning "Desktop shortcut could not be created, but Maddie Agent can still start."
}

function Test-PortListening([int]$Port) {
  $conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
  return $null -ne $conn
}

function Wait-Url([string]$Url, [int]$Seconds) {
  $deadline = (Get-Date).AddSeconds($Seconds)
  while ((Get-Date) -lt $deadline) {
    try {
      $res = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 2
      if ($res.StatusCode -ge 200 -and $res.StatusCode -lt 500) { return $true }
    } catch {
      Start-Sleep -Milliseconds 500
    }
  }
  return $false
}

function Find-Browser {
  $candidates = @(
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
  )
  foreach ($path in $candidates) {
    if ($path -and (Test-Path $path)) { return $path }
  }
  return $null
}

if (-not (Test-Path (Join-Path $ProjectDir "package.json"))) {
  throw "package.json was not found in $ProjectDir"
}

if (Test-Path (Join-Path $ProjectDir "config\tavily-api-key.txt")) {
  $env:TAVILY_API_KEY = (Get-Content -LiteralPath (Join-Path $ProjectDir "config\tavily-api-key.txt") -Raw).Trim()
}

if (Test-Path (Join-Path $PSScriptRoot "bootstrap-deps.ps1")) {
  & (Join-Path $PSScriptRoot "bootstrap-deps.ps1") -ProjectDir $ProjectDir
}

$env:PATH = "$ProjectDir\node_modules\.bin;$env:USERPROFILE\.local\bin;$env:ProgramFiles\nodejs;${env:ProgramFiles(x86)}\nodejs;$env:ProgramFiles\Git\cmd;$env:ProgramFiles\Git\bin;$env:PATH"
Get-ChildItem -LiteralPath (Join-Path $ProjectDir ".pi-bootstrap") -Directory -Filter "node-v*-win-*" -ErrorAction SilentlyContinue |
  ForEach-Object { $env:PATH = "$($_.FullName);$env:PATH" }
$portableGitDir = Join-Path $ProjectDir ".pi-bootstrap\PortableGit"
foreach ($relativePath in @("cmd", "bin", "usr\bin")) {
  $path = Join-Path $portableGitDir $relativePath
  if (Test-Path $path) {
    $env:PATH = "$path;$env:PATH"
  }
}

if (-not (Test-Path (Join-Path $ProjectDir "node_modules"))) {
  npm install --no-audit --no-fund
  if ($LASTEXITCODE -ne 0) {
    throw "npm install failed."
  }
}

if ($UseLocalAuth -and -not (Test-Path (Join-Path $AuthDir "package.json"))) {
  throw "auth-server/package.json was not found."
}

if ($UseLocalAuth -and -not (Test-Path (Join-Path $AuthDir "node_modules"))) {
  Push-Location $AuthDir
  try {
    npm install --omit=dev --no-audit --no-fund
    if ($LASTEXITCODE -ne 0) {
      throw "auth-server npm install failed."
    }
  } finally {
    Pop-Location
  }
}

if ($UseLocalAuth -and -not (Test-PortListening 4000)) {
  Start-Process -FilePath "npm.cmd" `
    -ArgumentList @("start") `
    -WorkingDirectory $AuthDir `
    -WindowStyle Hidden `
    -RedirectStandardOutput (Join-Path $LogDir "auth-server.out.log") `
    -RedirectStandardError (Join-Path $LogDir "auth-server.err.log") | Out-Null
}

if (-not (Test-PortListening 30141)) {
  $env:NEXT_PUBLIC_AUTH_SERVER_URL = $AuthBaseUrl
  Start-Process -FilePath "node.exe" `
    -ArgumentList @("node_modules\next\dist\bin\next", "dev", "--webpack", "-p", "30141") `
    -WorkingDirectory $ProjectDir `
    -WindowStyle Hidden `
    -RedirectStandardOutput (Join-Path $LogDir "pi-web.out.log") `
    -RedirectStandardError (Join-Path $LogDir "pi-web.err.log") | Out-Null
}

if (-not (Wait-Url $AuthUrl 20)) {
  Write-Warning "auth-server did not respond at $AuthUrl within 20 seconds."
}

if (-not (Wait-Url $MainUrl 40)) {
  Write-Warning "Maddie Agent did not respond at $MainUrl within 40 seconds."
}

if (-not $NoBrowser) {
  $browser = Find-Browser
  if ($browser) {
    Start-Process -FilePath $browser -ArgumentList @("--app=$MainUrl", "--new-window") | Out-Null
    Start-Process -FilePath "powershell.exe" `
      -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $PSScriptRoot "maddie-watch-browser.ps1"),
        "-MainUrl", $MainUrl,
        "-StopScript", (Join-Path $PSScriptRoot "maddie-stop.ps1")
      ) `
      -WindowStyle Hidden | Out-Null
  } else {
    Start-Process $MainUrl | Out-Null
  }
}

Write-Host "Maddie Agent is running:"
Write-Host "  App:  $MainUrl"
Write-Host "  Auth: $AuthBaseUrl"
Write-Host "Logs:"
Write-Host "  $LogDir"
