#requires -Version 5.1
<#
.SYNOPSIS
    One-shot setup: clones and builds the Windows and WSL LLVM reference
    trees that bench.ps1 needs, so bench.ps1 can be run immediately after.

.DESCRIPTION
    This script exists so nobody has to hand-run the multi-step build
    instructions from the README. It is safe to re-run at any time:
    every stage checks whether it already succeeded (worktree present /
    build configured / llvm-lit+FileCheck already built) and skips it if
    so, so a previous partial/interrupted run is resumed rather than
    redone from scratch. Pass -Force to redo every stage regardless.

    It still refuses to silently install heavyweight, system-level
    prerequisites that normally require a reboot or GUI installer
    (Visual Studio, WSL itself) - those are checked and reported with
    exact instructions, same as bench.ps1. The one thing it *does*
    install for you is the small set of Linux packages needed inside an
    already-installed WSL distro (build-essential, cmake, ninja-build,
    clang, lld, git), since that is low-risk and expected.

.PARAMETER RepoUrl
    LLVM git repository to clone. Defaults to the upstream repo.

.PARAMETER Commit
    Branch/tag/commit to check out on both sides, so the comparison is
    apples-to-apples. Defaults to 'main'.

.PARAMETER WinWorktreeDir
    Where to clone the Windows-side checkout.

.PARAMETER WinBuildDir
    Where to configure/build the Windows-side tree. Pass this same path
    to bench.ps1's -WinBuildDir.

.PARAMETER WslDistro
    WSL distro name to use (see `wsl -l -v`). If omitted, auto-detects the
    default (or first) installed WSL2 distro - lets this run unattended in
    CI without knowing the distro name in advance.

.PARAMETER WslWorktreeDir
    Where (inside WSL, on its native filesystem - must not be under
    /mnt/...) to clone the WSL-side checkout.

.PARAMETER WslBuildDir
    Where (inside WSL) to configure/build the WSL-side tree. Pass this
    same path to bench.ps1's -WslBuildDir.

.PARAMETER SkipWSL
    Only set up the Windows side.

.PARAMETER Jobs
    ninja parallelism to use for both builds. 0 (default) = auto-detect
    from logical core count.

.PARAMETER Force
    Redo every stage (re-clone/re-configure/re-build) even if it looks
    already done. Without this, each stage is skipped if already complete,
    so an interrupted run can simply be re-run to pick up where it left off.

.EXAMPLE
    .\setup.ps1

.EXAMPLE
    .\setup.ps1 -Commit release/19.x -SkipWSL

.EXAMPLE
    .\setup.ps1 -Force
#>
[CmdletBinding()]
param(
    [string]$RepoUrl = 'https://github.com/llvm/llvm-project.git',
    [string]$Commit = 'main',

    [string]$WinWorktreeDir = 'D:\llvm-perf-test-win',
    [string]$WinBuildDir = 'D:\llvm-perf-test-win\build-release',

    [string]$WslDistro,
    [string]$WslWorktreeDir = '~/llvm-perf-test-wsl',
    [string]$WslBuildDir = '~/llvm-perf-test-wsl/build-release',

    [switch]$SkipWSL,
    [int]$Jobs = 0,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'lib\BenchCommon.psm1') -Force

function Write-Step($msg) { Write-Host "`n== $msg ==" -ForegroundColor Cyan }
function Write-Skip($msg) { Write-Host "-- SKIP: $msg (already done; use -Force to redo)" -ForegroundColor DarkGray }
function Write-Ok($msg) { Write-Host "OK: $msg" -ForegroundColor Green }
function Fail {
    param([string]$Message, [string]$Remedy)
    Write-Host "`nSETUP FAILED: $Message" -ForegroundColor Red
    if ($Remedy) { Write-Host "REMEDY:`n$Remedy" -ForegroundColor Yellow }
    exit 1
}

Write-Host "== llvm-win-wsl-perf-bench setup ==" -ForegroundColor Cyan
Write-Host "Preparing Windows$(if (-not $SkipWSL) { ' and WSL' }) LLVM build trees for bench.ps1 (commit: $Commit).`n"

# ---------------------------------------------------------------------------
# Base tool checks. Never auto-installs a system-level toolchain (Visual
# Studio, WSL itself) - those need a reboot/GUI installer and are reported
# with exact instructions instead.
# ---------------------------------------------------------------------------
Write-Step "Checking base tools (git, cmake, ninja)"
foreach ($tool in 'git', 'cmake', 'ninja') {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Fail "'$tool' was not found on PATH." "Install $tool and ensure it is on PATH, then re-run this script."
    }
}
Write-Ok "git, cmake, ninja found"

Write-Step "Checking Windows C++ toolchain (clang-cl)"
if (-not (Get-Command clang-cl -ErrorAction SilentlyContinue)) {
    Fail "clang-cl was not found on PATH." @"
Install Visual Studio (the free Community edition is fine) with the
"Desktop development with C++" workload plus the "C++ Clang Compiler for
Windows" component, then run this script from a "Developer PowerShell for
VS <year>" shell (Start Menu) so clang-cl is on PATH.
https://visualstudio.microsoft.com/downloads/
"@
}
Write-Ok "clang-cl found"

if (-not $SkipWSL) {
    Write-Step "Checking WSL"
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
        Fail "wsl.exe was not found on PATH." "Install WSL2: open an Administrator PowerShell and run 'wsl --install', reboot, install a distro, then re-run this script. Or pass -SkipWSL to set up the Windows side only."
    }
    if (-not $WslDistro) {
        $WslDistro = Get-DefaultWslDistro
        if (-not $WslDistro) {
            Fail "No -WslDistro specified and no installed WSL2 distro could be auto-detected." "Install one (e.g. 'wsl --install -d Ubuntu-24.04') or pass -WslDistro <name> (see 'wsl -l -v' for installed distros)."
        }
        Write-Ok "Auto-detected WSL distro: $WslDistro"
    }
    $listOut = (& wsl.exe -l -v 2>&1 | Out-String) -replace "`0", ''
    if ($listOut -notmatch [regex]::Escape($WslDistro)) {
        Fail "WSL distro '$WslDistro' was not found. 'wsl -l -v' reported:`n$listOut" "Install it: wsl --install -d $WslDistro`nThen re-run this script, or pass -WslDistro <name-of-an-existing-distro>."
    }
    if ($listOut -match "$([regex]::Escape($WslDistro))\s+\S+\s+1\b") {
        Fail "WSL distro '$WslDistro' is registered as WSL version 1." "Convert it to WSL2 for a fair comparison: wsl --set-version $WslDistro 2"
    }
    $probe = Invoke-Wsl -Distro $WslDistro -Command 'echo WSL_OK'
    if ($probe -notmatch 'WSL_OK') {
        Fail "Could not run a command inside WSL distro '$WslDistro'." "Run 'wsl -d $WslDistro' manually and resolve any startup errors first, then re-run this script."
    }
    Write-Ok "WSL2 + distro '$WslDistro' present and reachable"

    Write-Step "Installing WSL build dependencies (build-essential, cmake, ninja-build, clang, lld, git)"
    $depCheck = Invoke-Wsl -Distro $WslDistro -Command "for p in build-essential cmake ninja-build clang lld git; do dpkg -s `$p >/dev/null 2>&1 || echo MISSING:`$p; done"
    if (-not $Force -and -not $depCheck.Trim()) {
        Write-Skip "WSL build dependencies already installed"
    }
    else {
        $depCmd = 'sudo apt-get update -qq && sudo apt-get install -y -qq build-essential cmake ninja-build clang lld git'
        Invoke-Wsl -Distro $WslDistro -Command $depCmd | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Fail "Failed to install WSL build dependencies (apt-get exited non-zero)." "Run this manually inside WSL to see the full error, resolve it (e.g. passwordless sudo may be required for a non-interactive apt-get), then re-run this script:`n  wsl -d $WslDistro`n  $depCmd"
        }
        Write-Ok "WSL build dependencies installed"
    }
}

# ---------------------------------------------------------------------------
# Resolve WSL '~' now, before using it in path checks below.
# ---------------------------------------------------------------------------
if (-not $SkipWSL -and ($WslWorktreeDir.StartsWith('~') -or $WslBuildDir.StartsWith('~'))) {
    $wslHomeDir = (Invoke-Wsl -Distro $WslDistro -Command 'echo $HOME').Trim()
    if ($wslHomeDir) {
        $WslWorktreeDir = $WslWorktreeDir -replace '^~', $wslHomeDir
        $WslBuildDir = $WslBuildDir -replace '^~', $wslHomeDir
    }
}
if ($WslBuildDir -match '^/mnt/') {
    Fail "-WslBuildDir '$WslBuildDir' is under /mnt/ (a Windows drive mounted into WSL via drvfs/9p)." "This benchmark intentionally requires the WSL build tree to live on WSL's native filesystem (e.g. under `$HOME), not a mounted NTFS drive, so filesystem timings are a fair Linux-native comparison. Use a path under `$HOME instead (this is the default)."
}

$cmakeCommonArgs = @(
    '-DLLVM_ENABLE_PROJECTS=clang;lld;clang-tools-extra',
    '-DLLVM_ENABLE_RUNTIMES=compiler-rt',
    '-DLLVM_INCLUDE_EXAMPLES=OFF',
    '-DLLVM_INCLUDE_BENCHMARKS=OFF'
)

# ---------------------------------------------------------------------------
# Windows side: clone -> configure -> build. Each stage is skipped if its
# completion marker already exists, so an interrupted run just resumes.
# ---------------------------------------------------------------------------
Write-Step "Windows checkout"
if ((Test-Path (Join-Path $WinWorktreeDir '.git')) -and -not $Force) {
    Write-Skip "Windows checkout already exists at '$WinWorktreeDir'"
}
else {
    if (Test-Path $WinWorktreeDir) { Remove-Item -Path $WinWorktreeDir -Recurse -Force }
    Write-Host "Cloning $RepoUrl into '$WinWorktreeDir' (commit: $Commit)..."
    & git clone --filter=blob:none --no-checkout $RepoUrl $WinWorktreeDir
    if ($LASTEXITCODE -ne 0) { Fail "git clone failed." "Check your network connection / git credentials and re-run." }
    Push-Location $WinWorktreeDir
    try {
        & git checkout $Commit
        if ($LASTEXITCODE -ne 0) { Fail "git checkout '$Commit' failed." "Confirm '$Commit' is a valid branch/tag/commit in $RepoUrl and re-run." }
    }
    finally { Pop-Location }
    Write-Ok "Windows checkout ready at '$WinWorktreeDir'"
}

Write-Step "Windows build configuration"
$winArch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'AArch64' } else { 'X86' }
if ((Test-Path (Join-Path $WinBuildDir 'build.ninja')) -and -not $Force) {
    Write-Skip "Windows build already configured at '$WinBuildDir'"
}
else {
    if (-not (Test-Path $WinBuildDir)) { New-Item -ItemType Directory -Path $WinBuildDir -Force | Out-Null }
    Write-Host "Configuring Windows build (target: $winArch)..."
    & cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=clang-cl -DCMAKE_CXX_COMPILER=clang-cl `
        -DLLVM_USE_LINKER=lld -DLLVM_TARGETS_TO_BUILD=$winArch @cmakeCommonArgs `
        -S (Join-Path $WinWorktreeDir 'llvm') -B $WinBuildDir
    if ($LASTEXITCODE -ne 0) { Fail "cmake configure failed for the Windows build." "Inspect the CMake error above. Common causes: clang-cl not actually resolvable from this shell (use a Developer PowerShell), or a stale CMakeCache.txt from an earlier different configuration (delete '$WinBuildDir' and re-run with -Force)." }
    Write-Ok "Windows build configured at '$WinBuildDir'"
}

Write-Step "Windows build (check-llvm check-clang check-lld)"
$winLit = Join-Path $WinBuildDir 'bin\llvm-lit.cmd'
$winFileCheck = Join-Path $WinBuildDir 'bin\FileCheck.exe'
if ((Test-Path $winLit) -and (Test-Path $winFileCheck) -and -not $Force) {
    Write-Skip "Windows build artifacts (llvm-lit, FileCheck) already present"
}
else {
    $winJobs = if ($Jobs -gt 0) { $Jobs } else { (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors }
    Write-Host "Running: ninja -C $WinBuildDir -j$winJobs check-llvm check-clang check-lld"
    Write-Host "(First run only - this builds and test-runs LLVM/Clang/LLD and can take a long time.)"
    & ninja -C $WinBuildDir "-j$winJobs" check-llvm check-clang check-lld
    if ($LASTEXITCODE -ne 0) { Fail "Windows ninja build failed." "Re-run 'ninja -C $WinBuildDir check-llvm check-clang check-lld' directly to see the full error, fix it, then re-run this script (already-built objects are cached, so this resumes quickly)." }
    Write-Ok "Windows build complete"
}

# ---------------------------------------------------------------------------
# WSL side: same three stages, run inside the distro via Invoke-Wsl.
# ---------------------------------------------------------------------------
if (-not $SkipWSL) {
    Write-Step "WSL checkout ($WslDistro)"
    $existsCheck = Invoke-Wsl -Distro $WslDistro -Command "test -d '$WslWorktreeDir/.git' && echo EXISTS || echo MISSING"
    if ($existsCheck -match 'EXISTS' -and -not $Force) {
        Write-Skip "WSL checkout already exists at '$WslWorktreeDir'"
    }
    else {
        Invoke-Wsl -Distro $WslDistro -Command "rm -rf '$WslWorktreeDir'" | Out-Null
        Write-Host "Cloning $RepoUrl into '$WslWorktreeDir' (commit: $Commit)..."
        $cloneCmd = "git clone --filter=blob:none --no-checkout '$RepoUrl' '$WslWorktreeDir' && cd '$WslWorktreeDir' && git checkout '$Commit'; echo EXITCODE:`$?"
        $cloneOut = Invoke-Wsl -Distro $WslDistro -Command $cloneCmd
        if ($cloneOut -notmatch 'EXITCODE:0') { Fail "WSL git clone/checkout failed." "Run manually to see the full error:`n  wsl -d $WslDistro`n  $cloneCmd" }
        Write-Ok "WSL checkout ready at '$WslWorktreeDir'"
    }

    Write-Step "WSL build configuration"
    $configuredCheck = Invoke-Wsl -Distro $WslDistro -Command "test -f '$WslBuildDir/build.ninja' && echo EXISTS || echo MISSING"
    if ($configuredCheck -match 'EXISTS' -and -not $Force) {
        Write-Skip "WSL build already configured at '$WslBuildDir'"
    }
    else {
        $wslArch = (Invoke-Wsl -Distro $WslDistro -Command 'uname -m').Trim()
        $wslTargetArch = if ($wslArch -match 'aarch64|arm64') { 'AArch64' } else { 'X86' }
        Write-Host "Configuring WSL build (target: $wslTargetArch)..."
        $configureCmd = "mkdir -p '$WslBuildDir' && cd '$WslBuildDir' && CC=clang CXX=clang++ cmake -G Ninja -DCMAKE_BUILD_TYPE=Release " +
        "-DLLVM_USE_LINKER=lld -DLLVM_TARGETS_TO_BUILD=$wslTargetArch " +
        "-DLLVM_ENABLE_PROJECTS='clang;lld;clang-tools-extra' -DLLVM_ENABLE_RUNTIMES=compiler-rt " +
        "-DLLVM_INCLUDE_EXAMPLES=OFF -DLLVM_INCLUDE_BENCHMARKS=OFF '$WslWorktreeDir/llvm'; echo EXITCODE:`$?"
        $configureOut = Invoke-Wsl -Distro $WslDistro -Command $configureCmd
        if ($configureOut -notmatch 'EXITCODE:0') { Fail "cmake configure failed for the WSL build." "Run manually to see the full error:`n  wsl -d $WslDistro`n  $configureCmd" }
        Write-Ok "WSL build configured at '$WslBuildDir'"
    }

    Write-Step "WSL build (check-llvm check-clang check-lld)"
    $wslBuiltCheck = Invoke-Wsl -Distro $WslDistro -Command "test -x '$WslBuildDir/bin/llvm-lit' && test -x '$WslBuildDir/bin/FileCheck' && echo FOUND || echo MISSING"
    if ($wslBuiltCheck -match 'FOUND' -and -not $Force) {
        Write-Skip "WSL build artifacts (llvm-lit, FileCheck) already present"
    }
    else {
        $wslJobs = if ($Jobs -gt 0) { $Jobs } else { [int](Invoke-Wsl -Distro $WslDistro -Command 'nproc').Trim() }
        Write-Host "Running: ninja -C $WslBuildDir -j$wslJobs check-llvm check-clang check-lld"
        Write-Host "(First run only - this builds and test-runs LLVM/Clang/LLD and can take a long time.)"
        $buildCmd = "cd '$WslBuildDir' && ninja -j$wslJobs check-llvm check-clang check-lld; echo EXITCODE:`$?"
        $buildOut = Invoke-Wsl -Distro $WslDistro -Command $buildCmd
        if ($buildOut -notmatch 'EXITCODE:0') { Fail "WSL ninja build failed." "Re-run manually to see the full error (already-built objects are cached, so a re-run resumes quickly):`n  wsl -d $WslDistro`n  $buildCmd" }
        Write-Ok "WSL build complete"
    }
}

# ---------------------------------------------------------------------------
# Final verification - reuse the exact same check bench.ps1 will run.
# ---------------------------------------------------------------------------
Write-Step "Verifying bench.ps1 prerequisites"
$problems = @(Test-Prerequisites -WinBuildDir $WinBuildDir -WslDistro $WslDistro -WslBuildDir $WslBuildDir -SkipWSL:$SkipWSL -Defender Skip)
if ($problems.Count -gt 0) {
    Write-Host "Setup finished but bench.ps1 prerequisite checks still report problems:" -ForegroundColor Red
    foreach ($p in $problems) {
        Write-Host "PROBLEM: $($p.Message)" -ForegroundColor Yellow
        Write-Host "REMEDY:`n$($p.Remedy)`n"
    }
    exit 1
}

Write-Host "`n== Setup complete ==" -ForegroundColor Green
Write-Host "Windows build tree: $WinBuildDir"
if (-not $SkipWSL) { Write-Host "WSL ($WslDistro) build tree: $WslBuildDir" }
Write-Host "`nYou can now run, for example:"
if ($SkipWSL) {
    Write-Host "  .\bench.ps1 -Mode Tight -WinBuildDir `"$WinBuildDir`" -SkipWSL" -ForegroundColor Cyan
}
else {
    Write-Host "  .\bench.ps1 -Mode Tight -WinBuildDir `"$WinBuildDir`" -WslDistro $WslDistro -WslBuildDir `"$WslBuildDir`"" -ForegroundColor Cyan
}
