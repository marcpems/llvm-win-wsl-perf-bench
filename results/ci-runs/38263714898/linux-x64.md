# CI perf-bench result: linux-x64

Timestamp (UTC): 2026-10-12_15-13-06 | LLVM commit/ref: main

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
| FreeDiskGB | 85.1 |
| RunnerName | GitHub Actions 1000000924 |
| RunnerLabel | linux-x64 |
| GithubRunId | 38263714898 |

## Results

| Test | Result |
|---|---:|
| Process spawn x200 | 0.2 s |
| Create+delete 2000 1-byte files | 1 s |
| Build (llvm-reduce + deps, -j 4) | 2136.44 s |
| lit LLVM::tools/llvm-reduce wall time | 25.65 s |
| lit LLVM::tools/llvm-reduce pass/fail/total | 167/11/206 |
