param(
    [string]$Python = "python",
    [string]$CertificateThumbprint = ""
)

$ErrorActionPreference = "Stop"

$project = Split-Path -Parent $PSScriptRoot
$decoder = Join-Path $PSScriptRoot "mort_decoder\mort_decoder.exe"
$dist = Join-Path $project "dist\announcer-builder"
$work = Join-Path $project "build\announcer-builder"
$releaseZip = Join-Path $project "dist\StadiumBattleFX-Announcer-Builder-windows.zip"

& $Python -c "from lupa.luajit21 import LuaRuntime"
if ($LASTEXITCODE -ne 0) {
    throw "The builder environment needs lupa (python -m pip install lupa)."
}

# Deliberately produce ordinary, inspectable PE files. Do not use PyInstaller
# --onefile or static linking: both create a self-extracting executable shape
# that reputation and heuristic scanners frequently classify as a dropper.
& $Python -m ziglang c++ `
    -std=c++17 `
    -O2 `
    -DNDEBUG `
    -target x86_64-windows-gnu `
    -mcpu=baseline `
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
    --onedir `
    --noupx `
    --windowed `
    --name "StadiumBattleFX-Announcer-Builder" `
    --paths $PSScriptRoot `
    --hidden-import "lupa.luajit21" `
    --add-binary "$decoder;." `
    --add-data "$(Join-Path $PSScriptRoot 'build_stadium_cache.lua');." `
    --distpath $dist `
    --workpath $work `
    --specpath $work `
    (Join-Path $PSScriptRoot "announcer_builder_gui.py")
if ($LASTEXITCODE -ne 0) {
    throw "PyInstaller failed with exit code $LASTEXITCODE."
}

$app = Join-Path $dist "StadiumBattleFX-Announcer-Builder\StadiumBattleFX-Announcer-Builder.exe"
if ($CertificateThumbprint) {
    $signtool = Get-Command signtool.exe -ErrorAction Stop
    & $signtool.Source sign /sha1 $CertificateThumbprint /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 $decoder $app
    if ($LASTEXITCODE -ne 0) {
        throw "Authenticode signing failed with exit code $LASTEXITCODE."
    }
}

if (Test-Path $releaseZip) {
    Remove-Item -LiteralPath $releaseZip -Force
}
Compress-Archive -Path (Join-Path $dist "StadiumBattleFX-Announcer-Builder") -DestinationPath $releaseZip -CompressionLevel Optimal
$hash = (Get-FileHash -LiteralPath $releaseZip -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath ($releaseZip + ".sha256") -Value "$hash  $(Split-Path -Leaf $releaseZip)" -NoNewline

Write-Host "Built $releaseZip"
Write-Host "SHA-256: $hash"
if (-not $CertificateThumbprint) {
    Write-Warning "The release is unsigned. Sign it with a trusted Authenticode certificate before public distribution."
}
