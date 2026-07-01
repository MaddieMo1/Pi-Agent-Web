$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot "maddie-stop.ps1")
Start-Sleep -Seconds 1
& (Join-Path $PSScriptRoot "maddie-start.ps1")
