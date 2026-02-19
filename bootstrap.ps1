# Islands Dark Theme Bootstrap Installer for Windows
# One-liner: irm https://raw.githubusercontent.com/Ericlein/vscode-dark-islands/main/bootstrap.ps1 | iex

param()

$ErrorActionPreference = "Stop"

Write-Output "🏝️  Islands Dark Theme Bootstrap Installer"
Write-Output "=========================================="
Write-Output ""

$RepoUrl = "https://github.com/Ericlein/vscode-dark-islands.git"
$InstallDir = "$env:TEMP\islands-dark-temp"

Write-Output "📥 Step 1: Downloading Islands Dark..."
Write-Output "   Repository: $RepoUrl"

# Remove old temp directory if exists
if (Test-Path $InstallDir) {
    Remove-Item -Recurse -Force $InstallDir
}

# Clone repository
try {
    git clone $RepoUrl $InstallDir --quiet
} catch {
    Write-Output "❌ Failed to download Islands Dark"
    Write-Output "   Make sure Git is installed: https://git-scm.com/download/win"
    exit 1
}

Write-Output "✓ Downloaded successfully"
Write-Output ""

Write-Output "🚀 Step 2: Running installer..."
Write-Output ""

# Run installer
Set-Location $InstallDir
try {
    .\install.ps1
} catch {
    Write-Output "❌ Installation failed"
    Write-Output $_.Exception.Message
    exit 1
}

# Cleanup
Write-Output ""
Write-Output "🧹 Step 3: Cleaning up..."
$remove = Read-Host "   Remove temporary files? (y/n)"
if ($remove -eq 'y' -or $remove -eq 'Y') {
    Remove-Item -Recurse -Force $InstallDir
    Write-Output "✓ Temporary files removed"
} else {
    Write-Output "   Files kept at: $InstallDir"
}

Write-Output ""
Write-Output "🎉 Done! Enjoy your Islands Dark theme!"
