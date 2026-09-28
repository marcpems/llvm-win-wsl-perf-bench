# CI perf-bench result: windows-x64

Timestamp (UTC): 2026-09-28_13-48-48 | LLVM commit/ref: main

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
| RunnerName | GitHub Actions 1000000616 |
| RunnerLabel | windows-x64 |
| GithubRunId | 36425733436 |

## Results

| Test | Result |
|---|---:|
| Process spawn x200 | 1.86 s |
| Create+delete 2000 1-byte files | 1.92 s |
| Build (llvm-reduce + deps, -j 4) | 2222.72 s |
| lit LLVM::tools/llvm-reduce wall time | 64.23 s |
| lit LLVM::tools/llvm-reduce pass/fail/total | 166/11/206 |
