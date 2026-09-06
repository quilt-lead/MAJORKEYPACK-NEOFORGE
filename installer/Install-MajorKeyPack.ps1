param(
    [Parameter(Mandatory = $true)]
    [string]$InstallDirectory
)

$ErrorActionPreference = "Stop"

try {

    Write-Host ""
    Write-Host "========================================"
    Write-Host "       Major Key Pack Installer"
    Write-Host "========================================"
    Write-Host ""

    Write-Host "Install directory:"
    Write-Host $InstallDirectory
    Write-Host ""

    # ------------------------------------------------------------
    # Locate the Minecraft directory
    # ------------------------------------------------------------

    $appData = [Environment]::GetFolderPath(
        [Environment+SpecialFolder]::ApplicationData
    )

    $minecraftDirectory = Join-Path `
        $appData `
        ".minecraft"

    if (!(Test-Path $minecraftDirectory)) {
        throw "Minecraft directory was not found: $minecraftDirectory"
    }

    Write-Host "Minecraft directory:"
    Write-Host $minecraftDirectory
    Write-Host ""

    # ------------------------------------------------------------
    # Create Major Key Pack installation directory
    # ------------------------------------------------------------

    if (!(Test-Path $InstallDirectory)) {
        New-Item `
            -ItemType Directory `
            -Path $InstallDirectory `
            -Force | Out-Null
    }

    # ------------------------------------------------------------
    # Locate the manifest
    #
    # IMPORTANT:
    # This assumes your manifest is available from the
    # Major Key Pack repository.
    # ------------------------------------------------------------

    $manifestUrl =
        "https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/YOUR_REPOSITORY_NAME/main/modpack-manifest.json"

    $manifestPath =
        Join-Path `
            $InstallDirectory `
            "modpack-manifest.json"

    Write-Host "Downloading modpack manifest..."

    Invoke-WebRequest `
        -Uri $manifestUrl `
        -OutFile $manifestPath

    Write-Host "Manifest downloaded."
    Write-Host ""

    # ------------------------------------------------------------
    # Parse manifest
    # ------------------------------------------------------------

    $manifest =
        Get-Content `
            $manifestPath `
            -Raw |
        ConvertFrom-Json

    # ------------------------------------------------------------
    # Example manifest information
    # ------------------------------------------------------------

    if ($manifest.version) {
        Write-Host "Modpack version:"
        Write-Host $manifest.version
        Write-Host ""
    }

    # ------------------------------------------------------------
    # Create mods directory
    # ------------------------------------------------------------

    $modsDirectory =
        Join-Path `
            $minecraftDirectory `
            "mods"

    if (!(Test-Path $modsDirectory)) {
        New-Item `
            -ItemType Directory `
            -Path $modsDirectory `
            -Force | Out-Null
    }

    # ------------------------------------------------------------
    # Install mods
    #
    # This section assumes your manifest has a "mods" array
    # containing objects with:
    #
    # {
    #   "name": "Example Mod",
    #   "url": "https://..."
    # }
    #
    # If your actual manifest structure is different, this
    # section needs to match that structure.
    # ------------------------------------------------------------

    if ($manifest.mods) {

        foreach ($mod in $manifest.mods) {

            if (!$mod.url) {
                Write-Warning `
                    "Skipping $($mod.name): no URL specified."
                continue
            }

            $fileName =
                Split-Path `
                    $mod.url `
                    -Leaf

            if ([string]::IsNullOrWhiteSpace($fileName)) {
                Write-Warning `
                    "Could not determine filename for $($mod.name)."
                continue
            }

            $destination =
                Join-Path `
                    $modsDirectory `
                    $fileName

            Write-Host ""
            Write-Host "Installing:"
            Write-Host $mod.name
            Write-Host $mod.url

            Invoke-WebRequest `
                -Uri $mod.url `
                -OutFile $destination

            Write-Host "Installed: $fileName"
        }
    }

    Write-Host ""
    Write-Host "========================================"
    Write-Host "       Installation Complete"
    Write-Host "========================================"
    Write-Host ""

    exit 0
}
catch {

    Write-Host ""
    Write-Host "========================================"
    Write-Host "       INSTALLATION FAILED"
    Write-Host "========================================"
    Write-Host ""

    Write-Host $_.Exception.Message

    Write-Host ""
    Write-Host "Press Enter to close..."

    Read-Host

    exit 1
}