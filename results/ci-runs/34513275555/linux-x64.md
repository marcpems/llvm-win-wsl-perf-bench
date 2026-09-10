# CI perf-bench result: linux-x64

Timestamp (UTC): 2026-09-10_18-54-12 | LLVM commit/ref: main

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
| RunnerName | GitHub Actions 1000000433 |
| RunnerLabel | linux-x64 |
| GithubRunId | 34513275555 |

## Results

| Test | Result |
|---|---:|
| Process spawn x200 | 0.21 s |
| Create+delete 2000 1-byte files | 0.71 s |
| Build (llvm-reduce + deps, -j 4) | 1982.85 s |
| lit LLVM::tools/llvm-reduce wall time | 25.43 s |
| lit LLVM::tools/llvm-reduce pass/fail/total | 166/11/205 |
