# llvm-win-wsl-perf-bench

A small, repeatable PowerShell benchmark that re-measures the core
Windows-vs-WSL performance gaps identified while investigating why LLVM's
Windows CI test stage takes far longer than the Linux/macOS stages. It is
meant to be re-run over time (after OS updates, tool updates, Defender
config changes, WSL kernel updates, etc.) to track whether the gap changes,
using a small comparison table rather than a full CI-scale run.

This tool does **not** build LLVM. It requires that a Windows build tree and
a WSL (native-filesystem) build tree already exist, and will refuse to run
with exact remediation instructions if they don't. It never installs or
auto-configures anything, with one narrow, opt-in exception: `-Defender
Exclude`/`-Defender Compare` can add/remove a Windows Defender path
exclusion, and only if you explicitly ask for it.

## Why this exists

An earlier investigation (`windows-vs-wsl-test-timing-report.md`) found
Windows was consistently 2.9x-3.7x slower than WSL on equivalent LLVM
test-suite runs, driven mainly by:

- Raw process-spawn overhead (Windows process creation is far more
  expensive than Linux `fork`/`exec`).
- NTFS metadata overhead on many small file creates/deletes (lit tests
  create/tear down many small files).
- Windows Defender real-time scanning likely amplifying both of the above.

This tool operationalizes those three specific measurements into a fast,
repeatable script instead of a one-off investigation, so the gap can be
tracked as a number over time.

## Why `llvm-lit` (Python) is invoked here despite "no Python"

Every file in this repository is pure PowerShell. `llvm-lit` is LLVM's own
test-suite driver and is itself implemented in Python — it is invoked here
as a black box because it is the *actual* tool whose real-world timing gap
this suite measures (the same driver LLVM's real CI uses). Swapping it out
for a non-Python substitute would stop the benchmark being representative
of the real CI gap. No code written for this repository is in Python.

## Prerequisites

This script checks all of the following itself and will print an exact
remedy (never installs/builds anything for you) if any are missing:

- PowerShell 5.1+ (Windows PowerShell 5.1, which ships with Windows, or
  PowerShell 7+).
- A pre-built Windows LLVM release-style build tree containing
  `bin\llvm-lit.cmd` and `bin\FileCheck.exe`.
- (Unless `-SkipWSL`) WSL2 installed, with a distro registered as WSL
  version 2, reachable, and a pre-built LLVM build tree on that distro's
  **native filesystem** (not under `/mnt/...`, which would go through the
  drvfs/9p bridge and defeat the point of a native-Linux-filesystem
  comparison) containing `bin/llvm-lit` and `bin/FileCheck`.
- (Only for `-Defender Exclude`/`-Defender Compare`) an elevated
  (Administrator) PowerShell session and the Defender PowerShell module
  (`Get-MpPreference`/`Add-MpPreference`).

### Building the reference trees

Both trees only need a single-stage Release build with tests built (no
LTO/PGO/PDB required — this harness only measures raw process/filesystem/
test-suite performance, not the release-packaging pipeline):

```powershell
# Windows (from a Developer/VS-tools shell with clang-cl on PATH)
git worktree add --detach D:\llvm-perf-test-win <commit-or-branch>
cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=clang-cl -DCMAKE_CXX_COMPILER=clang-cl `
  -DLLVM_USE_LINKER=lld -DLLVM_ENABLE_PROJECTS="clang;lld;clang-tools-extra" `
  -DLLVM_ENABLE_RUNTIMES="compiler-rt" -DLLVM_TARGETS_TO_BUILD=AArch64 `
  -DLLVM_INCLUDE_EXAMPLES=OFF -DLLVM_INCLUDE_BENCHMARKS=OFF `
  -S D:\llvm-perf-test-win\llvm -B D:\llvm-perf-test-win\build-release
ninja -C D:\llvm-perf-test-win\build-release check-llvm check-clang check-lld
```

```bash
# WSL - native filesystem (NOT /mnt/...)
wsl -d Ubuntu-24.04 -- bash -lc 'sudo apt-get update && sudo apt-get install -y build-essential cmake ninja-build clang lld git'
wsl -d Ubuntu-24.04 -- bash -lc 'git clone --no-hardlinks /mnt/<path-to-windows-checkout> ~/llvm-perf-test-wsl && cd ~/llvm-perf-test-wsl && git checkout <same-commit-as-windows-tree>'
wsl -d Ubuntu-24.04 -- bash -lc 'mkdir -p ~/llvm-perf-test-wsl/build-release && cd ~/llvm-perf-test-wsl/build-release && CC=clang CXX=clang++ cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DLLVM_USE_LINKER=lld -DLLVM_ENABLE_PROJECTS="clang;lld;clang-tools-extra" -DLLVM_ENABLE_RUNTIMES="compiler-rt" -DLLVM_TARGETS_TO_BUILD=AArch64 -DLLVM_INCLUDE_EXAMPLES=OFF -DLLVM_INCLUDE_BENCHMARKS=OFF ../llvm && ninja check-llvm check-clang check-lld'
```

Use the **same commit** on both sides so the comparison is apples-to-apples.

## Usage

```powershell
# Tight mode (default): finishes well under 5 minutes
.\bench.ps1 -Mode Tight -WinBuildDir D:\llvm-perf-test-win\build-release -WslDistro Ubuntu-24.04 -WslBuildDir ~/llvm-perf-test-wsl/build-release

# Full mode: check-llvm + check-clang + check-lld in full, including failing tests (recorded as data, not a script error)
.\bench.ps1 -Mode Full -WinBuildDir D:\llvm-perf-test-win\build-release -WslDistro Ubuntu-24.04 -WslBuildDir ~/llvm-perf-test-wsl/build-release

# Windows-only (no WSL side at all)
.\bench.ps1 -Mode Tight -WinBuildDir D:\llvm-perf-test-win\build-release -SkipWSL

# Include a Windows Defender exclusion for the build tree
.\bench.ps1 -Mode Tight -Defender Exclude -WinBuildDir D:\llvm-perf-test-win\build-release -WslDistro Ubuntu-24.04 -WslBuildDir ~/llvm-perf-test-wsl/build-release

# Run once with current Defender state, once with the exclusion toggled, then restore original state (needs Administrator)
.\bench.ps1 -Mode Tight -Defender Compare -WinBuildDir D:\llvm-perf-test-win\build-release -WslDistro Ubuntu-24.04 -WslBuildDir ~/llvm-perf-test-wsl/build-release
```

### Parameters

| Parameter | Default | Description |
|---|---|---|
| `-Mode` | `Tight` | `Tight` (<5 min, `llvm-reduce` subset only) or `Full` (check-llvm/check-clang/check-lld in full). |
| `-WinBuildDir` | `D:\llvm-perf-test-win\build-release` | Path to the Windows LLVM build tree. |
| `-WslDistro` | `Ubuntu-24.04` | WSL distro name (see `wsl -l -v`). |
| `-WslBuildDir` | `~/llvm-perf-test-wsl/build-release` | Path (inside WSL) to the WSL LLVM build tree. Must not be under `/mnt/`. |
| `-Defender` | `Skip` | `Skip` (report state only), `Exclude` (add and leave an exclusion), `Compare` (run twice, toggling the exclusion, then restore). |
| `-SkipWSL` | off | Run the Windows-only subset. |
| `-SpawnIterations` | `200` | Iterations for the process-spawn microbenchmark. |
| `-FileIterations` | `2000` | File count for the filesystem microbenchmark. |
| `-OutputDir` | `.\results` | Where timestamped `.md`/`.csv` reports are written. |

### Why `Tight` mode uses `llvm-reduce`

The original investigation report found `LLVM::tools/llvm-reduce` had the
single biggest individual-outlier test-time gaps (tests taking 40-47s on
Windows vs a few seconds on WSL) of any suite examined, while still being
small enough (205 discovered tests) to run in well under the 5-minute
budget. It is therefore used as the fixed, fast, representative canary for
`Tight` mode; `Full` mode covers the broader `check-llvm`/`check-clang`/
`check-lld` suites for a fuller picture when time allows.

## Output

Each run writes a timestamped Markdown report and a CSV (one row per
measurement, for easy historical diffing across repeated runs) to
`-OutputDir` (default `.\results\`). The report's final "Summary" section
states only plain measured numbers from that run — it does not draw
conclusions or attribute causes; that interpretation is left to the
original investigation report and to your own comparison across runs.

## Capability detection

The script detects logical core count, total memory, and free disk space
on both the Windows host and the WSL distro, and derives a shared lit
`-j` parallelism value (capped by the lower core count and a
memory-based heuristic of both sides) so that Windows and WSL runs use a
comparable degree of parallelism rather than each maxing out its own,
possibly very different, core count.
