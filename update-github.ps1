$ErrorActionPreference = "Stop"

$RepoFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $RepoFolder

# ========================================
# NEW NEOFORGE GITHUB REPOSITORY
# ========================================

$GitHubRepo = "YOUR_NEW_REPO_URL"

# ========================================
# HEADER
# ========================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "          GITHUB UPDATE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ========================================
# INITIALIZE REPOSITORY
# ========================================

if (-not (Test-Path ".git")) {

    Write-Host "Initializing new Git repository..." -ForegroundColor Yellow

    git init

    if ($LASTEXITCODE -ne 0) {
        throw "Git initialization failed."
    }
}

# ========================================
# CONFIGURE GITHUB REMOTE
# ========================================

$Remotes = @(git remote)

if ($Remotes -contains "origin") {

    $CurrentRemote = git remote get-url origin

    if ($CurrentRemote -ne $GitHubRepo) {

        Write-Host "Updating GitHub remote..." -ForegroundColor Yellow

        git remote set-url origin $GitHubRepo

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to update GitHub remote."
        }
    }

}
else {

    Write-Host "Adding NEW NeoForge GitHub repository..." -ForegroundColor Yellow

    git remote add origin $GitHubRepo

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to add GitHub remote."
    }
}

Write-Host ""
Write-Host "GitHub repository:" -ForegroundColor Gray
Write-Host $GitHubRepo -ForegroundColor White
Write-Host ""

# ========================================
# GITIGNORE
# ========================================

$GitIgnore = @"
libraries/
logs/
crash-reports/
run/

world/
world_nether/
world_the_end/

*.log
*.tmp

.idea/
.vscode/

Thumbs.db
.DS_Store
"@

Set-Content -Path ".gitignore" -Value $GitIgnore -Encoding UTF8

# ========================================
# CHECK FOR CHANGES
# ========================================

Write-Host "Checking for changes..." -ForegroundColor Cyan

$Changes = git status --porcelain

if (-not $Changes) {

    Write-Host ""
    Write-Host "No changes detected." -ForegroundColor Green
    Write-Host ""

    exit 0
}

Write-Host ""
Write-Host "Changes detected:" -ForegroundColor Yellow
git status --short

# ========================================
# ADD FILES
# ========================================

Write-Host ""
Write-Host "Adding files..." -ForegroundColor Cyan

git add .

if ($LASTEXITCODE -ne 0) {
    throw "git add failed."
}

# ========================================
# COMMIT
# ========================================

$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$CommitMessage = "Update NeoForge modpack - $Timestamp"

Write-Host ""
Write-Host "Creating commit..." -ForegroundColor Cyan

git commit -m $CommitMessage

if ($LASTEXITCODE -ne 0) {
    throw "Git commit failed."
}

# ========================================
# MAIN BRANCH
# ========================================

git branch -M main

# ========================================
# PUSH
# ========================================

Write-Host ""
Write-Host "Pushing to NEW GitHub repository..." -ForegroundColor Cyan

git push -u origin main

if ($LASTEXITCODE -ne 0) {
    throw "GitHub push failed."
}

# ========================================
# SUCCESS
# ========================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "       GITHUB UPDATE SUCCESSFUL" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""