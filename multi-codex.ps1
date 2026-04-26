<#
.SYNOPSIS
  multi-codex.ps1 — Run multiple OpenAI Codex CLI profiles at the same time (Windows version).

.DESCRIPTION
  This is the Windows PowerShell version of multi-codex. It does the same thing
  as the bash version but uses PowerShell commands and Windows paths.

  HOW IT WORKS:
    Codex CLI stores everything (config, auth, sessions) in a folder called
    %USERPROFILE%\.codex\ by default. But it also checks the CODEX_HOME
    environment variable. If CODEX_HOME is set, Codex uses THAT folder instead.

    So the trick is:
      1. We create separate folders for each profile (e.g. %USERPROFILE%\CodexProfiles\work\)
      2. When launching a profile, we set CODEX_HOME to that folder
      3. Each profile gets its own auth, config, sessions — fully independent

  USAGE:
    multi-codex help              — show all commands
    multi-codex new work          — create a profile called "work"
    multi-codex work              — launch Codex with the "work" profile
    multi-codex doctor            — check if everything is set up correctly
#>

param (
    [Parameter(Position = 0, Mandatory = $false)]
    [string]$cmd,

    [Parameter(Position = 1, Mandatory = $false)]
    [string]$arg1,

    [Parameter(Position = 2, Mandatory = $false)]
    [string]$arg2,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ForwardArgs
)

# =============================================================================
# CONFIGURATION
# Where profiles are stored. Users can override with MULTICODEX_HOME env var.
# Default: %USERPROFILE%\CodexProfiles (e.g. C:\Users\Max\CodexProfiles)
# =============================================================================

$VERSION = "1.0.0"

$BASE = if ($env:MULTICODEX_HOME) { $env:MULTICODEX_HOME } else { "$env:USERPROFILE\CodexProfiles" }

# =============================================================================
# FIND CODEX
# Locate the Codex CLI binary on the system.
# =============================================================================

# Search for the Codex CLI in common locations and PATH.
# Codex on Windows is a Node.js CLI tool installed via npm.
function Find-Codex {
    # Check common npm global install locations.
    $paths = @(
        "$env:APPDATA\npm\codex.cmd",
        "$env:APPDATA\npm\codex",
        "$env:LOCALAPPDATA\npm\codex.cmd",
        "$env:PROGRAMFILES\nodejs\codex.cmd"
    )
    foreach ($p in $paths) {
        if (Test-Path $p) { return $p }
    }

    # Try to find it in PATH (this catches custom install locations).
    $exeCommand = Get-Command codex -ErrorAction SilentlyContinue
    if ($exeCommand) { return $exeCommand.Source }

    # Also check for codex.cmd in PATH.
    $cmdCommand = Get-Command codex.cmd -ErrorAction SilentlyContinue
    if ($cmdCommand) { return $cmdCommand.Source }

    return $null
}

# The Codex binary path. Users can override with MULTICODEX_APP env var.
$APP = if ($env:MULTICODEX_APP) { $env:MULTICODEX_APP } else { Find-Codex }

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Get the path to the templates folder inside the profiles directory.
function Get-TemplatesDir {
    return "$BASE\.templates"
}

# Get the path to the system-wide Codex config folder.
function Get-SystemCodexHome {
    return "$env:USERPROFILE\.codex"
}

# Check if a profile is a "shared" profile (has a .shared marker file).
function Test-SharedProfile {
    param($name)
    return Test-Path "$BASE\$name\.shared"
}

# Check that a profile name is valid.
# Rules: must start with a letter or number, only letters/numbers/hyphens.
function Validate-Name {
    param($name)
    if ([string]::IsNullOrWhiteSpace($name)) {
        Write-Error "Error: profile name required"
        exit 1
    }
    if ($name -notmatch "^[a-zA-Z0-9][a-zA-Z0-9-]*$") {
        Write-Error "Error: profile name must start with alphanumeric and contain only letters, numbers, or hyphens"
        exit 1
    }
}

# Calculate the total size of a folder in a human-readable format.
function Get-FolderSize {
    param($Path)
    $size = (Get-ChildItem $Path -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    if ($null -eq $size) { $size = 0 }
    if ($size -ge 1GB) { "{0:N2} GB" -f ($size / 1GB) }
    elseif ($size -ge 1MB) { "{0:N2} MB" -f ($size / 1MB) }
    elseif ($size -ge 1KB) { "{0:N2} KB" -f ($size / 1KB) }
    else { "$size B" }
}

# =============================================================================
# USAGE / HELP
# Show all available commands.
# =============================================================================

function Write-Usage {
    Write-Host "Usage: multi-codex <command> [args]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  new <name> [options]        Create a new profile + Start Menu shortcut"
    Write-Host "      --shared                Share config/skills; isolate only accounts"
    Write-Host "      --from <template>       Seed from a saved template"
    Write-Host "  list                        List existing profiles"
    Write-Host "  status                      Show running state, type, and last-used per profile"
    Write-Host "  rename <old> <new>          Rename a profile (updates shortcut if present)"
    Write-Host "  delete <name>               Delete a profile and its data"
    Write-Host "  clone <src> <dest>          Copy an existing profile"
    Write-Host "  template save <profile> <name>   Save a profile as a reusable template"
    Write-Host "  template list               List saved templates"
    Write-Host "  template delete <name>      Remove a template"
    Write-Host "  export <name> [path]        Archive a profile to a .zip file"
    Write-Host "  import <archive> [name]     Restore a profile from a .zip archive"
    Write-Host "  update                      Update multi-codex to the latest version"
    Write-Host "  doctor                      Run a system diagnosis"
    Write-Host "  stats                       Show storage usage per profile"
    Write-Host "  completion                  Show setup instructions for shell completion"
    Write-Host "  <name>                      Launch Codex with the given profile"
    Write-Host "  help                        Show this help"
    Write-Host "  version                     Show version number"
    Write-Host ""
    Write-Host "Profile names: alphanumeric and hyphens only (e.g. work, personal, test-1)"
    Write-Host ""
    Write-Host "Environment:"
    Write-Host "  MULTICODEX_APP      Override the Codex binary path"
    Write-Host "  MULTICODEX_HOME     Override the profile storage directory"
    Write-Host "  CODEX_HOME          (used internally) Points Codex at the profile directory"
}

# =============================================================================
# PROFILE CREATION
# =============================================================================

# Create a "full" profile — an empty directory structure.
# Codex will populate it with config, auth, sessions on first launch.
function Invoke-CreateProfile {
    param($ProfileName)
    $profileDir = "$BASE\$ProfileName"
    New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
}

# Create a "shared" profile — symlinks config, skills, agents, prompts,
# MCP configs, and plugins from the system ~/.codex/ install.
# Auth stays isolated (different accounts per profile — that's the point).
function Invoke-CreateSharedProfile {
    param($name)
    $profileDir = "$BASE\$name"
    $sysHome    = Get-SystemCodexHome

    New-Item -ItemType Directory -Force -Path $profileDir | Out-Null

    # Drop a marker file so we know this is a shared profile later.
    New-Item -ItemType File -Force -Path "$profileDir\.shared" | Out-Null

    # Symlink config.toml from system install (shared settings).
    if ((Test-Path "$sysHome\config.toml") -and !(Test-Path "$profileDir\config.toml")) {
        New-Item -ItemType SymbolicLink -Path "$profileDir\config.toml" -Target "$sysHome\config.toml" -ErrorAction SilentlyContinue | Out-Null
    }

    # Symlink shared folders: skills, agents, prompts, mcp-configs, plugins.
    foreach ($folder in @("skills", "agents", "prompts", "mcp-configs", "plugins")) {
        $src  = "$sysHome\$folder"
        $dest = "$profileDir\$folder"
        if ((Test-Path $src) -and !(Test-Path $dest)) {
            New-Item -ItemType SymbolicLink -Path $dest -Target $src -ErrorAction SilentlyContinue | Out-Null
        }
    }

    # NOTE: auth.json is NOT symlinked — each profile needs its own login.
}

# =============================================================================
# SHORTCUTS
# Create Start Menu shortcuts so users can click to launch profiles.
# =============================================================================

# Create a Windows Start Menu shortcut (.lnk file) for a profile.
function Invoke-CreateShortcut {
    param($ProfileName)

    $APP_NAME = "Multi-codex $ProfileName"
    $SHORTCUT_PATH = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\$APP_NAME.lnk"

    # Figure out where this script lives so the shortcut can call it.
    $SCRIPT_PATH = $MyInvocation.ScriptName
    if ([string]::IsNullOrEmpty($SCRIPT_PATH)) {
        # If we can't find it from invocation, try the PATH.
        $cmdObj = Get-Command multi-codex -ErrorAction SilentlyContinue
        if ($cmdObj) { $SCRIPT_PATH = $cmdObj.Source }
    }

    # Use WScript.Shell COM object to create the .lnk shortcut.
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($SHORTCUT_PATH)
    $Shortcut.TargetPath = "powershell.exe"
    $Shortcut.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -Command `"& '$SCRIPT_PATH' $ProfileName`""
    if ($APP -and (Test-Path $APP -ErrorAction SilentlyContinue)) {
        $Shortcut.IconLocation = "$APP, 0"
    }
    $Shortcut.Save()

    Write-Host "Shortcut created: $SHORTCUT_PATH"
}

# Remove the Start Menu shortcut for a profile.
function Remove-ProfileShortcut {
    param($ProfileName)
    $SHORTCUT_PATH = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Multi-codex $ProfileName.lnk"
    if (Test-Path $SHORTCUT_PATH) {
        Remove-Item -Force $SHORTCUT_PATH
        Write-Host "Removed shortcut: $SHORTCUT_PATH"
    }
}

# =============================================================================
# SHELL ALIASES
# Create tiny .cmd wrapper scripts so profile names work as terminal commands.
# =============================================================================

# Path to the directory where shell alias scripts are stored.
function Get-ShellAliasDir {
    return "$BASE\bin"
}

# Create a .cmd wrapper at $BASE\bin\<profile>.cmd that invokes multi-codex.
function Invoke-CreateShellAlias {
    param($ProfileName)

    $aliasDir  = Get-ShellAliasDir
    $aliasPath = "$aliasDir\$ProfileName.cmd"

    # Figure out where this script lives.
    $scriptPath = $MyInvocation.ScriptName
    if ([string]::IsNullOrEmpty($scriptPath)) {
        $cmdObj = Get-Command multi-codex -ErrorAction SilentlyContinue
        if ($cmdObj) { $scriptPath = $cmdObj.Source }
    }
    if ([string]::IsNullOrEmpty($scriptPath)) {
        $scriptPath = $PSCommandPath
    }

    New-Item -ItemType Directory -Force -Path $aliasDir | Out-Null

    # Write a tiny .cmd wrapper that calls multi-codex with this profile name.
    @"
@echo off
powershell.exe -ExecutionPolicy Bypass -File "$scriptPath" $ProfileName %*
"@ | Set-Content -Path $aliasPath -Encoding ASCII

    Write-Host "Shell alias created: $aliasPath"
}

# Remove the .cmd wrapper for a profile.
function Remove-ShellAlias {
    param($ProfileName)
    $aliasPath = "$(Get-ShellAliasDir)\$ProfileName.cmd"
    if (Test-Path $aliasPath) {
        Remove-Item -Force $aliasPath
        Write-Host "Removed shell alias: $aliasPath"
    }
}

# Check whether $BASE\bin is already in $PATH.
function Test-ShellAliasInPath {
    $aliasDir = Get-ShellAliasDir
    return $env:PATH -split ';' | Where-Object { $_ -eq $aliasDir } | Select-Object -First 1
}

# =============================================================================
# LAUNCH
# Start Codex with a specific profile's CODEX_HOME.
# =============================================================================

# Launch Codex using a specific profile. Sets CODEX_HOME to the profile's
# folder so Codex uses that profile's config/auth/sessions.
function Invoke-LaunchProfile {
    param($ProfileName, $ArgsToForward)
    $profileDir = "$BASE\$ProfileName"

    # Make sure the profile exists.
    if (!(Test-Path $profileDir)) {
        Write-Error "Error: profile '$ProfileName' does not exist. Run: multi-codex new $ProfileName"
        exit 1
    }

    # Make sure Codex is installed.
    if ([string]::IsNullOrEmpty($APP)) {
        Write-Error "Error: Codex CLI not found. Install it (npm i -g @openai/codex) or set MULTICODEX_APP."
        exit 1
    }

    Write-Host "Launching Codex profile '$ProfileName'"

    # Set CODEX_HOME so Codex uses this profile's directory.
    $env:CODEX_HOME = $profileDir

    # Launch Codex, passing through any extra arguments.
    if ($ArgsToForward -and $ArgsToForward.Count -gt 0) {
        & $APP @ArgsToForward
    }
    else {
        & $APP
    }
}

# =============================================================================
# PROFILE MANAGEMENT
# =============================================================================

# List all existing profiles.
function Invoke-ListProfiles {
    Write-Host "Existing profiles:"
    if (Test-Path $BASE) {
        $profiles = @(Get-ChildItem -Directory -Path $BASE | Where-Object { $_.Name -ne ".templates" })
        if ($profiles.Count -gt 0) {
            foreach ($p in $profiles) {
                Write-Host "  $($p.Name)"
            }
        }
        else {
            Write-Host "  (none)"
        }
    }
    else {
        Write-Host "  (none)"
    }
}

# Create a new profile. Supports: full (default), shared, or from template.
function Invoke-NewProfile {
    param($name, [string[]]$extraArgs)

    $shared  = $false
    $fromTpl = ""

    # Parse extra arguments (--shared, --from <template>).
    $i = 0
    while ($i -lt $extraArgs.Count) {
        switch ($extraArgs[$i]) {
            "--shared" { $shared = $true }
            "--from"   { $i++; if ($i -lt $extraArgs.Count) { $fromTpl = $extraArgs[$i] } }
        }
        $i++
    }

    if ([string]::IsNullOrWhiteSpace($name)) {
        Write-Error "Error: profile name required"
        exit 1
    }

    Validate-Name $name

    $profileDir = "$BASE\$name"

    # Don't overwrite an existing profile.
    if (Test-Path $profileDir) {
        Write-Error "Error: profile '$name' already exists"
        exit 1
    }

    # Make sure the base profiles directory exists.
    New-Item -ItemType Directory -Force -Path $BASE | Out-Null

    # Create the profile using the chosen method.
    if ($fromTpl) {
        # From template.
        $tplPath = "$(Get-TemplatesDir)\$fromTpl"
        if (!(Test-Path $tplPath)) {
            Write-Error "Error: template '$fromTpl' not found. Run: multi-codex template list"
            exit 1
        }
        Write-Host "Creating profile '$name' from template '$fromTpl'..."
        Copy-Item -Path $tplPath -Destination $profileDir -Recurse
    } elseif ($shared) {
        # Shared profile.
        Invoke-CreateSharedProfile $name
    } else {
        # Full (isolated) profile.
        Invoke-CreateProfile $name
    }

    Write-Host "Created profile '$name'"
    Invoke-CreateShortcut $name
    Invoke-CreateShellAlias $name

    # Hint: remind the user to add $BASE\bin to PATH if it's not there yet.
    if (-not (Test-ShellAliasInPath)) {
        Write-Host ""
        Write-Host "Tip: To use '$name' as a command, add $(Get-ShellAliasDir) to your PATH:"
        Write-Host "  `$env:PATH += ';$(Get-ShellAliasDir)'"
        Write-Host "  # Or add it permanently via System Properties > Environment Variables"
    }
}

# Delete a profile and all its data. Asks for confirmation first.
function Invoke-DeleteProfile {
    param($ProfileName)
    Validate-Name $ProfileName

    $profileDir = "$BASE\$ProfileName"
    if (!(Test-Path $profileDir)) {
        Write-Error "Error: profile '$ProfileName' does not exist"
        exit 1
    }

    # Safety check — ask before deleting.
    $confirm = Read-Host "Delete profile '$ProfileName' and all its data? [y/N]"
    if ($confirm -match "^[Yy]$") {
        try {
            Remove-Item -Recurse -Force $profileDir -ErrorAction Stop
            Remove-ProfileShortcut $ProfileName
            Remove-ShellAlias $ProfileName
            Write-Host "Deleted profile '$ProfileName'"
        } catch {
            Write-Error "Error: could not delete profile directory. Make sure Codex is not running."
            Write-Host "Details: $_"
        }
    }
    else {
        Write-Host "Aborted."
    }
}

# Rename a profile (moves the folder and recreates the shortcut).
function Invoke-RenameProfile {
    param($OLD, $NEW)
    Validate-Name $OLD
    Validate-Name $NEW

    $oldDir = "$BASE\$OLD"
    $newDir = "$BASE\$NEW"

    if (!(Test-Path $oldDir)) {
        Write-Error "Error: profile '$OLD' does not exist"
        exit 1
    }
    if (Test-Path $newDir) {
        Write-Error "Error: profile '$NEW' already exists"
        exit 1
    }

    Rename-Item -Path $oldDir -NewName $NEW
    Remove-ProfileShortcut $OLD
    Remove-ShellAlias $OLD
    Invoke-CreateShortcut $NEW
    Invoke-CreateShellAlias $NEW

    Write-Host "Renamed profile '$OLD' to '$NEW'"
}

# Clone a profile — makes a full copy.
function Invoke-CloneProfile {
    param($SRC, $DEST)
    Validate-Name $SRC
    Validate-Name $DEST

    $srcDir  = "$BASE\$SRC"
    $destDir = "$BASE\$DEST"

    if (!(Test-Path $srcDir)) {
        Write-Error "Error: source profile '$SRC' does not exist"
        exit 1
    }
    if (Test-Path $destDir) {
        Write-Error "Error: destination profile '$DEST' already exists"
        exit 1
    }

    Write-Host "Cloning profile '$SRC' to '$DEST'..."
    Copy-Item -Path $srcDir -Destination $destDir -Recurse
    Invoke-CreateShortcut $DEST
    Invoke-CreateShellAlias $DEST

    Write-Host "Successfully cloned '$SRC' to '$DEST'"
}

# =============================================================================
# TEMPLATES
# Save/restore profile configurations as reusable templates.
# =============================================================================

function Invoke-TemplateCmd {
    param($sub, $a, $b)
    switch ($sub) {
        "save" {
            # Save an existing profile as a reusable template.
            if ([string]::IsNullOrWhiteSpace($a) -or [string]::IsNullOrWhiteSpace($b)) {
                Write-Error "Error: usage: multi-codex template save <profile> <name>"; exit 1
            }
            Validate-Name $a; Validate-Name $b
            $srcDir  = "$BASE\$a"
            $tplDir  = Get-TemplatesDir
            $tplPath = "$tplDir\$b"
            if (!(Test-Path $srcDir))  { Write-Error "Error: profile '$a' does not exist"; exit 1 }
            if (Test-Path $tplPath)    { Write-Error "Error: template '$b' already exists"; exit 1 }
            New-Item -ItemType Directory -Force -Path $tplDir | Out-Null
            Write-Host "Saving '$a' as template '$b'..."
            Copy-Item -Path $srcDir -Destination $tplPath -Recurse
            # Remove shared marker and auth (templates are always clean).
            $marker = "$tplPath\.shared"
            if (Test-Path $marker) { Remove-Item $marker -Force }
            $auth = "$tplPath\auth.json"
            if (Test-Path $auth) { Remove-Item $auth -Force }
            Write-Host "Saved template '$b'"
        }
        "list" {
            # Show all saved templates.
            $tplDir = Get-TemplatesDir
            Write-Host "Templates:"
            if (!(Test-Path $tplDir)) { Write-Host "  (none)"; return }
            $items = Get-ChildItem -Directory -Path $tplDir -ErrorAction SilentlyContinue
            if (!$items -or $items.Count -eq 0) { Write-Host "  (none)"; return }
            foreach ($t in $items) {
                Write-Host ("  {0,-20} {1}" -f $t.Name, (Get-FolderSize $t.FullName))
            }
        }
        "delete" {
            # Delete a saved template.
            if ([string]::IsNullOrWhiteSpace($a)) { Write-Error "Error: template name required"; exit 1 }
            Validate-Name $a
            $tplPath = "$(Get-TemplatesDir)\$a"
            if (!(Test-Path $tplPath)) { Write-Error "Error: template '$a' does not exist"; exit 1 }
            Remove-Item -Recurse -Force $tplPath
            Write-Host "Deleted template '$a'"
        }
        default {
            Write-Error "Error: usage: multi-codex template <save|list|delete>"; exit 1
        }
    }
}

# =============================================================================
# EXPORT / IMPORT
# Back up profiles to .zip archives and restore them.
# Uses .zip instead of .tar.gz because Windows has native zip support.
# =============================================================================

# Export a profile to a .zip archive.
function Invoke-ExportProfile {
    param($name, $outPath)
    if ([string]::IsNullOrWhiteSpace($name)) { Write-Error "Error: profile name required"; exit 1 }
    Validate-Name $name

    $profileDir = "$BASE\$name"
    if (!(Test-Path $profileDir)) { Write-Error "Error: profile '$name' does not exist"; exit 1 }

    # Default output filename.
    if ([string]::IsNullOrWhiteSpace($outPath)) { $outPath = ".\$name.zip" }

    Write-Host "Exporting '$name' to $outPath ..."
    Compress-Archive -Path $profileDir -DestinationPath $outPath -Force
    Write-Host "Done."
}

# Import a profile from a .zip archive.
function Invoke-ImportProfile {
    param($archivePath, $name)

    if ([string]::IsNullOrWhiteSpace($archivePath)) {
        Write-Error "Error: usage: multi-codex import <archive.zip> [name]"; exit 1
    }
    if (!(Test-Path $archivePath)) {
        Write-Error "Error: file not found: $archivePath"; exit 1
    }

    # If no name was given, use the archive filename (without extension).
    if ([string]::IsNullOrWhiteSpace($name)) {
        $name = [System.IO.Path]::GetFileNameWithoutExtension($archivePath)
    }
    Validate-Name $name

    $dest = "$BASE\$name"
    if (Test-Path $dest) {
        Write-Error "Error: profile '$name' already exists — choose a different name or delete it first"
        exit 1
    }

    New-Item -ItemType Directory -Force -Path $BASE | Out-Null
    Write-Host "Importing as '$name'..."

    # Extract to a temp folder, then move into place.
    $tmp = "$BASE\_mc_import_$(Get-Random)"
    Expand-Archive -Path $archivePath -DestinationPath $tmp -Force

    $top = Get-ChildItem -Directory -Path $tmp
    if ($top.Count -eq 1) {
        Move-Item -Path $top[0].FullName -Destination $dest
        Remove-Item $tmp -Recurse -Force
    } else {
        Rename-Item -Path $tmp -NewName $name
    }

    Invoke-CreateShortcut $name
    Write-Host "Imported profile '$name'"
}

# =============================================================================
# STATUS & DIAGNOSTICS
# =============================================================================

# Show a table of all profiles with running state, type, last used, and size.
function Invoke-StatusProfiles {
    if (!(Test-Path $BASE)) { Write-Host "No profiles found."; return }

    # Print table header.
    Write-Host ("{0,-18} {1,-10} {2,-12} {3,-20} {4}" -f "PROFILE", "RUNNING", "TYPE", "LAST USED", "SIZE")
    Write-Host ("{0,-18} {1,-10} {2,-12} {3,-20} {4}" -f "-------", "-------", "----", "---------", "----")

    $dirs = Get-ChildItem -Directory -Path $BASE -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne ".templates" }

    foreach ($d in $dirs) {
        # Check if this profile is currently running by looking at process
        # command lines for the profile directory name.
        $running = "no"
        $procs = Get-Process -Name "node" -ErrorAction SilentlyContinue
        if ($procs) {
            foreach ($proc in $procs) {
                try {
                    $cl = (Get-CimInstance Win32_Process -Filter "ProcessId = $($proc.Id)" -ErrorAction SilentlyContinue).CommandLine
                    if ($cl -and $cl -like "*$($d.Name)*") { $running = "yes"; break }
                } catch {}
            }
        }

        # Is it a shared or full profile?
        $ptype    = if (Test-Path "$($d.FullName)\.shared") { "shared" } else { "full" }
        $lastUsed = $d.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
        $size     = Get-FolderSize $d.FullName

        # Print the row (running profiles get green text).
        if ($running -eq "yes") {
            Write-Host ("{0,-18} " -f $d.Name) -NoNewline
            Write-Host ("{0,-10} " -f $running) -NoNewline -ForegroundColor Green
            Write-Host ("{0,-12} {1,-20} {2}" -f $ptype, $lastUsed, $size)
        } else {
            Write-Host ("{0,-18} {1,-10} {2,-12} {3,-20} {4}" -f $d.Name, $running, $ptype, $lastUsed, $size)
        }
    }
}

# Show disk usage per profile.
function Invoke-ProfileStats {
    if (!(Test-Path $BASE)) {
        Write-Host "No profiles found."
        return
    }

    Write-Host "Profile Storage Usage:"
    Write-Host ("{0,-20} {1,-10}" -f "PROFILE", "SIZE")
    Write-Host ("{0,-20} {1,-10}" -f "-------", "----")

    $profiles = Get-ChildItem -Directory -Path $BASE | Where-Object { $_.Name -ne ".templates" }
    foreach ($p in $profiles) {
        $size = Get-FolderSize $p.FullName
        Write-Host ("{0,-20} {1,-10}" -f $p.Name, $size)
    }

    Write-Host ""
    $total = Get-FolderSize $BASE
    Write-Host "Total usage: $total"
}

# Run a health check — verifies Codex is installed, PATH is set up, etc.
function Invoke-DoctorCli {
    $errors = 0
    $warnings = 0

    Write-Host "Checking multi-codex environment..."

    # 1. Platform.
    Write-Host "  [OK] Platform: Windows"

    # 2. Codex installation.
    if ($APP -and (Test-Path $APP -ErrorAction SilentlyContinue)) {
        Write-Host "  [OK] Codex: Found at $APP"
    } elseif ($APP) {
        Write-Host "  [OK] Codex: Found at $APP (via PATH)"
    } else {
        Write-Host "  [FAIL] Codex: Not found. Install it (npm i -g @openai/codex) or set MULTICODEX_APP."
        $errors++
    }

    # 3. Is multi-codex in PATH?
    $cmdObj = Get-Command multi-codex -ErrorAction SilentlyContinue
    if ($cmdObj) {
        Write-Host "  [OK] Global command: $($cmdObj.Source)"
    } else {
        Write-Host "  [WARN] Global command: Not found in PATH. Run install.ps1 or add to PATH."
        $warnings++
    }

    # 4. System Codex config.
    $sysHome = Get-SystemCodexHome
    if (Test-Path $sysHome) {
        Write-Host "  [OK] System Codex config: $sysHome"
        if (Test-Path "$sysHome\auth.json") {
            Write-Host "  [OK] System auth: configured"
        } else {
            Write-Host "  [WARN] System auth: not configured (no auth.json)"
            $warnings++
        }
    } else {
        Write-Host "  [WARN] System Codex config: $sysHome (not yet created - run Codex once first)"
        $warnings++
    }

    # 5. Profile storage directory.
    if (Test-Path $BASE) {
        try {
            $testFile = Join-Path $BASE ".write-test"
            New-Item -ItemType File -Path $testFile -Force -ErrorAction Stop | Out-Null
            Remove-Item $testFile -Force
            Write-Host "  [OK] Profile storage: $BASE (writable)"
        } catch {
            Write-Host "  [FAIL] Profile storage: $BASE (NOT writable)"
            $errors++
        }
    } else {
        Write-Host "  [WARN] Profile storage: $BASE (not yet created)"
    }

    # 6b. Is the shell alias bin directory in PATH?
    if (Test-ShellAliasInPath) {
        Write-Host "  [OK] Shell aliases: $(Get-ShellAliasDir) is in PATH"
    } else {
        Write-Host "  [WARN] Shell aliases: $(Get-ShellAliasDir) is NOT in PATH. Add it to use profile names as commands."
        $warnings++
    }

    # 6. Node.js check (required for Codex CLI).
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCmd) {
        $nodeVer = & node --version 2>$null
        Write-Host "  [OK] Node.js: $nodeVer"
    } else {
        Write-Host "  [WARN] Node.js: Not found in PATH. Codex CLI requires Node.js 22+."
        $warnings++
    }

    Write-Host ""
    if ($errors -eq 0) {
        if ($warnings -eq 0) {
            Write-Host "Your environment looks perfect!"
        } else {
            Write-Host "Found $warnings warning(s). Multi-codex should still work, but some features might be degraded."
        }
    } else {
        Write-Host "Found $errors error(s) and $warnings warning(s). Please fix the errors above."
    }
}

# =============================================================================
# UPDATE
# Download the latest version of this script from GitHub.
# =============================================================================

function Invoke-UpdateCli {
    $script_url = "https://raw.githubusercontent.com/ProGambler67/multi-codex/main/multi-codex.ps1"
    $target = $MyInvocation.ScriptName
    if ([string]::IsNullOrEmpty($target)) {
        $cmdObj = Get-Command multi-codex -ErrorAction SilentlyContinue
        if ($cmdObj) { $target = $cmdObj.Source }
    }

    if ([string]::IsNullOrEmpty($target)) {
        Write-Error "Error: could not determine script path for update"
        exit 1
    }

    Write-Host "Updating multi-codex from $script_url ..."
    try {
        $result = Invoke-WebRequest -Uri $script_url -UseBasicParsing -ErrorAction Stop
        [System.IO.File]::WriteAllText($target, $result.Content, [System.Text.Encoding]::UTF8)
        Write-Host "Successfully updated multi-codex!"
    } catch {
        Write-Error "Error: failed to download update: $_"
        exit 1
    }
}

# =============================================================================
# SHELL COMPLETION
# Tab completion for PowerShell.
# =============================================================================

# Show instructions for setting up tab completion.
function Invoke-HelpCompletion {
    Write-Host "To enable autocompletion in PowerShell, add the following to your `$PROFILE:"
    Write-Host ""
    Write-Host '  Invoke-Expression (& multi-codex completion powershell)'
    Write-Host ""
    Write-Host "Then restart your terminal or run: . `$PROFILE"
}

# Output the completion registration script.
function Invoke-GenerateCompletion {
    param($shell)
    if ($shell -eq "powershell") {
        @"
Register-ArgumentCompleter -Native -CommandName multi-codex -ScriptBlock {
    param(`$wordToComplete, `$commandAst, `$cursorPosition)
    `$opts = @('new', 'list', 'status', 'rename', 'delete', 'clone', 'template', 'export', 'import', 'update', 'doctor', 'stats', 'completion', 'help')
    `$profiles = if (Test-Path '$BASE') { Get-ChildItem -Directory -Path '$BASE' | Where-Object { `$_.Name -ne '.templates' } | Select-Object -ExpandProperty Name } else { @() }
    (`$opts + `$profiles) | Where-Object { `$_ -like "`$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new(`$_, `$_, 'ParameterValue', `$_)
    }
}
"@
    } else {
        Write-Host "Only 'powershell' completion is supported on Windows."
    }
}

# =============================================================================
# MAIN DISPATCH
# Route the user's command to the right function.
# =============================================================================

switch ($cmd) {
    "new" {
        $extra = @()
        if ($arg2)       { $extra += $arg2 }
        if ($ForwardArgs) { $extra += $ForwardArgs }
        Invoke-NewProfile $arg1 $extra
    }
    "list" {
        Invoke-ListProfiles
    }
    "status" {
        Invoke-StatusProfiles
    }
    "rename" {
        Invoke-RenameProfile $arg1 $arg2
    }
    "delete" {
        Invoke-DeleteProfile $arg1
    }
    "clone" {
        Invoke-CloneProfile $arg1 $arg2
    }
    "template" {
        Invoke-TemplateCmd $arg1 $arg2 ($ForwardArgs | Select-Object -First 1)
    }
    "export" {
        Invoke-ExportProfile $arg1 $arg2
    }
    "import" {
        Invoke-ImportProfile $arg1 $arg2
    }
    "update" {
        Invoke-UpdateCli
    }
    "doctor" {
        Invoke-DoctorCli
    }
    "stats" {
        Invoke-ProfileStats
    }
    "completion" {
        if ($arg1) {
            Invoke-GenerateCompletion $arg1
        } else {
            Invoke-HelpCompletion
        }
    }
    "help"   { Write-Usage }
    "--help" { Write-Usage }
    "-h"     { Write-Usage }
    "version"   { Write-Host "multi-codex $VERSION" }
    "--version" { Write-Host "multi-codex $VERSION" }
    "-v"        { Write-Host "multi-codex $VERSION" }
    "" {
        Write-Usage
        exit 1
    }
    default {
        # If the command doesn't match any built-in, treat it as a profile name.
        $AllArgs = @()
        if ($arg1)       { $AllArgs += $arg1 }
        if ($arg2)       { $AllArgs += $arg2 }
        if ($ForwardArgs) { $AllArgs += $ForwardArgs }
        Invoke-LaunchProfile $cmd $AllArgs
    }
}
