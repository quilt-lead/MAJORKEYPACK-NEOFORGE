$ErrorActionPreference = "Stop"

$RepoFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModsFolder = Join-Path $RepoFolder "mods"
$ManifestFile = Join-Path $RepoFolder "manifest.json"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "        MAJOR KEY PACK MANIFEST" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $ModsFolder)) {
    Write-Host "ERROR: mods folder not found:" -ForegroundColor Red
    Write-Host $ModsFolder -ForegroundColor Red
    exit 1
}

$Mods = Get-ChildItem -Path $ModsFolder -Filter "*.jar" -File |
    Sort-Object Name

Write-Host "Found $($Mods.Count) mod(s)." -ForegroundColor Green
Write-Host ""

$ModList = @()

foreach ($Mod in $Mods) {

    Write-Host "Scanning: $($Mod.Name)" -ForegroundColor Gray

    $Hash = Get-FileHash -Path $Mod.FullName -Algorithm SHA256

    $ModList += [ordered]@{
        filename = $Mod.Name
        size     = $Mod.Length
        sha256   = $Hash.Hash.ToLower()
    }
}

$Manifest = [ordered]@{
    minecraft = "1.21.1"
    loader    = "NeoForge"
    mods      = $ModList
}

$Json = $Manifest | ConvertTo-Json -Depth 10

[System.IO.File]::WriteAllText(
    $ManifestFile,
    $Json,
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host ""
Write-Host "Manifest updated:" -ForegroundColor Green
Write-Host $ManifestFile -ForegroundColor Gray
Write-Host ""
Write-Host "Minecraft: 1.21.1" -ForegroundColor Cyan
Write-Host "Loader:    NeoForge" -ForegroundColor Cyan
Write-Host "Mods:      $($Mods.Count)" -ForegroundColor Cyan
Write-Host ""