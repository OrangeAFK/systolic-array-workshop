#!/usr/bin/env python3
"""Host demo for Cora Z7-07S systolic array accelerator.

Reads/writes AXI-Lite registers via /dev/mem (hardware) or an in-process
simulator. Compares FPGA output against the Python golden model.

Usage on Cora Z7 Linux (root, bitstream already programmed):
    sudo python3 fpga/demo_host.py

Laptop / CI (no hardware):
    python3 fpga/demo_host.py --simulate
"""

from __future__ import annotations

import argparse
import mmap
import os
import struct
import sys
import time
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).parent.parent / "tb"))
from golden_model import golden, N  # noqa: E402

# AXI register offsets (must match rtl/axi_wrapper.sv / docs/contracts.md)
ADDR_CTRL = 0x00
ADDR_STATUS = 0x04
ADDR_W_BASE = 0x10  # weights (B)
ADDR_A_BASE = 0x50  # activations (A)
ADDR_C_BASE = 0x90

# Zynq GP0 mapping from block_design.tcl
AXI_BASE = 0x43C00000
AXI_SPAN = 0x10000  # 64 KiB


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
            result[i, j] = np.int32(dev.read(addr))
    return result


def run_matmul(dev: object, A: np.ndarray, B: np.ndarray) -> tuple[np.ndarray, float]:
    """Load W=B / A=A, start, poll done, read C. Returns (C, latency_ms)."""
    load_matrix(dev, ADDR_W_BASE, B)
    load_matrix(dev, ADDR_A_BASE, A)

    t0 = time.perf_counter()
    dev.write(ADDR_CTRL, 1)  # bit0 = start

    timeout = 1000
    while timeout > 0:
        status = dev.read(ADDR_STATUS)
        if status & 1:  # done
            break
        timeout -= 1
        time.sleep(0.001)

    latency_ms = (time.perf_counter() - t0) * 1000
    if timeout <= 0:
        raise TimeoutError("STATUS.done not set within timeout")
    C = read_matrix(dev, ADDR_C_BASE)
    return C, latency_ms


class MemDevice:
    """AXI-Lite MMIO via /dev/mem mmap (requires root on Linux)."""

    def __init__(self, base: int = AXI_BASE, span: int = AXI_SPAN) -> None:
        if not Path("/dev/mem").exists():
            raise FileNotFoundError(
                "/dev/mem not found — run on Cora Z7 Linux, or use --simulate"
            )
        if hasattr(os, "geteuid") and os.geteuid() != 0:
            raise PermissionError(
                "Opening /dev/mem requires root — try: sudo python3 fpga/demo_host.py"
            )
        self._base = base
        self._fd = os.open("/dev/mem", os.O_RDWR | os.O_SYNC)
        self._mm = mmap.mmap(
            self._fd,
            span,
            mmap.MAP_SHARED,
            mmap.PROT_READ | mmap.PROT_WRITE,
            offset=base,
        )

    def write(self, addr: int, value: int) -> None:
        self._mm.seek(addr)
        self._mm.write(struct.pack("<I", value & 0xFFFFFFFF))

    def read(self, addr: int) -> int:
        self._mm.seek(addr)
        return struct.unpack("<I", self._mm.read(4))[0]

    def close(self) -> None:
        self._mm.close()
        os.close(self._fd)

    def __enter__(self) -> MemDevice:
        return self

    def __exit__(self, *args: object) -> None:
        self.close()


class SimDevice:
    """Simulated AXI device for --simulate mode."""

    def __init__(self) -> None:
        self.regs: dict[int, int] = {}
        self._A = np.zeros((N, N), dtype=np.int32)
        self._B = np.zeros((N, N), dtype=np.int32)

    def write(self, addr: int, value: int) -> None:
        if addr == ADDR_CTRL:
            if value & 2:  # soft clear
                self.regs[ADDR_STATUS] = 0
            if value & 1:  # start
                self.regs[ADDR_STATUS] = 0
                C = golden(self._A, self._B)
                for i in range(N):
                    for j in range(N):
                        self.regs[ADDR_C_BASE + (i * N + j) * 4] = int(C[i, j])
                self.regs[ADDR_STATUS] = 0xD  # done | w_full | a_full
        elif ADDR_W_BASE <= addr < ADDR_A_BASE:
            idx = (addr - ADDR_W_BASE) // 4
            self._B[idx // N, idx % N] = np.int8(value)
            self.regs[ADDR_STATUS] = self.regs.get(ADDR_STATUS, 0) | 0x4
        elif ADDR_A_BASE <= addr < ADDR_C_BASE:
            idx = (addr - ADDR_A_BASE) // 4
            self._A[idx // N, idx % N] = np.int8(value)
            self.regs[ADDR_STATUS] = self.regs.get(ADDR_STATUS, 0) | 0x8
        else:
            self.regs[addr] = value

    def read(self, addr: int) -> int:
        return self.regs.get(addr, 0)


def main() -> None:
    parser = argparse.ArgumentParser(description="Systolic array FPGA demo host")
    parser.add_argument(
        "--simulate",
        action="store_true",
        help="Run without hardware (software simulation)",
    )
    parser.add_argument(
        "--base",
        type=lambda s: int(s, 0),
        default=AXI_BASE,
        help=f"AXI base address (default 0x{AXI_BASE:X})",
    )
    args = parser.parse_args()

    A = np.array(
        [
            [1, 2, 3, 4],
            [5, 6, 7, 8],
            [1, 0, 1, 0],
            [2, 2, 2, 2],
        ],
        dtype=np.int32,
    )

    B = np.array(
        [
            [1, 0, 0, 1],
            [0, 1, 0, 1],
            [1, 1, 1, 0],
            [0, 0, 1, 1],
        ],
        dtype=np.int32,
    )

    expected = golden(A, B)

    if args.simulate:
        dev: object = SimDevice()
        C, latency_ms = run_matmul(dev, A, B)
    else:
        try:
            with MemDevice(base=args.base) as mem:
                C, latency_ms = run_matmul(mem, A, B)
        except (FileNotFoundError, PermissionError, OSError) as exc:
            print(f"ERROR: {exc}")
            print("       Use --simulate on a laptop, or sudo on Cora Linux after programming.")
            print("       See fpga/README.md.")
            sys.exit(1)

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
