<#
.SYNOPSIS
    Reproduces the lit-inproc-builtins before/after comparison: runs the
    same 400-file synthetic lit test suite once under unmodified
    (but spawn-count-instrumented) lit, and once under the local fork that
    adds in-process 'true'/'false'/'count' builtins, reporting wall-clock
    time and real process-spawn counts for both.

.DESCRIPTION
    Each synthetic test file contains 5 RUN lines mirroring the measured
    average RUN-line density of clang/test (~5 lines/file):
        RUN: true
        RUN: false || true
        RUN: echo hello-N | count 1
        RUN: not false
        RUN: true
    'not false' is deliberately included as a control: current upstream lit
    (23.1.1, i.e. current llvm-project) already runs plain 'not' (without
    --crash) in-process, so this line's cost should already be near-zero on
    both sides and is not part of the claimed improvement.

.NOTES
    Run build-tools.ps1 first to compile true.exe/false.exe/count.exe, which
    the *baseline* run needs on PATH (the optimized fork does not need them
    for the three inlined tools, but still needs a real 'echo'-equivalent
    external hop and, incidentally, still benefits from them being present
    since they're simply unused when inlined).
#>
param(
    [int]$Trials = 3,
    [int]$Jobs = 1
)

$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
$suite = Join-Path $here "synthetic-suite"
$tools = Join-Path $here "synthetic-tools"
$optRoot = $here
$baseRoot = Join-Path (Split-Path $here -Parent) "lit-baseline-instrumented"

if (-not (Test-Path (Join-Path $tools "true.exe"))) {
    & (Join-Path $tools "build-tools.ps1")
}

$env:PATH = "$tools;$env:PATH"

function Invoke-LitTrial {
    param([string]$Root, [string]$Label)
    $countFile = Join-Path $env:TEMP "$Label.spawncount.txt"
    Remove-Item $countFile -ErrorAction SilentlyContinue
    $env:LIT_SPAWN_COUNT_FILE = $countFile
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    python -c "import sys; sys.path.insert(0, r'$Root'); sys.argv=['lit', r'$suite', '-j$Jobs', '-q']; import lit.main; lit.main.main()" | Out-Null
    $sw.Stop()
    # lit runs the actual test execution in a worker pool process even at
    # -j1; both the main driver process and the worker process load this
    # module and register their own atexit dump, so sum all recorded lines
    # rather than assuming a single writer.
    $spawns = (Get-Content $countFile | Measure-Object -Sum).Sum
    [PSCustomObject]@{
        Label   = $Label
        Seconds = [math]::Round($sw.Elapsed.TotalSeconds, 2)
        Spawns  = $spawns
    }
}

Write-Host "Running $Trials baseline trial(s) (unmodified lit, spawn-count instrumented only)..."
$baselineResults = 1..$Trials | ForEach-Object { Invoke-LitTrial $baseRoot "baseline_$_" }

Write-Host "Running $Trials optimized trial(s) (true/false/count as in-process builtins)..."
$optResults = 1..$Trials | ForEach-Object { Invoke-LitTrial $optRoot "opt_$_" }

$baselineResults + $optResults | Format-Table -AutoSize

$avgBase = ($baselineResults | Measure-Object -Property Seconds -Average).Average
$avgOpt = ($optResults | Measure-Object -Property Seconds -Average).Average
$spawnBase = $baselineResults[0].Spawns
$spawnOpt = $optResults[0].Spawns

Write-Host ""
Write-Host ("Average wall time : baseline={0:N2}s  optimized={1:N2}s  ({2:N1}x faster)" -f $avgBase, $avgOpt, ($avgBase / $avgOpt))
Write-Host ("Real process spawns per run : baseline={0}  optimized={1}  ({2:N1}x fewer)" -f $spawnBase, $spawnOpt, ($spawnBase / $spawnOpt))
