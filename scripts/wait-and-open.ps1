param(
  [string]$Url = "http://localhost:30141",
  [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = "SilentlyContinue"

for ($i = 0; $i -lt $TimeoutSeconds; $i++) {
  try {
    Invoke-WebRequest -UseBasicParsing -Uri $Url -TimeoutSec 1 | Out-Null
    Start-Process $Url
    exit 0
  } catch {
    Start-Sleep -Seconds 1
  }
}

exit 1
