# Islands Dark Theme Installer for Windows

param()

$ErrorActionPreference = "Stop"

Write-Host "Islands Dark Theme Installer for Windows" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Check if VS Code is installed
$codePath = Get-Command "code" -ErrorAction SilentlyContinue
if (-not $codePath) {
    # Try to find code in common locations
    $possiblePaths = @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
        "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd",
        "${env:ProgramFiles(x86)}\Microsoft VS Code\bin\code.cmd"
    )

    $found = $false
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $env:Path += ";$(Split-Path $path)"
            $found = $true
            break
        }
    }

    if (-not $found) {
        Write-Host "Error: VS Code CLI (code) not found!" -ForegroundColor Red
        Write-Host "Please install VS Code and make sure 'code' command is in your PATH."
        Write-Host "You can do this by:"
        Write-Host "  1. Open VS Code"
        Write-Host "  2. Press Ctrl+Shift+P"
        Write-Host "  3. Type 'Shell Command: Install code command in PATH'"
        exit 1
    }
}

Write-Host "VS Code CLI found" -ForegroundColor Green

# Get the directory where this script is located
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "Step 1: Installing Islands Dark theme extension..."

# Install by copying to VS Code extensions directory
$extDir = "$env:USERPROFILE\.vscode\extensions\bwya77.islands-dark-1.0.0"
if (Test-Path $extDir) {
    Remove-Item -Recurse -Force $extDir
}
New-Item -ItemType Directory -Path $extDir -Force | Out-Null
Copy-Item "$scriptDir\package.json" "$extDir\" -Force
Copy-Item "$scriptDir\themes" "$extDir\themes" -Recurse -Force

if (Test-Path "$extDir\themes") {
    Write-Host "Theme extension installed to $extDir" -ForegroundColor Green
} else {
    Write-Host "Failed to install theme extension" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 2: Installing Custom UI Style extension..."
try {
    $output = code --install-extension subframe7536.custom-ui-style --force 2>&1
    Write-Host "Custom UI Style extension installed" -ForegroundColor Green
} catch {
    Write-Host "Could not install Custom UI Style extension automatically" -ForegroundColor Yellow
    Write-Host "   Please install it manually from the Extensions marketplace"
}

Write-Host ""
Write-Host "Step 3: Installing Bear Sans UI fonts..."
$fontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"

# Try user fonts first
if (-not (Test-Path $fontDir)) {
    New-Item -ItemType Directory -Path $fontDir -Force | Out-Null
}

try {
    $fonts = Get-ChildItem "$scriptDir\fonts\*.otf"
    foreach ($font in $fonts) {
        try {
            Copy-Item $font.FullName $fontDir -Force -ErrorAction SilentlyContinue
        } catch {
            # Silently continue if copy fails
        }
    }

    Write-Host "Fonts installed" -ForegroundColor Green
    Write-Host "   Note: You may need to restart applications to use the new fonts" -ForegroundColor DarkGray
} catch {
    Write-Host "Could not install fonts automatically" -ForegroundColor Yellow
    Write-Host "   Please manually install the fonts from the 'fonts/' folder"
    Write-Host "   Select all .otf files and right-click > Install"
}

Write-Host ""
Write-Host "Line Highlight Preference" -ForegroundColor Cyan
Write-Host "   1) Subtle highlight (default)"
Write-Host "   2) No highlight (cursor only)"
$lineHighlightChoice = Read-Host "Choose [1/2]"

if ($lineHighlightChoice -eq "2") {
    $disableLineHighlight = $true
    Write-Host "Line highlight will be disabled" -ForegroundColor Green
} else {
    $disableLineHighlight = $false
    Write-Host "Subtle line highlight will be used" -ForegroundColor Green
}

Write-Host ""
Write-Host "Step 4: Applying VS Code settings..."
$settingsDir = "$env:APPDATA\Code\User"
if (-not (Test-Path $settingsDir)) {
    New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
}

$settingsFile = Join-Path $settingsDir "settings.json"

# Function to strip JSONC features (comments and trailing commas) for JSON parsing
function Strip-Jsonc {
    param([string]$Text)
    # Remove single-line comments
    $Text = $Text -replace '//.*$', ''
    # Remove multi-line comments
    $Text = $Text -replace '/\*[\s\S]*?\*/', ''
    # Remove trailing commas before } or ]
    $Text = $Text -replace ',\s*([}\]])', '$1'
    return $Text
}

$newSettingsRaw = Get-Content "$scriptDir\settings.json" -Raw
$newSettings = (Strip-Jsonc $newSettingsRaw) | ConvertFrom-Json

if (Test-Path $settingsFile) {
    Write-Host "Existing settings.json found" -ForegroundColor Yellow
    Write-Host "   Backing up to settings.json.backup"
    Copy-Item $settingsFile "$settingsFile.backup" -Force

    try {
        $existingRaw = Get-Content $settingsFile -Raw
        $existingSettings = (Strip-Jsonc $existingRaw) | ConvertFrom-Json

        # Merge settings - Islands Dark settings take precedence
        $mergedSettings = @{}
        $existingSettings.PSObject.Properties | ForEach-Object {
            $mergedSettings[$_.Name] = $_.Value
        }
        $newSettings.PSObject.Properties | ForEach-Object {
            $mergedSettings[$_.Name] = $_.Value
        }

        # Deep merge custom-ui-style.stylesheet
        $stylesheetKey = 'custom-ui-style.stylesheet'
        if ($existingSettings.$stylesheetKey -and $newSettings.$stylesheetKey) {
            $mergedStylesheet = @{}
            $existingSettings.$stylesheetKey.PSObject.Properties | ForEach-Object {
                $mergedStylesheet[$_.Name] = $_.Value
            }
            $newSettings.$stylesheetKey.PSObject.Properties | ForEach-Object {
                $mergedStylesheet[$_.Name] = $_.Value
            }
            $mergedSettings[$stylesheetKey] = [PSCustomObject]$mergedStylesheet
        }

        [PSCustomObject]$mergedSettings | ConvertTo-Json -Depth 100 | Set-Content $settingsFile
        Write-Host "Settings merged successfully" -ForegroundColor Green
    } catch {
        Write-Host "Could not merge settings automatically" -ForegroundColor Yellow
        Write-Host "   Please manually merge settings.json from this repo into your VS Code settings"
        Write-Host "   Your original settings have been backed up to settings.json.backup"
    }
} else {
    Copy-Item "$scriptDir\settings.json" $settingsFile
    Write-Host "Settings applied" -ForegroundColor Green
}

# Apply line highlight preference
if ($disableLineHighlight) {
    try {
        $currentRaw = Get-Content $settingsFile -Raw
        $currentSettings = (Strip-Jsonc $currentRaw) | ConvertFrom-Json
        $currentSettings | Add-Member -NotePropertyName "editor.renderLineHighlight" -NotePropertyValue "none" -Force
        $currentSettings | ConvertTo-Json -Depth 100 | Set-Content $settingsFile
        Write-Host "Line highlight disabled" -ForegroundColor Green
    } catch {
        Write-Host "Could not apply line highlight preference" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Step 5: Enabling Custom UI Style..."

# Check if this is the first run
$firstRunFile = Join-Path $scriptDir ".islands_dark_first_run"
if (-not (Test-Path $firstRunFile)) {
    New-Item -ItemType File -Path $firstRunFile | Out-Null
    Write-Host ""
    Write-Host "Important Notes:" -ForegroundColor Yellow
    Write-Host "   - IBM Plex Mono and FiraCode Nerd Font Mono need to be installed separately"
    Write-Host "   - After VS Code reloads, you may see a 'corrupt installation' warning"
    Write-Host "   - This is expected - click the gear icon and select 'Don't Show Again'"
    Write-Host ""
    Read-Host "Press Enter to continue and reload VS Code"
}

Write-Host ""
Write-Host "Islands Dark theme has been installed!" -ForegroundColor Green
Write-Host ""
Write-Host "   Opening VS Code and applying custom UI style..."
Write-Host ""

# Open VS Code
code $scriptDir 2>$null

# Wait for VS Code to fully load and extensions to activate
Write-Host "   Waiting for VS Code to load..." -ForegroundColor DarkGray
Start-Sleep -Seconds 10

# Trigger "Custom UI Style: Reload" via command palette using SendKeys
# This applies the CSS patches and auto-restarts (reloadWithoutPrompting=true)
Write-Host "   Triggering Custom UI Style reload..." -ForegroundColor DarkGray
try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type @"
        using System;
        using System.Runtime.InteropServices;
        public class Win32Util {
            [DllImport("user32.dll")]
            [return: MarshalAs(UnmanagedType.Bool)]
            public static extern bool SetForegroundWindow(IntPtr hWnd);
        }
"@

    # Find VS Code by window title (more reliable than process name)
    $vscodeProcess = Get-Process | Where-Object { $_.MainWindowTitle -match "Visual Studio Code" } | Select-Object -First 1
    if (-not $vscodeProcess) {
        # Fallback: try process name
        $vscodeProcess = Get-Process -Name "Code" -ErrorAction SilentlyContinue |
            Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    }

    if ($vscodeProcess -and $vscodeProcess.MainWindowHandle -ne 0) {
        # Focus VS Code window using Win32 API
        [Win32Util]::SetForegroundWindow($vscodeProcess.MainWindowHandle) | Out-Null
        Start-Sleep -Milliseconds 1000

        # Open command palette with Ctrl+Shift+P
        [System.Windows.Forms.SendKeys]::SendWait("^+p")
        Start-Sleep -Milliseconds 1000

        # Type the command
        [System.Windows.Forms.SendKeys]::SendWait("Custom UI Style{:} Reload")
        Start-Sleep -Milliseconds 1000

        # Press Enter to execute
        [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")

        Write-Host "   Custom UI Style reload triggered. VS Code will restart automatically." -ForegroundColor Green
    } else {
        Write-Host "   Could not find VS Code window." -ForegroundColor Yellow
        Write-Host "   Please run 'Custom UI Style: Reload' from the Command Palette (Ctrl+Shift+P)." -ForegroundColor Yellow
    }
} catch {
    Write-Host "   Could not trigger reload automatically: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "   Please run 'Custom UI Style: Reload' from the Command Palette (Ctrl+Shift+P)." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Done!" -ForegroundColor Green

Start-Sleep -Seconds 3
