```powershell
$ErrorActionPreference = "Stop"

# ============================================================
# MAJOR KEY PACK - NEOFORGE INSTALLER
# ============================================================

$MinecraftDirectory = Join-Path $env:APPDATA ".minecraft"
$VersionsDirectory = Join-Path $MinecraftDirectory "versions"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "       MAJOR KEY PACK - NEOFORGE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------
# Check Minecraft directory
# ------------------------------------------------------------

if (-not (Test-Path $MinecraftDirectory)) {
    Write-Host "Minecraft installation was not found." -ForegroundColor Red
    Write-Host ""
    Write-Host "Expected:" -ForegroundColor Yellow
    Write-Host $MinecraftDirectory
    Write-Host ""
    Read-Host "Press Enter to close"
    exit 1
}

# ------------------------------------------------------------
# Check versions directory
# ------------------------------------------------------------

if (-not (Test-Path $VersionsDirectory)) {
    Write-Host "Minecraft versions directory was not found." -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to close"
    exit 1
}

# ------------------------------------------------------------
# Detect NeoForge
#
# Do NOT assume a folder such as:
#     1.21.1-neoforge-*
#
# Modern NeoForge installations can use:
#     neoforge-21.11.45
#
# ------------------------------------------------------------

Write-Host "Checking for NeoForge..." -ForegroundColor Cyan

$NeoForgeVersions = Get-ChildItem `
    $VersionsDirectory `
    -Directory `
    -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -like "neoforge-*"
    }

if (-not $NeoForgeVersions) {
    Write-Host ""
    Write-Host "NeoForge was not detected." -ForegroundColor Red
    Write-Host ""
    Write-Host "Install NeoForge for the required Minecraft version and" -ForegroundColor Yellow
    Write-Host "run this installer again." -ForegroundColor Yellow
    Write-Host ""

    Start-Process "https://neoforged.net/"

    Read-Host "Press Enter to close"
    exit 1
}

# Use the first detected NeoForge installation
$NeoForgeVersion = $NeoForgeVersions |
    Select-Object -First 1

$NeoForgePath = $NeoForgeVersion.FullName

Write-Host ""
Write-Host "NeoForge detected:" -ForegroundColor Green
Write-Host "  $($NeoForgeVersion.Name)" -ForegroundColor Green
Write-Host ""

# ------------------------------------------------------------
# Verify NeoForge JSON
# ------------------------------------------------------------

$NeoForgeJson = Join-Path $NeoForgePath "$($NeoForgeVersion.Name).json"

if (Test-Path $NeoForgeJson) {
    Write-Host "NeoForge profile verified." -ForegroundColor Green
}
else {
    Write-Host "Warning: NeoForge JSON profile was not found." -ForegroundColor Yellow
    Write-Host "Expected:" -ForegroundColor Yellow
    Write-Host "  $NeoForgeJson" -ForegroundColor Yellow
    Write-Host ""
}

# ------------------------------------------------------------
# Locate Minecraft instance mods folder
# ------------------------------------------------------------

$ModsDirectory = Join-Path $MinecraftDirectory "mods"

if (-not (Test-Path $ModsDirectory)) {
    Write-Host "Creating Minecraft mods directory..." -ForegroundColor Cyan

    New-Item `
        -ItemType Directory `
        -Path $ModsDirectory `
        -Force | Out-Null
}

# ------------------------------------------------------------
# Embedded installer resources
# ------------------------------------------------------------

$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition

$ManifestPath = Join-Path $ScriptDirectory "..\modpack-manifest.json"

if (-not (Test-Path $ManifestPath)) {
    $ManifestPath = Join-Path $ScriptDirectory "modpack-manifest.json"
}

if (-not (Test-Path $ManifestPath)) {
    Write-Host ""
    Write-Host "modpack-manifest.json was not found." -ForegroundColor Red
    Write-Host ""
    Write-Host "Expected location:" -ForegroundColor Yellow
    Write-Host $ManifestPath
    Write-Host ""

    Read-Host "Press Enter to close"
    exit 1
}

# ------------------------------------------------------------
# Load manifest
# ------------------------------------------------------------

Write-Host "Loading modpack manifest..." -ForegroundColor Cyan

try {
    $Manifest = Get-Content `
        $ManifestPath `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json
}
catch {
    Write-Host ""
    Write-Host "Could not read modpack-manifest.json." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""

    Read-Host "Press Enter to close"
    exit 1
}

# ------------------------------------------------------------
# Validate Minecraft version
# ------------------------------------------------------------

if ($Manifest.minecraft) {
    Write-Host ""
    Write-Host "Minecraft version: $($Manifest.minecraft)" -ForegroundColor Green
}

if ($Manifest.loader) {
    Write-Host "Loader: $($Manifest.loader)" -ForegroundColor Green
}

# ------------------------------------------------------------
# Determine server directory
# ------------------------------------------------------------

$ServerDirectory = Join-Path $MinecraftDirectory "MajorKeyPack"

if (-not (Test-Path $ServerDirectory)) {
    Write-Host ""
    Write-Host "Creating Major Key Pack directory..." -ForegroundColor Cyan

    New-Item `
        -ItemType Directory `
        -Path $ServerDirectory `
        -Force | Out-Null
}

# ------------------------------------------------------------
# Server mods
# ------------------------------------------------------------

$ServerModsDirectory = Join-Path $ServerDirectory "mods"

if (-not (Test-Path $ServerModsDirectory)) {
    New-Item `
        -ItemType Directory `
        -Path $ServerModsDirectory `
        -Force | Out-Null
}

# ------------------------------------------------------------
# Client mods
#
# clientMods are intentionally kept separate from serverMods.
# They belong on the player's client and are NOT installed into
# the server mods directory.
# ------------------------------------------------------------

$ClientModsDirectory = Join-Path $MinecraftDirectory "mods"

# ------------------------------------------------------------
# Display manifest contents
# ------------------------------------------------------------

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "             MODPACK CONTENT" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($Manifest.serverMods) {
    $ServerModCount = @($Manifest.serverMods).Count

    Write-Host "Server mods: $ServerModCount" -ForegroundColor Green
}

if ($Manifest.clientMods) {
    $ClientModCount = @($Manifest.clientMods).Count

    Write-Host "Client mods: $ClientModCount" -ForegroundColor Green
}

Write-Host ""

# ------------------------------------------------------------
# Installation note
# ------------------------------------------------------------

Write-Host "NeoForge is installed and ready." -ForegroundColor Green
Write-Host ""
Write-Host "Detected installation:" -ForegroundColor Cyan
Write-Host "  $($NeoForgeVersion.Name)" -ForegroundColor White
Write-Host ""

Write-Host "Minecraft directory:" -ForegroundColor Cyan
Write-Host "  $MinecraftDirectory" -ForegroundColor White
Write-Host ""

Write-Host "Mods directory:" -ForegroundColor Cyan
Write-Host "  $ModsDirectory" -ForegroundColor White
Write-Host ""

# ------------------------------------------------------------
# NOTE
#
# The actual mod download/update logic should remain below this
# point if it already exists in the original installer.
#
# This file currently performs the corrected NeoForge detection
# and manifest loading without making assumptions about the
# installed NeoForge folder name.
# ------------------------------------------------------------

Write-Host "NeoForge detection completed successfully." -ForegroundColor Green
Write-Host ""

Read-Host "Press Enter to close"
```
