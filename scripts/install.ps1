<#
.SYNOPSIS
  Install multi-cli on Windows.
.PARAMETER Local
  Install from the current directory instead of cloning.
#>
param(
    [switch]$Local
)

$ErrorActionPreference = 'Stop'

$RepoUrl    = if ($env:MULTICLI_REPO)        { $env:MULTICLI_REPO }        else { 'https://github.com/Spielewoy/multi-codex.git' }
$InstallDir = if ($env:MULTICLI_INSTALL_DIR)  { $env:MULTICLI_INSTALL_DIR }  else { Join-Path $env:LOCALAPPDATA 'multi-cli' }
$BinDir     = if ($env:MULTICLI_BIN_DIR)      { $env:MULTICLI_BIN_DIR }      else { Join-Path $env:LOCALAPPDATA 'multi-cli\bin' }

Write-Host "multi-cli installer (Windows)"
Write-Host ""

if ($Local) {
    $InstallDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)
    Write-Host "Installing from local directory: $InstallDir"
} else {
    if ($RepoUrl -match '<owner>') {
        Write-Host "Error: MULTICLI_REPO is not set. Set it to the git clone URL." -ForegroundColor Red
        Write-Host '  $env:MULTICLI_REPO = "https://github.com/youruser/multi-cli"'
        exit 1
    }
    Write-Host "Cloning from $RepoUrl ..."
    if (Test-Path $InstallDir) {
        git -C $InstallDir pull --ff-only
    } else {
        New-Item -ItemType Directory -Force -Path (Split-Path $InstallDir) | Out-Null
        git clone $RepoUrl $InstallDir
    }
}

New-Item -ItemType Directory -Force -Path $BinDir | Out-Null

$wrapperPath = Join-Path $BinDir 'multi-cli.cmd'
$scriptPath  = Join-Path $InstallDir 'multi-cli.ps1'
@"
@echo off
powershell.exe -ExecutionPolicy Bypass -File "$scriptPath" %*
"@ | Set-Content -Path $wrapperPath -Encoding ASCII

$shim = Join-Path $BinDir 'multi-cli.cmd'
if (Test-Path (Join-Path $InstallDir 'multi-cli.ps1')) {
@"
@echo off
powershell.exe -ExecutionPolicy Bypass -File "$(Join-Path $InstallDir 'multi-cli.ps1')" %*
"@ | Set-Content -Path $shim -Encoding ASCII
}

Write-Host ""
Write-Host "Installed multi-cli to $InstallDir"
Write-Host "Command wrapper at $wrapperPath"

$userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
if ($userPath -notlike "*$BinDir*") {
    Write-Host ""
    Write-Host "Adding $BinDir to user PATH ..."
    [Environment]::SetEnvironmentVariable('PATH', "$BinDir;$userPath", 'User')
    $env:PATH = "$BinDir;$env:PATH"
    Write-Host "Done. Restart your terminal for PATH changes to take effect."
} else {
    Write-Host "$BinDir is already in PATH."
}

$ProfilesBinDir = if ($env:MULTICLI_HOME) { Join-Path $env:MULTICLI_HOME 'bin' } else { Join-Path $env:USERPROFILE 'MultiCliProfiles\bin' }
$userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
if ($userPath -notlike "*$ProfilesBinDir*") {
    Write-Host ""
    Write-Host "Adding $ProfilesBinDir to user PATH ..."
    [Environment]::SetEnvironmentVariable('PATH', "$ProfilesBinDir;$userPath", 'User')
    $env:PATH = "$ProfilesBinDir;$env:PATH"
    Write-Host "Done. Profile aliases will be available after terminal restart."
} else {
    Write-Host "$ProfilesBinDir is already in PATH."
}

Write-Host ""
Write-Host "Run 'multi-cli doctor' to verify your setup."
