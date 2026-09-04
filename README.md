# llvm-win-wsl-perf-bench

A small, repeatable PowerShell benchmark that re-measures the core
Windows-vs-WSL performance gaps identified while investigating why LLVM's
Windows CI test stage takes far longer than the Linux/macOS stages. It is
meant to be re-run over time (after OS updates, tool updates, Defender
config changes, WSL kernel updates, etc.) to track whether the gap changes,
using a small comparison table rather than a full CI-scale run.

This repository contains two scripts:

- **`setup.ps1`** - a one-shot, resilient script that clones and builds
  the Windows and WSL LLVM reference trees `bench.ps1` needs. Run this
  first, once, on a new machine (or any time you want a fresh build).
- **`bench.ps1`** - the actual benchmark. Fast, repeatable, and does not
  build or install anything itself; it only measures whatever build trees
  already exist.

Keeping these separate matters: `bench.ps1` is meant to be run over and
over, unattended, in seconds-to-minutes, to compare against past runs -
it would defeat that purpose if it also carried the risk/time cost of an
LLVM rebuild. `setup.ps1` carries that cost exactly once (and is safe to
re-run if interrupted, see below).

`bench.ps1` never installs or auto-configures anything, with one narrow,
opt-in exception: `-Defender Exclude`/`-Defender Compare` can add/remove a
Windows Defender path exclusion, and only if you explicitly ask for it.
If its prerequisite checks fail (e.g. no build tree exists yet), it prints
the exact problem and points you at `setup.ps1` rather than trying to fix
anything itself.

## Why this exists

An earlier investigation (`windows-vs-wsl-test-timing-report.md`) found
Windows was consistently 2.9x-3.7x slower than WSL on equivalent LLVM
test-suite runs, driven mainly by:

- Raw process-spawn overhead (Windows process creation is far more
  expensive than Linux `fork`/`exec`).
- NTFS metadata overhead on many small file creates/deletes (lit tests
  create/tear down many small files).
- Windows Defender real-time scanning likely amplifying both of the above.

That report was a one-off, manual investigation. This tool turns those
same three specific measurements into a fast, scriptable, repeatable
benchmark, so instead of re-doing that investigation by hand every time
something changes (a Windows update, a WSL kernel update, a new compiler,
a Defender policy change), you can just re-run one command and get a
directly comparable table of numbers. The intended workflow is: run it
once now to get a baseline, then re-run it again later (same machine,
same flags) whenever you want to know "did that change actually help?".

## Design principles

- **PowerShell only, no Python** in any code written for this repo (see
  below for the one, deliberate exception).
- **Command-line only** - no GUI, no interactive prompts, safe to run
  from a scheduled task or CI-style automation.
- **Two clearly separated speed tiers** (`Tight`/`Full`, see below) so you
  can choose between "a quick daily sanity check" and "the full picture".
- **Comparable, not maximal, parallelism** - Windows and WSL are each
  capped to the *same* shared `-j` value (see Capability detection below)
  so a fast run isn't just "whichever side happened to have more cores".
- **Never installs or builds LLVM itself** (`bench.ps1`) - it only
  measures pre-existing build trees, so a benchmark run can never
  accidentally kick off a multi-hour rebuild.
- **Resilient, idempotent setup** (`setup.ps1`) - every stage is a
  checked, skippable step, so a setup run interrupted partway through
  (network blip, closed laptop lid, etc.) can simply be re-run and will
  pick up where it left off rather than starting over.
- **Facts, not conclusions, in the output** - the generated report states
  only plain measured numbers; it does not draw conclusions about *why*
  a number is what it is. That interpretation is left to you (or to the
  original investigation report).

## Why `llvm-lit` (Python) is invoked here despite "no Python"

Every file in this repository is pure PowerShell. `llvm-lit` is LLVM's own
test-suite driver and is itself implemented in Python — it is invoked here
as a black box because it is the *actual* tool whose real-world timing gap
this suite measures (the same driver LLVM's real CI uses). Swapping it out
for a non-Python substitute would stop the benchmark being representative
of the real CI gap. No code written for this repository is in Python.

## Quick start

```powershell
# 1. One-time setup: clones + builds the Windows and WSL reference trees.
#    Safe to re-run if interrupted - it resumes rather than starting over.
#    From a "Developer PowerShell for VS <year>" shell (needed for clang-cl):
.\setup.ps1

# 2. Run the benchmark (repeat this as often as you like - it's the fast part):
.\bench.ps1 -Mode Tight
```

That's it for the default case. Everything below covers customizing paths,
distros, modes, and the optional Defender comparison.

## `setup.ps1`: one-shot environment preparation

`setup.ps1` exists so nobody has to hand-run the multi-step "build LLVM
twice, once per OS" instructions that this kind of benchmark otherwise
requires. Run it once per machine (or again later if you want a fresh
build, e.g. to track a new commit).

### What it does, step by step

1. Checks `git`, `cmake`, `ninja` are on `PATH` (errors with install
   instructions if not - it does not install these itself).
2. Checks `clang-cl` is on `PATH` (errors with instructions to use a
   Developer PowerShell / install the Clang component if not).
3. If not `-SkipWSL`: checks `wsl.exe` exists, the requested distro is
   registered as WSL **version 2**, and it's reachable. Errors with exact
   `wsl --install` instructions if not — it does not install WSL itself
   (that needs a reboot) or a distro.
4. If not `-SkipWSL`: installs the small set of Linux packages needed
   inside the (already-installed) WSL distro: `build-essential cmake
   ninja-build clang lld git`. This is the one thing `setup.ps1` installs
   automatically, since it's a normal, low-risk, non-interactive `apt-get
   install` inside an already-running distro rather than a change to the
   Windows host.
5. Clones LLVM (shallow, blob-filtered) into the Windows worktree
   directory and checks out `-Commit` (default `main`).
6. Configures the Windows build with CMake/Ninja/clang-cl (Release, no
   LTO/PGO/PDB - this harness only measures raw test-suite/process/
   filesystem performance, not the release-packaging pipeline).
7. Builds `check-llvm check-clang check-lld` once on Windows (this both
   builds the tools and runs the full test suite one time, so `bench.ps1`
   can just re-run `llvm-lit` against already-built binaries afterwards).
8. Repeats steps 5-7 inside WSL, on WSL's **native filesystem** (never
   under `/mnt/...` - see "native filesystem" note below).
9. Re-runs `bench.ps1`'s own prerequisite check and reports whether
   everything is now ready, printing the exact `bench.ps1` command to
   run next.

### Resilience to interruption / partial previous runs

Every stage above first checks whether it already succeeded (checkout
present, `build.ninja` present, `llvm-lit`/`FileCheck` binaries present)
and skips straight past it if so. This means:

- If your last run was interrupted (network drop, closed laptop lid,
  ran out of disk mid-build), just run `.\setup.ps1` again with the same
  arguments - it resumes at the first incomplete stage instead of
  starting from scratch.
- Ninja's own incremental build cache means even a resumed *build* stage
  (as opposed to a stage that hadn't started at all) picks up quickly
  rather than recompiling everything.
- Pass **`-Force`** to ignore all of that and redo every stage from
  scratch regardless (e.g. to pick up a new commit into an existing
  worktree, or if you suspect the existing tree is corrupted).

### `setup.ps1` parameters

| Parameter | Default | Description |
|---|---|---|
| `-RepoUrl` | `https://github.com/llvm/llvm-project.git` | Git repository to clone. |
| `-Commit` | `main` | Branch/tag/commit checked out on **both** sides, so the comparison is apples-to-apples. |
| `-WinWorktreeDir` | `D:\llvm-perf-test-win` | Where the Windows-side checkout is cloned. |
| `-WinBuildDir` | `D:\llvm-perf-test-win\build-release` | Where the Windows-side tree is configured/built. Pass this same path to `bench.ps1 -WinBuildDir`. |
| `-WslDistro` | `Ubuntu-24.04` | WSL distro name (see `wsl -l -v`). |
| `-WslWorktreeDir` | `~/llvm-perf-test-wsl` | Where (inside WSL, native filesystem) the WSL-side checkout is cloned. |
| `-WslBuildDir` | `~/llvm-perf-test-wsl/build-release` | Where (inside WSL) the WSL-side tree is configured/built. Pass this same path to `bench.ps1 -WslBuildDir`. |
| `-SkipWSL` | off | Only set up the Windows side. |
| `-Jobs` | `0` (auto) | ninja parallelism for both builds. `0` auto-detects from logical core count on each side. |
| `-Force` | off | Redo every stage from scratch, ignoring any already-completed state. |

### Example

```powershell
# Set up against a specific release branch, Windows-only, explicit paths:
.\setup.ps1 -Commit release/19.x -SkipWSL -WinWorktreeDir E:\llvm-win -WinBuildDir E:\llvm-win\build

# Re-run later to pick up a newer commit into the same trees:
.\setup.ps1 -Commit main -Force
```

## Prerequisites (checked, never silently installed, by `bench.ps1`)

`bench.ps1` itself checks all of the following and will print an exact
remedy (pointing at `setup.ps1` where applicable) if any are missing,
rather than installing/building anything:

- PowerShell 5.1+ (Windows PowerShell 5.1, which ships with Windows, or
  PowerShell 7+).
- A pre-built Windows LLVM release-style build tree containing
  `bin\llvm-lit.cmd` and `bin\FileCheck.exe` (`setup.ps1` builds this).
- (Unless `-SkipWSL`) WSL2 installed, with a distro registered as WSL
  version 2, reachable, and a pre-built LLVM build tree on that distro's
  **native filesystem** (not under `/mnt/...`, which would go through the
  drvfs/9p bridge and defeat the point of a native-Linux-filesystem
  comparison) containing `bin/llvm-lit` and `bin/FileCheck` (`setup.ps1`
  builds this too).
- (Only for `-Defender Exclude`/`-Defender Compare`) an elevated
  (Administrator) PowerShell session and the Defender PowerShell module
  (`Get-MpPreference`/`Add-MpPreference`).

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

If you used `setup.ps1` with its default paths, you don't need to pass
`-WinBuildDir`/`-WslDistro`/`-WslBuildDir` at all - `bench.ps1`'s defaults
already match `setup.ps1`'s defaults.

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

## What each measurement actually captures

`bench.ps1` runs three kinds of measurement every time (regardless of
`-Mode`), each targeting one of the three suspected causes from the
original investigation:

1. **Process-spawn microbenchmark** - spawns a trivial child process
   `-SpawnIterations` times, sequentially, timing the total wall time on
   each side. Isolates raw OS process-creation overhead (Windows
   `CreateProcess` vs. Linux `fork`/`exec`) from anything LLVM-specific.
2. **Filesystem microbenchmark** - creates then deletes
   `-FileIterations` one-byte files on each side (WSL side always on its
   native filesystem, never `/mnt/...`). Isolates filesystem metadata
   overhead (NTFS vs. ext4) from process-spawn cost, since lit tests
   create and tear down many small files per test.
3. **Real `llvm-lit` test-suite run(s)** - the actual CI-relevant
   measurement: wall time and pass/fail counts for the same lit-driven
   test suite(s) on both sides. This is the number that actually matters
   for "how much slower is Windows CI", with the two microbenchmarks
   above providing supporting evidence for *why*.

## Output

Each run writes a timestamped Markdown report and a CSV (one row per
measurement, for easy historical diffing across repeated runs) to
`-OutputDir` (default `.\results\`). Individual timestamped result files
are gitignored by default (they're specific to your own machine/run), but
`results/samples/` contains two committed example outputs from a real run
on one machine (`example-tight-run.md`/`.csv` and `example-full-run.md`/
`.csv`) so you can see the exact report shape without running it first.
The report's final "Summary" section states only plain measured numbers
from that run — it does not draw conclusions or attribute causes; that
interpretation is left to the original investigation report and to your
own comparison across runs.

To track whether a change (OS update, Defender policy, new compiler,
etc.) actually helped, diff the CSVs from two runs taken before/after the
change - same machine, same `-Mode`, same build-tree commit ideally.

## Capability detection

The script detects logical core count, total memory, and free disk space
on both the Windows host and the WSL distro, and derives a shared lit
`-j` parallelism value (capped by the lower core count and a
memory-based heuristic of both sides) so that Windows and WSL runs use a
comparable degree of parallelism rather than each maxing out its own,
possibly very different, core count.

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `bench.ps1` reports a missing build tree | Run `.\setup.ps1` (see above), or pass the correct `-WinBuildDir`/`-WslBuildDir` if you built manually elsewhere. |
| `setup.ps1` fails at the `clang-cl` check | Run it from a "Developer PowerShell for VS <year>" shell, or install the "C++ Clang Compiler for Windows" VS component. |
| `setup.ps1` fails installing WSL apt packages | `sudo` inside your distro may require an interactive password; configure passwordless `sudo` for your user, or run the printed `apt-get install` command manually inside WSL first. |
| WSL build tree check fails with an `/mnt/` error | You pointed `-WslBuildDir`/`-WslWorktreeDir` at a Windows-mounted path. Use a path under WSL's own `$HOME` instead (the default). |
| `-Defender Exclude`/`Compare` fails immediately | Requires an elevated (Administrator) PowerShell session; re-run from one. |
| Numbers vary a lot between runs | Close other CPU/disk-heavy applications, and prefer `-Mode Full` (larger sample) over `-Mode Tight` when precision matters more than speed. |
