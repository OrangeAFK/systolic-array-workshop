#!/usr/bin/env python3
"""Golden model and test vector utilities for systolic array verification."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

import numpy as np

N = 4
DATA_LO = -8
DATA_HI = 7
VECTORS_DIR = Path(__file__).parent / "test_vectors"
MANIFEST_PATH = VECTORS_DIR / "manifest.json"
MANIFEST_LIST = VECTORS_DIR / "manifest.list"
RESULTS_PATH = VECTORS_DIR / "results.json"


def golden(A: np.ndarray, B: np.ndarray) -> np.ndarray:
    """Reference matrix multiply: C = A @ B with int8 operands, int32 accumulation."""
    A_i8 = A.astype(np.int8)
    B_i8 = B.astype(np.int8)
    return (A_i8.astype(np.int32) @ B_i8.astype(np.int32))


def matrix_to_list(m: np.ndarray) -> list[list[int]]:
    """Convert a 4x4 numpy array to a nested Python list."""
    return m.astype(int).tolist()


def write_case_file(case: dict[str, Any], directory: Path) -> None:
    """Write a single test case in a simple text format for SV $fscanf."""
    path = directory / f"{case['name']}.txt"
    with path.open("w", encoding="utf-8") as f:
        f.write(f"name {case['name']}\n")
        f.write("A\n")
        for row in case["A"]:
            f.write(" ".join(str(v) for v in row) + "\n")
        f.write("B\n")
        for row in case["B"]:
            f.write(" ".join(str(v) for v in row) + "\n")


def generate_random_tests(n: int = 100, lo: int = DATA_LO, hi: int = DATA_HI) -> list[dict[str, Any]]:
    """Generate n random 4x4 int8 test cases."""
    cases = []
    for i in range(n):
        A = np.random.randint(lo, hi + 1, size=(N, N), dtype=np.int32)
        B = np.random.randint(lo, hi + 1, size=(N, N), dtype=np.int32)
        cases.append({
            "name": f"random_{i:03d}",
            "A": matrix_to_list(A),
            "B": matrix_to_list(B),
            "C": matrix_to_list(golden(A, B)),
        })
    return cases


def edge_cases() -> list[dict[str, Any]]:
    """Fixed edge-case matrices for verification."""
    cases = []

    def add(name: str, A: np.ndarray, B: np.ndarray) -> None:
        cases.append({
            "name": name,
            "A": matrix_to_list(A),
            "B": matrix_to_list(B),
            "C": matrix_to_list(golden(A, B)),
        })

    add("zeros", np.zeros((N, N), dtype=np.int32), np.zeros((N, N), dtype=np.int32))
    add("ones", np.ones((N, N), dtype=np.int32), np.ones((N, N), dtype=np.int32))
    add("identity", np.eye(N, dtype=np.int32), np.eye(N, dtype=np.int32))
    add("max_pos", np.full((N, N), 7, dtype=np.int32), np.full((N, N), 7, dtype=np.int32))
    add("max_neg", np.full((N, N), -8, dtype=np.int32), np.full((N, N), -8, dtype=np.int32))
    add("mixed_sign",
        np.array([[1, -2, 3, -4], [-5, 6, -7, 8], [1, 1, -1, -1], [7, -8, 0, 2]], dtype=np.int32),
        np.array([[2, 0, -1, 4], [3, -3, 5, 1], [-2, 6, 0, -7], [1, 1, 1, 1]], dtype=np.int32))
    add("sparse",
        np.array([[1, 0, 0, 0], [0, 2, 0, 0], [0, 0, 3, 0], [0, 0, 0, 4]], dtype=np.int32),
        np.array([[5, 0, 0, 0], [0, 6, 0, 0], [0, 0, 7, 0], [0, 0, 0, 8]], dtype=np.int32))
    add("fixed_small",
        np.array([[1, 2, 3, 4], [5, 6, 7, 8], [1, 0, 1, 0], [2, 2, 2, 2]], dtype=np.int32),
        np.array([[1, 0, 0, 1], [0, 1, 0, 1], [1, 1, 1, 0], [0, 0, 1, 1]], dtype=np.int32))
    return cases


def write_manifest(cases: list[dict[str, Any]]) -> None:
    """Write JSON manifest and per-case text files for the SV testbench."""
    VECTORS_DIR.mkdir(parents=True, exist_ok=True)

    with MANIFEST_PATH.open("w", encoding="utf-8") as f:
        json.dump({"N": N, "cases": cases}, f, indent=2)

    with MANIFEST_LIST.open("w", encoding="utf-8", newline="\n") as f:
        for case in cases:
            f.write(f"{case['name']}\n")
            write_case_file(case, VECTORS_DIR)

    print(f"Wrote {len(cases)} test cases to {VECTORS_DIR}")


def read_results(path: Path = RESULTS_PATH) -> list[dict[str, Any]]:
    """Read RTL simulation results written by the testbench."""
    with path.open(encoding="utf-8") as f:
        data = json.load(f)
    return data["results"]


def check_results() -> int:
    """Compare RTL results against golden model. Returns number of failures."""
    with MANIFEST_PATH.open(encoding="utf-8") as f:
        manifest = json.load(f)
    results = read_results()

    expected_by_name = {c["name"]: np.array(c["C"], dtype=np.int32) for c in manifest["cases"]}
    failures = 0

    for entry in results:
        name = entry["name"]
        actual = np.array(entry["C"], dtype=np.int32)
        expected = expected_by_name.get(name)

        if expected is None:
            print(f"FAIL [{name}]: unknown test case")
            failures += 1
            continue

        if np.array_equal(actual, expected):
            print(f"PASS [{name}]")
        else:
            failures += 1
            print(f"FAIL [{name}]:")
            print(f"  Expected:\n{expected}")
            print(f"  Actual:\n{actual}")

    total = len(results)
    passed = total - failures
    print(f"\n=== {passed}/{total} tests passed ===")
    return failures


def cmd_generate(args: argparse.Namespace) -> None:
    """Generate test vectors."""
    cases = edge_cases()
    if args.random > 0:
        cases.extend(generate_random_tests(args.random))
    write_manifest(cases)


def cmd_check(args: argparse.Namespace) -> None:
    """Check simulation results."""
    failures = check_results()
    sys.exit(1 if failures else 0)


def main() -> None:
    parser = argparse.ArgumentParser(description="Systolic array golden model")
    sub = parser.add_subparsers(dest="command")

    gen = sub.add_parser("generate", help="Generate test vectors")
    gen.add_argument("--random", type=int, default=100, help="Number of random tests")
    gen.set_defaults(func=cmd_generate)

    chk = sub.add_parser("check", help="Check RTL results against golden model")
    chk.set_defaults(func=cmd_check)

    args = parser.parse_args()
    if args.command is None:
        parser.print_help()
        sys.exit(1)
    args.func(args)


if __name__ == "__main__":
    main()
