# CI perf-bench result: linux-x64

Timestamp (UTC): 2026-10-19_12-55-25 | LLVM commit/ref: main

## Machine spec

| Field | Value |
|---|---|
| Os | Linux |
| OsVersion | Ubuntu 24.04.5 LTS |
| Architecture | X64 |
| CpuModel | AMD EPYC 7763 64-Core Processor |
| PhysicalCores | 2 |
| LogicalCores | 4 |
| MemoryGB | 15.6 |
| FreeDiskGB | 85.8 |
| RunnerName | GitHub Actions 1000000952 |
| RunnerLabel | linux-x64 |
| GithubRunId | 39250726898 |

## Results

| Test | Result |
|---|---:|
| Process spawn x200 | 0.21 s |
| Create+delete 2000 1-byte files | 1.01 s |
| Build (llvm-reduce + deps, -j 4) | 2093.63 s |
| lit LLVM::tools/llvm-reduce wall time | 25.52 s |
| lit LLVM::tools/llvm-reduce pass/fail/total | 167/11/206 |
