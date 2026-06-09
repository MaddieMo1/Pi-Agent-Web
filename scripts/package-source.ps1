param(
  [string]$ProjectDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [string]$OutputDir = (Join-Path $ProjectDir "dist")
)

$ErrorActionPreference = "Stop"

$includePaths = @(
  ".agents/skills",
  "app",
  "bin",
  "components",
  "config",
  "hooks",
  "lib",
  "public",
  "scripts",
  "vendor",
  "eslint.config.mjs",
  "LICENSE",
  "next.config.ts",
  "package.json",
  "package-lock.json",
  "postcss.config.mjs",
  "README.md",
  "tailwind.config.ts",
  "tsconfig.json"
)

$includeRootFilePatterns = @(
  "*.bat"
)

$excludeNames = @(
  ".git",
  ".next",
  ".pi-bootstrap",
  "node_modules",
  "dist",
  "coverage",
  ".vercel",
  ".factory",
  "next-env.d.ts",
  "tsconfig.tsbuildinfo",
  "tavily-api-key.txt"
)

$excludeRelativePaths = @(
  ".env",
  ".env.local",
  ".env.development",
  ".env.production",
  "config/tavily-api-key.txt"
)

function Get-ProjectRelativePath {
  param([string]$FullPath)

  $root = (Resolve-Path -LiteralPath $ProjectDir).Path.TrimEnd("\", "/")
  $resolved = (Resolve-Path -LiteralPath $FullPath).Path
  if (-not $resolved.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Path is outside project directory: $FullPath"
  }

  return $resolved.Substring($root.Length).TrimStart("\", "/")
}

function Test-Excluded {
  param([string]$FullPath)

  $relative = (Get-ProjectRelativePath $FullPath).Replace("\", "/")
  $name = Split-Path -Leaf $FullPath

  if ($excludeNames -contains $name) {
    return $true
  }

  foreach ($excluded in $excludeRelativePaths) {
    if ($relative -eq $excluded -or $relative.StartsWith("$excluded/")) {
      return $true
    }
  }

  return $false
}

function Copy-IncludedPath {
  param(
    [string]$RelativePath,
    [string]$StagingDir
  )

  $source = Join-Path $ProjectDir $RelativePath
  if (-not (Test-Path -LiteralPath $source)) {
    throw "Required package path is missing: $RelativePath"
  }

  $target = Join-Path $StagingDir $RelativePath
  $sourceItem = Get-Item -LiteralPath $source -Force

  if (-not $sourceItem.PSIsContainer) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    Copy-Item -LiteralPath $source -Destination $target -Force
    return
  }

  Get-ChildItem -LiteralPath $source -Recurse -Force | ForEach-Object {
    if (Test-Excluded $_.FullName) {
      return
    }

    $relative = Get-ProjectRelativePath $_.FullName
    $destination = Join-Path $StagingDir $relative
    if ($_.PSIsContainer) {
      New-Item -ItemType Directory -Force -Path $destination | Out-Null
    } else {
      New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
      Copy-Item -LiteralPath $_.FullName -Destination $destination -Force
    }
  }
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$staging = Join-Path $OutputDir "pi-agent-web-source-$stamp"
$zipPath = Join-Path $OutputDir "pi-agent-web-source-$stamp.zip"

if (Test-Path -LiteralPath $staging) {
  Remove-Item -LiteralPath $staging -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $staging | Out-Null

try {
  foreach ($path in $includePaths) {
    Copy-IncludedPath -RelativePath $path -StagingDir $staging
  }

  foreach ($pattern in $includeRootFilePatterns) {
    Get-ChildItem -LiteralPath $ProjectDir -File -Filter $pattern | ForEach-Object {
      if (-not (Test-Excluded $_.FullName)) {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $staging $_.Name) -Force
      }
    }
  }

  if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
  }
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  [System.IO.Compression.ZipFile]::CreateFromDirectory($staging, $zipPath)
  Write-Host "Created source package:"
  Write-Host $zipPath
} finally {
  if (Test-Path -LiteralPath $staging) {
    Remove-Item -LiteralPath $staging -Recurse -Force
  }
}
