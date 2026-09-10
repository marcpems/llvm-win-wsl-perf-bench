# CI perf-bench result: windows-x64

Timestamp (UTC): 2026-09-10_19-01-01 | LLVM commit/ref: main

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
| FreeDiskGB | 147 |
| RunnerName | GitHub Actions 1000000432 |
| RunnerLabel | windows-x64 |
| GithubRunId | 34513275555 |

## Results

| Test | Result |
|---|---:|
| Process spawn x200 | 1.7 s |
| Create+delete 2000 1-byte files | 1.96 s |
| Build (llvm-reduce + deps, -j 4) | 2132.53 s |
| lit LLVM::tools/llvm-reduce wall time | 58.51 s |
| lit LLVM::tools/llvm-reduce pass/fail/total | 165/11/205 |
