# CI perf-bench results

No `ci-bench.ps1` run has published results yet.

Trigger `.github/workflows/ci-bench.yml` manually ("Run workflow" in the
Actions tab) or wait for its weekly schedule (Mondays 06:00 UTC) - once a
run completes, this file is regenerated automatically with the latest
per-runner machine spec and measurements (Windows x64, Windows ARM64,
Linux x64), and the same table is mirrored into `README.md`.

Historical per-run raw results are kept under `results/ci-runs/<run-id>/`.
