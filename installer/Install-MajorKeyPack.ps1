param(
    [string]$InstallDirectory = "$env:APPDATA\MajorKeyPack",
    [string]$ManifestPath = ""
)

$ErrorActionPreference = "Stop"

$Repository = "quilt-lead/MAJORKEYPACK-NEOFORGE"
$Raw = "https://raw.githubusercontent.com/$Repository/main"

$MinecraftDirectory = Join-Path $env:APPDATA ".minecraft"
$ModsDirectory = Join-Path $MinecraftDirectory "mods"

# Always use a unique temp directory
$TempDirectory = Join-Path `
    $env:TEMP `
    ("MajorKeyPack-" + [guid]::NewGuid().ToString("N"))

try {

    Write-Host ""
    Write-Host "========================================"
    Write-Host "       MAJOR KEY PACK - NEOFORGE"
    Write-Host "========================================"
    Write-Host ""

    # ========================================
    # CHECK MINECRAFT
    # ========================================

    if (!(Test-Path -LiteralPath $MinecraftDirectory)) {
        throw `
            "Minecraft Java Edition was not found.`n" +
            "Please install Minecraft Java Edition first."
    }

    Write-Host "Minecraft directory:"
    Write-Host $MinecraftDirectory
    Write-Host ""

    # ========================================
    # CHECK NEOFORGE
    # ========================================

    Write-Host "Checking NeoForge installation..."

    $NeoForgeVersionsDirectory =
        Join-Path `
            $MinecraftDirectory `
            "versions"

    if (!(Test-Path -LiteralPath $NeoForgeVersionsDirectory)) {
        throw `
            "The Minecraft versions directory was not found.`n" +
            "Please install NeoForge 1.21.1 first."
    }

    $NeoForgeVersions =
        Get-ChildItem `
            -LiteralPath $NeoForgeVersionsDirectory `
            -Directory |
        Where-Object {
            $_.Name -like "neoforge-*"
        } |
        Sort-Object Name -Descending

    if (!$NeoForgeVersions) {
        throw `
            "NeoForge was not found.`n" +
            "Please install NeoForge 21.11.45 for Minecraft 1.21.1 first."
    }

    $NeoForge =
        $NeoForgeVersions |
        Select-Object -First 1

    $NeoForgeJson =
        Join-Path `
            $NeoForge.FullName `
            "$($NeoForge.Name).json"

    if (!(Test-Path -LiteralPath $NeoForgeJson)) {
        throw `
            "NeoForge installation appears incomplete.`n" +
            "Missing:`n$NeoForgeJson"
    }

    Write-Host `
        "NeoForge detected: $($NeoForge.Name)" `
        -ForegroundColor Green

    Write-Host ""

    # ========================================
    # PREPARE DIRECTORIES
    # ========================================

    Write-Host "Preparing temporary directory..."

    New-Item `
        -ItemType Directory `
        -Path $TempDirectory `
        -Force |
        Out-Null

    New-Item `
        -ItemType Directory `
        -Path $ModsDirectory `
        -Force |
        Out-Null

    New-Item `
        -ItemType Directory `
        -Path $InstallDirectory `
        -Force |
        Out-Null

    Write-Host "Temporary directory:"
    Write-Host $TempDirectory
    Write-Host ""

    # ========================================
    # GET MANIFEST
    # ========================================

    if (
        ![string]::IsNullOrWhiteSpace($ManifestPath) `
        -and `
        (Test-Path -LiteralPath $ManifestPath)
    ) {

        Write-Host `
            "Using bundled modpack manifest..." `
            -ForegroundColor Green

    }
    else {

        Write-Host "Downloading Major Key Pack manifest..."

        $ManifestPath =
            Join-Path `
                $TempDirectory `
                "modpack-manifest.json"

        Invoke-WebRequest `
            -Uri "$Raw/modpack-manifest.json" `
            -OutFile $ManifestPath `
            -UseBasicParsing
    }

    if (!(Test-Path -LiteralPath $ManifestPath)) {
        throw "Failed to obtain modpack manifest."
    }

    try {

        $Manifest =
            Get-Content `
                -LiteralPath $ManifestPath `
                -Raw |
            ConvertFrom-Json

    }
    catch {

        throw `
            "The modpack manifest is not valid JSON.`n" +
            $_.Exception.Message
    }

    # ========================================
    # VALIDATE MANIFEST
    # ========================================

    if ($Manifest.minecraft -ne "1.21.1") {
        throw `
            "Wrong Minecraft version in manifest.`n" +
            "Expected: 1.21.1`n" +
            "Found: $($Manifest.minecraft)"
    }

    if ($Manifest.loader -ne "NeoForge") {
        throw `
            "Wrong loader in manifest.`n" +
            "Expected: NeoForge`n" +
            "Found: $($Manifest.loader)"
    }

    if ($null -eq $Manifest.mods) {
        throw "The manifest does not contain a mods array."
    }

    $Mods = @($Manifest.mods)

    if ($Mods.Count -eq 0) {
        throw "The manifest contains no mods."
    }

    Write-Host ""
    Write-Host "========================================"
    Write-Host "        MODPACK INFORMATION"
    Write-Host "========================================"
    Write-Host ""
    Write-Host "Pack:      $($Manifest.name)"
    Write-Host "Version:   $($Manifest.version)"
    Write-Host "Minecraft: $($Manifest.minecraft)"
    Write-Host "Loader:    $($Manifest.loader)"
    Write-Host "Mods:      $($Mods.Count)"
    Write-Host ""

    # ========================================
    # DOWNLOAD / VERIFY MODS
    # ========================================

    $Completed = 0

    foreach ($Mod in $Mods) {

        $Completed++

        if ([string]::IsNullOrWhiteSpace($Mod.filename)) {
            throw "A mod entry is missing its filename."
        }

        if ([string]::IsNullOrWhiteSpace($Mod.url)) {
            throw `
                "Mod '$($Mod.filename)' is missing its download URL."
        }

        if ([string]::IsNullOrWhiteSpace($Mod.sha256)) {
            throw `
                "Mod '$($Mod.filename)' is missing its SHA256."
        }

        if ($null -eq $Mod.size) {
            throw `
                "Mod '$($Mod.filename)' is missing its file size."
        }

        # IMPORTANT:
        # Use Join-Path to construct the complete filename.
        # All file operations below use -LiteralPath so
        # [ ] characters are NEVER treated as wildcards.

        $Destination =
            Join-Path `
                $ModsDirectory `
                $Mod.filename

        $TempFile =
            Join-Path `
                $TempDirectory `
                $Mod.filename

        Write-Host ""
        Write-Host "[$Completed/$($Mods.Count)] $($Mod.filename)"

        # ========================================
        # EXISTING FILE CHECK
        # ========================================

        if (Test-Path -LiteralPath $Destination) {

            $ExistingFile =
                Get-Item -LiteralPath $Destination

            if (
                $ExistingFile.Length `
                -eq `
                [long]$Mod.size
            ) {

                Write-Host "Checking existing file..."

                $ExistingHash =
                    (
                        Get-FileHash `
                            -LiteralPath $Destination `
                            -Algorithm SHA256
                    ).Hash.ToLower()

                if (
                    $ExistingHash `
                    -eq `
                    $Mod.sha256.ToLower()
                ) {

                    Write-Host `
                        "Already installed - SHA256 verified." `
                        -ForegroundColor Green

                    continue
                }
            }

            Write-Host `
                "Existing file is incorrect. Re-downloading..." `
                -ForegroundColor Yellow
        }

        # ========================================
        # REMOVE OLD TEMP FILE
        # ========================================

        if (Test-Path -LiteralPath $TempFile) {

            Remove-Item `
                -LiteralPath $TempFile `
                -Force
        }

        # ========================================
        # DOWNLOAD
        # ========================================

        Write-Host "Downloading..."

        try {

            Invoke-WebRequest `
                -Uri $Mod.url `
                -OutFile $TempFile `
                -UseBasicParsing

        }
        catch {

            throw `
                "Download failed: $($Mod.filename)`n" +
                $_.Exception.Message
        }

        if (!(Test-Path -LiteralPath $TempFile)) {
            throw `
                "Download failed: $($Mod.filename)"
        }

        # ========================================
        # SIZE CHECK
        # ========================================

        Write-Host "Checking file size..."

        $File =
            Get-Item -LiteralPath $TempFile

        if (
            $File.Length `
            -ne `
            [long]$Mod.size
        ) {

            $ActualSize =
                $File.Length

            Remove-Item `
                -LiteralPath $TempFile `
                -Force

            throw `
                "Size mismatch: $($Mod.filename)`n" +
                "Expected: $($Mod.size)`n" +
                "Actual: $ActualSize"
        }

        # ========================================
        # SHA256 CHECK
        # ========================================

        Write-Host "Verifying SHA256..."

        $Hash =
            (
                Get-FileHash `
                    -LiteralPath $TempFile `
                    -Algorithm SHA256
            ).Hash.ToLower()

        if (
            $Hash `
            -ne `
            $Mod.sha256.ToLower()
        ) {

            Remove-Item `
                -LiteralPath $TempFile `
                -Force

            throw `
                "SHA256 mismatch: $($Mod.filename)`n" +
                "Expected: $($Mod.sha256)`n" +
                "Actual: $Hash"
        }

        Write-Host `
            "OK - SHA256 verified." `
            -ForegroundColor Green

        # ========================================
        # INSTALL VERIFIED FILE
        # ========================================

        Write-Host "Installing..."

        # If an old file exists, remove it literally.
        if (Test-Path -LiteralPath $Destination) {

            Remove-Item `
                -LiteralPath $Destination `
                -Force
        }

        # Move verified file into mods folder.
        Move-Item `
            -LiteralPath $TempFile `
            -Destination $Destination `
            -Force

        if (!(Test-Path -LiteralPath $Destination)) {
            throw `
                "Installation failed: $($Mod.filename)"
        }

        Write-Host `
            "OK - installed." `
            -ForegroundColor Green
    }

    # ========================================
    # WRITE INSTALLATION RECORD
    # ========================================

    $InstallationRecord =
        [PSCustomObject]@{
            name =
                $Manifest.name

            version =
                $Manifest.version

            minecraft =
                $Manifest.minecraft

            loader =
                $Manifest.loader

            neoforge =
                $NeoForge.Name

            installed =
                (Get-Date).ToString("o")

            modCount =
                $Mods.Count
        }

    $RecordPath =
        Join-Path `
            $InstallDirectory `
            "major-key-pack.json"

    $InstallationRecord |
        ConvertTo-Json |
        Set-Content `
            -LiteralPath $RecordPath `
            -Encoding UTF8

    # ========================================
    # SUCCESS
    # ========================================

    Write-Host ""
    Write-Host "========================================" `
        -ForegroundColor Green

    Write-Host "       MAJOR KEY PACK INSTALLED" `
        -ForegroundColor Green

    Write-Host "========================================" `
        -ForegroundColor Green

    Write-Host ""
    Write-Host "Minecraft: 1.21.1"
    Write-Host "Loader:    NeoForge"
    Write-Host "NeoForge:  $($NeoForge.Name)"
    Write-Host "Mods:      $($Mods.Count)"
    Write-Host ""
    Write-Host "Mods location:"
    Write-Host $ModsDirectory
    Write-Host ""
    Write-Host "Install record:"
    Write-Host $RecordPath
    Write-Host ""

}
catch {

    Write-Host ""
    Write-Host "========================================" `
        -ForegroundColor Red

    Write-Host "       INSTALLATION FAILED" `
        -ForegroundColor Red

    Write-Host "========================================" `
        -ForegroundColor Red

    Write-Host ""

    Write-Host `
        $_.Exception.Message `
        -ForegroundColor Red

    Write-Host ""
    Write-Host "The installer did not complete." `
        -ForegroundColor Red

    Write-Host ""
}

Write-Host ""
Write-Host "Press Enter to close..."
Read-Host