# CI perf-bench result: linux-x64

Timestamp (UTC): 2026-10-26_13-01-20 | LLVM commit/ref: main

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
| FreeDiskGB | 85.4 |
| RunnerName | GitHub Actions 1000001385 |
| RunnerLabel | linux-x64 |
| GithubRunId | 40321727036 |

## Results

| Test | Result |
|---|---:|
| Process spawn x200 | 0.21 s |
| Create+delete 2000 1-byte files | 1.01 s |
| Build (llvm-reduce + deps, -j 4) | 2203.15 s |
| lit LLVM::tools/llvm-reduce wall time | 25.68 s |
| lit LLVM::tools/llvm-reduce pass/fail/total | 168/11/207 |
