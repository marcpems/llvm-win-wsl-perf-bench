<#
.SYNOPSIS
    Compiles minimal native true/false/count executables that faithfully
    reproduce the real LLVM/coreutils tools' semantics, so the *baseline*
    (unmodified lit) run in this experiment spawns genuine, representative
    processes rather than something synthetic/unrealistic.

    count.c is a line-for-line port of llvm/utils/count/count.c (reads all
    of stdin, counts '\n' bytes, compares against the single required
    numeric argument). true.c/false.c just return 0/1.

.NOTES
    Requires a C compiler on PATH. Any of clang, cl, or gcc will do; this
    repo's setup already installs LLVM's own clang, so that is used here.
#>
param(
    [string]$Compiler = "clang"
)

$ErrorActionPreference = "Stop"
$here = $PSScriptRoot

foreach ($name in @("true", "false", "count")) {
    $src = Join-Path $here "$name.c"
    $exe = Join-Path $here "$name.exe"
    & $Compiler -O2 -o $exe $src
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to compile $src"
    }
}

Write-Host "Built true.exe, false.exe, count.exe in $here"
