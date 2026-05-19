<#
.SYNOPSIS
  Uninstall multi-cli from Windows.
#>

$ErrorActionPreference = 'Stop'

$InstallDir = if ($env:MULTICLI_INSTALL_DIR) { $env:MULTICLI_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'multi-cli' }
$BinDir     = if ($env:MULTICLI_BIN_DIR)     { $env:MULTICLI_BIN_DIR }     else { Join-Path $env:LOCALAPPDATA 'multi-cli\bin' }
$ProfileDir = if ($env:MULTICLI_HOME)        { $env:MULTICLI_HOME }        else { Join-Path $env:USERPROFILE 'MultiCliProfiles' }

Write-Host "multi-cli uninstaller (Windows)"
Write-Host ""

foreach ($cmd in @('multi-cli.cmd')) {
    $p = Join-Path $BinDir $cmd
    if (Test-Path $p) { Remove-Item -Force $p; Write-Host "Removed $p" }
}

$userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
if ($userPath -like "*$BinDir*") {
    $newPath = ($userPath -split ';' | Where-Object { $_ -ne $BinDir }) -join ';'
    [Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
    Write-Host "Removed $BinDir from user PATH"
}

if ((Test-Path $InstallDir) -and ($InstallDir -ne (Split-Path -Parent $MyInvocation.MyCommand.Definition))) {
    $confirm = Read-Host "Remove install directory $InstallDir? [y/N]"
    if ($confirm -match '^[Yy]$') {
        Remove-Item -Recurse -Force $InstallDir
        Write-Host "Removed $InstallDir"
    }
}

if (Test-Path $ProfileDir) {
    $confirm = Read-Host "Remove all profiles at $ProfileDir? [y/N]"
    if ($confirm -match '^[Yy]$') {
        Remove-Item -Recurse -Force $ProfileDir
        Write-Host "Removed $ProfileDir"
    } else {
        Write-Host "Profiles kept at $ProfileDir"
    }
}

$smDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
$links = Get-ChildItem -Path $smDir -Filter 'multi-cli *.lnk' -ErrorAction SilentlyContinue
foreach ($l in $links) { Remove-Item -Force $l.FullName; Write-Host "Removed shortcut: $($l.Name)" }

Write-Host ""
Write-Host "multi-cli uninstalled."
