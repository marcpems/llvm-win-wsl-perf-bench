# CI perf-bench result: linux-x64

Timestamp (UTC): 2026-09-28_13-44-02 | LLVM commit/ref: main

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
| FreeDiskGB | 86 |
| RunnerName | GitHub Actions 1000000618 |
| RunnerLabel | linux-x64 |
| GithubRunId | 36425733436 |

## Results

| Test | Result |
|---|---:|
| Process spawn x200 | 0.2 s |
| Create+delete 2000 1-byte files | 0.97 s |
| Build (llvm-reduce + deps, -j 4) | 2219.86 s |
| lit LLVM::tools/llvm-reduce wall time | 25.8 s |
| lit LLVM::tools/llvm-reduce pass/fail/total | 167/11/206 |
