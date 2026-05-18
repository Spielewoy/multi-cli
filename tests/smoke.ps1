<#
.SYNOPSIS
  Real launch smoke tests for every supported tool detected on this machine.

.DESCRIPTION
  For each adapter:
    1. Skip if binary not detected.
    2. Create a throwaway profile <tool>/smoketest.
    3. Try to run the binary with `--version` (or other adapter.versionCommand).
    4. Verify EITHER the version printed cleanly, OR the profile directory
       was written to during the run (proves isolation took effect even if
       the tool went interactive / windowed).
    5. Delete the profile.

  Exits non-zero if any installed tool fails. Tools that aren't installed
  are reported as SKIP and don't fail the run.
#>

param(
    [string[]]$Only = @(),
    [switch]$KeepProfiles
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoRoot  = Split-Path -Parent $ScriptDir
$Cli       = Join-Path $RepoRoot 'multi-cli.ps1'
$ToolsDir  = Join-Path $RepoRoot 'tools'

function Invoke-Cli {
    param([string[]]$CliArgs)
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Cli @CliArgs 2>&1
}

function Get-ProfileDir {
    param([string]$Tool, [string]$Name)
    $base = if ($env:MULTICLI_HOME) { $env:MULTICLI_HOME } else { Join-Path $env:USERPROFILE 'MultiCliProfiles' }
    return Join-Path (Join-Path $base $Tool) $Name
}

function Get-Adapters {
    Get-ChildItem -Directory -Path $ToolsDir | ForEach-Object {
        $manifest = Join-Path $_.FullName 'adapter.json'
        if (Test-Path $manifest) {
            $a = Get-Content $manifest -Raw | ConvertFrom-Json
            if ($Only -and ($Only -notcontains $a.id)) { return }
            $a
        }
    }
}

function Test-BinaryDetected {
    param($Adapter)
    $out = Invoke-Cli @('tools') | Out-String
    return ($out -match "(?m)^\s+$([regex]::Escape($Adapter.id))\s+\S+\s+\S+\s+\S+\s+yes")
}

$results = @()
$smoke   = 'smoketest'

foreach ($a in (Get-Adapters | Sort-Object id)) {
    Write-Host ""
    Write-Host "=== $($a.id) ($($a.displayName)) ===" -ForegroundColor Cyan

    if (-not (Test-BinaryDetected $a)) {
        Write-Host "  SKIP -- binary not detected on this machine" -ForegroundColor DarkGray
        $results += [pscustomobject]@{ Tool = $a.id; Result = 'SKIP'; Detail = 'binary not detected' }
        continue
    }

    $spec = "$($a.id)/$smoke"
    $profileDir = Get-ProfileDir $a.id $smoke

    if (Test-Path $profileDir) {
        Write-Host "  cleanup: removing leftover profile dir" -ForegroundColor DarkGray
        Remove-Item -Recurse -Force $profileDir
    }

    Write-Host "  step 1: create profile $spec"
    $createOut = Invoke-Cli @('new', $spec)
    if (-not (Test-Path $profileDir)) {
        Write-Host "  FAIL -- profile dir not created" -ForegroundColor Red
        Write-Host "  output: $createOut"
        $results += [pscustomobject]@{ Tool = $a.id; Result = 'FAIL'; Detail = "create did not produce dir" }
        continue
    }
    $createdAt = (Get-Item $profileDir).LastWriteTime
    Start-Sleep -Milliseconds 200

    Write-Host "  step 2: launch with --version (8s timeout)"
    $versionFlag = if ($a.versionCommand) { $a.versionCommand[0] } else { '--version' }

    $job = Start-Job -ScriptBlock {
        param($cli, $spec, $flag)
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $cli launch $spec $flag 2>&1
    } -ArgumentList $Cli, $spec, $versionFlag

    $finished = Wait-Job $job -Timeout 8
    $output   = Receive-Job $job -ErrorAction SilentlyContinue
    if (-not $finished) {
        Stop-Job $job -ErrorAction SilentlyContinue
        $output = @($output) + '[killed after 8s -- expected for GUI tools]'
    }
    Remove-Job $job -Force -ErrorAction SilentlyContinue

    Write-Host "  step 3: verify isolation"
    $items = Get-ChildItem -Recurse -Force -Path $profileDir -ErrorAction SilentlyContinue |
             Where-Object { $_.LastWriteTime -gt $createdAt -and $_.Name -notmatch '^(_home|extensions|\.cli|\.shared)$' }
    $touched = @($items).Count
    $printedVersion = ($output -match '\d+\.\d+')

    if ($printedVersion -or $touched -gt 0) {
        $detail = if ($printedVersion) { "version printed; $touched extra files written" } else { "$touched files written into profile dir (isolation verified)" }
        Write-Host "  PASS -- $detail" -ForegroundColor Green
        $results += [pscustomobject]@{ Tool = $a.id; Result = 'PASS'; Detail = $detail }
    } else {
        Write-Host "  FAIL -- no version output and no profile dir writes detected" -ForegroundColor Red
        Write-Host "  output preview: $(($output | Out-String).Substring(0, [Math]::Min(200, ($output | Out-String).Length)))"
        $results += [pscustomobject]@{ Tool = $a.id; Result = 'FAIL'; Detail = 'no isolation evidence' }
    }

    Write-Host "  step 4: cleanup"
    if (-not $KeepProfiles) {
        if (Test-Path $profileDir) { Remove-Item -Recurse -Force $profileDir -ErrorAction SilentlyContinue }
        $aliasFile = Join-Path (Join-Path $env:USERPROFILE 'MultiCliProfiles\bin') "$($a.id)-$smoke.cmd"
        if (Test-Path $aliasFile) { Remove-Item -Force $aliasFile -ErrorAction SilentlyContinue }
        $shortcut = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\multi-cli $($a.id) $smoke.lnk"
        if (Test-Path $shortcut) { Remove-Item -Force $shortcut -ErrorAction SilentlyContinue }
    }
}

Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
foreach ($r in $results) {
    $color = switch ($r.Result) { 'PASS' { 'Green' } 'FAIL' { 'Red' } default { 'DarkGray' } }
    Write-Host ("  {0,-18} {1,-6} {2}" -f $r.Tool, $r.Result, $r.Detail) -ForegroundColor $color
}

$failures = ($results | Where-Object { $_.Result -eq 'FAIL' }).Count
if ($failures -gt 0) {
    Write-Host ""
    Write-Host "$failures failure(s)." -ForegroundColor Red
    exit 1
}
Write-Host ""
Write-Host "All installed tools passed." -ForegroundColor Green
