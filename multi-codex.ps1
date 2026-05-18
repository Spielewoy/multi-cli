<#
.SYNOPSIS
  multi-codex.ps1 -- backward-compatible shim for multi-cli.ps1
.DESCRIPTION
  Delegates all arguments to: multi-cli.ps1 with codex as the tool prefix.
  If the first arg contains '/', treat it as a full spec (codex/name).
  Otherwise, rewrite bare profile names to codex/<name>.
#>

param(
    [Parameter(Position = 0, Mandatory = $false)]
    [string]$Cmd,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Rest
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$Launcher  = Join-Path $ScriptDir 'multi-cli.ps1'

$managementCmds = @('help','--help','-h','version','--version','-v','tools','doctor','stats','completion','template')

if (-not $Cmd) {
    & powershell.exe -ExecutionPolicy Bypass -File $Launcher help
    exit 0
}

if ($managementCmds -contains $Cmd) {
    & powershell.exe -ExecutionPolicy Bypass -File $Launcher $Cmd @Rest
    exit $LASTEXITCODE
}

$profileCmds = @('new','launch','delete','rename','clone','export','import','list','status')
if ($profileCmds -contains $Cmd) {
    $newRest = @()
    $first = $true
    foreach ($a in $Rest) {
        if ($first -and $a -notmatch '/') {
            $newRest += "codex/$a"
        } else {
            $newRest += $a
        }
        $first = $false
    }
    & powershell.exe -ExecutionPolicy Bypass -File $Launcher $Cmd @newRest
    exit $LASTEXITCODE
}

if ($Cmd -notmatch '/') {
    $Cmd = "codex/$Cmd"
}
& powershell.exe -ExecutionPolicy Bypass -File $Launcher $Cmd @Rest
exit $LASTEXITCODE
