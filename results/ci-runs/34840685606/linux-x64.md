# CI perf-bench result: linux-x64

Timestamp (UTC): 2026-09-14_12-35-02 | LLVM commit/ref: main

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
| FreeDiskGB | 86.1 |
| RunnerName | GitHub Actions 1000000505 |
| RunnerLabel | linux-x64 |
| GithubRunId | 34840685606 |

## Results

| Test | Result |
|---|---:|
| Process spawn x200 | 0.19 s |
| Create+delete 2000 1-byte files | 0.79 s |
| Build (llvm-reduce + deps, -j 4) | 2074.98 s |
| lit LLVM::tools/llvm-reduce wall time | 25.37 s |
| lit LLVM::tools/llvm-reduce pass/fail/total | 166/11/205 |
