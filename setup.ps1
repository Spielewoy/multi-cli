<#
.SYNOPSIS
  Multi-Codex Interactive Setup Wizard (Windows)

.DESCRIPTION
  This script walks a new user through setting up multi-codex step by step.
  It's designed to be as beginner-friendly as possible — every question has
  a sensible default, and you can just press Enter to accept the default.

  What it does:
    1. Welcomes you and explains what multi-codex is
    2. Checks that Node.js and Codex CLI are installed
    3. Installs multi-codex if it's not already installed
    4. Asks where to store profiles (or uses the default)
    5. Walks you through creating your first profiles
    6. Shows a summary and next steps

  Usage:
    powershell -ExecutionPolicy Bypass -File setup.ps1
#>

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Ask a question with a default value. Returns the user's answer (or default).
function Ask {
    param($Prompt, $Default)
    if ($Default) {
        $answer = Read-Host "  ? $Prompt [$Default]"
    } else {
        $answer = Read-Host "  ? $Prompt"
    }
    if ([string]::IsNullOrWhiteSpace($answer)) { return $Default }
    return $answer
}

# Ask a yes/no question. Returns $true for yes, $false for no.
function Ask-YN {
    param($Prompt, [bool]$DefaultYes = $false)
    $hint = if ($DefaultYes) { "[Y/n]" } else { "[y/N]" }
    $answer = Read-Host "  ? $Prompt $hint"
    if ([string]::IsNullOrWhiteSpace($answer)) {
        return $DefaultYes
    }
    return ($answer -match "^[Yy]$")
}

# Print a section header.
function Write-Section {
    param($Title)
    Write-Host ""
    Write-Host "  ================================================================" -ForegroundColor Blue
    Write-Host "    $Title" -ForegroundColor White
    Write-Host "  ================================================================" -ForegroundColor Blue
    Write-Host ""
}

function Write-Ok    { param($Msg) Write-Host "  [OK]   $Msg" -ForegroundColor Green }
function Write-Warn  { param($Msg) Write-Host "  [WARN] $Msg" -ForegroundColor Yellow }
function Write-Fail  { param($Msg) Write-Host "  [FAIL] $Msg" -ForegroundColor Red }
function Write-Info  { param($Msg) Write-Host "  $Msg" -ForegroundColor DarkGray }

# =============================================================================
# FIND THE MULTI-CODEX SCRIPT
# =============================================================================

# Figure out where this setup script is — multi-codex.ps1 should be next to it.
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$MULTI_CODEX = Join-Path $SCRIPT_DIR "multi-codex.ps1"

# =============================================================================
# STEP 1: WELCOME
# =============================================================================

Clear-Host

Write-Host ""
Write-Host "  ======================================================" -ForegroundColor Blue
Write-Host "  |                                                      |" -ForegroundColor Blue
Write-Host "  |             Multi-Codex Setup Wizard                 |" -ForegroundColor Cyan
Write-Host "  |                                                      |" -ForegroundColor Blue
Write-Host "  ======================================================" -ForegroundColor Blue
Write-Host ""
Write-Host "  Welcome! This wizard will help you set up Multi-Codex."
Write-Host ""
Write-Host "  Multi-Codex lets you run multiple Codex CLI profiles"
Write-Host "  at the same time - each with its own account, config,"
Write-Host "  and sessions. Think of it like browser profiles but"
Write-Host "  for Codex."
Write-Host ""
Write-Host "  Press Enter to accept the default for any question." -ForegroundColor DarkGray
Write-Host "  Press Ctrl+C at any time to cancel." -ForegroundColor DarkGray

# =============================================================================
# STEP 2: CHECK PREREQUISITES
# =============================================================================

Write-Section "Step 1/4 - Checking Prerequisites"

# Platform.
Write-Ok "Platform: Windows"
Write-Info "PowerShell $($PSVersionTable.PSVersion)"

# Node.js check.
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if ($nodeCmd) {
    $nodeVer = & node --version 2>$null
    Write-Ok "Node.js: $nodeVer"
} else {
    Write-Fail "Node.js: NOT FOUND"
    Write-Host ""
    Write-Host "  Codex CLI requires Node.js 22 or later."
    Write-Host "  Download from: https://nodejs.org/"
    Write-Host ""
    if (!(Ask-YN "Continue anyway?")) {
        Write-Host "  Setup cancelled. Install Node.js first, then re-run this setup."
        exit 1
    }
}

# Codex CLI check.
$codexPath = ""
$codexCmd = Get-Command codex -ErrorAction SilentlyContinue
if ($codexCmd) {
    $codexPath = $codexCmd.Source
    Write-Ok "Codex CLI: $codexPath"
} else {
    $codexCmdCmd = Get-Command codex.cmd -ErrorAction SilentlyContinue
    if ($codexCmdCmd) {
        $codexPath = $codexCmdCmd.Source
        Write-Ok "Codex CLI: $codexPath"
    } else {
        Write-Warn "Codex CLI: NOT FOUND"
        Write-Host ""
        Write-Host "  You can install Codex CLI with:"
        Write-Host "    npm install -g @openai/codex"
        Write-Host ""
        if (Ask-YN "Install Codex CLI now?" $true) {
            Write-Host ""
            Write-Host "  Installing Codex CLI..."
            try {
                & npm install -g @openai/codex 2>$null
                Write-Ok "Codex CLI installed!"
                $codexCmd = Get-Command codex -ErrorAction SilentlyContinue
                if ($codexCmd) { $codexPath = $codexCmd.Source }
            } catch {
                Write-Warn "Could not install automatically. You can install it manually later."
            }
        } else {
            Write-Warn "Skipping Codex CLI install. You'll need to install it before using profiles."
        }
    }
}

# multi-codex script check.
if (Test-Path $MULTI_CODEX) {
    Write-Ok "multi-codex.ps1: $MULTI_CODEX"
} else {
    # Check if installed globally.
    $globalCmd = Get-Command multi-codex -ErrorAction SilentlyContinue
    if ($globalCmd) {
        $MULTI_CODEX = $globalCmd.Source
        Write-Ok "multi-codex: $MULTI_CODEX (installed globally)"
    } else {
        Write-Fail "multi-codex.ps1 not found at $MULTI_CODEX"
        Write-Host ""
        Write-Host "  Make sure 'multi-codex.ps1' is in the same folder as this setup wizard."
        exit 1
    }
}

# =============================================================================
# STEP 3: CONFIGURE PROFILE STORAGE
# =============================================================================

Write-Section "Step 2/4 - Profile Storage Location"

$DEFAULT_BASE = "$env:USERPROFILE\CodexProfiles"

Write-Host "  Where should Multi-Codex store profiles?"
Write-Host "  Each profile is just a folder with Codex configs inside."
Write-Host ""
$profilesDir = Ask "Profile storage directory:" $DEFAULT_BASE

# Resolve the path.
$profilesDir = [System.IO.Path]::GetFullPath($profilesDir)

Write-Ok "Profiles will be stored at: $profilesDir"

# =============================================================================
# STEP 4: CREATE PROFILES
# =============================================================================

Write-Section "Step 3/4 - Create Your Profiles"

Write-Host "  Let's create your first profiles. You can always create"
Write-Host "  more later with: multi-codex new <name>"
Write-Host ""

$numProfiles = Ask "How many profiles do you want to create?" "2"

# Validate number.
if ($numProfiles -notmatch "^\d+$" -or [int]$numProfiles -lt 1) {
    Write-Warn "Invalid number. Creating 2 profiles."
    $numProfiles = 2
} else {
    $numProfiles = [int]$numProfiles
}

# Cap at 10.
if ($numProfiles -gt 10) {
    Write-Warn "That's a lot of profiles! Capping at 10."
    $numProfiles = 10
}

# Suggest default names.
$defaults = @("work", "personal", "client", "test", "dev", "staging", "project-a", "project-b", "project-c", "project-d")
$createdProfiles = @()

Write-Host ""
for ($i = 0; $i -lt $numProfiles; $i++) {
    $defaultName = $defaults[$i]
    $profileName = Ask "Name for profile #$($i + 1):" $defaultName

    # Validate name.
    if ($profileName -notmatch "^[a-zA-Z0-9][a-zA-Z0-9-]*$") {
        Write-Warn "Invalid name '$profileName'. Using '$defaultName' instead."
        $profileName = $defaultName
    }

    # Ask if shared.
    $sharedFlag = ""
    if (Ask-YN "Make '$profileName' a shared profile? (shares config, isolates auth)") {
        $sharedFlag = "--shared"
    }

    # Create the profile.
    Write-Host ""
    Write-Host "  Creating profile '$profileName'..."
    try {
        $env:MULTICODEX_HOME = $profilesDir
        if ($sharedFlag) {
            & powershell.exe -ExecutionPolicy Bypass -File $MULTI_CODEX new $profileName $sharedFlag 2>$null
        } else {
            & powershell.exe -ExecutionPolicy Bypass -File $MULTI_CODEX new $profileName 2>$null
        }
        Write-Ok "Created profile '$profileName'"
        $createdProfiles += $profileName
    } catch {
        Write-Warn "Could not create profile '$profileName' (might already exist)"
    }
    Write-Host ""
}

# =============================================================================
# STEP 5: SUMMARY
# =============================================================================

Write-Section "Step 4/4 - Setup Complete!"

Write-Host "  Everything is set up. Here's what was created:" -ForegroundColor Green
Write-Host ""

# Show created profiles.
if ($createdProfiles.Count -gt 0) {
    Write-Host "  Profiles:"
    foreach ($p in $createdProfiles) {
        Write-Host "    * $p  ->  $profilesDir\$p" -ForegroundColor Green
    }
} else {
    Write-Host "  No profiles were created. Create one with:"
    Write-Host "    multi-codex new <name>"
}

Write-Host ""
Write-Host "  Quick Reference:" -ForegroundColor White
Write-Host ""
Write-Host "  Launch a profile:"
Write-Host "    multi-codex <name>" -ForegroundColor Cyan
Write-Host "                                e.g. multi-codex work"
Write-Host ""
Write-Host "  Create a new profile:"
Write-Host "    multi-codex new <name>" -ForegroundColor Cyan
Write-Host "                                e.g. multi-codex new client-x"
Write-Host ""
Write-Host "  List all profiles:"
Write-Host "    multi-codex list" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Check your setup:"
Write-Host "    multi-codex doctor" -ForegroundColor Cyan
Write-Host ""
Write-Host "  See all commands:"
Write-Host "    multi-codex help" -ForegroundColor Cyan
Write-Host ""

# Remind about custom storage location.
if ($profilesDir -ne $DEFAULT_BASE) {
    Write-Host "  Important: You chose a custom storage location." -ForegroundColor Yellow
    Write-Host "  Set this environment variable permanently:"
    Write-Host ""
    Write-Host "    [Environment]::SetEnvironmentVariable('MULTICODEX_HOME', '$profilesDir', 'User')"
    Write-Host ""
}

Write-Host "  Each profile gets its own auth, so you'll need to log in" -ForegroundColor DarkGray
Write-Host "  to each profile the first time you launch it." -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Happy coding!" -ForegroundColor White
Write-Host ""
