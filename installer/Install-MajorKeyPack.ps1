$ErrorActionPreference = "Stop"

$Host.UI.RawUI.WindowTitle = "Major Key Pack Installer"

Write-Host ""
Write-Host "========================================"
Write-Host "       Major Key Pack Installer"
Write-Host "========================================"
Write-Host ""

$installDirectory = Join-Path $env:APPDATA "MajorKeyPack"
$minecraftDirectory = Join-Path $env:APPDATA ".minecraft"
$modsDirectory = Join-Path $minecraftDirectory "mods"

Write-Host "Install directory:"
Write-Host $installDirectory
Write-Host ""

Write-Host "Minecraft directory:"
Write-Host $minecraftDirectory
Write-Host ""

# -------------------------------------------------------------------
# Embedded manifest
# -------------------------------------------------------------------

$manifestJson = @'
{
    "minecraft": "1.20.1",
    "loader": "Forge",
    "mods": [
        {
            "filename": "create-1.20.1-6.0.8.jar",
            "size": 19170905,
            "sha256": "6fbb910c367dbce8e4fc7e5bf64b6edd4de980906ed00af8e47e4af843c0d9b0",
            "url": "https://mediafilez.forgecdn.net/files/7178/761/create-1.20.1-6.0.8.jar"
        },
        {
            "filename": "createbigcannons-5.11.4-mc.1.20.1-forge.jar",
            "size": 4058306,
            "sha256": "11845f0d79a9014977f667a57b14d0527928bee8b66bc6b50bedcc29ee81878a",
            "url": "https://mediafilez.forgecdn.net/files/8169/547/createbigcannons-5.11.4-mc.1.20.1-forge.jar"
        },
        {
            "filename": "eureka-1201-1.6.3.jar",
            "size": 462827,
            "sha256": "1d59778581a533d2bb7702a3d403fb37eaddb94aa786ebf3f4ab889dded82c55",
            "url": "https://mediafilez.forgecdn.net/files/7979/379/eureka-1201-1.6.3.jar"
        },
        {
            "filename": "jei-1.20.1-forge-15.58.0.209.jar",
            "size": 1821883,
            "sha256": "e39f3794233d16455217984592744fa8eb350a5f898f1002ed721659b77fdd97",
            "url": "https://mediafilez.forgecdn.net/files/8820/520/jei-1.20.1-forge-15.58.0.209.jar"
        },
        {
            "filename": "kotlinforforge-4.3.0-all.jar",
            "size": 7513212,
            "sha256": "3ab83c53de3c0e3f9fc0d08295ea067ff456d1cff31c707a7889e6c09f8c94d0",
            "url": "https://mediafilez.forgecdn.net/files/4578/885/kotlinforforge-4.3.0-all.jar"
        },
        {
            "filename": "OptiFine_1.20.1_HD_U_I6.jar",
            "size": 7145205,
            "sha256": "0b67cb670aedf2e55a982f3d52b6d53e46791a0c984aa1d2ee58100fc9bfc650",
            "url": "https://optifine.tommo.team/OptiFine_1.20.1_HD_U_I6.jar"
        },
        {
            "filename": "ritchiesprojectilelib-2.1.1-mc.1.20.1-forge.jar",
            "size": 78625,
            "sha256": "5531ec454792f98993fa29d55f8810444ba3e9ef8f04331c5811b84ec8d0c3dc",
            "url": "https://mediafilez.forgecdn.net/files/7292/523/ritchiesprojectilelib-2.1.1-mc.1.20.1-forge.jar"
        },
        {
            "filename": "valkyrienskies-120-2.4.11.jar",
            "size": 27752937,
            "sha256": "f99f24de62015451a047f90484cf9d25970cac350105b581c22b2d5247ebfd53",
            "url": "https://mediafilez.forgecdn.net/files/7906/689/valkyrienskies-120-2.4.11.jar"
        }
    ]
}
'@

try {

    $manifest = $manifestJson | ConvertFrom-Json

    # ----------------------------------------------------------------
    # Verify Minecraft directory
    # ----------------------------------------------------------------

    if (-not (Test-Path $minecraftDirectory)) {
        throw "Minecraft directory was not found:`n$minecraftDirectory"
    }

    # ----------------------------------------------------------------
    # Find Forge 1.20.1
    # ----------------------------------------------------------------

    Write-Host "Checking for Forge 1.20.1..."
    Write-Host ""

    $forgeDirectories = Get-ChildItem $minecraftDirectory -Directory -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -like "1.20.1-forge-*"
        }

    if (-not $forgeDirectories) {

        Write-Host "Forge 1.20.1 was not found."
        Write-Host ""
        Write-Host "Opening the official Forge download page..."
        Write-Host ""

        Start-Process "https://files.minecraftforge.net/net/minecraftforge/forge/index_1.20.1.html"

        throw "Forge 1.20.1 is required. Install Forge 1.20.1 and run this installer again."
    }

    Write-Host "Forge 1.20.1 found."
    Write-Host ""

    # ----------------------------------------------------------------
    # Create directories
    # ----------------------------------------------------------------

    if (-not (Test-Path $installDirectory)) {
        New-Item -ItemType Directory -Path $installDirectory -Force | Out-Null
    }

    if (-not (Test-Path $modsDirectory)) {
        New-Item -ItemType Directory -Path $modsDirectory -Force | Out-Null
    }

    # ----------------------------------------------------------------
    # Download mods
    # ----------------------------------------------------------------

    Write-Host "Installing mods..."
    Write-Host ""

    $webClient = New-Object System.Net.WebClient

    foreach ($mod in $manifest.mods) {

        $destination = Join-Path $modsDirectory $mod.filename

        Write-Host "----------------------------------------"
        Write-Host $mod.filename
        Write-Host ""

        $needsDownload = $true

        if (Test-Path $destination) {

            $existingHash = (Get-FileHash `
                -Path $destination `
                -Algorithm SHA256).Hash.ToLowerInvariant()

            if ($existingHash -eq $mod.sha256.ToLowerInvariant()) {
                Write-Host "Already installed and verified."
                $needsDownload = $false
            }
            else {
                Write-Host "Existing file failed verification."
                Write-Host "Downloading a fresh copy..."
            }
        }

        if ($needsDownload) {

            $tempFile = "$destination.download"

            if (Test-Path $tempFile) {
                Remove-Item $tempFile -Force
            }

            Write-Host "Downloading..."

            $webClient.DownloadFile(
                $mod.url,
                $tempFile
            )

            if (-not (Test-Path $tempFile)) {
                throw "Download failed: $($mod.filename)"
            }

            $actualSize = (Get-Item $tempFile).Length

            if ([int64]$actualSize -ne [int64]$mod.size) {
                Remove-Item $tempFile -Force

                throw @"
File size verification failed.

File:
$($mod.filename)

Expected:
$($mod.size) bytes

Received:
$actualSize bytes
"@
            }

            $actualHash = (Get-FileHash `
                -Path $tempFile `
                -Algorithm SHA256).Hash.ToLowerInvariant()

            if ($actualHash -ne $mod.sha256.ToLowerInvariant()) {

                Remove-Item $tempFile -Force

                throw @"
SHA-256 verification failed.

File:
$($mod.filename)

Expected:
$($mod.sha256)

Received:
$actualHash
"@
            }

            Move-Item `
                -Path $tempFile `
                -Destination $destination `
                -Force

            Write-Host "Downloaded and verified."
        }

        Write-Host ""
    }

    # ----------------------------------------------------------------
    # Finished
    # ----------------------------------------------------------------

    Write-Host ""
    Write-Host "========================================"
    Write-Host "       INSTALLATION COMPLETE"
    Write-Host "========================================"
    Write-Host ""
    Write-Host "Minecraft: 1.20.1"
    Write-Host "Loader:    Forge"
    Write-Host ""
    Write-Host "Mods installed:"
    Write-Host $manifest.mods.Count
    Write-Host ""
    Write-Host "Location:"
    Write-Host $modsDirectory
    Write-Host ""

}
catch {

    Write-Host ""
    Write-Host "========================================"
    Write-Host "       INSTALLATION FAILED"
    Write-Host "========================================"
    Write-Host ""
    Write-Host $_.Exception.Message
    Write-Host ""
}

Read-Host "Press Enter to close"