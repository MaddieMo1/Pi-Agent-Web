$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$launcher = Get-ChildItem -LiteralPath $projectRoot -Filter "* Pi Agent.bat" -File |
  Where-Object { $_.Name -like "*Pi Agent.bat" } |
  Select-Object -First 1

if (-not $launcher) {
  throw "Launcher not found in: $projectRoot"
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
