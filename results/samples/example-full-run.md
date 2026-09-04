# LLVM Windows-vs-WSL performance benchmark result

Run timestamp (local): 2026-09-04_11-09-07
Mode: Full
Windows build tree: D:\llvm-perf-test-win\build-release
WSL (Ubuntu-24.04) build tree: /home/marcpe/llvm-perf-test-wsl/build-release
Shared lit parallelism (-j): 4
Defender option: Skip (not checked (Defender option = Skip))

## Environment

| Metric | Windows | WSL |
|---|---:|---:|
| Logical cores | 18 | 18 |
| Memory (GB) | 14.4 | 6.9 |
| Free disk at build dir (GB) | 55.2 | 926.8 |

## Microbenchmarks

| Test | Windows (s) | WSL (s) | Ratio (Win/WSL) |
|---|---:|---:|---:|
| Process spawn x200 | 3.25 | 0.12 | 27.08 |
| Create+delete 2000 1-byte files | 0.69 | 0.11 | 6.27 |

## Lit test-suite result(s)

| Suite | Win wall (s) | WSL wall (s) | Wall ratio | Win tests (P/F/total) | WSL tests (P/F/total) |
|---|---:|---:|---:|---:|---:|
| check-llvm (full) | 1226.62 | 152.5 | 8.04 | 34588/46/77249 | 34766/46/77281 |
| check-clang (full) | 4233.22 | 929.1 | 4.56 | 48939/32/54547 | 49295/26/54639 |
| check-lld (full) | 70.83 | 42.06 | 1.68 | 527/0/3255 | 534/0/3255 |

## Summary (measured facts, no analysis)

- Process spawn x200: Windows 3.25s, WSL 0.12s.
- File create+delete x2000: Windows 0.69s, WSL 0.11s.
- check-llvm (full): Windows wall 1226.62s (34588 passed / 46 failed of 77249); WSL wall 152.5s (34766 passed / 46 failed of 77281).
- check-clang (full): Windows wall 4233.22s (48939 passed / 32 failed of 54547); WSL wall 929.1s (49295 passed / 26 failed of 54639).
- check-lld (full): Windows wall 70.83s (527 passed / 0 failed of 3255); WSL wall 42.06s (534 passed / 0 failed of 3255).
