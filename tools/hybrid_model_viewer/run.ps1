$ErrorActionPreference = 'Stop'

$workspace = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$love = Join-Path $workspace '.tools\love-11.5-win64\love.exe'
$storage = Join-Path $env:APPDATA 'pokemon-love2d\mod_storage\yellow'

if (-not (Test-Path -LiteralPath $love -PathType Leaf)) {
    throw "LÖVE runtime not found: $love"
}

$latest = Get-ChildItem -LiteralPath $storage -Recurse -File -Filter '004.lua' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match 'STADIUM_BATTLE_FX[\\/]models[\\/]packs[\\/]004\.lua$' } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if ($latest) {
    $env:S1_PACK_ROOT = $latest.DirectoryName
    Write-Host "Using Stadium 1 pack: $env:S1_PACK_ROOT"
} else {
    Remove-Item Env:S1_PACK_ROOT -ErrorAction SilentlyContinue
    Write-Warning 'No active v6 Stadium 1 pack found; using the loose developer cache.'
}

$env:STADIUM_WORKSPACE = $workspace
& $love $PSScriptRoot
