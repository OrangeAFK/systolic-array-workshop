# Architecture Overview

This workshop builds a **4×4 output-stationary systolic array** that computes `C = A × B`, wrapped in a **TPU-shaped** portable stream interface (`systolic_core`) and an AXI-Lite host path for the Digilent Cora Z7.

"TPU-shaped" means the external contract (AXIS weights → activations → explicit start → result stream with backpressure), not a claim that this mesh is a Google TPU.

## The Teaching Spine

```text
matrix multiplication
      ↓
one processing element (PE) with en/clear
      ↓
4×4 PE mesh + skewed controller
      ↓
systolic_core (AXIS TPU-shaped IP)
      ↓
axi_wrapper (Cora Z7 MMIO)
```

## Why "Systolic"?

Data **pulses** through a grid of PEs:

- Matrix **A** (activations) flows **left → right**
- Matrix **B** (weights) flows **top → bottom**

Each PE multiplies passing operands and accumulates into a local register when `en=1`.

```text
        B0   B1   B2   B3
         ↓    ↓    ↓    ↓
A0 →    PE → PE → PE → PE
         ↓    ↓    ↓    ↓
A1 →    PE → PE → PE → PE
         ↓    ↓    ↓    ↓
A2 →    PE → PE → PE → PE
         ↓    ↓    ↓    ↓
A3 →    PE → PE → PE → PE
```

## Module Hierarchy

| Module | File | Responsibility |
|--------|------|----------------|
| `pe` | `rtl/pe.sv` | MAC + propagate; `en` hold; `clear` zeros acc |
| `systolic_array` | `rtl/systolic_array.sv` | N×N mesh; broadcasts `en` |
| `controller` | `rtl/controller.sv` | Skew injection; `pe_en` only in RUN |
| `top` | `rtl/top.sv` | Memory-mapped shell for array TB |
| `systolic_core` | `rtl/systolic_core.sv` | AXIS weights/acts/results + start/done |
| `streaming_top` | `rtl/streaming_top.sv` | Thin wrapper over `systolic_core` |
| `axi_wrapper` | `rtl/axi_wrapper.sv` | AXI-Lite MMIO → core |

Locked port/register contracts: [`docs/contracts.md`](contracts.md).

## Numeric Representation

**int8 × int8 → int32** accumulation (matches the golden model and FPGA DSP mapping).

## Checkpoints (TDD)

| Stage | Gate | Notes |
|-------|------|-------|
| 1 | `make -C sim pe` | PE `en` / `clear` / hold |
| 2 | `make -C sim array` + `all` | Mesh + stability + golden |
| 3 | `make -C sim stream` | `systolic_core` AXIS contract |
| 4 | `make -C sim axi` | AXI-Lite split AW/W + STATUS |
| 5 | Vivado (after sim green) | Cora Z7 BD + bitstream |

Reference RTL lives in `rtl/`. Exercises under `exercises/` track the same contracts.
