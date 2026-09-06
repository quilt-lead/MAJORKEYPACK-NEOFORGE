param([string]$InstallDirectory="$env:APPDATA\MajorKeyPack")

$ErrorActionPreference="Stop"

$Raw="https://raw.githubusercontent.com/quilt-lead/MAJORKEYPACK/main"
$Temp=Join-Path $env:TEMP "MajorKeyPack"
$Mods=Join-Path (Join-Path $env:APPDATA ".minecraft") "mods"

if(Test-Path $Temp){Remove-Item $Temp -Recurse -Force}
New-Item $Temp -ItemType Directory -Force | Out-Null
New-Item $Mods -ItemType Directory -Force | Out-Null

Write-Host ""
Write-Host "Downloading Major Key Pack manifest..."

Invoke-WebRequest `
    "$Raw/modpack-manifest.json" `
    -OutFile "$Temp\manifest.json"

$Manifest=Get-Content "$Temp\manifest.json" -Raw | ConvertFrom-Json

if($Manifest.minecraft -ne "1.20.1"){
    throw "Minecraft 1.20.1 is required."
}

if($Manifest.loader -ne "Forge"){
    throw "Forge is required."
}

Write-Host ""
Write-Host "Major Key Pack"
Write-Host "Minecraft: $($Manifest.minecraft)"
Write-Host "Loader: $($Manifest.loader)"
Write-Host "Mods: $($Manifest.mods.Count)"
Write-Host ""

foreach($Mod in $Manifest.mods){

    $Destination=Join-Path $Mods $Mod.filename

    if($Mod.filename -eq "OptiFine_1.20.1_HD_U_I6.jar" -and (Test-Path $Destination) -and (Get-Item $Destination).Length -eq $Mod.size){ Write-Host "Using existing OptiFine JAR..."; continue }; Write-Host "Downloading $($Mod.filename)..."

    if($Mod.filename -eq "OptiFine_1.20.1_HD_U_I6.jar"){curl.exe -L --fail --silent --show-error --output "$Destination" "https://optifine.tommo.team/OptiFine_1.20.1_HD_U_I6.jar"}else{curl.exe -L --fail --silent --show-error --output "$Destination" "$($Mod.url)"}

    if(!(Test-Path $Destination)){
        throw "Download failed: $($Mod.filename)"
    }

    $File=Get-Item $Destination

    if($File.Length -ne $Mod.size){
        Remove-Item $Destination -Force
        throw "Size mismatch: $($Mod.filename)"
    }

    $Hash=(Get-FileHash $Destination -Algorithm SHA256).Hash.ToLower()

    if($Hash -ne $Mod.sha256){
        Remove-Item $Destination -Force
        throw "SHA256 mismatch: $($Mod.filename)"
    }

    Write-Host "OK: $($Mod.filename)" -ForegroundColor Green
}

[PSCustomObject]@{
    name=$Manifest.name
    version=$Manifest.version
    minecraft=$Manifest.minecraft
    loader=$Manifest.loader
    installed=(Get-Date).ToString("o")
} | ConvertTo-Json | Set-Content `
    "$InstallDirectory\major-key-pack.json" `
    -Encoding UTF8

Write-Host ""
Write-Host "========================================"
Write-Host " MAJOR KEY PACK INSTALLED"
Write-Host "========================================"
Write-Host ""
Write-Host "Location: $InstallDirectory"
Write-Host "Mods: $($Manifest.mods.Count)"
Write-Host ""




