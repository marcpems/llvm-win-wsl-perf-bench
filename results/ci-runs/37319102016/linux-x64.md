# CI perf-bench result: linux-x64

Timestamp (UTC): 2026-10-05_14-23-49 | LLVM commit/ref: main

## Machine spec

| Field | Value |
|---|---|
| Os | Linux |
| OsVersion | Ubuntu 24.04.5 LTS |
| Architecture | X64 |
| CpuModel | Intel(R) Xeon(R) Platinum 8370C CPU @ 2.80GHz |
| PhysicalCores | 2 |
| LogicalCores | 4 |
| MemoryGB | 15.6 |
| FreeDiskGB | 86.1 |
| RunnerName | GitHub Actions 1000000804 |
| RunnerLabel | linux-x64 |
| GithubRunId | 37319102016 |

## Results

| Test | Result |
|---|---:|
| Process spawn x200 | 0.15 s |
| Create+delete 2000 1-byte files | 0.71 s |
| Build (llvm-reduce + deps, -j 4) | 2072.17 s |
| lit LLVM::tools/llvm-reduce wall time | 25.4 s |
| lit LLVM::tools/llvm-reduce pass/fail/total | 167/11/206 |
