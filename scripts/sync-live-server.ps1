# Sync the live Qbox installation into the GTARP Git repository.
# Run this on the Windows server PC from the root of the local GTARP clone.
# This script intentionally excludes runtime state, logs, caches, databases and secrets.

[CmdletBinding()]
param(
    [string]$LiveRoot = 'H:\GTARP\txData\Qbox_A4B177.base',
    [string]$RepoRoot = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $LiveRoot)) {
    throw "Live server path not found: $LiveRoot"
}
if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot '.git'))) {
    throw "Run this script from the root of the local GTARP Git repository."
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$LiveRoot = (Resolve-Path -LiteralPath $LiveRoot).Path

$items = @(
    'resources',
    'server.cfg',
    'ox.cfg',
    'voice.cfg',
    'permissions.cfg'
)

# Never copy these live-server/runtime paths into Git.
$excluded = @(
    '.git',
    'cache',
    'crashes',
    'logs',
    'local-database',
    '.console-history',
    'id',
    'server.cfg.bkp'
)

foreach ($item in $items) {
    $source = Join-Path $LiveRoot $item
    $destination = Join-Path $RepoRoot $item

    if (-not (Test-Path -LiteralPath $source)) {
        Write-Warning "Skipping missing path: $source"
        continue
    }

    if ((Get-Item -LiteralPath $source).PSIsContainer) {
        robocopy $source $destination /E /COPY:DAT /DCOPY:DAT /R:2 /W:1 /XJ /XD @('cache','logs','node_modules') /XF @('*.log','*.tmp','*.bak') | Out-Host
        if ($LASTEXITCODE -gt 7) { throw "robocopy failed for $item with exit code $LASTEXITCODE" }
    }
    else {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
        Copy-Item -LiteralPath $source -Destination $destination -Force
    }
}

Write-Host ''
Write-Host 'Sync complete. Review changes before committing.' -ForegroundColor Green
Write-Host 'Run: git status' -ForegroundColor Cyan
Write-Host 'Then inspect for secrets before git add/commit.' -ForegroundColor Yellow
