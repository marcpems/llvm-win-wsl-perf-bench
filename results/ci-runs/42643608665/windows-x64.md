# CI perf-bench result: windows-x64

Timestamp (UTC): 2026-11-09_15-58-38 | LLVM commit/ref: main

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
| RunnerName | GitHub Actions 1000001503 |
| RunnerLabel | windows-x64 |
| GithubRunId | 42643608665 |

## Results

| Test | Result |
|---|---:|
| Process spawn x200 | 1.26 s |
| Create+delete 2000 1-byte files | 2.86 s |
| Build (llvm-reduce + deps, -j 4) | 1659.26 s |
| lit LLVM::tools/llvm-reduce wall time | 49.34 s |
| lit LLVM::tools/llvm-reduce pass/fail/total | 167/11/207 |
