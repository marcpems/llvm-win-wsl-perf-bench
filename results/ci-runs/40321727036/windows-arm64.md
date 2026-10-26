# CI perf-bench result: windows-arm64

Timestamp (UTC): 2026-10-26_05-58-10 | LLVM commit/ref: main

## Machine spec

| Field | Value |
|---|---|
| Os | Windows |
| OsVersion | Microsoft Windows 11 Enterprise (10.0.26200) |
| Architecture | Arm64 |
| CpuModel | Cobalt 100 |
| PhysicalCores | 4 |
| LogicalCores | 4 |
| MemoryGB | 16 |
| FreeDiskGB | 126.7 |
| RunnerName | GitHub Actions 1000001386 |
| RunnerLabel | windows-arm64 |
| GithubRunId | 40321727036 |

## Results

| Test | Result |
|---|---:|
| Process spawn x200 | 3.07 s |
| Create+delete 2000 1-byte files | 2.7 s |
| Build (llvm-reduce + deps, -j 4) | 1587.4 s |
| lit LLVM::tools/llvm-reduce wall time | 106.5 s |
| lit LLVM::tools/llvm-reduce pass/fail/total | 168/8/207 |
