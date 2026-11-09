# CI perf-bench result: windows-arm64

Timestamp (UTC): 2026-11-09_07-59-02 | LLVM commit/ref: main

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
| FreeDiskGB | 124.6 |
| RunnerName | GitHub Actions 1000001505 |
| RunnerLabel | windows-arm64 |
| GithubRunId | 42643608665 |

## Results

| Test | Result |
|---|---:|
| Process spawn x200 | 2.84 s |
| Create+delete 2000 1-byte files | 2.66 s |
| Build (llvm-reduce + deps, -j 4) | 1627.32 s |
| lit LLVM::tools/llvm-reduce wall time | 107.05 s |
| lit LLVM::tools/llvm-reduce pass/fail/total | 168/8/207 |
