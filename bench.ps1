#requires -Version 5.1
<#
.SYNOPSIS
    Repeatable Windows-vs-WSL LLVM build/test performance benchmark.

.DESCRIPTION
    Small, fast, repeatable benchmark that re-measures the core performance
    gaps identified in windows-vs-wsl-test-timing-report.md:
      - raw process-spawn overhead
      - filesystem metadata overhead (many small file creates/deletes)
      - real llvm-lit test-suite wall time (the actual CI-relevant gap)

    Intended to be re-run repeatedly (e.g. after OS/tool updates, Defender
    config changes, WSL kernel updates) to track whether the gap changes.
    This script does not build LLVM itself - it requires that a Windows
    build tree and a WSL (native-filesystem) build tree already exist, and
    will error with exact build instructions if they do not. It never
    installs or modifies software; the only optional state change it can
    make is a temporary Windows Defender exclusion, and only if you pass
    -Defender Exclude or -Defender Compare.

.PARAMETER Mode
    'Tight'  (default): finishes in well under 5 minutes. Runs only the
             llvm-reduce test subset (the single biggest Windows-vs-WSL gap
             found in the original report) plus the two microbenchmarks.
    'Full'   : runs check-llvm, check-clang and check-lld in full (including
             any failing tests - failures are recorded as data, not treated
             as a script error) plus the two microbenchmarks. Takes
             substantially longer (tens of minutes), matching the scope of
             the original investigation.

.PARAMETER WinBuildDir
    Path to a pre-built Windows LLVM release-style build tree
    (must contain bin\llvm-lit.cmd and bin\FileCheck.exe).

.PARAMETER WslDistro
    Name of the WSL distro to use (see `wsl -l -v`). If omitted, auto-
    detects the default (or first) installed WSL2 distro.

.PARAMETER WslBuildDir
    Path (as seen from inside WSL) to a pre-built LLVM build tree on WSL's
    native filesystem (must NOT be under /mnt/...).

.PARAMETER Defender
    'Skip'    (default): do not touch Defender at all; just report current
              real-time-protection/exclusion state for context.
    'Exclude' : add a Defender exclusion for -WinBuildDir before running,
              then leave it in place (state is printed clearly).
    'Compare' : run the lit benchmark twice - once in whatever Defender
              state currently exists, once with an exclusion toggled - then
              restore the original Defender state afterwards. Requires
              Administrator.

.PARAMETER SkipWSL
    Run the Windows-only subset (no WSL comparison at all).

.PARAMETER OutputDir
    Directory to write the timestamped .md/.csv result files. Defaults to
    .\results next to this script.

.EXAMPLE
    .\bench.ps1 -Mode Tight -WinBuildDir D:\llvm-perf-test-win\build-release -WslDistro Ubuntu-24.04 -WslBuildDir ~/llvm-perf-test-wsl/build-release

.EXAMPLE
    .\bench.ps1 -Mode Full -Defender Compare -WinBuildDir D:\llvm-perf-test-win\build-release -WslDistro Ubuntu-24.04 -WslBuildDir ~/llvm-perf-test-wsl/build-release
#>
[CmdletBinding()]
param(
    [ValidateSet('Tight', 'Full')]
    [string]$Mode = 'Tight',

    [string]$WinBuildDir = 'D:\llvm-perf-test-win\build-release',

    [string]$WslDistro,

    [string]$WslBuildDir = '~/llvm-perf-test-wsl/build-release',

    [ValidateSet('Skip', 'Exclude', 'Compare')]
    [string]$Defender = 'Skip',

    [switch]$SkipWSL,

    [int]$SpawnIterations = 200,

    [int]$FileIterations = 2000,

    [string]$OutputDir = (Join-Path $PSScriptRoot 'results')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'lib\BenchCommon.psm1') -Force

Write-Host "== Windows vs WSL LLVM build/test performance benchmark ==" -ForegroundColor Cyan
Write-Host "Mode: $Mode | Defender: $Defender | SkipWSL: $($SkipWSL.IsPresent)`n"

# --- Auto-detect the WSL distro if none was passed, so this can run
# unattended in CI without anyone hardcoding a distro name in advance ---
if (-not $SkipWSL -and -not $WslDistro) {
    $WslDistro = Get-DefaultWslDistro
    if (-not $WslDistro) {
        Write-Host "No -WslDistro specified and no installed WSL2 distro could be auto-detected." -ForegroundColor Red
        Write-Host "REMEDY:`nInstall one (e.g. 'wsl --install -d Ubuntu-24.04') or pass -WslDistro <name> (see 'wsl -l -v' for installed distros)."
        exit 1
    }
    Write-Host "Auto-detected WSL distro: $WslDistro" -ForegroundColor Green
}

# --- Resolve the WSL build dir's literal tilde now, before any prerequisite checks use it in path comparisons ---
if (-not $SkipWSL -and $WslBuildDir.StartsWith('~')) {
    $wslHomeDir = (Invoke-Wsl -Distro $WslDistro -Command 'echo $HOME').Trim()
    if ($wslHomeDir) { $WslBuildDir = $WslBuildDir -replace '^~', $wslHomeDir }
}

# --- Prerequisite checks (never installs anything) ---
$problems = @(Test-Prerequisites -WinBuildDir $WinBuildDir -WslDistro $WslDistro -WslBuildDir $WslBuildDir -SkipWSL:$SkipWSL -Defender $Defender)
if ($problems.Count -gt 0) {
    Write-Host "Prerequisite checks failed. This script does not install/build anything automatically." -ForegroundColor Red
    Write-Host "Most build-tree problems below can be fixed by running: .\setup.ps1`n" -ForegroundColor Red
    foreach ($p in $problems) {
        Write-Host "PROBLEM: $($p.Message)" -ForegroundColor Yellow
        Write-Host "REMEDY:`n$($p.Remedy)`n"
    }
    exit 1
}
Write-Host "Prerequisite checks passed." -ForegroundColor Green

# --- Capability detection ---
$caps = Get-Capabilities -WinBuildDir $WinBuildDir -WslDistro $WslDistro -WslBuildDir $WslBuildDir -SkipWSL:$SkipWSL
Write-Host "`n-- Environment --"
Write-Host ("Windows: {0} logical cores, {1} GB RAM, {2} GB free at build drive" -f $caps.WinCores, $caps.WinMemGB, $caps.WinFreeGB)
if (-not $SkipWSL) {
    Write-Host ("WSL ($WslDistro): {0} cores, {1} GB RAM, {2} GB free at build dir" -f $caps.WslCores, $caps.WslMemGB, $caps.WslFreeGB)
}
Write-Host ("Shared parallelism used for lit on both sides (-j): {0}" -f $caps.SharedJ)

# --- Defender state handling ---
$defenderNote = "not checked (Defender option = Skip)"
$exclusionAddedByUs = $false
$originalExclusionPresent = $false
if ($Defender -ne 'Skip') {
    $state = Get-DefenderExclusionState -Path $WinBuildDir
    $originalExclusionPresent = $state.PathAlreadyExcluded
    $defenderNote = "RealTimeProtectionEnabled=$($state.RealTimeProtectionEnabled); PathAlreadyExcluded(before)=$($state.PathAlreadyExcluded)"

    if ($Defender -eq 'Exclude' -and -not $state.PathAlreadyExcluded) {
        Add-MpPreference -ExclusionPath $WinBuildDir
        $exclusionAddedByUs = $true
        Write-Host "Added a Defender exclusion for '$WinBuildDir' (left in place after this run)." -ForegroundColor Yellow
    }
}
Write-Host "`n-- Defender state -- `n$defenderNote"

# --- Microbenchmarks (always run, cheap, same iteration counts regardless of Mode for comparability) ---
Write-Host "`n-- Running process-spawn microbenchmark ($SpawnIterations iterations) --"
$spawnResult = Invoke-SpawnMicrobench -Iterations $SpawnIterations -WslDistro $WslDistro -SkipWSL:$SkipWSL

Write-Host "-- Running filesystem microbenchmark ($FileIterations files) --"
$fileResult = Invoke-FileMicrobench -FileCount $FileIterations -WslDistro $WslDistro -WslBuildDir $WslBuildDir -SkipWSL:$SkipWSL

# --- Lit-based real test-suite benchmark(s) ---
$litResults = @()
if ($Mode -eq 'Tight') {
    Write-Host "`n-- Running lit suite: llvm-reduce subset (tight mode) --"
    $litResults += Invoke-LitBench -SuiteName 'LLVM::tools/llvm-reduce' -RelativeTestPath 'test\tools\llvm-reduce' `
        -WinBuildDir $WinBuildDir -WslDistro $WslDistro -WslBuildDir $WslBuildDir -Parallelism $caps.SharedJ -SkipWSL:$SkipWSL
}
else {
    $suites = @(
        @{ Name = 'check-llvm (full)'; Path = 'test' },
        @{ Name = 'check-clang (full)'; Path = 'tools\clang\test' },
        @{ Name = 'check-lld (full)'; Path = 'tools\lld\test' }
    )
    foreach ($s in $suites) {
        Write-Host "`n-- Running lit suite: $($s.Name) --"
        $litResults += Invoke-LitBench -SuiteName $s.Name -RelativeTestPath $s.Path `
            -WinBuildDir $WinBuildDir -WslDistro $WslDistro -WslBuildDir $WslBuildDir -Parallelism $caps.SharedJ -SkipWSL:$SkipWSL
    }
}

# --- Defender Compare mode: re-run the lit benchmark(s) with the opposite exclusion state, then restore ---
$compareLitResults = $null
if ($Defender -eq 'Compare') {
    $toggledState = -not $originalExclusionPresent
    if ($toggledState) {
        Add-MpPreference -ExclusionPath $WinBuildDir
        Write-Host "`n[Defender Compare] Added exclusion for second pass." -ForegroundColor Yellow
    }
    else {
        Remove-MpPreference -ExclusionPath $WinBuildDir
        Write-Host "`n[Defender Compare] Removed exclusion for second pass." -ForegroundColor Yellow
    }

    $compareLitResults = @()
    if ($Mode -eq 'Tight') {
        $compareLitResults += Invoke-LitBench -SuiteName 'LLVM::tools/llvm-reduce' -RelativeTestPath 'test\tools\llvm-reduce' `
            -WinBuildDir $WinBuildDir -WslDistro $WslDistro -WslBuildDir $WslBuildDir -Parallelism $caps.SharedJ -SkipWSL:$SkipWSL
    }
    else {
        foreach ($s in $suites) {
            $compareLitResults += Invoke-LitBench -SuiteName $s.Name -RelativeTestPath $s.Path `
                -WinBuildDir $WinBuildDir -WslDistro $WslDistro -WslBuildDir $WslBuildDir -Parallelism $caps.SharedJ -SkipWSL:$SkipWSL
        }
    }

    # restore original state
    if ($toggledState -and -not $originalExclusionPresent) {
        Remove-MpPreference -ExclusionPath $WinBuildDir
    }
    elseif (-not $toggledState -and $originalExclusionPresent) {
        Add-MpPreference -ExclusionPath $WinBuildDir
    }
    Write-Host "[Defender Compare] Restored original exclusion state (PathAlreadyExcluded=$originalExclusionPresent)." -ForegroundColor Yellow
}

# --- Report ---
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }
$timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$mdPath = Join-Path $OutputDir "$timestamp-$Mode.md"
$csvPath = Join-Path $OutputDir "$timestamp-$Mode.csv"

$lines = @()
$lines += "# LLVM Windows-vs-WSL performance benchmark result"
$lines += ""
$lines += "Run timestamp (local): $timestamp"
$lines += "Mode: $Mode"
$lines += "Windows build tree: $WinBuildDir"
if (-not $SkipWSL) { $lines += "WSL ($WslDistro) build tree: $WslBuildDir" }
$lines += "Shared lit parallelism (-j): $($caps.SharedJ)"
$lines += "Defender option: $Defender ($defenderNote)"
$lines += ""
$lines += "## Environment"
$lines += ""
$lines += "| Metric | Windows | WSL |"
$lines += "|---|---:|---:|"
$wslCoresDisp = if ($SkipWSL) { 'n/a' } else { $caps.WslCores }
$wslMemDisp = if ($SkipWSL) { 'n/a' } else { $caps.WslMemGB }
$wslFreeDisp = if ($SkipWSL) { 'n/a' } else { $caps.WslFreeGB }
$lines += "| Logical cores | $($caps.WinCores) | $wslCoresDisp |"
$lines += "| Memory (GB) | $($caps.WinMemGB) | $wslMemDisp |"
$lines += "| Free disk at build dir (GB) | $($caps.WinFreeGB) | $wslFreeDisp |"
$lines += ""
$lines += "## Microbenchmarks"
$lines += ""
$lines += "| Test | Windows (s) | WSL (s) | Ratio (Win/WSL) |"
$lines += "|---|---:|---:|---:|"
foreach ($r in @($spawnResult, $fileResult)) {
    $ratio = if ($r.WslSeconds) { [math]::Round($r.WinSeconds / $r.WslSeconds, 2) } else { 'n/a' }
    $wslSecDisp = if ($null -ne $r.WslSeconds) { $r.WslSeconds } else { 'n/a' }
    $lines += "| $($r.Test) | $($r.WinSeconds) | $wslSecDisp | $ratio |"
}
$lines += ""
$lines += "## Lit test-suite result(s)"
$lines += ""
$lines += "| Suite | Win wall (s) | WSL wall (s) | Wall ratio | Win tests (P/F/total) | WSL tests (P/F/total) |"
$lines += "|---|---:|---:|---:|---:|---:|"
foreach ($r in $litResults) {
    $ratio = if ($r.WslWallSec) { [math]::Round($r.WinWallSec / $r.WslWallSec, 2) } else { 'n/a' }
    $winStats = "$($r.WinPass)/$($r.WinFail)/$($r.WinTotal)"
    $wslWallDisp = if ($null -ne $r.WslWallSec) { $r.WslWallSec } else { 'n/a' }
    $wslStats = if ($r.WslTotal -ne $null) { "$($r.WslPass)/$($r.WslFail)/$($r.WslTotal)" } else { 'n/a' }
    $lines += "| $($r.Suite) | $($r.WinWallSec) | $wslWallDisp | $ratio | $winStats | $wslStats |"
}

if ($compareLitResults) {
    $lines += ""
    $lines += "## Lit test-suite result(s) - Defender toggled second pass"
    $lines += ""
    $lines += "| Suite | Win wall (s) | WSL wall (s) | Wall ratio |"
    $lines += "|---|---:|---:|---:|"
    foreach ($r in $compareLitResults) {
        $ratio = if ($r.WslWallSec) { [math]::Round($r.WinWallSec / $r.WslWallSec, 2) } else { 'n/a' }
        $lines += "| $($r.Suite) | $($r.WinWallSec) | $($r.WslWallSec) | $ratio |"
    }
}

$lines += ""
$lines += "## Summary (measured facts, no analysis)"
$lines += ""
$lines += "- Process spawn x${SpawnIterations}: Windows $($spawnResult.WinSeconds)s$(if (-not $SkipWSL) { ", WSL $($spawnResult.WslSeconds)s." } else { '.' })"
$lines += "- File create+delete x${FileIterations}: Windows $($fileResult.WinSeconds)s$(if (-not $SkipWSL) { ", WSL $($fileResult.WslSeconds)s." } else { '.' })"
foreach ($r in $litResults) {
    if (-not $SkipWSL) {
        $lines += "- $($r.Suite): Windows wall $($r.WinWallSec)s ($($r.WinPass) passed / $($r.WinFail) failed of $($r.WinTotal)); WSL wall $($r.WslWallSec)s ($($r.WslPass) passed / $($r.WslFail) failed of $($r.WslTotal))."
    }
    else {
        $lines += "- $($r.Suite): Windows wall $($r.WinWallSec)s ($($r.WinPass) passed / $($r.WinFail) failed of $($r.WinTotal))."
    }
}

$reportText = $lines -join "`n"
$reportText | Out-File -FilePath $mdPath -Encoding utf8
Write-Host "`n$reportText"
Write-Host "`nSaved: $mdPath" -ForegroundColor Green

# CSV: one row per measurement for easy historical diffing across repeated runs
$csvRows = @()
$csvRows += [pscustomobject]@{ Timestamp = $timestamp; Mode = $Mode; Category = 'Microbench'; Test = $spawnResult.Test; WinSeconds = $spawnResult.WinSeconds; WslSeconds = $spawnResult.WslSeconds; WinPass = ''; WinFail = ''; WinTotal = ''; WslPass = ''; WslFail = ''; WslTotal = '' }
$csvRows += [pscustomobject]@{ Timestamp = $timestamp; Mode = $Mode; Category = 'Microbench'; Test = $fileResult.Test; WinSeconds = $fileResult.WinSeconds; WslSeconds = $fileResult.WslSeconds; WinPass = ''; WinFail = ''; WinTotal = ''; WslPass = ''; WslFail = ''; WslTotal = '' }
foreach ($r in $litResults) {
    $csvRows += [pscustomobject]@{ Timestamp = $timestamp; Mode = $Mode; Category = 'LitSuite'; Test = $r.Suite; WinSeconds = $r.WinWallSec; WslSeconds = $r.WslWallSec; WinPass = $r.WinPass; WinFail = $r.WinFail; WinTotal = $r.WinTotal; WslPass = $r.WslPass; WslFail = $r.WslFail; WslTotal = $r.WslTotal }
}
$csvRows | Export-Csv -Path $csvPath -NoTypeInformation -Encoding utf8
Write-Host "Saved: $csvPath" -ForegroundColor Green
