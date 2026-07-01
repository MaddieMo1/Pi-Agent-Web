$ErrorActionPreference = "Stop"

function Stop-Port([int]$Port) {
  $processIds = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -Unique

  foreach ($processId in $processIds) {
    if ($processId) {
      Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
      Write-Host "Stopped process $processId on port $Port"
    }
  }
}

function Stop-AppBrowserWindow {
  $matches = Get-CimInstance Win32_Process -Filter "name = 'msedge.exe' or name = 'chrome.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*--app=http://127.0.0.1:30141*" }

  foreach ($proc in $matches) {
    Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
    Write-Host "Closed Maddie Agent app window process $($proc.ProcessId)"
  }
}

Stop-Port 30141
Stop-Port 4000
Stop-AppBrowserWindow

Write-Host "Maddie Agent has stopped."
