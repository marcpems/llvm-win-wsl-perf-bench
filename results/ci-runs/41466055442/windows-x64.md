# CI perf-bench result: windows-x64

Timestamp (UTC): 2026-11-02_15-30-02 | LLVM commit/ref: main

## Machine spec

| Field | Value |
|---|---|
| Os | Windows |
| OsVersion | Microsoft Windows Server 2025 Datacenter (10.0.26100) |
| Architecture | X64 |
| CpuModel | AMD EPYC 9V74 80-Core Processor |
| PhysicalCores | 2 |
| LogicalCores | 4 |
| MemoryGB | 16 |
| FreeDiskGB | 219.9 |
| RunnerName | GitHub Actions 1000001473 |
| RunnerLabel | windows-x64 |
| GithubRunId | 41466055442 |

## Results

| Test | Result |
|---|---:|
| Process spawn x200 | 1.35 s |
| Create+delete 2000 1-byte files | 1.82 s |
| Build (llvm-reduce + deps, -j 4) | 1691.24 s |
| lit LLVM::tools/llvm-reduce wall time | 50.23 s |
| lit LLVM::tools/llvm-reduce pass/fail/total | 167/11/207 |
