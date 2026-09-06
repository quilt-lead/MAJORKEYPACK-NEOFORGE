param(
    [string]$InstallDirectory="$env:APPDATA\MajorKeyPack"
)

$ErrorActionPreference="Stop"

try {

    $Raw="https://raw.githubusercontent.com/quilt-lead/MAJORKEYPACK/main"
    $Repository="quilt-lead/MAJORKEYPACK"
    $Temp=Join-Path $env:TEMP "MajorKeyPack"
    $MinecraftDirectory=Join-Path $env:APPDATA ".minecraft"
    $Mods=Join-Path $MinecraftDirectory "mods"

    # ========================================
    # CHECK FOR INSTALLER UPDATES
    # ========================================

    Write-Host ""
    Write-Host "========================================"
    Write-Host "        CHECKING FOR UPDATES"
    Write-Host "========================================"
    Write-Host ""
    Write-Host "Checking GitHub latest release..."

    $Headers=@{
        "User-Agent"="MajorKeyPackInstaller"
        "Accept"="application/vnd.github+json"
    }

    $LatestReleaseUrl=
        "https://api.github.com/repos/$Repository/releases/latest"

    $Release=Invoke-RestMethod `
        -Uri $LatestReleaseUrl `
        -Headers $Headers

    $LatestTag=[string]$Release.tag_name

    if($LatestTag -notmatch '^v(\d+)$'){
        Write-Host ""
        Write-Host "Could not determine the latest installer version."
        Write-Host "Continuing with the current installer."
        Write-Host ""
    }
    else {

        $LatestVersion=[int]$Matches[1]

        # The installed release number is stored locally after installation.
        $CurrentVersion=0

        $InstalledInfoPath=
            Join-Path $InstallDirectory "major-key-pack.json"

        if(Test-Path $InstalledInfoPath){

            try {

                $InstalledInfo=
                    Get-Content `
                        $InstalledInfoPath `
                        -Raw |
                    ConvertFrom-Json

                if($InstalledInfo.installerVersion){

                    $ParsedVersion=0

                    if([int]::TryParse(
                        [string]$InstalledInfo.installerVersion,
                        [ref]$ParsedVersion)){

                        $CurrentVersion=$ParsedVersion
                    }
                }
            }
            catch {
                $CurrentVersion=0
            }
        }

        Write-Host "Current installer: v$CurrentVersion"
        Write-Host "Latest installer:  v$LatestVersion"
        Write-Host ""

        if($LatestVersion -gt $CurrentVersion){

            Write-Host "========================================" -ForegroundColor Yellow
            Write-Host "        UPDATE AVAILABLE" -ForegroundColor Yellow
            Write-Host "========================================" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "A newer Major Key Pack installer is available."
            Write-Host ""
            Write-Host "Current: v$CurrentVersion"
            Write-Host "Latest:  v$LatestVersion"
            Write-Host ""
            Write-Host "Stopping current installation..."
            Write-Host "Downloading latest installer..."
            Write-Host ""

            $InstallerAsset=
                $Release.assets |
                Where-Object {
                    $_.name -ieq "MajorKeyPack-Installer.exe"
                } |
                Select-Object -First 1

            if(!$InstallerAsset){
                throw `
                    "The latest GitHub release does not contain MajorKeyPack-Installer.exe."
            }

            $UpdateDirectory=
                Join-Path `
                    $env:TEMP `
                    ("MajorKeyPackUpdate-" +
                     [guid]::NewGuid().ToString("N"))

            New-Item `
                -ItemType Directory `
                -Path $UpdateDirectory `
                -Force |
                Out-Null

            $NewInstaller=
                Join-Path `
                    $UpdateDirectory `
                    "MajorKeyPack-Installer.exe"

            Invoke-WebRequest `
                -Uri $InstallerAsset.browser_download_url `
                -OutFile $NewInstaller

            if(!(Test-Path $NewInstaller)){
                throw `
                    "The updated installer could not be downloaded."
            }

            $DownloadedFile=
                Get-Item $NewInstaller

            if($DownloadedFile.Length -lt 1000000){

                Remove-Item `
                    $NewInstaller `
                    -Force `
                    -ErrorAction SilentlyContinue

                throw "The downloaded installer is invalid."
            }

            Write-Host ""
            Write-Host `
                "Latest installer downloaded successfully." `
                -ForegroundColor Green

            Write-Host `
                "Starting Major Key Pack v$LatestVersion..."

            Write-Host ""
            Write-Host `
                "The current installer will now close."
            Write-Host ""

            Start-Process `
                -FilePath $NewInstaller

            exit 0
        }

        Write-Host `
            "Installer is up to date." `
            -ForegroundColor Green

        Write-Host ""
    }

    # ========================================
    # NORMAL INSTALLATION
    # ========================================

    if(!(Test-Path $MinecraftDirectory)){
        throw `
            "Minecraft Java Edition was not found. Please install Minecraft Java Edition first."
    }

    if(Test-Path $Temp){
        Remove-Item `
            $Temp `
            -Recurse `
            -Force
    }

    New-Item `
        $Temp `
        -ItemType Directory `
        -Force |
        Out-Null

    New-Item `
        $Mods `
        -ItemType Directory `
        -Force |
        Out-Null

    New-Item `
        $InstallDirectory `
        -ItemType Directory `
        -Force |
        Out-Null

    Write-Host ""
    Write-Host "========================================"
    Write-Host "        MAJOR KEY PACK INSTALLER"
    Write-Host "========================================"
    Write-Host ""

    Write-Host "Downloading Major Key Pack manifest..."

    $ManifestPath=
        Join-Path `
            $Temp `
            "manifest.json"

    Invoke-WebRequest `
        -Uri "$Raw/modpack-manifest.json" `
        -OutFile $ManifestPath

    if(!(Test-Path $ManifestPath)){
        throw "Failed to download modpack manifest."
    }

    $Manifest=
        Get-Content `
            $ManifestPath `
            -Raw |
        ConvertFrom-Json

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

        $Destination=
            Join-Path `
                $Mods `
                $Mod.filename

        Write-Host `
            "Downloading $($Mod.filename)..."

        Invoke-WebRequest `
            -Uri $Mod.url `
            -OutFile $Destination

        if(!(Test-Path $Destination)){
            throw `
                "Download failed: $($Mod.filename)"
        }

        $File=
            Get-Item $Destination

        if($File.Length -ne [long]$Mod.size){

            Remove-Item `
                $Destination `
                -Force

            throw `
                "Size mismatch: $($Mod.filename)`nExpected: $($Mod.size)`nActual: $($File.Length)"
        }

        $Hash=
            (Get-FileHash `
                $Destination `
                -Algorithm SHA256).Hash.ToLower()

        if($Hash -ne $Mod.sha256.ToLower()){

            Remove-Item `
                $Destination `
                -Force

            throw `
                "SHA256 mismatch: $($Mod.filename)`nExpected: $($Mod.sha256)`nActual: $Hash"
        }

        Write-Host `
            "OK: $($Mod.filename)" `
            -ForegroundColor Green
    }

    [PSCustomObject]@{
        name=$Manifest.name
        version=$Manifest.version
        minecraft=$Manifest.minecraft
        loader=$Manifest.loader
        installerVersion=$LatestVersion
        installed=(Get-Date).ToString("o")
    } |
        ConvertTo-Json |
        Set-Content `
            (Join-Path `
                $InstallDirectory `
                "major-key-pack.json") `
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
