#requires -Version 5.1
<#
    BenchCommon.psm1

    Shared functions for the Windows-vs-WSL LLVM build/test performance
    benchmark. Pure PowerShell (Windows side) driving `wsl.exe` for the
    WSL side. No Python is used anywhere in this harness itself.

    NOTE: `llvm-lit` (invoked as a black box in Invoke-LitBench) is LLVM's
    own test driver and is implemented in Python. It is invoked here only
    because it is the actual tool whose real-world timing gap this suite
    is measuring (the same driver used by LLVM's CI) - it is not part of
    the harness/tooling being written, and no code in this repository is
    written in Python.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-IsAdministrator {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-Wsl {
    <# Runs a bash -lc command string in the given WSL distro and returns stdout as text. #>
    param(
        [Parameter(Mandatory)][string]$Distro,
        [Parameter(Mandatory)][string]$Command
    )
    $out = & wsl.exe -d $Distro -- bash -lc $Command 2>&1
    return ($out -join "`n")
}

function Test-Prerequisites {
    <#
        Verifies every tool/path this benchmark needs is already present.
        Never installs or modifies anything. Returns a list of problems
        (empty array = all good). Each problem is a hashtable with
        Message and Remedy.
    #>
    param(
        [Parameter(Mandatory)][string]$WinBuildDir,
        [string]$WslDistro,
        [string]$WslBuildDir,
        [switch]$SkipWSL,
        [ValidateSet('Skip', 'Exclude', 'Compare')][string]$Defender = 'Skip'
    )

    $problems = @()

    if ($PSVersionTable.PSVersion.Major -lt 5) {
        $problems += @{
            Message = "PowerShell $($PSVersionTable.PSVersion) is too old."
            Remedy  = "Install PowerShell 5.1 or later (Windows PowerShell 5.1 ships with Windows; PowerShell 7+ available from https://aka.ms/powershell)."
        }
    }

    # --- Windows build tree ---
    $winLit = Join-Path $WinBuildDir 'bin\llvm-lit.cmd'
    $winFileCheck = Join-Path $WinBuildDir 'bin\FileCheck.exe'
    if (-not (Test-Path $WinBuildDir)) {
        $problems += @{
            Message = "Windows LLVM build tree not found at '$WinBuildDir'."
            Remedy  = "Run the setup script to build it automatically: .\setup.ps1 -WinBuildDir `"$WinBuildDir`"`nSee README.md for what it does and its own prerequisites (git/cmake/ninja/clang-cl)."
        }
    }
    elseif (-not (Test-Path $winLit) -or -not (Test-Path $winFileCheck)) {
        $problems += @{
            Message = "Windows build tree at '$WinBuildDir' exists but is missing bin\llvm-lit.cmd or bin\FileCheck.exe."
            Remedy  = "Run the setup script to finish building it: .\setup.ps1 -WinBuildDir `"$WinBuildDir`""
        }
    }

    if (-not $SkipWSL) {
        if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
            $problems += @{
                Message = "wsl.exe was not found on PATH."
                Remedy  = "Install the Windows Subsystem for Linux (Settings > Apps > Optional Features, or 'wsl --install' as Administrator), then install a distro, then re-run. Alternatively pass -SkipWSL to run the Windows-only subset."
            }
        }
        else {
            if (-not $WslDistro) {
                $problems += @{
                    Message = "No -WslDistro specified and no default could be assumed."
                    Remedy  = "Pass -WslDistro <name> (see 'wsl -l -v' for installed distros)."
                }
            }
            else {
                $listOut = (& wsl.exe -l -v 2>&1 | Out-String)
                $normalizedList = $listOut -replace "`0", ''
                if ($normalizedList -notmatch [regex]::Escape($WslDistro)) {
                    $problems += @{
                        Message = "WSL distro '$WslDistro' was not found. 'wsl -l -v' reported:`n$normalizedList"
                        Remedy  = "Install it (e.g. 'wsl --install -d $WslDistro') or pass -WslDistro with the name of an existing distro."
                    }
                }
                elseif ($normalizedList -match "$([regex]::Escape($WslDistro))\s+\S+\s+1\b") {
                    $problems += @{
                        Message = "WSL distro '$WslDistro' is registered as WSL version 1."
                        Remedy  = "Convert it to WSL2 for a fair comparison: wsl --set-version $WslDistro 2"
                    }
                }
                else {
                    $probe = Invoke-Wsl -Distro $WslDistro -Command 'echo WSL_OK'
                    if ($probe -notmatch 'WSL_OK') {
                        $problems += @{
                            Message = "Could not run a command inside WSL distro '$WslDistro'."
                            Remedy  = "Run 'wsl -d $WslDistro' manually and resolve any startup errors first."
                        }
                    }

                    if ($WslBuildDir -match '^/mnt/') {
                        $problems += @{
                            Message = "-WslBuildDir '$WslBuildDir' is under /mnt/ (a Windows drive mounted into WSL via drvfs/9p)."
                            Remedy  = "This benchmark intentionally requires the WSL build tree to live on WSL's native filesystem (e.g. under `$HOME), not on a mounted NTFS drive, so filesystem timings are a fair Linux-native comparison. Clone/build the tree under, e.g., ~/llvm-perf-test-wsl instead."
                        }
                    }
                    else {
                        $wslLitCheck = Invoke-Wsl -Distro $WslDistro -Command "test -x '$WslBuildDir/bin/llvm-lit' && test -x '$WslBuildDir/bin/FileCheck' && echo FOUND || echo MISSING"
                        if ($wslLitCheck -notmatch 'FOUND') {
                            $problems += @{
                                Message = "WSL build tree at '$WslBuildDir' is missing or missing bin/llvm-lit or bin/FileCheck."
                                Remedy  = "Run the setup script to build it automatically: .\setup.ps1 -WslDistro $WslDistro -WslBuildDir `"$WslBuildDir`"`nSee README.md for what it does and its own prerequisites."
                            }
                        }
                    }
                }
            }
        }
    }

    if ($Defender -in @('Exclude', 'Compare')) {
        if (-not (Test-IsAdministrator)) {
            $problems += @{
                Message = "-Defender $Defender requires an elevated (Administrator) PowerShell session."
                Remedy  = "Re-run this script from an Administrator PowerShell prompt, or use -Defender Skip."
            }
        }
        elseif (-not (Get-Command Get-MpPreference -ErrorAction SilentlyContinue)) {
            $problems += @{
                Message = "The Windows Defender PowerShell cmdlets (Get-MpPreference/Add-MpPreference) are not available on this machine."
                Remedy  = "-Defender Exclude/Compare requires Windows Defender to be installed and its PowerShell module present. Use -Defender Skip if you are running a third-party AV or Defender is disabled/unavailable."
            }
        }
    }

    return $problems
}

function Get-Capabilities {
    <# Detects cores/memory/disk on both sides and derives a shared, comparable parallelism value. #>
    param(
        [Parameter(Mandatory)][string]$WinBuildDir,
        [string]$WslDistro,
        [string]$WslBuildDir,
        [switch]$SkipWSL
    )

    $winCores = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
    $winMemGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
    $winDrive = (Resolve-Path $WinBuildDir).Path.Substring(0, 2)
    $winFreeGB = [math]::Round((Get-PSDrive $winDrive.TrimEnd(':')).Free / 1GB, 1)

    $result = [ordered]@{
        WinCores  = $winCores
        WinMemGB  = $winMemGB
        WinFreeGB = $winFreeGB
        WslCores  = $null
        WslMemGB  = $null
        WslFreeGB = $null
        SharedJ   = $null
    }

    if (-not $SkipWSL) {
        $wslCores = [int](Invoke-Wsl -Distro $WslDistro -Command 'nproc').Trim()
        $wslMemBytes = [int64](Invoke-Wsl -Distro $WslDistro -Command "cat /proc/meminfo | head -1 | tr -s ' ' | cut -d' ' -f2").Trim()
        $wslMemGB = [math]::Round(($wslMemBytes * 1KB) / 1GB, 1)
        $wslFreeBytes = [int64](Invoke-Wsl -Distro $WslDistro -Command "df -B1 --output=avail '$WslBuildDir' | tail -1").Trim()
        $wslFreeGB = [math]::Round($wslFreeBytes / 1GB, 1)

        $result.WslCores = $wslCores
        $result.WslMemGB = $wslMemGB
        $result.WslFreeGB = $wslFreeGB

        $coreCap = [math]::Min($winCores, $wslCores)
        $memCap = [math]::Floor([math]::Min($winMemGB, $wslMemGB) / 1.5)
        $result.SharedJ = [math]::Max(1, [math]::Min($coreCap, $memCap))
    }
    else {
        $result.SharedJ = [math]::Max(1, $winCores)
    }

    return $result
}

function Invoke-SpawnMicrobench {
    <# Measures raw process-creation overhead: spawn a trivial child process N times, sequentially. #>
    param(
        [int]$Iterations = 200,
        [string]$WslDistro,
        [switch]$SkipWSL
    )

    $winSw = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt $Iterations; $i++) {
        & $env:ComSpec /c exit 0 | Out-Null
    }
    $winSw.Stop()

    $wslSeconds = $null
    if (-not $SkipWSL) {
        $wslSw = [System.Diagnostics.Stopwatch]::StartNew()
        Invoke-Wsl -Distro $WslDistro -Command "for i in `$(seq 1 $Iterations); do /bin/true; done" | Out-Null
        $wslSw.Stop()
        $wslSeconds = [math]::Round($wslSw.Elapsed.TotalSeconds, 2)
    }

    return [ordered]@{
        Test       = "Process spawn x$Iterations"
        WinSeconds = [math]::Round($winSw.Elapsed.TotalSeconds, 2)
        WslSeconds = $wslSeconds
    }
}

function Invoke-FileMicrobench {
    <# Measures filesystem metadata overhead: create then delete N one-byte files. WSL side uses the
       native filesystem under the WSL build dir's parent (never /mnt/...). #>
    param(
        [int]$FileCount = 2000,
        [string]$WslDistro,
        [string]$WslBuildDir,
        [switch]$SkipWSL
    )

    $winDir = Join-Path $env:TEMP ("bench-fs-{0}" -f ([guid]::NewGuid().ToString('N')))
    New-Item -ItemType Directory -Path $winDir -Force | Out-Null
    $bytes = [byte[]](1)
    $winSw = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt $FileCount; $i++) {
        [System.IO.File]::WriteAllBytes((Join-Path $winDir "f$i.tmp"), $bytes)
    }
    for ($i = 0; $i -lt $FileCount; $i++) {
        [System.IO.File]::Delete((Join-Path $winDir "f$i.tmp"))
    }
    $winSw.Stop()
    Remove-Item -Path $winDir -Recurse -Force -ErrorAction SilentlyContinue

    $wslSeconds = $null
    if (-not $SkipWSL) {
        $wslDir = "`$(dirname '$WslBuildDir')/bench-fs-$([guid]::NewGuid().ToString('N'))"
        $cmd = "mkdir -p $wslDir && cd $wslDir && for i in `$(seq 1 $FileCount); do : > f`$i.tmp; done && for i in `$(seq 1 $FileCount); do rm -f f`$i.tmp; done && cd / && rm -rf $wslDir"
        $wslSw = [System.Diagnostics.Stopwatch]::StartNew()
        Invoke-Wsl -Distro $WslDistro -Command $cmd | Out-Null
        $wslSw.Stop()
        $wslSeconds = [math]::Round($wslSw.Elapsed.TotalSeconds, 2)
    }

    return [ordered]@{
        Test       = "Create+delete $FileCount 1-byte files"
        WinSeconds = [math]::Round($winSw.Elapsed.TotalSeconds, 2)
        WslSeconds = $wslSeconds
    }
}

function Invoke-LitBench {
    <#
        Runs llvm-lit against a given relative test path inside each build tree.
        Returns wall time, lit-reported testing time, and pass/fail counts.
        Failures are NOT treated as harness errors - they are recorded as data.
    #>
    param(
        [Parameter(Mandatory)][string]$SuiteName,
        [Parameter(Mandatory)][string]$RelativeTestPath,
        [Parameter(Mandatory)][string]$WinBuildDir,
        [string]$WslDistro,
        [string]$WslBuildDir,
        [int]$Parallelism = 4,
        [switch]$SkipWSL
    )

    $winLit = Join-Path $WinBuildDir 'bin\llvm-lit.cmd'
    $winTestPath = Join-Path $WinBuildDir $RelativeTestPath
    # NOTE: lit's "-q" (quiet) mode suppresses the Passed/Failed/Unsupported
    # breakdown lines entirely - only "Total Discovered Tests" is printed.
    # We omit -q (and instead redirect the per-test progress-bar output,
    # which we don't parse) so the summary breakdown is always present.
    $winSw = [System.Diagnostics.Stopwatch]::StartNew()
    $winOutput = & $winLit --time-tests -j $Parallelism $winTestPath 2>&1 | Out-String
    $winExit = $LASTEXITCODE
    $winSw.Stop()

    $winTesting = $null
    if ($winOutput -match 'Testing Time:\s*([0-9.]+)s') { $winTesting = [double]$Matches[1] }
    $winTotal = 0; $winPass = 0; $winFail = 0
    if ($winOutput -match 'Total Discovered Tests:\s*(\d+)') { $winTotal = [int]$Matches[1] }
    if ($winOutput -match 'Passed\s*:\s*(\d+)') { $winPass = [int]$Matches[1] }
    if ($winOutput -match 'Failed\s*:\s*(\d+)') { $winFail = [int]$Matches[1] }

    $result = [ordered]@{
        Suite         = $SuiteName
        WinWallSec    = [math]::Round($winSw.Elapsed.TotalSeconds, 2)
        WinTestingSec = $winTesting
        WinTotal      = $winTotal
        WinPass       = $winPass
        WinFail       = $winFail
        WinExitCode   = $winExit
        WslWallSec    = $null
        WslTestingSec = $null
        WslTotal      = $null
        WslPass       = $null
        WslFail       = $null
        WslExitCode   = $null
    }

    if (-not $SkipWSL) {
        $wslTestPath = "$WslBuildDir/$($RelativeTestPath -replace '\\','/')"
        $cmd = "cd '$WslBuildDir' && bin/llvm-lit --time-tests -j $Parallelism '$wslTestPath'; echo EXITCODE:`$?"
        $wslSw = [System.Diagnostics.Stopwatch]::StartNew()
        $wslOutput = Invoke-Wsl -Distro $WslDistro -Command $cmd
        $wslSw.Stop()

        $wslExit = $null
        if ($wslOutput -match 'EXITCODE:(\d+)') { $wslExit = [int]$Matches[1] }
        $wslTesting = $null
        if ($wslOutput -match 'Testing Time:\s*([0-9.]+)s') { $wslTesting = [double]$Matches[1] }
        $wslTotal = 0; $wslPass = 0; $wslFail = 0
        if ($wslOutput -match 'Total Discovered Tests:\s*(\d+)') { $wslTotal = [int]$Matches[1] }
        if ($wslOutput -match 'Passed\s*:\s*(\d+)') { $wslPass = [int]$Matches[1] }
        if ($wslOutput -match 'Failed\s*:\s*(\d+)') { $wslFail = [int]$Matches[1] }

        $result.WslWallSec = [math]::Round($wslSw.Elapsed.TotalSeconds, 2)
        $result.WslTestingSec = $wslTesting
        $result.WslTotal = $wslTotal
        $result.WslPass = $wslPass
        $result.WslFail = $wslFail
        $result.WslExitCode = $wslExit
    }

    return $result
}

function Get-DefenderExclusionState {
    param([Parameter(Mandatory)][string]$Path)
    $prefs = Get-MpPreference
    $isExcluded = $false
    if ($prefs.ExclusionPath) {
        foreach ($p in $prefs.ExclusionPath) {
            if ($Path.StartsWith($p, [StringComparison]::OrdinalIgnoreCase)) { $isExcluded = $true; break }
        }
    }
    return [ordered]@{
        RealTimeProtectionEnabled = -not $prefs.DisableRealtimeMonitoring
        PathAlreadyExcluded       = $isExcluded
    }
}

Export-ModuleMember -Function *
