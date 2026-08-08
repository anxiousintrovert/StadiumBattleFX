param(
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"

$project = Split-Path -Parent $PSScriptRoot
$decoder = Join-Path $PSScriptRoot "mort_decoder\mort_decoder.exe"
$dist = Join-Path $project "dist\announcer-builder"
$work = Join-Path $project "build\announcer-builder"

& $Python -m ziglang c++ `
    -std=c++17 `
    -O3 `
    -DNDEBUG `
    -static `
    -Wno-format `
    -Wno-nullability-completeness `
    -o $decoder `
    (Join-Path $PSScriptRoot "mort_decoder\main.cpp") `
    (Join-Path $PSScriptRoot "mort_decoder\MORTDecoder.cpp")
if ($LASTEXITCODE -ne 0) {
    throw "MORT decoder build failed with exit code $LASTEXITCODE."
}

& $Python -m PyInstaller `
    --noconfirm `
    --clean `
    --onefile `
    --windowed `
    --name "StadiumBattleFX-Announcer-Builder" `
    --paths $PSScriptRoot `
    --add-binary "$decoder;." `
    --distpath $dist `
    --workpath $work `
    --specpath $work `
    (Join-Path $PSScriptRoot "announcer_builder_gui.py")

if ($LASTEXITCODE -ne 0) {
    throw "PyInstaller failed with exit code $LASTEXITCODE."
}

Write-Host (Join-Path $dist "StadiumBattleFX-Announcer-Builder.exe")
