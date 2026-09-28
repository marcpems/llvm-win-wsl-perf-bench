# CI perf-bench result: windows-arm64

Timestamp (UTC): 2026-09-28_06-36-28 | LLVM commit/ref: main

## Machine spec

| Field | Value |
|---|---|
| Os | Windows |
| OsVersion | Microsoft Windows 11 Enterprise (10.0.26200) |
| Architecture | Arm64 |
| CpuModel | Cobalt 100 |
| PhysicalCores | 4 |
| LogicalCores | 4 |
| MemoryGB | 16 |
| FreeDiskGB | 125.7 |
| RunnerName | GitHub Actions 1000000617 |
| RunnerLabel | windows-arm64 |
| GithubRunId | 36425733436 |

## Results

| Test | Result |
|---|---:|
| Process spawn x200 | 2.98 s |
| Create+delete 2000 1-byte files | 2.23 s |
| Build (llvm-reduce + deps, -j 4) | 1470.8 s |
| lit LLVM::tools/llvm-reduce wall time | 100.69 s |
| lit LLVM::tools/llvm-reduce pass/fail/total | 167/8/206 |
