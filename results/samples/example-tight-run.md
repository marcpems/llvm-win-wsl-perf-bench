# LLVM Windows-vs-WSL performance benchmark result

Run timestamp (local): 2026-09-04_09-12-56
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
| Free disk at build dir (GB) | 55.2 | 926.9 |

## Microbenchmarks

| Test | Windows (s) | WSL (s) | Ratio (Win/WSL) |
|---|---:|---:|---:|
| Process spawn x200 | 3.06 | 0.13 | 23.54 |
| Create+delete 2000 1-byte files | 0.76 | 0.12 | 6.33 |

## Lit test-suite result(s)

| Suite | Win wall (s) | WSL wall (s) | Wall ratio | Win tests (P/F/total) | WSL tests (P/F/total) |
|---|---:|---:|---:|---:|---:|
| LLVM::tools/llvm-reduce | 126.15 | 31.69 | 3.98 | 174/0/205 | 175/0/205 |

## Summary (measured facts, no analysis)

- Process spawn x200: Windows 3.06s, WSL 0.13s.
- File create+delete x2000: Windows 0.76s, WSL 0.12s.
- LLVM::tools/llvm-reduce: Windows wall 126.15s (174 passed / 0 failed of 205); WSL wall 31.69s (175 passed / 0 failed of 205).
