# llvm-win-wsl-perf-bench

A small, repeatable PowerShell benchmark that re-measures the Windows-vs-WSL
performance gap found while investigating why LLVM's Windows CI test stage
takes far longer than Linux/macOS. Re-run it over time (OS updates, tool
updates, Defender changes, WSL kernel updates) to track whether the gap
changes, via a quick comparison table rather than a full CI-scale run.

## Why this exists

An earlier investigation found Windows consistently 2.9x-3.7x slower than
WSL on equivalent LLVM test-suite runs, driven mainly by:

- Raw process-spawn overhead (Windows process creation vs. Linux `fork`/`exec`).
- NTFS metadata overhead on many small file creates/deletes (lit tests do this a lot).
- Windows Defender real-time scanning likely amplifying both.

This tool turns those three measurements into a repeatable script, so you
can re-run one command later and get a directly comparable table instead
of redoing the investigation by hand.

## Two scripts

- **`setup.ps1`** — one-shot, resilient environment prep. Clones and
  builds the Windows and WSL LLVM reference trees `bench.ps1` needs. Run
  once per machine (safe to re-run if interrupted — it resumes rather
  than starting over; pass `-Force` to rebuild from scratch).
- **`bench.ps1`** — the actual benchmark. Fast (seconds-to-minutes),
  repeatable, and never builds or installs anything itself — it only
  measures whatever build trees already exist. The one opt-in exception:
  `-Defender Exclude`/`-Defender Compare` can add/remove a Windows
  Defender path exclusion, only if you ask for it.

If `bench.ps1`'s prerequisite checks fail (e.g. no build tree yet), it
prints the exact problem and points you at `setup.ps1` rather than trying
to fix anything itself.

## Quick start

```powershell
# 1. One-time setup (from a "Developer PowerShell for VS <year>" shell, needed for clang-cl):
.\setup.ps1

# 2. Run the benchmark (repeat as often as you like):
.\bench.ps1 -Mode Tight
```

If you used `setup.ps1`'s default paths, `bench.ps1`'s defaults already
match, so no further flags are needed.

## `setup.ps1`

Checks/builds, in order: `git`/`cmake`/`ninja`/`clang-cl` on `PATH` (errors
with install instructions if missing, does not install them); WSL2 +
requested distro registered and reachable (unless `-SkipWSL`); installs
`build-essential cmake ninja-build clang lld git` inside the distro;
clones LLVM (shallow) and checks out `-Commit` on both sides; configures
and builds `check-llvm check-clang check-lld` once on Windows, then
repeats on WSL's **native filesystem** (never `/mnt/...`, which would
route through the drvfs/9p bridge and defeat the comparison).

Every stage checks whether it already succeeded and skips if so, so an
interrupted run (network blip, closed lid, low disk) can just be
re-run — it resumes at the first incomplete stage. Pass `-Force` to redo
everything from scratch.

| Parameter | Default | Description |
|---|---|---|
| `-RepoUrl` | `https://github.com/llvm/llvm-project.git` | Git repository to clone. |
| `-Commit` | `main` | Branch/tag/commit checked out on **both** sides. |
| `-WinWorktreeDir` | `D:\llvm-perf-test-win` | Windows-side checkout location. |
| `-WinBuildDir` | `D:\llvm-perf-test-win\build-release` | Windows-side build location. |
| `-WslDistro` | `Ubuntu-24.04` | WSL distro name (see `wsl -l -v`). |
| `-WslWorktreeDir` | `~/llvm-perf-test-wsl` | WSL-side checkout location (native filesystem). |
| `-WslBuildDir` | `~/llvm-perf-test-wsl/build-release` | WSL-side build location. |
| `-SkipWSL` | off | Only set up the Windows side. |
| `-Jobs` | `0` (auto) | Ninja parallelism for both builds; `0` auto-detects per side. |
| `-Force` | off | Redo every stage from scratch. |

## `bench.ps1`

Runs three measurements every time, each targeting one suspected cause:

1. **Process-spawn microbenchmark** — spawns a trivial child process
   `-SpawnIterations` times, timing total wall time on each side.
2. **Filesystem microbenchmark** — creates/deletes `-FileIterations`
   1-byte files on each side (WSL always on its native filesystem).
3. **Real `llvm-lit` test-suite run(s)** — wall time and pass/fail counts
   for the same suite(s) on both sides; the number that actually matters
   for "how much slower is Windows CI", with the microbenchmarks above as
   supporting evidence for *why*.

`Tight` mode runs only `LLVM::tools/llvm-reduce` (finishes in well under 5
minutes) — chosen because the original investigation found it had the
largest individual per-test outlier gaps of any suite while still being
small (205 tests). `Full` mode runs `check-llvm`/`check-clang`/`check-lld`
in full for a fuller picture when time allows.

```powershell
# Tight mode (default, <5 min)
.\bench.ps1 -Mode Tight -WinBuildDir D:\llvm-perf-test-win\build-release -WslDistro Ubuntu-24.04 -WslBuildDir ~/llvm-perf-test-wsl/build-release

# Full mode (check-llvm + check-clang + check-lld, including failing tests as data)
.\bench.ps1 -Mode Full -WinBuildDir D:\llvm-perf-test-win\build-release -WslDistro Ubuntu-24.04 -WslBuildDir ~/llvm-perf-test-wsl/build-release

# Windows-only, and with a Defender exclusion comparison (needs Administrator):
.\bench.ps1 -Mode Tight -SkipWSL
.\bench.ps1 -Mode Tight -Defender Compare -WinBuildDir D:\llvm-perf-test-win\build-release -WslDistro Ubuntu-24.04 -WslBuildDir ~/llvm-perf-test-wsl/build-release
```

| Parameter | Default | Description |
|---|---|---|
| `-Mode` | `Tight` | `Tight` (`llvm-reduce` only) or `Full` (check-llvm/check-clang/check-lld). |
| `-WinBuildDir` | `D:\llvm-perf-test-win\build-release` | Path to the Windows LLVM build tree. |
| `-WslDistro` | `Ubuntu-24.04` | WSL distro name. |
| `-WslBuildDir` | `~/llvm-perf-test-wsl/build-release` | Path (inside WSL) to the build tree; must not be under `/mnt/`. |
| `-Defender` | `Skip` | `Skip` (report only), `Exclude` (add exclusion), `Compare` (run twice, toggling exclusion, then restore). |
| `-SkipWSL` | off | Windows-only subset. |
| `-SpawnIterations` | `200` | Iterations for the process-spawn microbenchmark. |
| `-FileIterations` | `2000` | File count for the filesystem microbenchmark. |
| `-OutputDir` | `.\results` | Where timestamped `.md`/`.csv` reports are written. |

Each run writes a timestamped Markdown+CSV report to `-OutputDir` (one CSV
row per measurement, for easy historical diffing). Committed examples live
in `results/samples/`. The report's Summary section states only measured
facts — no conclusions; that's left to you or the original investigation
report. To check whether a change helped, diff CSVs from before/after runs
on the same machine/mode/commit.

## Sample results (from `results/samples/`)

**Environment for both sample runs:** 18 logical cores both sides; 14.4 GB
RAM (Windows) vs 6.9 GB (WSL); 55 GB free disk (Windows) vs 927 GB (WSL).

### Tight mode (`example-tight-run.md`, `-j 4`)

| Test | Windows | WSL | Ratio (Win/WSL) |
|---|---:|---:|---:|
| Process spawn x200 | 3.06 s | 0.13 s | 23.5x |
| Create+delete 2000 1-byte files | 0.76 s | 0.12 s | 6.3x |
| `LLVM::tools/llvm-reduce` wall time | 126.15 s | 31.69 s | 4.0x |
| `LLVM::tools/llvm-reduce` pass/fail/total | 174/0/205 | 175/0/205 | — |

### Full mode (`example-full-run.md`, `-j 4`)

| Test | Windows | WSL | Ratio (Win/WSL) |
|---|---:|---:|---:|
| Process spawn x200 | 3.25 s | 0.12 s | 27.1x |
| Create+delete 2000 1-byte files | 0.69 s | 0.11 s | 6.3x |
| `check-llvm` wall time | 1226.62 s | 152.5 s | 8.0x |
| `check-llvm` pass/fail/total | 34588/46/77249 | 34766/46/77281 | — |
| `check-clang` wall time | 4233.22 s | 929.1 s | 4.6x |
| `check-clang` pass/fail/total | 48939/32/54547 | 49295/26/54639 | — |
| `check-lld` wall time | 70.83 s | 42.06 s | 1.7x |
| `check-lld` pass/fail/total | 527/0/3255 | 534/0/3255 | — |

## Troubleshooting

| Symptom | Fix |
|---|---|
| Missing build tree | Run `.\setup.ps1`, or pass the correct `-WinBuildDir`/`-WslBuildDir`. |
| `setup.ps1` fails at `clang-cl` check | Run from a "Developer PowerShell for VS <year>" shell, or install the Clang VS component. |
| `setup.ps1` fails installing WSL apt packages | Configure passwordless `sudo`, or run the printed `apt-get install` manually. |
| WSL build tree check fails with `/mnt/` error | Point `-WslBuildDir`/`-WslWorktreeDir` at a path under WSL's own `$HOME`, not a Windows mount. |
| `-Defender Exclude`/`Compare` fails immediately | Requires an elevated (Administrator) PowerShell session. |
| Numbers vary a lot between runs | Close other CPU/disk-heavy apps; prefer `-Mode Full` when precision matters more than speed. |

## Design notes

PowerShell only (no Python in any code written for this repo) — `llvm-lit`
itself is Python, but it's invoked as a black box since it's the actual
driver LLVM's real CI uses; substituting it would stop the benchmark being
representative. Command-line only, no GUI/prompts. Windows and WSL are
capped to the same shared lit `-j` value (auto-detected from logical cores
and memory on each side) so a fast run isn't just "whichever side has more
cores".
