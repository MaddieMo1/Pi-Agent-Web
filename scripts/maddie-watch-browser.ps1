param(
  [Parameter(Mandatory = $true)]
  [string]$MainUrl,

  [Parameter(Mandatory = $true)]
  [string]$StopScript
)

$ErrorActionPreference = "SilentlyContinue"

function Get-AppBrowserProcess {
  Get-CimInstance Win32_Process -Filter "name = 'msedge.exe' or name = 'chrome.exe'" |
    Where-Object { $_.CommandLine -like "*--app=$MainUrl*" }
}

$appeared = $false
$deadline = (Get-Date).AddSeconds(20)
while ((Get-Date) -lt $deadline) {
  if (Get-AppBrowserProcess) {
    $appeared = $true
    break
  }
  Start-Sleep -Milliseconds 500
}

if (-not $appeared) {
  exit 0
}

while ($true) {
  Start-Sleep -Seconds 2
  if (-not (Get-AppBrowserProcess)) {
    & $StopScript
    exit 0
  }
}
