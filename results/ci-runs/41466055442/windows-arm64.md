# CI perf-bench result: windows-arm64

Timestamp (UTC): 2026-11-02_07-30-09 | LLVM commit/ref: main

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
| FreeDiskGB | 124.3 |
| RunnerName | GitHub Actions 1000001472 |
| RunnerLabel | windows-arm64 |
| GithubRunId | 41466055442 |

## Results

| Test | Result |
|---|---:|
| Process spawn x200 | 2.76 s |
| Create+delete 2000 1-byte files | 2.56 s |
| Build (llvm-reduce + deps, -j 4) | 1646.59 s |
| lit LLVM::tools/llvm-reduce wall time | 108.41 s |
| lit LLVM::tools/llvm-reduce pass/fail/total | 168/8/207 |
