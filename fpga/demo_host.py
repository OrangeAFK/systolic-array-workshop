#!/usr/bin/env python3
"""Host demo for Cora Z7-07S systolic array accelerator.

Reads/writes AXI registers to load matrices, start computation, and read results.
Compares FPGA output against the Python golden model.

Usage (on Cora Z7 Linux):
    python3 fpga/demo_host.py

For simulation-only testing without hardware:
    python3 fpga/demo_host.py --simulate
"""

from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

import numpy as np

# Add tb/ to path for golden model import
sys.path.insert(0, str(Path(__file__).parent.parent / "tb"))
from golden_model import golden, N  # noqa: E402

# AXI register offsets (must match rtl/axi_wrapper.sv)
ADDR_CTRL   = 0x00
ADDR_STATUS = 0x04
ADDR_A_BASE = 0x10
ADDR_B_BASE = 0x50
ADDR_C_BASE = 0x90


def simulate_fpga(A: np.ndarray, B: np.ndarray) -> np.ndarray:
    """Software stand-in for FPGA when hardware is not available."""
    return golden(A, B)


def load_matrix(dev: object, base_addr: int, matrix: np.ndarray) -> None:
    """Write a 4x4 int8 matrix to AXI registers."""
    for i in range(N):
        for j in range(N):
            addr = base_addr + (i * N + j) * 4
            dev.write(addr, int(matrix[i, j]) & 0xFF)


def read_matrix(dev: object, base_addr: int) -> np.ndarray:
    """Read a 4x4 int32 matrix from AXI registers."""
    result = np.zeros((N, N), dtype=np.int32)
    for i in range(N):
        for j in range(N):
            addr = base_addr + (i * N + j) * 4
            result[i, j] = dev.read(addr)
    return result


def run_matmul(dev: object, A: np.ndarray, B: np.ndarray) -> tuple[np.ndarray, float]:
    """Load A/B, start computation, poll done, read C. Returns (C, latency_ms)."""
    load_matrix(dev, ADDR_A_BASE, A)
    load_matrix(dev, ADDR_B_BASE, B)

    t0 = time.perf_counter()
    dev.write(ADDR_CTRL, 1)

    timeout = 1000
    while timeout > 0:
        status = dev.read(ADDR_STATUS)
        if status & 1:
            break
        timeout -= 1
        time.sleep(0.001)

    latency_ms = (time.perf_counter() - t0) * 1000
    C = read_matrix(dev, ADDR_C_BASE)
    return C, latency_ms


class SimDevice:
    """Simulated AXI device for --simulate mode."""

    def __init__(self) -> None:
        self.regs: dict[int, int] = {}
        self._A = np.zeros((N, N), dtype=np.int32)
        self._B = np.zeros((N, N), dtype=np.int32)

    def write(self, addr: int, value: int) -> None:
        if addr == ADDR_CTRL and value & 1:
            self.regs[ADDR_STATUS] = 0
            C = golden(self._A, self._B)
            for i in range(N):
                for j in range(N):
                    self.regs[ADDR_C_BASE + (i * N + j) * 4] = int(C[i, j])
            self.regs[ADDR_STATUS] = 1
        elif ADDR_A_BASE <= addr < ADDR_B_BASE:
            idx = (addr - ADDR_A_BASE) // 4
            self._A[idx // N, idx % N] = value
        elif ADDR_B_BASE <= addr < ADDR_C_BASE:
            idx = (addr - ADDR_B_BASE) // 4
            self._B[idx // N, idx % N] = value
        else:
            self.regs[addr] = value

    def read(self, addr: int) -> int:
        return self.regs.get(addr, 0)


def main() -> None:
    parser = argparse.ArgumentParser(description="Systolic array FPGA demo host")
    parser.add_argument("--simulate", action="store_true",
                        help="Run without hardware (software simulation)")
    args = parser.parse_args()

    A = np.array([
        [1, 2, 3, 4],
        [5, 6, 7, 8],
        [1, 0, 1, 0],
        [2, 2, 2, 2],
    ], dtype=np.int32)

    B = np.array([
        [1, 0, 0, 1],
        [0, 1, 0, 1],
        [1, 1, 1, 0],
        [0, 0, 1, 1],
    ], dtype=np.int32)

    expected = golden(A, B)

    if args.simulate:
        dev: object = SimDevice()
    else:
        print("ERROR: Hardware access requires a PYNQ-style overlay or /dev/mem driver.")
        print("       Use --simulate for a software-only demo, or load the bitstream")
        print("       and implement hardware access for your Cora Z7 setup.")
        print("       See fpga/README.md for Vivado build instructions.")
        sys.exit(1)

    C, latency_ms = run_matmul(dev, A, B)

    print("Software:")
    print(expected)
    print("\nFPGA:")
    print(C)

    if np.array_equal(C, expected):
        print("\nPASS")
    else:
        print("\nFAIL")
        sys.exit(1)

    print(f"\nLatency: {latency_ms:.2f} ms")


if __name__ == "__main__":
    main()
