param(
    [string]$InstallDirectory="$env:APPDATA\MajorKeyPack"
)

$ErrorActionPreference="Stop"

try {

    $Raw="https://raw.githubusercontent.com/quilt-lead/MAJORKEYPACK/main"
    $Temp=Join-Path $env:TEMP "MajorKeyPack"
    $MinecraftDirectory=Join-Path $env:APPDATA ".minecraft"
    $Mods=Join-Path $MinecraftDirectory "mods"

    if(!(Test-Path $MinecraftDirectory)){
        throw "Minecraft Java Edition was not found. Please install Minecraft Java Edition first."
    }

    if(Test-Path $Temp){
        Remove-Item $Temp -Recurse -Force
    }

    New-Item $Temp -ItemType Directory -Force | Out-Null
    New-Item $Mods -ItemType Directory -Force | Out-Null
    New-Item $InstallDirectory -ItemType Directory -Force | Out-Null

    Write-Host ""
    Write-Host "========================================"
    Write-Host "        MAJOR KEY PACK INSTALLER"
    Write-Host "========================================"
    Write-Host ""

    Write-Host "Downloading Major Key Pack manifest..."

    $ManifestPath=Join-Path $Temp "manifest.json"

    Invoke-WebRequest `
        -Uri "$Raw/modpack-manifest.json" `
        -OutFile $ManifestPath

    if(!(Test-Path $ManifestPath)){
        throw "Failed to download modpack manifest."
    }

    $Manifest=Get-Content $ManifestPath -Raw | ConvertFrom-Json

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

        Write-Host "Downloading $($Mod.filename)..."

        Invoke-WebRequest `
            -Uri $Mod.url `
            -OutFile $Destination

        if(!(Test-Path $Destination)){
            throw "Download failed: $($Mod.filename)"
        }

        $File=Get-Item $Destination

        if($File.Length -ne [long]$Mod.size){
            Remove-Item $Destination -Force
            throw "Size mismatch: $($Mod.filename)`nExpected: $($Mod.size)`nActual: $($File.Length)"
        }

        $Hash=(Get-FileHash $Destination -Algorithm SHA256).Hash.ToLower()

        if($Hash -ne $Mod.sha256.ToLower()){
            Remove-Item $Destination -Force
            throw "SHA256 mismatch: $($Mod.filename)`nExpected: $($Mod.sha256)`nActual: $Hash"
        }

        Write-Host "OK: $($Mod.filename)" -ForegroundColor Green
    }

    [PSCustomObject]@{
        name=$Manifest.name
        version=$Manifest.version
        minecraft=$Manifest.minecraft
        loader=$Manifest.loader
        installed=(Get-Date).ToString("o")
    } |
        ConvertTo-Json |
        Set-Content `
            (Join-Path $InstallDirectory "major-key-pack.json") `
            -Encoding UTF8

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host " MAJOR KEY PACK INSTALLED" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Location: $InstallDirectory"
    Write-Host "Mods: $($Manifest.mods.Count)"
    Write-Host ""

}
catch {

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host " INSTALLATION FAILED" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""

    exit 1
}
