# CI perf-bench result: windows-x64

Timestamp (UTC): 2026-10-05_14-31-13 | LLVM commit/ref: main

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
| RunnerName | GitHub Actions 1000000806 |
| RunnerLabel | windows-x64 |
| GithubRunId | 37319102016 |

## Results

| Test | Result |
|---|---:|
| Process spawn x200 | 1.64 s |
| Create+delete 2000 1-byte files | 1.97 s |
| Build (llvm-reduce + deps, -j 4) | 2159.91 s |
| lit LLVM::tools/llvm-reduce wall time | 62.68 s |
| lit LLVM::tools/llvm-reduce pass/fail/total | 166/11/206 |
