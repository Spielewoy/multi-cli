# =============================================================================
# Multi-Codex Installer (Windows)
#
# What this does:
#   1. Downloads multi-codex.ps1 from GitHub
#   2. Puts it in %USERPROFILE%\.local\bin\
#   3. Creates a multi-codex.cmd wrapper so it works from cmd.exe too
#   4. Adds the install directory to the user's PATH if needed
#
# Usage (run in PowerShell):
#   irm https://raw.githubusercontent.com/Spielewoy/multi-codex/main/install.ps1 | iex
# =============================================================================

$ErrorActionPreference = "Stop"

$REPO = "Spielewoy/multi-codex"
$BRANCH = "main"
$RAW = "https://raw.githubusercontent.com/$REPO/$BRANCH"

# Where to install the scripts. We use a user-level directory so
# no admin/elevation is needed.
$INSTALL_DIR = "$env:USERPROFILE\.local\bin"

# ── helpers ──────────────────────────────────────────────────────────────────

function Write-Step ($message) {
    Write-Host "  -> $message"
}

function Abort ($message) {
    Write-Error "Error: $message"
    exit 1
}

# ── create install directory ─────────────────────────────────────────────────

Write-Host "Installing Multi-codex to $INSTALL_DIR ..."

if (!(Test-Path $INSTALL_DIR)) {
    New-Item -ItemType Directory -Force -Path $INSTALL_DIR | Out-Null
}

# ── add to PATH if needed ────────────────────────────────────────────────────
# Check if the install directory is already in the user's PATH.

$IN_PATH = $false
foreach ($path in ($env:PATH -split ';')) {
    if ($path.TrimEnd('\') -eq $INSTALL_DIR.TrimEnd('\')) {
        $IN_PATH = $true
        break
    }
}

if (!$IN_PATH) {
    Write-Step "Adding $INSTALL_DIR to user PATH..."
    $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    $newPath = if ($userPath) { "$userPath;$INSTALL_DIR" } else { "$INSTALL_DIR" }
    [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
    # Also update the current session so the user can start using it right away.
    $env:PATH = "$env:PATH;$INSTALL_DIR"
    Write-Host "  Added to PATH! You may need to restart your terminal for changes to take effect."
    Write-Host ""
}

# ── download multi-codex.ps1 ────────────────────────────────────────────────

Write-Step "Downloading multi-codex.ps1..."
try {
    $scriptContent = Invoke-WebRequest -Uri "$RAW/multi-codex.ps1" -UseBasicParsing -ErrorAction Stop
    [System.IO.File]::WriteAllText("$INSTALL_DIR\multi-codex.ps1", $scriptContent.Content, [System.Text.Encoding]::UTF8)
} catch {
    Abort "Failed to download multi-codex.ps1: $_"
}

# ── create .cmd wrapper ─────────────────────────────────────────────────────
# This lets users run "multi-codex" from cmd.exe (not just PowerShell).
# The wrapper just calls PowerShell to run the actual .ps1 script.

Write-Step "Creating multi-codex.cmd wrapper..."
$wrapper = @"
@echo off
powershell.exe -ExecutionPolicy Bypass -File "%~dp0multi-codex.ps1" %*
"@

# Save as ASCII for maximum compatibility with cmd.exe.
[System.IO.File]::WriteAllText("$INSTALL_DIR\multi-codex.cmd", $wrapper, [System.Text.Encoding]::ASCII)

# ── done! ────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "Multi-codex installed successfully!"
Write-Host ""
Write-Host "Usage:"
Write-Host "  multi-codex help"
Write-Host "  multi-codex new <profile-name>"
Write-Host "  multi-codex <profile-name>"

# Remind the user if Codex CLI itself isn't installed.
$codexCmd = Get-Command codex -ErrorAction SilentlyContinue
if (!$codexCmd) {
    Write-Host ""
    Write-Host "Note:"
    Write-Host "  Codex CLI was not found on this machine."
    Write-Host "  Install it with: npm install -g @openai/codex"
}
