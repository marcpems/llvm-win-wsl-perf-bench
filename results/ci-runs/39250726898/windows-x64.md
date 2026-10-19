# CI perf-bench result: windows-x64

Timestamp (UTC): 2026-10-19_12-53-21 | LLVM commit/ref: main

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
| RunnerName | GitHub Actions 1000000953 |
| RunnerLabel | windows-x64 |
| GithubRunId | 39250726898 |

## Results

| Test | Result |
|---|---:|
| Process spawn x200 | 1.23 s |
| Create+delete 2000 1-byte files | 4.35 s |
| Build (llvm-reduce + deps, -j 4) | 1601.55 s |
| lit LLVM::tools/llvm-reduce wall time | 48.04 s |
| lit LLVM::tools/llvm-reduce pass/fail/total | 166/11/206 |
