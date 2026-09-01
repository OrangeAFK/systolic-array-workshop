# Systolic Array Workshop

Build a **4×4 systolic array** matrix multiplier — from dot product on paper to a synthesizable, verified hardware accelerator on the Digilent Cora Z7-07S FPGA.

**Goal:** In ~2 hours, go from `C = A × B` to a passing simulation, randomized verification, synthesis report, and (optionally) an FPGA demo.

This repo is the conceptual prerequisite for [StreamState](https://github.com/OrangeAFK): the systolic array is the **compute substrate**; StreamState is the **system architecture** built around it.

---

## Quick Start

```bash
# Prerequisites: Verilator, Python 3.10+, numpy, make
pip install -r requirements.txt

# Run the full verification flow (reference solution in rtl/)
./scripts/run_sim.sh

# Or step by step:
make -C sim pe      # Stage 1: processing element
make -C sim array   # Stage 2: 4×4 array (fixed test)
make -C sim all     # Stage 3: randomized tests
```

To use your exercise solution instead of the reference:

```bash
make -C sim pe PE_SRC=../exercises/01_pe.sv
make -C sim array ARRAY_SRC=../exercises/02_array.sv
```

---

## Repository Layout

```text
systolic-array-workshop/
├── README.md
├── docs/           # Architecture, dataflow, PE, verification guides
├── rtl/            # Complete reference solution (always runnable)
├── exercises/      # Student skeletons with TODO checkpoints
├── tb/             # Testbenches + Python golden model
├── sim/            # Verilator Makefile
├── scripts/        # run_sim.sh, run_synth.tcl
└── fpga/           # Cora Z7-07S constraints, block design, demo host
```

| Directory | Purpose |
|-----------|---------|
| [`rtl/`](rtl/) | Reference implementation — use this if you get stuck |
| [`exercises/`](exercises/) | Progressive checkpoints: PE → array → streaming |
| [`docs/`](docs/) | Read in order: `00` → `01` → `02` → `03` |

---

## Workshop Schedule (~2 hours)

| Time | Activity | Artifact |
|------|----------|----------|
| 0–15 min | Matrix multiply cost in software | — |
| 15–30 min | Derive PE on paper | [`docs/02_pe.md`](docs/02_pe.md) |
| 30–50 min | Implement + verify PE | `exercises/01_pe.sv` passes `make pe` |
| 50–80 min | Build 4×4 mesh | `exercises/02_array.sv` passes `make array` |
| 80–100 min | Golden model + randomized tests | `make all` + Python check |
| 100–115 min | Synthesize, inspect DSP/LUT/Fmax | Vivado utilization report |
| 115–120 min | FPGA demo on Cora Z7 | `fpga/demo_host.py` prints PASS |

---

## Prerequisites

| Tool | Used for |
|------|----------|
| [Verilator](https://www.veripool.org/verilator/) 5.0+ | RTL simulation |
| Python 3.10+ | Golden model, test generation |
| `numpy` | Reference matrix multiply |
| `make` | Build orchestration |
| Vivado 2022+ | Synthesis + FPGA (optional) |

---

## Verification Workflow

We teach the standard hardware workflow:

```text
specification → golden model → RTL → simulation → hardware → compare
```

1. **Python** generates random `A`, `B` matrices and expected `C = A @ B`
2. **SystemVerilog** testbench drives the RTL and writes results to JSON
3. **Python** compares RTL output against the golden model

See [`docs/03_verification.md`](docs/03_verification.md) for details.

---

## FPGA (Cora Z7-07S)

See [`fpga/README.md`](fpga/README.md) for Vivado block design, bitstream build, and host demo.

```bash
# After building bitstream:
python fpga/demo_host.py
```

---

## Why are we building this?

```text
                   SYSTOLIC ARRAY
                         │
              spatial data reuse
                         │
                         ▼
                  matrix engine
                         │
                         ▼
                ┌─────────────────┐
                │   StreamState   │
                │                 │
weights ───────►│ matrix engine   │
                │       +         │
state ─────────►│ SSM recurrence  │
                └─────────────────┘
                         │
                         ▼
                    next token
```

> **The systolic array is the compute substrate. StreamState is the system architecture built around that substrate.**

When you finish this workshop, you will understand *why* StreamState needs a matrix engine — and what that engine actually does at the cycle level.

---

## Naming Note

This design is called **`systolic_array_4x4`**, not a "TPU." A 4×4 educational array teaches the underlying architecture. Production TPUs are large-scale systems built around related systolic-array and dataflow ideas — but they are not the same thing.

---

## License

MIT — use freely for teaching and learning.
