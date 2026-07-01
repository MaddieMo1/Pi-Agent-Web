$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$launcher = Get-ChildItem -LiteralPath $projectRoot -Filter "*.bat" -File |
  Where-Object { (Get-Content -LiteralPath $_.FullName -Raw) -like "*maddie-start.ps1*" } |
  Select-Object -First 1

if (-not $launcher) {
  throw "Maddie Agent launcher was not found in: $projectRoot"
}

$launcherPath = $launcher.FullName
$iconPath = Join-Path $projectRoot "public\app-icon.ico"
$desktopPath = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktopPath "Maddie Agent.lnk"

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $launcherPath
$shortcut.WorkingDirectory = $projectRoot
$shortcut.WindowStyle = 1
$shortcut.Description = "Start Maddie Agent"
if (Test-Path -LiteralPath $iconPath) {
  $shortcut.IconLocation = $iconPath
}
$shortcut.Save()

Write-Host "Created desktop shortcut:"
Write-Host "  $shortcutPath"
