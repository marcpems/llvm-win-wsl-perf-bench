# CI perf-bench result: windows-x64

Timestamp (UTC): 2026-09-21_12-58-43 | LLVM commit/ref: main

## Machine spec

| Field | Value |
|---|---|
| Os | Windows |
| OsVersion | Microsoft Windows Server 2025 Datacenter (10.0.26100) |
| Architecture | X64 |
| CpuModel | AMD EPYC 7763 64-Core Processor |
| PhysicalCores | 2 |
| LogicalCores | 4 |
| MemoryGB | 16 |
| FreeDiskGB | 147 |
| RunnerName | GitHub Actions 1000000560 |
| RunnerLabel | windows-x64 |
| GithubRunId | 35597668488 |

## Results

| Test | Result |
|---|---:|
| Process spawn x200 | 1.81 s |
| Create+delete 2000 1-byte files | 1.91 s |
| Build (llvm-reduce + deps, -j 4) | 2202.63 s |
| lit LLVM::tools/llvm-reduce wall time | 62.25 s |
| lit LLVM::tools/llvm-reduce pass/fail/total | 165/11/205 |
