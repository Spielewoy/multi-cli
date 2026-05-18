<#
.SYNOPSIS
  multi-cli.ps1 -- Run multiple sandboxed profiles of any supported AI CLI or IDE.

.DESCRIPTION
  Adapter-driven launcher: each supported tool (codex, claude-cli, claude-desktop,
  cursor, antigravity, opencode, commandcode, gemini-cli) ships an adapter.json
  describing how to find its binary and how to isolate its state. multi-cli reads
  the adapter and applies one of four isolation strategies: env, userDataDir,
  redirectHome, or appdata.

  USAGE
    multi-cli new <tool>/<name>      Create a new profile
    multi-cli launch <tool>/<name>   Launch the profile (binary args after `--`)
    multi-cli list                   List all profiles
    multi-cli tools                  List supported tools and detect installs
    multi-cli doctor                 Diagnose environment
    multi-cli help                   Full command reference
#>

param (
    [Parameter(Position = 0, Mandatory = $false)]
    [string]$Cmd,

    [Parameter(Position = 1, Mandatory = $false)]
    [string]$Arg1,

    [Parameter(Position = 2, Mandatory = $false)]
    [string]$Arg2,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ForwardArgs
)

$ErrorActionPreference = 'Stop'
$VERSION = '0.1.0'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ToolsDir  = Join-Path $ScriptDir 'tools'
$BASE = if ($env:MULTICLI_HOME) { $env:MULTICLI_HOME } else { Join-Path $env:USERPROFILE 'MultiCliProfiles' }

# =============================================================================
# Adapter loading
# =============================================================================

function Get-Adapters {
    if (-not (Test-Path $ToolsDir)) { return @() }
    $adapters = @()
    foreach ($dir in Get-ChildItem -Directory -Path $ToolsDir) {
        $manifest = Join-Path $dir.FullName 'adapter.json'
        if (Test-Path $manifest) {
            try {
                $adapters += (Get-Content $manifest -Raw | ConvertFrom-Json)
            } catch {
                Write-Warning "Skipping invalid adapter at $manifest : $_"
            }
        }
    }
    return $adapters
}

function Get-Adapter {
    param([string]$ToolId)
    $manifest = Join-Path (Join-Path $ToolsDir $ToolId) 'adapter.json'
    if (-not (Test-Path $manifest)) { throw "Unknown tool '$ToolId'. Run: multi-cli tools" }
    return Get-Content $manifest -Raw | ConvertFrom-Json
}

function Resolve-PathToken {
    param([string]$Path)
    if (-not $Path) { return $Path }
    $expanded = $Path -replace '\$HOME', $env:USERPROFILE.Replace('\', '\\')
    return [Environment]::ExpandEnvironmentVariables($expanded)
}

function Find-AdapterBinary {
    param($Adapter)
    if ($env:MULTICLI_OVERRIDE_BINARY) { return $env:MULTICLI_OVERRIDE_BINARY }
    $candidates = @()
    if ($Adapter.binary.windows) { $candidates += $Adapter.binary.windows }
    foreach ($c in $candidates) {
        $resolved = Resolve-PathToken $c
        if (Test-Path $resolved -ErrorAction SilentlyContinue) { return $resolved }
        $cmd = Get-Command $resolved -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    return $null
}

# =============================================================================
# Profile addressing
# =============================================================================

function Split-ProfileSpec {
    param([string]$Spec)
    if (-not $Spec) { throw "Profile required: <tool>/<name>" }
    if ($Spec -notmatch '/') { throw "Profile must be in form <tool>/<name>. Got: '$Spec'" }
    $parts = $Spec.Split('/', 2)
    return [pscustomobject]@{ Tool = $parts[0]; Name = $parts[1] }
}

function Test-ProfileName {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { throw "Profile name required" }
    if ($Name -notmatch '^[a-zA-Z0-9][a-zA-Z0-9-]*$') {
        throw "Profile name '$Name' invalid: must start with alphanumeric, contain only letters/numbers/hyphens"
    }
}

function Get-ProfileDir { param([string]$Tool,[string]$Name) Join-Path (Join-Path $BASE $Tool) $Name }
function Get-ToolProfilesDir { param([string]$Tool) Join-Path $BASE $Tool }
function Get-AliasDir { Join-Path $BASE 'bin' }
function Get-TemplatesDir { Join-Path $BASE '.templates' }

# =============================================================================
# Profile CRUD
# =============================================================================

function New-Profile {
    param([string]$Spec, [bool]$Shared = $false, [bool]$Cli = $false, [string]$FromTemplate = '')

    $p = Split-ProfileSpec $Spec
    Test-ProfileName $p.Name
    $adapter = Get-Adapter $p.Tool
    $profileDir = Get-ProfileDir $p.Tool $p.Name

    if (Test-Path $profileDir) { throw "Profile '$Spec' already exists" }
    New-Item -ItemType Directory -Force -Path (Get-ToolProfilesDir $p.Tool) | Out-Null

    if ($FromTemplate) {
        $tplDir = Join-Path (Get-TemplatesDir) $FromTemplate
        if (-not (Test-Path $tplDir)) { throw "Template '$FromTemplate' not found" }
        Copy-Item -Path $tplDir -Destination $profileDir -Recurse
    } elseif ($Shared) {
        New-SharedProfile -Adapter $adapter -ProfileDir $profileDir
    } else {
        New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
    }

    if ($adapter.isolation.strategy -eq 'redirectHome') {
        $homeDir = Join-Path $profileDir '_home'
        New-Item -ItemType Directory -Force -Path $homeDir | Out-Null
        Set-RedirectHomeDotfileLinks -Adapter $adapter -HomeDir $homeDir
    }

    if ($Cli) { New-Item -ItemType File -Force -Path (Join-Path $profileDir '.cli') | Out-Null }

    New-AliasScript -Tool $p.Tool -Name $p.Name
    New-StartMenuShortcut -Tool $p.Tool -Name $p.Name -Adapter $adapter | Out-Null

    Write-Host "Created profile $Spec ($($adapter.displayName), strategy=$($adapter.isolation.strategy))"
    if (-not (Test-AliasDirInPath)) {
        Write-Host ""
        Write-Host "Tip: add $(Get-AliasDir) to PATH to use '$($p.Tool)-$($p.Name)' as a command."
    }
}

function New-SharedProfile {
    param($Adapter, [string]$ProfileDir)
    New-Item -ItemType Directory -Force -Path $ProfileDir | Out-Null
    New-Item -ItemType File -Force -Path (Join-Path $ProfileDir '.shared') | Out-Null
    if (-not $Adapter.share -or -not $Adapter.share.systemHome) { return }

    $sysHome = Resolve-PathToken $Adapter.share.systemHome
    if (-not (Test-Path $sysHome)) { return }

    foreach ($entry in @($Adapter.share.linkable)) {
        if (-not $entry) { continue }
        $src = Join-Path $sysHome $entry
        $dst = Join-Path $ProfileDir $entry
        if ((Test-Path $src) -and (-not (Test-Path $dst))) {
            try {
                New-Item -ItemType SymbolicLink -Path $dst -Target $src -ErrorAction Stop | Out-Null
            } catch {
                Write-Warning "Could not symlink $entry (Developer Mode may be required). Falling back to copy."
                Copy-Item -Path $src -Destination $dst -Recurse -ErrorAction SilentlyContinue
            }
        }
    }
}

function Set-RedirectHomeDotfileLinks {
    param($Adapter, [string]$HomeDir)
    if (-not $Adapter.isolation.shareFromRealHome) { return }
    foreach ($entry in @($Adapter.isolation.shareFromRealHome)) {
        if (-not $entry) { continue }
        $src = Join-Path $env:USERPROFILE $entry
        $dst = Join-Path $HomeDir $entry
        if ((Test-Path $src) -and (-not (Test-Path $dst))) {
            try {
                New-Item -ItemType SymbolicLink -Path $dst -Target $src -ErrorAction Stop | Out-Null
            } catch {
                Write-Warning "Could not symlink shared dotfile $entry."
            }
        }
    }
}

function Remove-Profile {
    param([string]$Spec)
    $p = Split-ProfileSpec $Spec
    Test-ProfileName $p.Name
    $profileDir = Get-ProfileDir $p.Tool $p.Name
    if (-not (Test-Path $profileDir)) { throw "Profile '$Spec' does not exist" }

    $confirm = Read-Host "Delete profile '$Spec' and all its data? [y/N]"
    if ($confirm -notmatch '^[Yy]$') { Write-Host "Aborted."; return }

    Remove-Item -Recurse -Force $profileDir
    Remove-AliasScript -Tool $p.Tool -Name $p.Name
    Remove-StartMenuShortcut -Tool $p.Tool -Name $p.Name
    Write-Host "Deleted profile '$Spec'"
}

function Rename-Profile {
    param([string]$OldSpec, [string]$NewSpec)
    $a = Split-ProfileSpec $OldSpec
    $b = Split-ProfileSpec $NewSpec
    if ($a.Tool -ne $b.Tool) { throw "Cannot rename across tools" }
    Test-ProfileName $a.Name
    Test-ProfileName $b.Name
    $oldDir = Get-ProfileDir $a.Tool $a.Name
    $newDir = Get-ProfileDir $b.Tool $b.Name
    if (-not (Test-Path $oldDir)) { throw "Profile '$OldSpec' does not exist" }
    if (Test-Path $newDir) { throw "Profile '$NewSpec' already exists" }
    Rename-Item -Path $oldDir -NewName $b.Name
    Remove-AliasScript -Tool $a.Tool -Name $a.Name
    Remove-StartMenuShortcut -Tool $a.Tool -Name $a.Name
    New-AliasScript -Tool $b.Tool -Name $b.Name
    New-StartMenuShortcut -Tool $b.Tool -Name $b.Name -Adapter (Get-Adapter $b.Tool) | Out-Null
    Write-Host "Renamed '$OldSpec' to '$NewSpec'"
}

function Copy-ProfileTo {
    param([string]$SrcSpec, [string]$DestSpec)
    $a = Split-ProfileSpec $SrcSpec
    $b = Split-ProfileSpec $DestSpec
    if ($a.Tool -ne $b.Tool) { throw "Cannot clone across tools" }
    Test-ProfileName $a.Name
    Test-ProfileName $b.Name
    $srcDir  = Get-ProfileDir $a.Tool $a.Name
    $destDir = Get-ProfileDir $b.Tool $b.Name
    if (-not (Test-Path $srcDir)) { throw "Source profile '$SrcSpec' does not exist" }
    if (Test-Path $destDir) { throw "Destination profile '$DestSpec' already exists" }
    Copy-Item -Path $srcDir -Destination $destDir -Recurse
    New-AliasScript -Tool $b.Tool -Name $b.Name
    New-StartMenuShortcut -Tool $b.Tool -Name $b.Name -Adapter (Get-Adapter $b.Tool) | Out-Null
    Write-Host "Cloned '$SrcSpec' to '$DestSpec'"
}

# =============================================================================
# Aliases & shortcuts
# =============================================================================

function New-AliasScript {
    param([string]$Tool, [string]$Name)
    $aliasDir = Get-AliasDir
    New-Item -ItemType Directory -Force -Path $aliasDir | Out-Null
    $aliasPath = Join-Path $aliasDir "$Tool-$Name.cmd"
    $scriptPath = $MyInvocation.MyCommand.Definition
    if (-not $scriptPath) { $scriptPath = $PSCommandPath }
@"
@echo off
powershell.exe -ExecutionPolicy Bypass -File "$scriptPath" launch $Tool/$Name %*
"@ | Set-Content -Path $aliasPath -Encoding ASCII
}

function Remove-AliasScript {
    param([string]$Tool, [string]$Name)
    $aliasPath = Join-Path (Get-AliasDir) "$Tool-$Name.cmd"
    if (Test-Path $aliasPath) { Remove-Item -Force $aliasPath }
}

function Test-AliasDirInPath {
    $dir = Get-AliasDir
    return ($env:PATH -split ';') -contains $dir
}

function New-StartMenuShortcut {
    param([string]$Tool, [string]$Name, $Adapter)
    try {
        $linkName = "multi-cli $Tool $Name.lnk"
        $linkPath = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\$linkName"
        $WshShell = New-Object -ComObject WScript.Shell
        $shortcut = $WshShell.CreateShortcut($linkPath)
        $shortcut.TargetPath = 'powershell.exe'
        $scriptPath = $MyInvocation.MyCommand.Definition
        if (-not $scriptPath) { $scriptPath = $PSCommandPath }
        $shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$scriptPath`" launch $Tool/$Name"
        $shortcut.Save()
        return $linkPath
    } catch {
        Write-Warning "Could not create Start Menu shortcut for ${Tool}/${Name}: $_"
        return $null
    }
}

function Remove-StartMenuShortcut {
    param([string]$Tool, [string]$Name)
    $linkPath = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\multi-cli $Tool $Name.lnk"
    if (Test-Path $linkPath) { Remove-Item -Force $linkPath }
}

# =============================================================================
# Launch -- strategy dispatch
# =============================================================================

function Invoke-Launch {
    param([string]$Spec, [string[]]$BinaryArgs = @())
    $p = Split-ProfileSpec $Spec
    $adapter = Get-Adapter $p.Tool
    $profileDir = Get-ProfileDir $p.Tool $p.Name
    if (-not (Test-Path $profileDir)) { throw "Profile '$Spec' does not exist. Create with: multi-cli new $Spec" }

    $binary = Find-AdapterBinary $adapter
    if (-not $binary) {
        $hint = if ($adapter.install) { " ($($adapter.install))" } else { '' }
        throw "$($adapter.displayName) binary not found.$hint"
    }

    Write-Host "Launching $($adapter.displayName) profile '$Spec' [$($adapter.isolation.strategy)]"

    switch ($adapter.isolation.strategy) {
        'env'           { Invoke-LaunchEnv          -Adapter $adapter -ProfileDir $profileDir -Binary $binary -BinaryArgs $BinaryArgs }
        'userDataDir'   { Invoke-LaunchUserDataDir  -Adapter $adapter -ProfileDir $profileDir -Binary $binary -BinaryArgs $BinaryArgs }
        'redirectHome'  { Invoke-LaunchRedirectHome -Adapter $adapter -ProfileDir $profileDir -Binary $binary -BinaryArgs $BinaryArgs }
        'appdata'       { Invoke-LaunchAppData      -Adapter $adapter -ProfileDir $profileDir -Binary $binary -BinaryArgs $BinaryArgs }
        default         { throw "Unknown isolation strategy '$($adapter.isolation.strategy)' for $($adapter.id)" }
    }
}

function Expand-Placeholder {
    param([string]$Value, [string]$ProfileDir)
    return $Value.Replace('{profileDir}', $ProfileDir)
}

function Invoke-LaunchEnv {
    param($Adapter, [string]$ProfileDir, [string]$Binary, [string[]]$BinaryArgs)
    $envMap = @{}
    foreach ($prop in $Adapter.isolation.env.PSObject.Properties) {
        $envMap[$prop.Name] = (Expand-Placeholder $prop.Value $ProfileDir)
    }
    Start-WithEnv -Binary $Binary -BinaryArgs $BinaryArgs -EnvMap $envMap
}

function Invoke-LaunchUserDataDir {
    param($Adapter, [string]$ProfileDir, [string]$Binary, [string[]]$BinaryArgs)
    $argsList = @()
    foreach ($a in @($Adapter.isolation.args)) { $argsList += (Expand-Placeholder $a $ProfileDir) }
    if ($BinaryArgs) { $argsList += $BinaryArgs }
    & $Binary @argsList
}

function Invoke-LaunchRedirectHome {
    param($Adapter, [string]$ProfileDir, [string]$Binary, [string[]]$BinaryArgs)
    $homeDir = Join-Path $ProfileDir '_home'
    if (-not (Test-Path $homeDir)) { New-Item -ItemType Directory -Force -Path $homeDir | Out-Null }
    Set-RedirectHomeDotfileLinks -Adapter $Adapter -HomeDir $homeDir
    $appdata     = Join-Path $homeDir 'AppData\Roaming'
    $localApp    = Join-Path $homeDir 'AppData\Local'
    New-Item -ItemType Directory -Force -Path $appdata  | Out-Null
    New-Item -ItemType Directory -Force -Path $localApp | Out-Null
    Start-WithEnv -Binary $Binary -BinaryArgs $BinaryArgs -EnvMap @{
        USERPROFILE  = $homeDir
        HOME         = $homeDir
        HOMEDRIVE    = $homeDir.Substring(0, 2)
        HOMEPATH     = $homeDir.Substring(2)
        APPDATA      = $appdata
        LOCALAPPDATA = $localApp
    }
}

function Invoke-LaunchAppData {
    param($Adapter, [string]$ProfileDir, [string]$Binary, [string[]]$BinaryArgs)
    $appdata = Join-Path $ProfileDir 'AppData\Roaming'
    New-Item -ItemType Directory -Force -Path $appdata | Out-Null
    Start-WithEnv -Binary $Binary -BinaryArgs $BinaryArgs -EnvMap @{ APPDATA = $appdata }
}

function Start-WithEnv {
    param([string]$Binary, [string[]]$BinaryArgs, [hashtable]$EnvMap)
    $original = @{}
    foreach ($k in $EnvMap.Keys) {
        $original[$k] = [Environment]::GetEnvironmentVariable($k, 'Process')
        [Environment]::SetEnvironmentVariable($k, $EnvMap[$k], 'Process')
    }
    try {
        if ($BinaryArgs -and $BinaryArgs.Count -gt 0) { & $Binary @BinaryArgs } else { & $Binary }
    } finally {
        foreach ($k in $original.Keys) {
            [Environment]::SetEnvironmentVariable($k, $original[$k], 'Process')
        }
    }
}

# =============================================================================
# Listings & diagnostics
# =============================================================================

function Get-FolderSize {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return '0 B' }
    $size = (Get-ChildItem $Path -Recurse -Force -ErrorAction SilentlyContinue |
             Measure-Object -Property Length -Sum).Sum
    if (-not $size) { $size = 0 }
    if ($size -ge 1GB) { '{0:N2} GB' -f ($size / 1GB) }
    elseif ($size -ge 1MB) { '{0:N2} MB' -f ($size / 1MB) }
    elseif ($size -ge 1KB) { '{0:N2} KB' -f ($size / 1KB) }
    else { "$size B" }
}

function Show-List {
    param([string]$ToolFilter)
    if (-not (Test-Path $BASE)) { Write-Host "No profiles yet."; return }
    $tools = Get-ChildItem -Directory -Path $BASE | Where-Object { $_.Name -notmatch '^\.' -and $_.Name -ne 'bin' }
    if ($ToolFilter) { $tools = $tools | Where-Object { $_.Name -eq $ToolFilter } }
    foreach ($toolDir in $tools) {
        Write-Host ""
        Write-Host "[$($toolDir.Name)]" -ForegroundColor Cyan
        $profiles = Get-ChildItem -Directory -Path $toolDir.FullName -ErrorAction SilentlyContinue
        if (-not $profiles) { Write-Host "  (none)"; continue }
        foreach ($prof in $profiles) {
            $type = if (Test-Path (Join-Path $prof.FullName '.cli')) { 'cli' }
                    elseif (Test-Path (Join-Path $prof.FullName '.shared')) { 'shared' }
                    else { 'full' }
            Write-Host ("  {0,-20} {1,-8} {2}" -f $prof.Name, $type, (Get-FolderSize $prof.FullName))
        }
    }
}

function Show-Tools {
    Write-Host "Supported tools:"
    Write-Host ""
    Write-Host ("  {0,-18} {1,-12} {2,-15} {3,-10} {4}" -f 'TOOL', 'KIND', 'STRATEGY', 'STATUS', 'INSTALLED')
    Write-Host ("  {0,-18} {1,-12} {2,-15} {3,-10} {4}" -f '----', '----', '--------', '------', '---------')
    foreach ($a in (Get-Adapters | Sort-Object id)) {
        $bin = Find-AdapterBinary $a
        $installed = if ($bin) { "yes" } else { 'no' }
        $color = if ($bin) { 'Green' } else { 'DarkGray' }
        $status = if ($a.status) { $a.status } else { '?' }
        Write-Host ("  {0,-18} {1,-12} {2,-15} {3,-10} {4}" -f $a.id, $a.kind, $a.isolation.strategy, $status, $installed) -ForegroundColor $color
    }
}

function Show-Doctor {
    $errors = 0; $warnings = 0
    Write-Host "multi-cli $VERSION  --  Windows"
    Write-Host ""
    Write-Host "Profile storage: $BASE"
    if (Test-Path $BASE) {
        try {
            $t = Join-Path $BASE '.write-test'
            New-Item -ItemType File -Path $t -Force | Out-Null
            Remove-Item $t -Force
            Write-Host "  [OK] writable" -ForegroundColor Green
        } catch { Write-Host "  [FAIL] not writable" -ForegroundColor Red; $errors++ }
    } else {
        Write-Host "  [INFO] not yet created (will be created on first profile)"
    }

    if (Test-AliasDirInPath) { Write-Host "Alias dir in PATH: yes" -ForegroundColor Green }
    else { Write-Host "Alias dir in PATH: no  ($((Get-AliasDir)) -- add to PATH for shorthand commands)" -ForegroundColor Yellow; $warnings++ }

    Write-Host ""
    Write-Host "Tools:"
    foreach ($a in (Get-Adapters | Sort-Object id)) {
        $bin = Find-AdapterBinary $a
        if ($bin) { Write-Host "  [OK]   $($a.id) -> $bin" -ForegroundColor Green }
        else {
            $hint = if ($a.install) { "  install: $($a.install)" } else { '' }
            Write-Host "  [MISS] $($a.id)$hint" -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    if ($errors -eq 0 -and $warnings -eq 0) { Write-Host "All good." -ForegroundColor Green }
    elseif ($errors -eq 0) { Write-Host "$warnings warning(s)." -ForegroundColor Yellow }
    else { Write-Host "$errors error(s), $warnings warning(s)." -ForegroundColor Red }
}

function Show-Stats {
    if (-not (Test-Path $BASE)) { Write-Host "No profiles yet."; return }
    Write-Host ("{0,-30} {1}" -f 'PROFILE', 'SIZE')
    foreach ($toolDir in Get-ChildItem -Directory -Path $BASE | Where-Object { $_.Name -notmatch '^\.' -and $_.Name -ne 'bin' }) {
        foreach ($p in Get-ChildItem -Directory -Path $toolDir.FullName -ErrorAction SilentlyContinue) {
            Write-Host ("{0,-30} {1}" -f "$($toolDir.Name)/$($p.Name)", (Get-FolderSize $p.FullName))
        }
    }
    Write-Host ""
    Write-Host "Total: $(Get-FolderSize $BASE)"
}

function Show-Status { Show-List }

# =============================================================================
# Templates / export / import
# =============================================================================

function Invoke-Template {
    param([string]$Sub, [string]$A, [string]$B)
    switch ($Sub) {
        'save' {
            if (-not $A -or -not $B) { throw "Usage: multi-cli template save <tool>/<profile> <name>" }
            $p = Split-ProfileSpec $A
            $srcDir = Get-ProfileDir $p.Tool $p.Name
            if (-not (Test-Path $srcDir)) { throw "Profile '$A' does not exist" }
            Test-ProfileName $B
            $tplDir = Get-TemplatesDir
            New-Item -ItemType Directory -Force -Path $tplDir | Out-Null
            $dest = Join-Path $tplDir $B
            if (Test-Path $dest) { throw "Template '$B' already exists" }
            Copy-Item -Path $srcDir -Destination $dest -Recurse
            foreach ($f in @('.shared', '.cli', 'auth.json', '.credentials.json', 'oauth_creds.json')) {
                $strip = Join-Path $dest $f
                if (Test-Path $strip) { Remove-Item -Recurse -Force $strip }
            }
            Write-Host "Saved template '$B' from '$A'"
        }
        'list' {
            $tplDir = Get-TemplatesDir
            Write-Host "Templates:"
            if (-not (Test-Path $tplDir)) { Write-Host "  (none)"; return }
            $items = Get-ChildItem -Directory -Path $tplDir
            if (-not $items) { Write-Host "  (none)"; return }
            foreach ($t in $items) { Write-Host ("  {0,-20} {1}" -f $t.Name, (Get-FolderSize $t.FullName)) }
        }
        'delete' {
            if (-not $A) { throw "Usage: multi-cli template delete <name>" }
            Test-ProfileName $A
            $dest = Join-Path (Get-TemplatesDir) $A
            if (-not (Test-Path $dest)) { throw "Template '$A' does not exist" }
            Remove-Item -Recurse -Force $dest
            Write-Host "Deleted template '$A'"
        }
        default { throw "Usage: multi-cli template <save|list|delete>" }
    }
}

function Invoke-Export {
    param([string]$Spec, [string]$OutPath)
    $p = Split-ProfileSpec $Spec
    $srcDir = Get-ProfileDir $p.Tool $p.Name
    if (-not (Test-Path $srcDir)) { throw "Profile '$Spec' does not exist" }
    if (-not $OutPath) { $OutPath = ".\$($p.Tool)-$($p.Name).zip" }
    Compress-Archive -Path $srcDir -DestinationPath $OutPath -Force
    Write-Host "Exported '$Spec' to $OutPath"
}

function Invoke-Import {
    param([string]$ArchivePath, [string]$Spec)
    if (-not (Test-Path $ArchivePath)) { throw "File not found: $ArchivePath" }
    if (-not $Spec) { throw "Usage: multi-cli import <archive> <tool>/<name>" }
    $p = Split-ProfileSpec $Spec
    Test-ProfileName $p.Name
    Get-Adapter $p.Tool | Out-Null
    $destDir = Get-ProfileDir $p.Tool $p.Name
    if (Test-Path $destDir) { throw "Profile '$Spec' already exists" }

    New-Item -ItemType Directory -Force -Path (Get-ToolProfilesDir $p.Tool) | Out-Null
    $tmp = Join-Path $env:TEMP "multicli_import_$(Get-Random)"
    Expand-Archive -Path $ArchivePath -DestinationPath $tmp -Force
    $top = Get-ChildItem -Directory -Path $tmp
    if ($top.Count -eq 1) {
        Move-Item -Path $top[0].FullName -Destination $destDir
        Remove-Item $tmp -Recurse -Force
    } else {
        Move-Item -Path $tmp -Destination $destDir
    }
    New-AliasScript -Tool $p.Tool -Name $p.Name
    New-StartMenuShortcut -Tool $p.Tool -Name $p.Name -Adapter (Get-Adapter $p.Tool) | Out-Null
    Write-Host "Imported '$Spec'"
}

# =============================================================================
# Help / completion
# =============================================================================

function Show-Help {
@"
multi-cli $VERSION -- sandboxed profiles for AI CLIs and agent IDEs

USAGE
  multi-cli <command> [args]

COMMANDS
  new <tool>/<name> [--shared] [--cli] [--from <tpl>]   Create a profile
  launch <tool>/<name> [-- args...]                     Launch the profile
  list [<tool>]                                         List profiles
  status                                                Same as list
  rename <tool>/<old> <tool>/<new>                      Rename
  delete <tool>/<name>                                  Delete (confirms)
  clone <tool>/<src> <tool>/<dest>                      Clone
  template save <tool>/<profile> <name>                 Save as template
  template list | delete <name>                         Manage templates
  export <tool>/<name> [path]                           Export to .zip
  import <archive> <tool>/<name>                        Import from .zip
  tools                                                 List supported tools
  doctor                                                Diagnose environment
  stats                                                 Storage usage
  completion powershell                                 Print completion script
  help | version                                        This / version

PROFILE SHORTHAND
  multi-cli <tool>/<name> [args...]   -- same as `launch`

ENVIRONMENT
  MULTICLI_HOME              Profile storage root (default ~/MultiCliProfiles)
  MULTICLI_OVERRIDE_BINARY   Override binary discovery for the next launch

EXAMPLES
  multi-cli new claude-cli/work
  multi-cli new cursor/personal --shared
  multi-cli launch codex/acme -- exec --search "fix the build"
  claude-cli-work          # via auto-generated alias on `$PATH

"@ | Write-Host
}

function Show-Completion {
    param([string]$Shell = 'powershell')
    if ($Shell -ne 'powershell') {
        Write-Host "Only 'powershell' completion is supported on Windows."
        return
    }
@"
Register-ArgumentCompleter -Native -CommandName multi-cli -ScriptBlock {
    param(`$wordToComplete, `$commandAst, `$cursorPosition)
    `$base = if (`$env:MULTICLI_HOME) { `$env:MULTICLI_HOME } else { Join-Path `$env:USERPROFILE 'MultiCliProfiles' }
    `$tools = (Get-ChildItem -Directory '$ScriptDir/tools' -ErrorAction SilentlyContinue).Name
    `$cmds = @('new','launch','list','status','rename','delete','clone','template','export','import','tools','doctor','stats','completion','help','version')
    `$specs = @()
    foreach (`$t in `$tools) {
        `$dir = Join-Path `$base `$t
        if (Test-Path `$dir) {
            foreach (`$p in (Get-ChildItem -Directory `$dir -ErrorAction SilentlyContinue)) {
                `$specs += "`$t/`$(`$p.Name)"
            }
        }
    }
    (`$cmds + `$tools + `$specs) | Where-Object { `$_ -like "`$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new(`$_, `$_, 'ParameterValue', `$_)
    }
}
"@ | Write-Host
}

# =============================================================================
# Main dispatch
# =============================================================================

function Split-LaunchArgs {
    param([string[]]$All)
    $idx = [Array]::IndexOf($All, '--')
    if ($idx -ge 0) {
        $pre = if ($idx -gt 0) { $All[0..($idx - 1)] } else { @() }
        $post = if ($idx + 1 -lt $All.Count) { $All[($idx + 1)..($All.Count - 1)] } else { @() }
        return [pscustomobject]@{ Pre = $pre; Post = $post; HadDelim = $true }
    }
    return [pscustomobject]@{ Pre = $All; Post = @(); HadDelim = $false }
}

function Parse-NewFlags {
    param([string[]]$Tokens)
    $shared = $false; $cli = $false; $tpl = ''
    for ($i = 0; $i -lt $Tokens.Count; $i++) {
        switch ($Tokens[$i]) {
            '--shared' { $shared = $true }
            '--cli'    { $cli = $true }
            '--from'   { $i++; if ($i -lt $Tokens.Count) { $tpl = $Tokens[$i] } }
        }
    }
    return [pscustomobject]@{ Shared = $shared; Cli = $cli; FromTemplate = $tpl }
}

try {
    switch ($Cmd) {
        'new' {
            $tokens = @()
            if ($Arg2) { $tokens += $Arg2 }
            if ($ForwardArgs) { $tokens += $ForwardArgs }
            $flags = Parse-NewFlags $tokens
            New-Profile -Spec $Arg1 -Shared $flags.Shared -Cli $flags.Cli -FromTemplate $flags.FromTemplate
        }
        'launch' {
            $forward = @()
            if ($Arg2) { $forward += $Arg2 }
            if ($ForwardArgs) { $forward += $ForwardArgs }
            $split = Split-LaunchArgs $forward
            $passthrough = if ($split.HadDelim) { $split.Post } else { $split.Pre }
            Invoke-Launch -Spec $Arg1 -BinaryArgs $passthrough
        }
        'list'    { Show-List $Arg1 }
        'status'  { Show-Status }
        'rename'  { Rename-Profile $Arg1 $Arg2 }
        'delete'  { Remove-Profile $Arg1 }
        'clone'   { Copy-ProfileTo $Arg1 $Arg2 }
        'template' {
            $third = if ($ForwardArgs -and $ForwardArgs.Count -gt 0) { $ForwardArgs[0] } else { $null }
            Invoke-Template -Sub $Arg1 -A $Arg2 -B $third
        }
        'export'  { Invoke-Export $Arg1 $Arg2 }
        'import'  { Invoke-Import $Arg1 $Arg2 }
        'tools'   { Show-Tools }
        'doctor'  { Show-Doctor }
        'stats'   { Show-Stats }
        'completion' { Show-Completion ($(if ($Arg1) { $Arg1 } else { 'powershell' })) }
        'help'      { Show-Help }
        '--help'    { Show-Help }
        '-h'        { Show-Help }
        'version'   { Write-Host "multi-cli $VERSION" }
        '--version' { Write-Host "multi-cli $VERSION" }
        '-v'        { Write-Host "multi-cli $VERSION" }
        ''          { Show-Help; exit 1 }
        default {
            if ($Cmd -match '/') {
                $forward = @()
                if ($Arg1) { $forward += $Arg1 }
                if ($Arg2) { $forward += $Arg2 }
                if ($ForwardArgs) { $forward += $ForwardArgs }
                $split = Split-LaunchArgs $forward
                $passthrough = if ($split.HadDelim) { $split.Post } else { $split.Pre }
                Invoke-Launch -Spec $Cmd -BinaryArgs $passthrough
            } else {
                Write-Host "Unknown command: $Cmd"
                Show-Help
                exit 1
            }
        }
    }
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}
