$ErrorActionPreference = "Stop"

$Host.UI.RawUI.WindowTitle = "Major Key Pack Installer"

Write-Host ""
Write-Host "========================================"
Write-Host "       Major Key Pack Installer"
Write-Host "========================================"
Write-Host ""

$installDirectory = Join-Path $env:APPDATA "MajorKeyPack"
$minecraftDirectory = Join-Path $env:APPDATA ".minecraft"
$versionsDirectory = Join-Path $minecraftDirectory "versions"
$modsDirectory = Join-Path $minecraftDirectory "mods"

Write-Host "Install directory:"
Write-Host $installDirectory
Write-Host ""

Write-Host "Minecraft directory:"
Write-Host $minecraftDirectory
Write-Host ""

try {

    # ----------------------------------------------------------------
    # Load manifest from the JSON file next to this script
    # ----------------------------------------------------------------

    $manifestPath = Join-Path $PSScriptRoot "modpack-manifest.json"

    if (-not (Test-Path $manifestPath)) {
        throw "Modpack manifest was not found:`n$manifestPath"
    }

    $manifestJson = Get-Content `
        -Path $manifestPath `
        -Raw `
        -Encoding UTF8

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

    if (-not (Test-Path $versionsDirectory)) {
        throw "Minecraft versions directory was not found:`n$versionsDirectory"
    }

    $forgeDirectories = Get-ChildItem `
        $versionsDirectory `
        -Directory `
        -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -like "1.20.1-forge-*"
        }

    if (-not $forgeDirectories) {

        Write-Host "Forge 1.20.1 was not found."
        Write-Host ""
        Write-Host "Opening the official Forge download page..."
        Write-Host ""

        Start-Process `
            "https://files.minecraftforge.net/net/minecraftforge/forge/index_1.20.1.html"

        throw "Forge 1.20.1 is required. Install Forge 1.20.1 and run this installer again."
    }

    Write-Host "Forge 1.20.1 found."
    Write-Host ""

    # ----------------------------------------------------------------
    # Create directories
    # ----------------------------------------------------------------

    if (-not (Test-Path $installDirectory)) {
        New-Item `
            -ItemType Directory `
            -Path $installDirectory `
            -Force | Out-Null
    }

    if (-not (Test-Path $modsDirectory)) {
        New-Item `
            -ItemType Directory `
            -Path $modsDirectory `
            -Force | Out-Null
    }

    # ----------------------------------------------------------------
    # Download mods
    # ----------------------------------------------------------------

    Write-Host "Installing mods..."
    Write-Host ""

    $webClient = New-Object System.Net.WebClient

    foreach ($mod in $manifest.mods) {

        $destination = Join-Path `
            $modsDirectory `
            $mod.filename

        Write-Host "----------------------------------------"
        Write-Host $mod.filename
        Write-Host ""

        $needsDownload = $true

        # ------------------------------------------------------------
        # Check existing mod
        # ------------------------------------------------------------

        if (Test-Path $destination) {

            $existingHash = (
                Get-FileHash `
                    -Path $destination `
                    -Algorithm SHA256
            ).Hash.ToLowerInvariant()

            if ($existingHash -eq $mod.sha256.ToLowerInvariant()) {

                Write-Host "Already installed and verified."

                $needsDownload = $false
            }
            else {

                Write-Host "Existing file failed verification."
                Write-Host "Downloading a fresh copy..."
            }
        }

        # ------------------------------------------------------------
        # Download mod
        # ------------------------------------------------------------

        if ($needsDownload) {

            $tempFile = "$destination.download"

            if (Test-Path $tempFile) {
                Remove-Item `
                    $tempFile `
                    -Force
            }

            Write-Host "Downloading..."

            $webClient.DownloadFile(
                $mod.url,
                $tempFile
            )

            if (-not (Test-Path $tempFile)) {
                throw "Download failed: $($mod.filename)"
            }

            # --------------------------------------------------------
            # Verify file size
            # --------------------------------------------------------

            $actualSize = (
                Get-Item $tempFile
            ).Length

            if ([int64]$actualSize -ne [int64]$mod.size) {

                Remove-Item `
                    $tempFile `
                    -Force

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

            # --------------------------------------------------------
            # Verify SHA-256
            # --------------------------------------------------------

            $actualHash = (
                Get-FileHash `
                    -Path $tempFile `
                    -Algorithm SHA256
            ).Hash.ToLowerInvariant()

            if ($actualHash -ne $mod.sha256.ToLowerInvariant()) {

                Remove-Item `
                    $tempFile `
                    -Force

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

            # --------------------------------------------------------
            # Install verified file
            # --------------------------------------------------------

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
    Write-Host "Minecraft: $($manifest.minecraft)"
    Write-Host "Loader:    $($manifest.loader)"
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