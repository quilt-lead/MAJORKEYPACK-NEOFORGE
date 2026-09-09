param(
[string]$InstallDirectory = "$env:APPDATA\MajorKeyPack"
)

$ErrorActionPreference = "Stop"

# ============================================================

# MAJOR KEY PACK - NEOFORGE INSTALLER

# ============================================================

$MinecraftDirectory = Join-Path $env:APPDATA ".minecraft"
$VersionsDirectory  = Join-Path $MinecraftDirectory "versions"
$ModsDirectory      = Join-Path $MinecraftDirectory "mods"
$TempDirectory      = Join-Path $env:TEMP "MajorKeyPack"

$GitHubRaw = "https://raw.githubusercontent.com/quilt-lead/MAJORKEYPACK-NEOFORGE/main"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "       MAJOR KEY PACK - NEOFORGE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------

# Prepare directories

# ------------------------------------------------------------

if (Test-Path $TempDirectory) {
Remove-Item $TempDirectory -Recurse -Force
}

New-Item -Path $TempDirectory -ItemType Directory -Force | Out-Null
New-Item -Path $ModsDirectory -ItemType Directory -Force | Out-Null
New-Item -Path $InstallDirectory -ItemType Directory -Force | Out-Null

# ------------------------------------------------------------

# Locate manifest

#

# The launcher extracts both the installer and manifest into

# the same temporary directory, so use the local manifest first.

# When running the PS1 directly from the repository, this also

# allows the root manifest to be copied manually if desired.

# ------------------------------------------------------------

$LocalManifest = Join-Path $PSScriptRoot "modpack-manifest.json"
$ManifestPath  = Join-Path $TempDirectory "manifest.json"

if (Test-Path $LocalManifest) {
Copy-Item $LocalManifest $ManifestPath -Force
}
else {
Write-Host "Downloading modpack manifest..." -ForegroundColor Yellow

```
Invoke-WebRequest `
    -Uri "$GitHubRaw/modpack-manifest.json" `
    -OutFile $ManifestPath `
    -UseBasicParsing
```

}

if (!(Test-Path $ManifestPath)) {
throw "Could not obtain modpack-manifest.json."
}

# ------------------------------------------------------------

# Read manifest

# ------------------------------------------------------------

try {
$Manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
}
catch {
throw "modpack-manifest.json is not valid JSON. $($_.Exception.Message)"
}

# ------------------------------------------------------------

# Validate pack

# ------------------------------------------------------------

if ([string]::IsNullOrWhiteSpace($Manifest.minecraft)) {
throw "Manifest is missing the Minecraft version."
}

if ($Manifest.minecraft -ne "1.21.1") {
throw "This installer requires Minecraft 1.21.1. Manifest specifies $($Manifest.minecraft)."
}

if ([string]::IsNullOrWhiteSpace($Manifest.loader)) {
throw "Manifest is missing the mod loader."
}

if ($Manifest.loader -ne "NeoForge") {
throw "This installer requires NeoForge. Manifest specifies $($Manifest.loader)."
}

if ($null -eq $Manifest.mods) {
throw "Manifest does not contain a 'mods' array."
}

$Mods = @($Manifest.mods)

if ($Mods.Count -eq 0) {
throw "The manifest contains no mods."
}

# ------------------------------------------------------------

# Locate Minecraft

# ------------------------------------------------------------

if (!(Test-Path $MinecraftDirectory)) {
throw "Minecraft directory was not found: $MinecraftDirectory"
}

if (!(Test-Path $VersionsDirectory)) {
Start-Process "https://neoforged.net/"
throw "Minecraft versions directory was not found. Install Minecraft and NeoForge 1.21.1 first."
}

# ------------------------------------------------------------

# Locate NeoForge

#

# Expected installation format:

#

# .minecraft\versions\neoforge-21.11.45

#

# We intentionally detect any neoforge-* version rather than

# assuming a specific NeoForge build number.

# ------------------------------------------------------------

$NeoForgeVersions = @(
Get-ChildItem `        -Path $VersionsDirectory`
-Directory `
-ErrorAction SilentlyContinue |
Where-Object {
$_.Name -like "neoforge-*"
} |
Sort-Object LastWriteTime -Descending
)

if ($NeoForgeVersions.Count -eq 0) {
Start-Process "https://neoforged.net/"
throw "NeoForge was not found. Install NeoForge for Minecraft 1.21.1 first."
}

$NeoForgeVersion = $NeoForgeVersions | Select-Object -First 1
$NeoForgePath = $NeoForgeVersion.FullName

$NeoForgeJson = Join-Path `    $NeoForgePath`
"$($NeoForgeVersion.Name).json"

if (!(Test-Path $NeoForgeJson)) {
throw "NeoForge installation appears incomplete. Missing: $NeoForgeJson"
}

Write-Host "Minecraft:      $($Manifest.minecraft)" -ForegroundColor Green
Write-Host "Loader:         $($Manifest.loader)" -ForegroundColor Green
Write-Host "NeoForge:       $($NeoForgeVersion.Name)" -ForegroundColor Green
Write-Host "Mods in pack:   $($Mods.Count)" -ForegroundColor Green
Write-Host ""

# ------------------------------------------------------------

# Remove duplicate manifest entries

# ------------------------------------------------------------

$Mods = @(
$Mods |
Group-Object filename |
ForEach-Object {
$_.Group | Select-Object -First 1
}
)

# ------------------------------------------------------------

# Install mods

# ------------------------------------------------------------

$InstalledCount = 0
$SkippedCount   = 0

foreach ($Mod in $Mods) {

```
if ([string]::IsNullOrWhiteSpace($Mod.filename)) {
    throw "A mod entry is missing 'filename'."
}

if ([string]::IsNullOrWhiteSpace($Mod.url)) {
    throw "Mod '$($Mod.filename)' is missing 'url'."
}

if ([string]::IsNullOrWhiteSpace($Mod.sha256)) {
    throw "Mod '$($Mod.filename)' is missing 'sha256'."
}

if ($null -eq $Mod.size) {
    throw "Mod '$($Mod.filename)' is missing 'size'."
}

$Destination = Join-Path $ModsDirectory $Mod.filename

# --------------------------------------------------------
# Check existing file
# --------------------------------------------------------

if (Test-Path $Destination) {

    $ExistingFile = Get-Item $Destination

    if ($ExistingFile.Length -eq [int64]$Mod.size) {

        $ExistingHash = (
            Get-FileHash `
                -Path $Destination `
                -Algorithm SHA256
        ).Hash.ToLower()

        if ($ExistingHash -eq $Mod.sha256.ToLower()) {

            Write-Host "[OK]     $($Mod.filename)" -ForegroundColor Green

            $SkippedCount++
            continue
        }
    }

    Write-Host "[UPDATE] $($Mod.filename)" -ForegroundColor Yellow

    Remove-Item $Destination -Force
}
else {
    Write-Host "[GET]    $($Mod.filename)" -ForegroundColor Cyan
}

# --------------------------------------------------------
# Download
# --------------------------------------------------------

try {
    curl.exe `
        -L `
        --fail `
        --silent `
        --show-error `
        --output "$Destination" `
        "$($Mod.url)"
}
catch {
    if (Test-Path $Destination) {
        Remove-Item $Destination -Force
    }

    throw "Failed to download $($Mod.filename): $($_.Exception.Message)"
}

if (!(Test-Path $Destination)) {
    throw "Download failed: $($Mod.filename)"
}

# --------------------------------------------------------
# Verify file size
# --------------------------------------------------------

$File = Get-Item $Destination

if ($File.Length -ne [int64]$Mod.size) {

    $ActualSize = $File.Length

    Remove-Item $Destination -Force

    throw @"
```

File size verification failed for:

$($Mod.filename)

Expected: $($Mod.size) bytes
Actual:   $ActualSize bytes
"@
}

```
# --------------------------------------------------------
# Verify SHA-256
# --------------------------------------------------------

$Hash = (
    Get-FileHash `
        -Path $Destination `
        -Algorithm SHA256
).Hash.ToLower()

if ($Hash -ne $Mod.sha256.ToLower()) {

    Remove-Item $Destination -Force

    throw @"
```

SHA-256 verification failed for:

$($Mod.filename)

Expected:
$($Mod.sha256)

Actual:
$Hash
"@
}

```
Write-Host "[DONE]   $($Mod.filename)" -ForegroundColor Green

$InstalledCount++
```

}

# ------------------------------------------------------------

# Write installation record

# ------------------------------------------------------------

$InstallRecord = [PSCustomObject]@{
name       = $Manifest.name
version    = $Manifest.version
minecraft  = $Manifest.minecraft
loader     = $Manifest.loader
neoforge   = $NeoForgeVersion.Name
mods       = $Mods.Count
installed  = (Get-Date).ToString("o")
}

$InstallRecordPath = Join-Path `    $InstallDirectory`
"major-key-pack.json"

$InstallRecord |
ConvertTo-Json -Depth 10 |
Set-Content `        -Path $InstallRecordPath`
-Encoding UTF8

# ------------------------------------------------------------

# Complete

# ------------------------------------------------------------

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "       INSTALLATION COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Pack:             $($Manifest.name)"
Write-Host "Minecraft:        $($Manifest.minecraft)"
Write-Host "NeoForge:         $($NeoForgeVersion.Name)"
Write-Host "Mods verified:    $($Mods.Count)"
Write-Host "New downloads:    $InstalledCount"
Write-Host "Already installed:$SkippedCount"
Write-Host ""
Write-Host "Mods installed to:"
Write-Host "$ModsDirectory"
Write-Host ""
Write-Host "Installation record:"
Write-Host "$InstallRecordPath"
Write-Host ""

Read-Host "Press Enter to close"
