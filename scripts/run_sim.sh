#!/usr/bin/env bash
# Run the full simulation and verification flow.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Generating test vectors"
python3 tb/golden_model.py generate --random 100 2>/dev/null || python tb/golden_model.py generate --random 100

echo "==> Stage 1: PE test"
make -C sim pe

echo "==> Stage 2: Array test (identity)"
make -C sim array

echo "==> Stage 3: Full randomized suite"
make -C sim all

echo "==> Checking results against golden model"
python3 tb/golden_model.py check 2>/dev/null || python tb/golden_model.py check

echo "==> All stages passed"
