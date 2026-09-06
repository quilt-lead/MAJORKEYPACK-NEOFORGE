$ErrorActionPreference="Stop"

$InstallDirectory="$env:APPDATA\MajorKeyPack"
$MinecraftDirectory="$env:APPDATA\.minecraft"

Write-Host ""
Write-Host "========================================"
Write-Host "        MAJOR KEY PACK INSTALLER"
Write-Host "========================================"
Write-Host ""

if(!(Test-Path $MinecraftDirectory)){
    Write-Host "Minecraft was not found." -ForegroundColor Red
    Write-Host "Please install Minecraft Java Edition first."
    exit 1
}

$Forge=Get-ChildItem "$MinecraftDirectory\versions" -Directory -ErrorAction SilentlyContinue |
    Where-Object {$_.Name -like "1.20.1-forge-*"} |
    Select-Object -First 1

if(!$Forge){
    Write-Host "Forge 1.20.1 was not found." -ForegroundColor Red
    Write-Host "Please install Forge 1.20.1 using the Minecraft Launcher first."
    exit 1
}

Write-Host "Forge detected: $($Forge.Name)" -ForegroundColor Green

if(Test-Path $InstallDirectory){
    Write-Host "Existing Major Key Pack installation found."
}else{
    New-Item $InstallDirectory -ItemType Directory -Force | Out-Null
}

$Script=Join-Path $PSScriptRoot "Install-MajorKeyPack.ps1"

if(!(Test-Path $Script)){
    throw "Install-MajorKeyPack.ps1 was not found."
}

& powershell.exe `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -File $Script `
    -InstallDirectory $InstallDirectory

if($LASTEXITCODE -ne 0){
    throw "Major Key Pack installation failed."
}

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Installed to:"
Write-Host $InstallDirectory
Write-Host ""
Read-Host "Press ENTER to close"
