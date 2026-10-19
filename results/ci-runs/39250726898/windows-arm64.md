# CI perf-bench result: windows-arm64

Timestamp (UTC): 2026-10-19_05-52-28 | LLVM commit/ref: main

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
| FreeDiskGB | 123.4 |
| RunnerName | GitHub Actions 1000000951 |
| RunnerLabel | windows-arm64 |
| GithubRunId | 39250726898 |

## Results

| Test | Result |
|---|---:|
| Process spawn x200 | 2.48 s |
| Create+delete 2000 1-byte files | 2.07 s |
| Build (llvm-reduce + deps, -j 4) | 1530.31 s |
| lit LLVM::tools/llvm-reduce wall time | 106.22 s |
| lit LLVM::tools/llvm-reduce pass/fail/total | 167/8/206 |
