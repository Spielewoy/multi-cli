# =============================================================================
# Multi-Codex Uninstaller (Windows)
#
# What this does:
#   1. Removes multi-codex.ps1 and multi-codex.cmd from the install directory
#   2. Removes any Start Menu shortcuts created for profiles
#   3. Cleans the install directory from the user's PATH
#   4. Optionally removes all profile data (asks first)
#
# Usage (run in PowerShell):
#   irm https://raw.githubusercontent.com/ProGambler67/multi-codex/main/uninstall.ps1 | iex
# =============================================================================

$ErrorActionPreference = "Stop"

$INSTALL_DIR = "$env:USERPROFILE\.local\bin"

# ── helpers ──────────────────────────────────────────────────────────────────

function Write-Step ($message) {
    Write-Host "  -> $message"
}

Write-Host "Uninstalling Multi-codex..."
Write-Host ""

$removed = 0

# ── remove script files ─────────────────────────────────────────────────────
# Delete the PowerShell script and the cmd.exe wrapper.

foreach ($file in @("multi-codex.ps1", "multi-codex.cmd")) {
    $path = "$INSTALL_DIR\$file"
    if (Test-Path $path) {
        Write-Step "Removing $path"
        Remove-Item -Force $path
        $removed++
    }
}

# ── remove Start Menu shortcuts ─────────────────────────────────────────────
# These are .lnk files that we created for each profile.

$startMenu = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
$shortcuts = Get-ChildItem -Path $startMenu -Filter "Multi-codex *.lnk" -ErrorAction SilentlyContinue
foreach ($s in $shortcuts) {
    Write-Step "Removing shortcut: $($s.FullName)"
    Remove-Item -Force $s.FullName
}

# ── clean PATH ───────────────────────────────────────────────────────────────
# Remove the install directory from the user's PATH if it's there.

$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath -and $userPath -like "*$INSTALL_DIR*") {
    $cleaned = ($userPath -split ';' | Where-Object { $_.TrimEnd('\') -ne $INSTALL_DIR.TrimEnd('\') }) -join ';'
    [Environment]::SetEnvironmentVariable("PATH", $cleaned, "User")
    Write-Step "Removed $INSTALL_DIR from user PATH"
}

# ── optionally remove profile data ──────────────────────────────────────────
# This is where all Codex configs, auth tokens, and sessions live.
# We NEVER delete this without asking the user first.

$profileBase = if ($env:MULTICODEX_HOME) { $env:MULTICODEX_HOME } else { "$env:USERPROFILE\CodexProfiles" }
if (Test-Path $profileBase) {
    Write-Host ""
    $confirm = Read-Host "Remove all profile data at '$profileBase'? [y/N]"
    if ($confirm -match "^[Yy]$") {
        Write-Step "Removing profile data: $profileBase"
        Remove-Item -Recurse -Force $profileBase
    } else {
        Write-Host "  Keeping profile data."
    }
}

# ── done! ────────────────────────────────────────────────────────────────────

Write-Host ""
if ($removed -eq 0) {
    Write-Host "Multi-codex files were not found - nothing to remove."
} else {
    Write-Host "Multi-codex uninstalled."
}
