#requires -Version 7.0
<#
.SYNOPSIS
    Self-contained, cross-platform CI benchmark for GitHub-hosted runners.

.DESCRIPTION
    Unlike bench.ps1 (which compares a Windows host against WSL and needs
    setup.ps1's pre-built trees), this script is meant to run standalone
    on any single GitHub-hosted runner (Windows x64, Windows ARM64, or a
    bare-bones Linux runner) with no pre-existing build tree. It:

      1. Records the machine spec (OS, CPU model/architecture, physical
         and logical core counts, memory, free disk).
      2. Runs the same two OS-level microbenchmarks as bench.ps1 (process
         spawn, file create/delete) - now single-machine, absolute
         numbers rather than a Windows-vs-WSL ratio.
      3. Does a minimal, bounded LLVM build (shallow clone + just enough
         targets to run the `llvm-reduce` lit tests, the same fixed
         canary suite bench.ps1's Tight mode uses) and records its wall
         time plus lit pass/fail counts.

    This produces directly comparable, per-runner-type numbers (Windows
    x64 vs Windows ARM64 vs Linux x64) without requiring WSL or any
    pre-built tree, so it can run unattended in a GitHub Actions matrix.
    PowerShell 7+ (pwsh) is preinstalled on all GitHub-hosted runners this
    targets, including Linux and Windows ARM64.

.PARAMETER Commit
    LLVM commit/tag/branch to check out on the (single) side being
    benchmarked. Default: main.

.PARAMETER OutputDir
    Directory to write the JSON + Markdown result files to.

.PARAMETER WorkDir
    Directory to clone/build LLVM in. Defaults to a temp directory.

.PARAMETER SpawnIterations / -FileIterations
    Same meaning as in bench.ps1.
#>
[CmdletBinding()]
param(
    [string]$Commit = 'main',
    [string]$OutputDir = (Join-Path $PSScriptRoot 'results\ci-runs'),
    [string]$WorkDir = (Join-Path ([System.IO.Path]::GetTempPath()) 'llvm-ci-bench'),
    [int]$SpawnIterations = 200,
    [int]$FileIterations = 2000,
    [int]$Jobs = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-MachineSpec {
    $os = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }
    $arch = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()

    if ($IsWindows) {
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
        $cs = Get-CimInstance Win32_ComputerSystem
        $osInfo = Get-CimInstance Win32_OperatingSystem
        $cpuModel = $cpu.Name.Trim()
        $physicalCores = [int]$cpu.NumberOfCores
        $logicalCores = [int]$cs.NumberOfLogicalProcessors
        $memGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
        $osVersion = "$($osInfo.Caption) ($($osInfo.Version))"
        $drive = (Get-Location).Drive.Name
        $freeGB = [math]::Round((Get-PSDrive $drive).Free / 1GB, 1)
    }
    elseif ($IsLinux) {
        $cpuModel = (Get-Content /proc/cpuinfo | Where-Object { $_ -match '^model name\s*:' } | Select-Object -First 1)
        if ($cpuModel) { $cpuModel = ($cpuModel -split ':', 2)[1].Trim() }
        else {
            # ARM /proc/cpuinfo often has no "model name"; fall back to lscpu.
            $lscpu = (lscpu 2>$null)
            $modelLine = $lscpu | Where-Object { $_ -match 'Model name:' } | Select-Object -First 1
            $cpuModel = if ($modelLine) { ($modelLine -split ':', 2)[1].Trim() } else { 'unknown' }
        }
        $logicalCores = [int](nproc)
        $lscpu = (lscpu 2>$null)
        $coresPerSocket = ($lscpu | Where-Object { $_ -match 'Core\(s\) per socket:' } | ForEach-Object { ($_ -split ':', 2)[1].Trim() }) | Select-Object -First 1
        $sockets = ($lscpu | Where-Object { $_ -match 'Socket\(s\):' } | ForEach-Object { ($_ -split ':', 2)[1].Trim() }) | Select-Object -First 1
        $physicalCores = if ($coresPerSocket -and $sockets) { [int]$coresPerSocket * [int]$sockets } else { $logicalCores }
        $memKB = [int64]((Get-Content /proc/meminfo | Where-Object { $_ -match '^MemTotal:' }) -split '\s+' | Select-Object -Index 1)
        $memGB = [math]::Round(($memKB * 1KB) / 1GB, 1)
        $osVersion = (Get-Content /etc/os-release | Where-Object { $_ -match '^PRETTY_NAME=' }) -replace '^PRETTY_NAME=', '' -replace '"', ''
        $freeBytes = [int64]((df -B1 --output=avail . | Select-Object -Last 1).Trim())
        $freeGB = [math]::Round($freeBytes / 1GB, 1)
    }
    else {
        $cpuModel = 'unknown'; $physicalCores = 0; $logicalCores = 0; $memGB = 0; $osVersion = 'unknown'; $freeGB = 0
    }

    return [ordered]@{
        Os              = $os
        OsVersion       = $osVersion
        Architecture    = $arch
        CpuModel        = $cpuModel
        PhysicalCores   = $physicalCores
        LogicalCores    = $logicalCores
        MemoryGB        = $memGB
        FreeDiskGB      = $freeGB
        RunnerName      = $env:RUNNER_NAME
        RunnerLabel     = $env:CI_BENCH_RUNNER_LABEL
        GithubRunId     = $env:GITHUB_RUN_ID
    }
}

function Invoke-SpawnMicrobenchSingle {
    param([int]$Iterations)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    if ($IsWindows) {
        for ($i = 0; $i -lt $Iterations; $i++) { & $env:ComSpec /c exit 0 | Out-Null }
    }
    else {
        for ($i = 0; $i -lt $Iterations; $i++) { & /bin/true }
    }
    $sw.Stop()
    return [math]::Round($sw.Elapsed.TotalSeconds, 2)
}

function Invoke-FileMicrobenchSingle {
    param([int]$FileCount)
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("bench-fs-{0}" -f ([guid]::NewGuid().ToString('N')))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $bytes = [byte[]](1)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt $FileCount; $i++) { [System.IO.File]::WriteAllBytes((Join-Path $dir "f$i.tmp"), $bytes) }
    for ($i = 0; $i -lt $FileCount; $i++) { [System.IO.File]::Delete((Join-Path $dir "f$i.tmp")) }
    $sw.Stop()
    Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
    return [math]::Round($sw.Elapsed.TotalSeconds, 2)
}

Write-Host "== CI perf-bench (single-machine, self-contained) ==" -ForegroundColor Cyan
$spec = Get-MachineSpec
Write-Host ("OS: {0} ({1}) | Arch: {2} | CPU: {3} | Cores: {4} logical / {5} physical | RAM: {6} GB | Free disk: {7} GB" -f `
        $spec.Os, $spec.OsVersion, $spec.Architecture, $spec.CpuModel, $spec.LogicalCores, $spec.PhysicalCores, $spec.MemoryGB, $spec.FreeDiskGB)

if ($Jobs -le 0) { $Jobs = [math]::Max(1, $spec.LogicalCores) }

Write-Host "`n-- Process-spawn microbenchmark ($SpawnIterations iterations) --"
$spawnSec = Invoke-SpawnMicrobenchSingle -Iterations $SpawnIterations
Write-Host "  $spawnSec s"

Write-Host "-- Filesystem microbenchmark ($FileIterations files) --"
$fileSec = Invoke-FileMicrobenchSingle -FileCount $FileIterations
Write-Host "  $fileSec s"

# --- Minimal, bounded LLVM build: just enough to run the llvm-reduce lit suite ---
New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
$srcDir = Join-Path $WorkDir 'llvm-project'
$buildDir = Join-Path $WorkDir 'build'

if (-not (Test-Path (Join-Path $srcDir '.git'))) {
    Write-Host "`n-- Cloning llvm-project (shallow, blobless) @ $Commit --"
    git clone --filter=blob:none --no-checkout https://github.com/llvm/llvm-project.git $srcDir
    Push-Location $srcDir
    git fetch --depth 1 origin $Commit
    git checkout FETCH_HEAD
    Pop-Location
}

# Ninja + single-config Release everywhere (Windows included) - this needs
# cl.exe/link.exe already on PATH on Windows (the workflow sets that up via
# the ilammy/msvc-dev-cmd action before calling this script), which is more
# robust on hosted runners than relying on CMake's Visual Studio generator
# probing (that generator has intermittently failed to find VS at all on
# some hosted Windows images/architectures).
$configArgs = @(
    '-S', (Join-Path $srcDir 'llvm'),
    '-B', $buildDir,
    '-G', 'Ninja',
    '-DCMAKE_BUILD_TYPE=Release',
    '-DLLVM_ENABLE_PROJECTS=llvm',
    '-DLLVM_TARGETS_TO_BUILD=Native',
    '-DLLVM_ENABLE_ASSERTIONS=OFF',
    '-DLLVM_INCLUDE_BENCHMARKS=OFF',
    '-DLLVM_INCLUDE_EXAMPLES=OFF'
)

Write-Host "`n-- Configuring (generator: Ninja) --"
cmake @configArgs
if ($LASTEXITCODE -ne 0) { throw "cmake configure failed with exit code $LASTEXITCODE" }

$buildTargets = @('llvm-reduce', 'FileCheck', 'count', 'not', 'split-file', 'llvm-lit')
Write-Host "-- Building targets: $($buildTargets -join ', ') (-j $Jobs) --"
$buildSw = [System.Diagnostics.Stopwatch]::StartNew()
cmake --build $buildDir --target @buildTargets --parallel $Jobs 2>&1 | ForEach-Object { $_ }
if ($LASTEXITCODE -ne 0) { throw "cmake --build failed with exit code $LASTEXITCODE" }
$binDir = Join-Path $buildDir 'bin'
$buildSw.Stop()
$buildSeconds = [math]::Round($buildSw.Elapsed.TotalSeconds, 2)
Write-Host "Build took $buildSeconds s"

# --- Run llvm-lit against the llvm-reduce test subset ---
# Use the llvm-lit wrapper LLVM's own build generates (same approach as
# bench.ps1/BenchCommon.psm1's Invoke-LitBench) instead of invoking the
# lit.py source directly - this avoids guessing which Python interpreter
# name/PATH entry is correct on a given runner, since the generated
# wrapper already embeds the right one plus the site config pointing at
# this exact build tree's freshly built tools.
$litExe = if ($IsWindows) { Join-Path $binDir 'llvm-lit.cmd' } else { Join-Path $binDir 'llvm-lit' }
if (-not (Test-Path $litExe)) { throw "Expected llvm-lit wrapper not found at '$litExe' after building the llvm-lit target." }
$testPath = Join-Path $srcDir 'llvm\test\tools\llvm-reduce'
$litSw = [System.Diagnostics.Stopwatch]::StartNew()
$litOutput = & $litExe --time-tests -j $Jobs $testPath 2>&1 | Out-String
$litSw.Stop()
$litSeconds = [math]::Round($litSw.Elapsed.TotalSeconds, 2)

$litTotal = 0; $litPass = 0; $litFail = 0
if ($litOutput -match 'Total Discovered Tests:\s*(\d+)') { $litTotal = [int]$Matches[1] }
if ($litOutput -match 'Passed\s*:\s*(\d+)') { $litPass = [int]$Matches[1] }
if ($litOutput -match 'Failed\s*:\s*(\d+)') { $litFail = [int]$Matches[1] }
Write-Host "`n-- lit: llvm-reduce suite --"
Write-Host "  wall $litSeconds s | pass $litPass / fail $litFail / total $litTotal"
if ($litTotal -eq 0) {
    # Surface the raw lit output so a misconfiguration is visible in CI
    # logs rather than silently producing a report full of zeros.
    Write-Host "-- Raw lit output (no tests discovered - see below for why) --"
    Write-Host $litOutput
}

# --- Assemble + write report ---
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }
$timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$label = if ($env:CI_BENCH_RUNNER_LABEL) { $env:CI_BENCH_RUNNER_LABEL } else { "$($spec.Os)-$($spec.Architecture)" }

$result = [ordered]@{
    Timestamp      = $timestamp
    Commit         = $Commit
    RunnerLabel    = $label
    MachineSpec    = $spec
    Microbench     = [ordered]@{
        SpawnIterations = $SpawnIterations
        SpawnSeconds    = $spawnSec
        FileIterations  = $FileIterations
        FileSeconds     = $fileSec
    }
    Build          = [ordered]@{
        Targets       = $buildTargets
        Jobs          = $Jobs
        BuildSeconds  = $buildSeconds
    }
    Lit            = [ordered]@{
        Suite         = 'LLVM::tools/llvm-reduce'
        WallSeconds   = $litSeconds
        Pass          = $litPass
        Fail          = $litFail
        Total         = $litTotal
    }
}

$jsonPath = Join-Path $OutputDir "$label.json"
$mdPath = Join-Path $OutputDir "$label.md"

$result | ConvertTo-Json -Depth 6 | Out-File -FilePath $jsonPath -Encoding utf8

$md = @()
$md += "# CI perf-bench result: $label"
$md += ""
$md += "Timestamp (UTC): $timestamp | LLVM commit/ref: $Commit"
$md += ""
$md += "## Machine spec"
$md += ""
$md += "| Field | Value |"
$md += "|---|---|"
foreach ($k in $spec.Keys) { $md += "| $k | $($spec[$k]) |" }
$md += ""
$md += "## Results"
$md += ""
$md += "| Test | Result |"
$md += "|---|---:|"
$md += "| Process spawn x$SpawnIterations | $spawnSec s |"
$md += "| Create+delete $FileIterations 1-byte files | $fileSec s |"
$md += "| Build (llvm-reduce + deps, -j $Jobs) | $buildSeconds s |"
$md += "| lit LLVM::tools/llvm-reduce wall time | $litSeconds s |"
$md += "| lit LLVM::tools/llvm-reduce pass/fail/total | $litPass/$litFail/$litTotal |"

$md -join "`n" | Out-File -FilePath $mdPath -Encoding utf8

Write-Host "`nSaved: $jsonPath"
Write-Host "Saved: $mdPath"
