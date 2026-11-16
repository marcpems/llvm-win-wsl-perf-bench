# CI perf-bench result: linux-x64

Timestamp (UTC): 2026-11-16_15-36-56 | LLVM commit/ref: main

## Machine spec

| Field | Value |
|---|---|
| Os | Linux |
| OsVersion | Ubuntu 26.04.1 LTS |
| Architecture | X64 |
| CpuModel | AMD EPYC 9V74 80-Core Processor |
| PhysicalCores | 2 |
| LogicalCores | 4 |
| MemoryGB | 15.6 |
| FreeDiskGB | 87.2 |
| RunnerName | GitHub Actions 1000001544 |
| RunnerLabel | linux-x64 |
| GithubRunId | 43890935862 |

## Results

| Test | Result |
|---|---:|
| Process spawn x200 | 0.22 s |
| Create+delete 2000 1-byte files | 0.89 s |
| Build (llvm-reduce + deps, -j 4) | 2190.39 s |
| lit LLVM::tools/llvm-reduce wall time | 25.73 s |
| lit LLVM::tools/llvm-reduce pass/fail/total | 168/11/207 |
