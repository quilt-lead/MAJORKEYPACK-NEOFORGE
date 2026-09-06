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

}

$Forge=Get-ChildItem "$MinecraftDirectory\versions" -Directory -ErrorAction SilentlyContinue |
    Where-Object {$_.Name -like "1.20.1-forge-*"} |
    Select-Object -First 1

if(!$Forge){
    Add-Type -AssemblyName System.Windows.Forms

    $ForgeUrl = "https://files.minecraftforge.net/net/minecraftforge/forge/index_1.20.1.html"

    $result = [System.Windows.Forms.MessageBox]::Show(
        "Forge 1.20.1 was not found.`n`nPlease install Forge 1.20.1 before installing Major Key Pack.`n`nClick Yes to open the official Forge download page.`nClick No to exit.",
        "Major Key Pack - Forge Required",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )

    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        Start-Process $ForgeUrl

        [System.Windows.Forms.MessageBox]::Show(
            "Install Forge 1.20.1, then run the Major Key Pack installer again.",
            "Major Key Pack",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    }

    throw "Forge 1.20.1 is required."

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


