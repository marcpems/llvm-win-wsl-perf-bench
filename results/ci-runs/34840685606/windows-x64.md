# CI perf-bench result: windows-x64

Timestamp (UTC): 2026-09-14_12-34-54 | LLVM commit/ref: main

## Machine spec

| Field | Value |
|---|---|
| Os | Windows |
| OsVersion | Microsoft Windows Server 2025 Datacenter (10.0.26100) |
| Architecture | X64 |
| CpuModel | Intel(R) Xeon(R) 6973P-C |
| PhysicalCores | 2 |
| LogicalCores | 4 |
| MemoryGB | 16 |
| FreeDiskGB | 219.9 |
| RunnerName | GitHub Actions 1000000504 |
| RunnerLabel | windows-x64 |
| GithubRunId | 34840685606 |

## Results

| Test | Result |
|---|---:|
| Process spawn x200 | 1.33 s |
| Create+delete 2000 1-byte files | 7.3 s |
| Build (llvm-reduce + deps, -j 4) | 1556.81 s |
| lit LLVM::tools/llvm-reduce wall time | 49.84 s |
| lit LLVM::tools/llvm-reduce pass/fail/total | 165/11/205 |
