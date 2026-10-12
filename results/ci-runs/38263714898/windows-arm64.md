# CI perf-bench result: windows-arm64

Timestamp (UTC): 2026-10-12_08-10-33 | LLVM commit/ref: main

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
| FreeDiskGB | 123 |
| RunnerName | GitHub Actions 1000000925 |
| RunnerLabel | windows-arm64 |
| GithubRunId | 38263714898 |

## Results

| Test | Result |
|---|---:|
| Process spawn x200 | 3.1 s |
| Create+delete 2000 1-byte files | 2.22 s |
| Build (llvm-reduce + deps, -j 4) | 1672.14 s |
| lit LLVM::tools/llvm-reduce wall time | 118.63 s |
| lit LLVM::tools/llvm-reduce pass/fail/total | 167/8/206 |
