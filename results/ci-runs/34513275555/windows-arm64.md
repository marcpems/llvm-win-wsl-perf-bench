# CI perf-bench result: windows-arm64

Timestamp (UTC): 2026-09-10_18-51-20 | LLVM commit/ref: main

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
| FreeDiskGB | 121.5 |
| RunnerName | GitHub Actions 1000000431 |
| RunnerLabel | windows-arm64 |
| GithubRunId | 34513275555 |

## Results

| Test | Result |
|---|---:|
| Process spawn x200 | 2.63 s |
| Create+delete 2000 1-byte files | 2.32 s |
| Build (llvm-reduce + deps, -j 4) | 1425.65 s |
| lit LLVM::tools/llvm-reduce wall time | 107.54 s |
| lit LLVM::tools/llvm-reduce pass/fail/total | 166/8/205 |
