param([string]$InstallDirectory="$env:APPDATA\MajorKeyPack")

$ErrorActionPreference="Stop"
$Repo="https://github.com/quilt-lead/MAJORKEYPACK"
$Raw="https://raw.githubusercontent.com/quilt-lead/MAJORKEYPACK/main"
$Temp=Join-Path $env:TEMP "MajorKeyPack"
$Mods=Join-Path $InstallDirectory "mods"

if(Test-Path $Temp){Remove-Item $Temp -Recurse -Force}
New-Item $Temp -ItemType Directory -Force | Out-Null
New-Item $Mods -ItemType Directory -Force | Out-Null

Write-Host "Downloading manifest..."
Invoke-WebRequest "$Raw/modpack-manifest.json" -OutFile "$Temp\manifest.json"

$Manifest=Get-Content "$Temp\manifest.json" -Raw | ConvertFrom-Json

if($Manifest.minecraft -ne "1.20.1"){throw "Minecraft 1.20.1 is required."}
if($Manifest.loader -ne "Forge"){throw "Forge is required."}

Write-Host "Major Key Pack $($Manifest.version)"
Write-Host "Mods: $($Manifest.mods.Count)"

$Zip="$Temp\mods.zip"

Write-Host "Downloading mods..."
Invoke-WebRequest "$Repo/releases/latest/download/mods.zip" -OutFile $Zip

Write-Host "Extracting mods..."
Expand-Archive $Zip $Mods -Force

Write-Host "Verifying mods..."

foreach($Mod in $Manifest.mods){
    $File=Join-Path $Mods $Mod.filename

    if(!(Test-Path $File)){
        throw "Missing mod: $($Mod.filename)"
    }

    $Hash=(Get-FileHash $File -Algorithm SHA256).Hash.ToLower()

    if($Hash -ne $Mod.sha256){
        throw "Hash mismatch: $($Mod.filename)"
    }

    Write-Host "OK: $($Mod.filename)" -ForegroundColor Green
}

[PSCustomObject]@{
    name=$Manifest.name
    version=$Manifest.version
    minecraft=$Manifest.minecraft
    loader=$Manifest.loader
    installed=(Get-Date).ToString("o")
}|ConvertTo-Json|Set-Content "$InstallDirectory\major-key-pack.json" -Encoding UTF8

Write-Host ""
Write-Host "========================================"
Write-Host " MAJOR KEY PACK INSTALLED" -ForegroundColor Green
Write-Host "========================================"
Write-Host "Location: $InstallDirectory"
Write-Host "Mods: $($Manifest.mods.Count)"
Write-Host ""
