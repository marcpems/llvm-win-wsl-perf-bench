# CI perf-bench result: windows-arm64

Timestamp (UTC): 2026-11-16_07-36-56 | LLVM commit/ref: main

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
| FreeDiskGB | 125.2 |
| RunnerName | GitHub Actions 1000001546 |
| RunnerLabel | windows-arm64 |
| GithubRunId | 43890935862 |

## Results

| Test | Result |
|---|---:|
| Process spawn x200 | 2.95 s |
| Create+delete 2000 1-byte files | 2.4 s |
| Build (llvm-reduce + deps, -j 4) | 1784.62 s |
| lit LLVM::tools/llvm-reduce wall time | 110.19 s |
| lit LLVM::tools/llvm-reduce pass/fail/total | 168/8/207 |
