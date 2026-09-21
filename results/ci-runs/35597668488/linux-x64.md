# CI perf-bench result: linux-x64

Timestamp (UTC): 2026-09-21_12-39-15 | LLVM commit/ref: main

## Machine spec

| Field | Value |
|---|---|
| Os | Linux |
| OsVersion | Ubuntu 24.04.5 LTS |
| Architecture | X64 |
| CpuModel | AMD EPYC 9V74 80-Core Processor |
| PhysicalCores | 2 |
| LogicalCores | 4 |
| MemoryGB | 15.6 |
| FreeDiskGB | 86.1 |
| RunnerName | GitHub Actions 1000000561 |
| RunnerLabel | linux-x64 |
| GithubRunId | 35597668488 |

## Results

| Test | Result |
|---|---:|
| Process spawn x200 | 0.15 s |
| Create+delete 2000 1-byte files | 0.55 s |
| Build (llvm-reduce + deps, -j 4) | 1653.54 s |
| lit LLVM::tools/llvm-reduce wall time | 24.73 s |
| lit LLVM::tools/llvm-reduce pass/fail/total | 166/11/205 |
