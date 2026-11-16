# CI perf-bench result: windows-x64

Timestamp (UTC): 2026-11-16_15-34-41 | LLVM commit/ref: main

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
| RunnerName | GitHub Actions 1000001545 |
| RunnerLabel | windows-x64 |
| GithubRunId | 43890935862 |

## Results

| Test | Result |
|---|---:|
| Process spawn x200 | 1.23 s |
| Create+delete 2000 1-byte files | 1.57 s |
| Build (llvm-reduce + deps, -j 4) | 1670.52 s |
| lit LLVM::tools/llvm-reduce wall time | 48.15 s |
| lit LLVM::tools/llvm-reduce pass/fail/total | 167/11/207 |
