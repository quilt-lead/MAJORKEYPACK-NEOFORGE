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

    $manifestPath = Join-Path $PSScriptRoot "manifest.json"

    if (-not (Test-Path -LiteralPath $manifestPath)) {
        throw "Modpack manifest was not found:`n$manifestPath"
    }

    $manifestJson = Get-Content `
        -LiteralPath $manifestPath `
        -Raw `
        -Encoding UTF8

    $manifest = $manifestJson | ConvertFrom-Json

    # ----------------------------------------------------------------
    # Verify Minecraft directory
    # ----------------------------------------------------------------

    if (-not (Test-Path -LiteralPath $minecraftDirectory)) {
        throw "Minecraft directory was not found:`n$minecraftDirectory"
    }

    # ----------------------------------------------------------------
    # Find NeoForge 1.21.1
    # ----------------------------------------------------------------

    Write-Host "Checking for NeoForge 1.21.1..."
    Write-Host ""

    if (-not (Test-Path -LiteralPath $versionsDirectory)) {
        throw "Minecraft versions directory was not found:`n$versionsDirectory"
    }

    $NeoForgeDirectories = Get-ChildItem `
        -LiteralPath $versionsDirectory `
        -Directory `
        -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -like "1.21.1-NeoForge-*"
        }

    if (-not $NeoForgeDirectories) {

        Write-Host "NeoForge 1.21.1 was not found."
        Write-Host ""
        Write-Host "Opening the official NeoForge download page..."
        Write-Host ""

        Start-Process `
            "https://neoforged.net/"

        throw "NeoForge 1.21.1 is required. Install NeoForge 1.21.1 and run this installer again."
    }

    Write-Host "NeoForge 1.21.1 found."
    Write-Host ""

    # ----------------------------------------------------------------
    # Create directories
    # ----------------------------------------------------------------

    if (-not (Test-Path -LiteralPath $installDirectory)) {
        New-Item `
            -ItemType Directory `
            -Path $installDirectory `
            -Force | Out-Null
    }

    if (-not (Test-Path -LiteralPath $modsDirectory)) {
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

        if (Test-Path -LiteralPath $destination) {

            $existingHash = (
                Get-FileHash `
                    -LiteralPath $destination `
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

            if (Test-Path -LiteralPath $tempFile) {
                Remove-Item `
                    -LiteralPath $tempFile `
                    -Force
            }

            Write-Host "Downloading..."

            $webClient.DownloadFile(
                $mod.url,
                $tempFile
            )

            if (-not (Test-Path -LiteralPath $tempFile)) {
                throw "Download failed: $($mod.filename)"
            }

            # --------------------------------------------------------
            # Verify file size
            # --------------------------------------------------------

            $actualSize = (
                Get-Item `
                    -LiteralPath $tempFile
            ).Length

            if ([int64]$actualSize -ne [int64]$mod.size) {

                Remove-Item `
                    -LiteralPath $tempFile `
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
                    -LiteralPath $tempFile `
                    -Algorithm SHA256
            ).Hash.ToLowerInvariant()

            if ($actualHash -ne $mod.sha256.ToLowerInvariant()) {

                Remove-Item `
                    -LiteralPath $tempFile `
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
                -LiteralPath $tempFile `
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
