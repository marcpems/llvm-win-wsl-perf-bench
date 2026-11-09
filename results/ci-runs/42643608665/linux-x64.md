# CI perf-bench result: linux-x64

Timestamp (UTC): 2026-11-09_16-05-11 | LLVM commit/ref: main

## Machine spec

| Field | Value |
|---|---|
| Os | Linux |
| OsVersion | Ubuntu 26.04.1 LTS |
| Architecture | X64 |
| CpuModel | AMD EPYC 7763 64-Core Processor |
| PhysicalCores | 2 |
| LogicalCores | 4 |
| MemoryGB | 15.6 |
| FreeDiskGB | 87.7 |
| RunnerName | GitHub Actions 1000001504 |
| RunnerLabel | linux-x64 |
| GithubRunId | 42643608665 |

## Results

| Test | Result |
|---|---:|
| Process spawn x200 | 0.21 s |
| Create+delete 2000 1-byte files | 1 s |
| Build (llvm-reduce + deps, -j 4) | 2378.17 s |
| lit LLVM::tools/llvm-reduce wall time | 25.76 s |
| lit LLVM::tools/llvm-reduce pass/fail/total | 168/11/207 |
