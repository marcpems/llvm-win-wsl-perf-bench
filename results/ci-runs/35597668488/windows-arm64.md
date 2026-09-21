# CI perf-bench result: windows-arm64

Timestamp (UTC): 2026-09-21_05-40-30 | LLVM commit/ref: main

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
| FreeDiskGB | 122.6 |
| RunnerName | GitHub Actions 1000000562 |
| RunnerLabel | windows-arm64 |
| GithubRunId | 35597668488 |

## Results

| Test | Result |
|---|---:|
| Process spawn x200 | 2.54 s |
| Create+delete 2000 1-byte files | 3.89 s |
| Build (llvm-reduce + deps, -j 4) | 1367.01 s |
| lit LLVM::tools/llvm-reduce wall time | 102.53 s |
| lit LLVM::tools/llvm-reduce pass/fail/total | 166/8/205 |
