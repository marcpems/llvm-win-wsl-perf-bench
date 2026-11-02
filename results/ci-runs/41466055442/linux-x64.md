# CI perf-bench result: linux-x64

Timestamp (UTC): 2026-11-02_15-34-31 | LLVM commit/ref: main

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
| FreeDiskGB | 85.6 |
| RunnerName | GitHub Actions 1000001474 |
| RunnerLabel | linux-x64 |
| GithubRunId | 41466055442 |

## Results

| Test | Result |
|---|---:|
| Process spawn x200 | 0.2 s |
| Create+delete 2000 1-byte files | 0.83 s |
| Build (llvm-reduce + deps, -j 4) | 2245.64 s |
| lit LLVM::tools/llvm-reduce wall time | 25.69 s |
| lit LLVM::tools/llvm-reduce pass/fail/total | 168/11/207 |
