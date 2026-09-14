# CI perf-bench result: windows-arm64

Timestamp (UTC): 2026-09-14_12-29-32 | LLVM commit/ref: main

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
| FreeDiskGB | 121.3 |
| RunnerName | GitHub Actions 1000000503 |
| RunnerLabel | windows-arm64 |
| GithubRunId | 34840685606 |

## Results

| Test | Result |
|---|---:|
| Process spawn x200 | 2.62 s |
| Create+delete 2000 1-byte files | 2.1 s |
| Build (llvm-reduce + deps, -j 4) | 1432.37 s |
| lit LLVM::tools/llvm-reduce wall time | 108.4 s |
| lit LLVM::tools/llvm-reduce pass/fail/total | 166/8/205 |
