# CI perf-bench result: windows-x64

Timestamp (UTC): 2026-10-12_15-16-38 | LLVM commit/ref: main

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
| RunnerName | GitHub Actions 1000000923 |
| RunnerLabel | windows-x64 |
| GithubRunId | 38263714898 |

## Results

| Test | Result |
|---|---:|
| Process spawn x200 | 1.39 s |
| Create+delete 2000 1-byte files | 2.49 s |
| Build (llvm-reduce + deps, -j 4) | 1748.27 s |
| lit LLVM::tools/llvm-reduce wall time | 49.19 s |
| lit LLVM::tools/llvm-reduce pass/fail/total | 166/11/206 |
