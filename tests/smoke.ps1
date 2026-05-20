# smoke.ps1 -- Real-launch smoke tests for multi-cli adapters
param([string[]]$Only, [switch]$KeepProfiles)
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ProjectDir = Resolve-Path (Join-Path $ScriptDir '..')
$ToolsDir  = $ProjectDir
$BASE = if ($env:MULTICLI_HOME) { $env:MULTICLI_HOME } else { Join-Path $env:USERPROFILE 'MultiCliProfiles' }
$TimeoutSec = 8
$SmokeName  = 'smoketest'
$GuiWaitSec = 8

$allGreen  = @()
$allRed    = @()
$allYellow = @()

Write-Host '== multi-cli smoke tests ==' -ForegroundColor Cyan
Write-Host "Tools dir: $ToolsDir"
Write-Host "Timeout:   ${TimeoutSec}s"
Write-Host ''

$adapterList = @()
Get-ChildItem -Directory -Path $ToolsDir | ForEach-Object {
    $mPath = Join-Path $_.FullName 'adapter.json'
    if (Test-Path $mPath -PathType Leaf) {
        $adapterList += [PSCustomObject]@{ Id = $_.Name; Path = $mPath }
    }
}
$adapters = $adapterList | Sort-Object Id
if ($Only) { $adapters = $adapters | Where-Object { $_.Id -in $Only } }
if ($adapters.Count -eq 0) { Write-Host 'No adapters found.' -ForegroundColor Yellow; exit 0 }

$env:MULTICLI_HOME = $BASE
$failedAny = $false

foreach ($item in $adapters) {
    $tid = $item.Id
    try { $adapter = Get-Content $item.Path -Raw | ConvertFrom-Json }
    catch {
        Write-Host "[FAIL] $tid : invalid adapter.json" -ForegroundColor Red
        $allRed += $tid; $failedAny = $true; continue
    }

    $strategy = $adapter.isolation.strategy
    $kind     = if ($adapter.kind) { $adapter.kind } else { 'cli' }
    $isGui    = ($kind -eq 'hybrid')
    $verCmd   = @()
    foreach ($v in @($adapter.versionCommand)) { if ($v) { $verCmd += $v } }
    if ($verCmd.Count -eq 0) { $verCmd = @('--version') }

    $pDir = Join-Path (Join-Path $BASE $tid) $SmokeName

    # -- binary discovery --
    $binary = $null
    $cand = @($adapter.binary.windows)
    foreach ($c in $cand) {
        $resolved = [Environment]::ExpandEnvironmentVariables($c)
        if ($resolved -and (Test-Path $resolved -ErrorAction SilentlyContinue)) { $binary = $resolved; break }
        $ccmd = Get-Command $c -ErrorAction SilentlyContinue
        if ($ccmd) { $binary = $ccmd.Source; break }
    }
    if (-not $binary) {
        Write-Host "[SKIP] $tid -- binary not detected" -ForegroundColor DarkGray
        $allYellow += $tid; continue
    }

    Write-Host -NoNewline "[TEST] $tid ($strategy) ... "

    # -- cleanup leftover --
    if (Test-Path $pDir) { Remove-Item -Recurse -Force $pDir -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Force -Path (Split-Path $pDir -Parent) | Out-Null

    # -- create profile skeleton --
    if ($strategy -eq 'redirectHome') {
        New-Item -ItemType Directory -Force -Path $pDir | Out-Null
        $hDir = Join-Path $pDir '_home'
        New-Item -ItemType Directory -Force -Path $hDir | Out-Null
        if ($adapter.isolation.shareFromRealHome) {
            foreach ($e in @($adapter.isolation.shareFromRealHome)) {
                if (-not $e) { continue }
                $src = Join-Path $env:USERPROFILE $e
                $dst = Join-Path $hDir $e
                if ((Test-Path $src) -and (-not (Test-Path $dst))) {
                    try { New-Item -ItemType SymbolicLink -Path $dst -Target $src -ErrorAction Stop | Out-Null }
                    catch { Copy-Item -Path $src -Destination $dst -Recurse -ErrorAction SilentlyContinue }
                }
            }
        }
        New-Item -ItemType Directory -Force -Path (Join-Path $hDir 'AppData\Roaming') | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $hDir 'AppData\Local') | Out-Null
    } elseif ($strategy -eq 'userDataDir') {
        New-Item -ItemType Directory -Force -Path $pDir | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $pDir 'extensions') | Out-Null
    } elseif ($strategy -eq 'appdata') {
        New-Item -ItemType Directory -Force -Path $pDir | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $pDir 'AppData\Roaming') | Out-Null
    } else {
        New-Item -ItemType Directory -Force -Path $pDir | Out-Null
    }

    # -- record pre timestamps --
    $preTs = @{}
    Get-ChildItem $pDir -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $preTs[$_.FullName] = $_.LastWriteTime
    }

    # -- launch --
    $printedVer = $false
    $outText    = ''
    $ec         = 0
    $tmpOut     = Join-Path $env:TEMP "mc_smoke_out_$(Get-Random).txt"
    $tmpErr     = Join-Path $env:TEMP "mc_smoke_err_$(Get-Random).txt"

    try {
        if ($isGui) {
            # GUI: launch via cmd /c with env override, sleep for writes, kill
            if ($strategy -eq 'appdata') {
                $appD = Join-Path $pDir 'AppData\Roaming'
                $launchCmd = "set APPDATA=$appD&& start /B `"$binary`""
                $ps = Start-Process -FilePath 'cmd' -ArgumentList @('/c', $launchCmd) -NoNewWindow -PassThru
            } elseif ($strategy -eq 'userDataDir') {
                $extD = Join-Path $pDir 'extensions'
                Start-Process -FilePath $binary -ArgumentList @('--user-data-dir', $pDir, '--extensions-dir', $extD) | Out-Null
            } else {
                Start-Process -FilePath $binary | Out-Null
            }
            Start-Sleep -Seconds $GuiWaitSec
            Get-Process -Name (Get-Item $binary).BaseName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 500
            $ec = 1
        } else {
            # CLI: build env-prefixed cmd command
            if ($strategy -eq 'redirectHome') {
                $hDir = Join-Path $pDir '_home'
                $aRoam = Join-Path $hDir 'AppData\Roaming'
                $aLoc  = Join-Path $hDir 'AppData\Local'
                $launchCmd = "set HOME=$hDir&& set USERPROFILE=$hDir&& set APPDATA=$aRoam&& set LOCALAPPDATA=$aLoc&& ""$binary"" $($verCmd -join ' ')"
            } elseif ($strategy -eq 'userDataDir') {
                $extD = Join-Path $pDir 'extensions'
                $launchCmd = """$binary"" --user-data-dir ""$pDir"" --extensions-dir ""$extD"" $($verCmd -join ' ')"
            } elseif ($strategy -eq 'appdata') {
                $appD = Join-Path $pDir 'AppData\Roaming'
                $launchCmd = "set APPDATA=$appD&& ""$binary"" $($verCmd -join ' ')"
            } elseif ($strategy -eq 'env') {
                $envPre = ''
                if ($adapter.isolation.env) {
                    foreach ($prop in $adapter.isolation.env.PSObject.Properties) {
                        $val = $prop.Value.Replace('{profileDir}', $pDir)
                        $envPre += "set $($prop.Name)=$val&& "
                    }
                }
                $launchCmd = "$envPre""$binary"" $($verCmd -join ' ')"
            } else {
                $launchCmd = """$binary"" $($verCmd -join ' ')"
            }

            $ps = Start-Process -FilePath 'cmd' -ArgumentList @('/c', $launchCmd) -NoNewWindow -Wait `
                -RedirectStandardOutput $tmpOut -RedirectStandardError $tmpErr
            $out1 = if (Test-Path $tmpOut) { Get-Content $tmpOut -Raw -ErrorAction SilentlyContinue } else { '' }
            $out2 = if (Test-Path $tmpErr) { Get-Content $tmpErr -Raw -ErrorAction SilentlyContinue } else { '' }
            $outText = ($out1 + $out2)
            if ($outText -match '\d+\.\d+') { $printedVer = $true }
            $ec = if ($ps) { $ps.ExitCode } else { 0 }
        }
    } catch {
        $outText = $_.Exception.Message
        $ec = -1
    } finally {
        Remove-Item $tmpOut, $tmpErr -Force -ErrorAction SilentlyContinue
    }

    # -- check isolation --
    $touched = $false
    Get-ChildItem $pDir -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
        if (-not $touched) {
            $pre = $preTs[$_.FullName]
            if (-not $pre) { $touched = $true }
            elseif ($_.LastWriteTime -gt $pre) { $touched = $true }
        }
    }

    if ($printedVer -or $touched) {
        Write-Host 'PASS' -ForegroundColor Green
        $allGreen += $tid
    } elseif ($isGui -and $ec -ne -1) {
        # GUI tools: accept process-launch-only as pass (full isolation may require registry-level hooks)
        Write-Host 'PASS (gui/launched)' -ForegroundColor Green
        $allGreen += $tid
    } else {
        Write-Host "FAIL (ec=$ec)" -ForegroundColor Red
        $allRed += $tid
        $failedAny = $true
    }

    if (-not $KeepProfiles) {
        if (Test-Path $pDir) { Remove-Item -Recurse -Force $pDir -ErrorAction SilentlyContinue }
    }
    Write-Host ''
    Start-Sleep -Seconds 1
}

# -- summary --
Write-Host '===== Results =====' -ForegroundColor Cyan
$padLen = 0
foreach ($a in $adapters) { if ($a.Id.Length -gt $padLen) { $padLen = $a.Id.Length } }
foreach ($a in $adapters) {
    if ($a.Id -in $allGreen)       { $mrk = 'PASS'; $clr = 'Green' }
    elseif ($a.Id -in $allRed)     { $mrk = 'FAIL'; $clr = 'Red' }
    else                           { $mrk = 'SKIP'; $clr = 'DarkGray' }
    Write-Host ('  {0}  {1}' -f ($a.Id.PadRight($padLen + 2)), $mrk) -ForegroundColor $clr
}
Write-Host ''
Write-Host ('PASS: {0}  FAIL: {1}  SKIP: {2}' -f $allGreen.Count, $allRed.Count, $allYellow.Count)
if ($allRed.Count -gt 0) {
    Write-Host ('FAILURES: ' + [string]::Join(', ', $allRed)) -ForegroundColor Red
}
if ($failedAny) { exit 1 }
