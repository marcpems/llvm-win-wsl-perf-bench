# CI perf-bench result: windows-arm64

Timestamp (UTC): 2026-10-05_07-20-13 | LLVM commit/ref: main

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
| FreeDiskGB | 124.1 |
| RunnerName | GitHub Actions 1000000805 |
| RunnerLabel | windows-arm64 |
| GithubRunId | 37319102016 |

## Results

| Test | Result |
|---|---:|
| Process spawn x200 | 2.66 s |
| Create+delete 2000 1-byte files | 2.25 s |
| Build (llvm-reduce + deps, -j 4) | 1545.78 s |
| lit LLVM::tools/llvm-reduce wall time | 108.83 s |
| lit LLVM::tools/llvm-reduce pass/fail/total | 167/8/206 |
