# Experiment: in-process `true` / `false` / `count` builtins for `lit`

## Why this experiment exists

Earlier analysis in this repo established that Windows process creation is
~15-25x more expensive than native Linux `fork`/`exec`, and that a full
`clang/test` run spawns on the order of ~190,000 real child processes. Since
that per-spawn cost is largely fixed (kernel-level, not configurable away —
see the `-Optimize` results in `optimize-windows-path`), the only remaining
lever with real headroom is reducing the **number** of real process spawns
`lit` performs.

**Correction to an earlier claim in this repo:** a previous investigation
here assumed `not`-wrapped `RUN:` lines were a meaningful, fully-addressable
process-spawn cost. Verifying against the actual current lit source
(`lit` 23.1.1, matching current `llvm-project@main`) shows this is no longer
accurate: plain `not <cmd>` (without `--crash`) is **already** executed
in-process by upstream lit — it just runs `<cmd>` directly and inverts the
exit code afterwards, with no separate `not` child process at all. Only
`not --crash <cmd>` still spawns the real `not` binary (correctly — signal/
crash detection needs the compiled tool). So `not` was not a fruitful target
here; this experiment instead targets three wrapper tools that are **not**
yet inlined by upstream lit: `true`, `false`, and `count`.

## What was built

A local, file-level fork of the installed `lit` 23.1.1 package
(`./lit`, copied from `site-packages` and patched — **not upstream, not
submitted to LLVM, purely a local experiment to measure a "what if"**):

- `lit/InprocBuiltins.py`: adds `executeBuiltinTrue`, `executeBuiltinFalse`
  (trivial, always return exit code 0/1), and `executeBuiltinCount`, a
  faithful line-for-line reimplementation of
  [`llvm/utils/count/count.c`](https://github.com/llvm/llvm-project/blob/main/llvm/utils/count/count.c)
  (reads all of stdin, counts `\n` bytes, compares to the required numeric
  argument).
- `lit/TestRunner.py`:
  - Registers `true`/`false` in the existing `inproc_builtins` dispatch
    table (the same mechanism upstream already uses for `cd`, `echo`,
    `mkdir`, `:`, etc.) — this required no new mechanism, just two dict
    entries, since these two tools are trivially single-command.
  - `count` needed a small amount of new plumbing: it is (almost) always
    the terminal stage of a pipeline (`RUN: ... | count N`), and the
    existing `inproc_builtins` dispatch explicitly refuses to run inside a
    pipeline. Added a narrow special case that fires only when `count` is
    the **last** stage, isn't wrapped in `not`/`env`, and reads the already
    partially-piped stdin synchronously (the same thing `communicate()`
    already does for the true last stage today) — no process is spawned for
    it, but pipeline semantics are otherwise unaffected.
  - Adds a `LIT_SPAWN_COUNT_FILE`-gated counter around the single
    `subprocess.Popen(...)` call site, so the spawn-count claim below is
    **measured**, not estimated.
- `../lit-baseline-instrumented/lit`: an unmodified copy of the same lit
  version with **only** the spawn counter added (no behavioral changes), so
  the baseline-vs-optimized spawn count comparison is apples-to-apples.

This is a local, throwaway fork for measurement purposes — it is **not** a
finished, upstreamable patch (see Limitations below).

## Test suite used

`synthetic-suite/` contains 400 generated `.test` files, each with 5 `RUN:`
lines chosen to match the previously-measured average RUN-line density of
`clang/test` (~5.25 lines/file):

```
RUN: true
RUN: false || true
RUN: echo hello-N | count 1
RUN: not false
RUN: true
```

`not false` is a deliberate control: since plain `not` is already inlined by
stock lit, this line's cost is expected to be near-identical on both sides
(it also happens to end up free in the optimized fork too, since `false` is
now itself an inproc builtin and the generic `not`-inversion dispatch picks
it up automatically — see Results).

`synthetic-tools/{true,false,count}.c` are compiled to real native `.exe`s
so that the **baseline** run spawns genuine representative processes (not
something synthetic/unrealistic) — `count.c` is the same algorithm as
LLVM's own tool.

## How to reproduce

```powershell
cd experiments/lit-inproc-builtins
./run-comparison.ps1 -Trials 3 -Jobs 1
```

(`build-tools.ps1` is run automatically if `synthetic-tools/*.exe` don't
exist yet; requires a C compiler on PATH — this repo's `setup.ps1` already
installs LLVM's own `clang`.)

## Results (measured on this machine, `-j1`, 3 trials each, all 400/400 tests pass both ways)

| | Baseline (unmodified lit) | Optimized (in-process true/false/count) | Delta |
|---|---|---|---|
| Real process spawns (`subprocess.Popen` calls) | 2,800 (exactly 7/test) | 400 (exactly 1/test — just `echo`) | **7.0x fewer** |
| Wall-clock time (avg of 3 trials) | 78.4s | 20.1s | **3.9x faster** |

The spawn counts are exact and deterministic (not estimates): 400 tests ×
7 real spawns/test in baseline (`true`, `false`+`true` via `||`, `echo`,
`count`, `false` via `not`) vs. 400 tests × 1 real spawn/test optimized
(only `echo`, which remains external in both since it's part of a pipeline
and this experiment didn't touch it).

At `-j8` the wall-time gain persists (~3.1x observed over 2 trials), though
the per-worker-process spawn-count instrumentation becomes less precise
once lit's multiprocessing worker pool is involved (each worker process
independently dumps its own partial count, and counts weren't fully
reconciled across pool shutdown in this quick check) — the `-j1` numbers
above are the reliable, exact figures.

## Limitations / what this does *not* prove

- This is a **synthetic** suite, not `clang/test` itself — no attempt was
  made to build LLVM/clang and inline these builtins there. The real-world
  gain on `clang/test` depends on how many of its ~130,875 `RUN:` lines
  actually use bare `true`/`false`/`count` (a follow-up measurement, not
  done here).
- The in-process `count` implementation takes a shortcut for pipeline
  correctness: if `count` were *not* the last pipeline stage (an unusual,
  arguably nonsensical usage), it silently falls back to spawning the real
  external tool — that path is untested here since it isn't exercised by
  the synthetic suite.
- Diagnostic completeness on failure: for a non-last pipeline stage whose
  output is later consumed by an in-process `count`, this fork reads that
  stage's stdout once during count evaluation; lit's own later
  diagnostic-dump code path (used only when a test fails) may then see an
  already-drained stream for that specific stage. Not exercised in this
  experiment (all synthetic tests pass), but relevant if this idea were
  taken further.
- Not a proposed upstream patch — no LLVM community review, no full lit
  test-suite regression run against lit's own test suite, and the `count`
  special-case bypasses the general pipeline-execution path rather than
  properly generalizing "in-process builtin as pipeline terminal" for
  every builtin. A real upstream change would need to generalize that
  properly rather than special-case one tool.
