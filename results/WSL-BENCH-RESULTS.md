# LLVM Windows-vs-WSL performance benchmark result

Run timestamp (local): 2026-09-10_20-32-16
Mode: Tight
Windows build tree: D:\llvm-perf-test-win\build-release
WSL (Ubuntu-24.04) build tree: /home/marcpe/llvm-perf-test-wsl/build-release
Shared lit parallelism (-j): 4
Defender option: Skip (not checked (Defender option = Skip))

## Environment

| Metric | Windows | WSL |
|---|---:|---:|
| Logical cores | 18 | 18 |
| Memory (GB) | 14.4 | 6.9 |
| Free disk at build dir (GB) | 50.4 | 926.6 |

## Microbenchmarks

| Test | Windows (s) | WSL (s) | Ratio (Win/WSL) |
|---|---:|---:|---:|
| Process spawn x200 | 2.92 | 0.12 | 24.33 |
| Create+delete 2000 1-byte files | 0.65 | 0.12 | 5.42 |

## Lit test-suite result(s)

| Suite | Win wall (s) | WSL wall (s) | Wall ratio | Win tests (P/F/total) | WSL tests (P/F/total) |
|---|---:|---:|---:|---:|---:|
| LLVM::tools/llvm-reduce | 121.09 | 30.77 | 3.94 | 174/0/205 | 175/0/205 |

## Summary (measured facts, no analysis)

- Process spawn x200: Windows 2.92s, WSL 0.12s.
- File create+delete x2000: Windows 0.65s, WSL 0.12s.
- LLVM::tools/llvm-reduce: Windows wall 121.09s (174 passed / 0 failed of 205); WSL wall 30.77s (175 passed / 0 failed of 205).
