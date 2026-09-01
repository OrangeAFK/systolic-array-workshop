# Architecture Overview

This workshop builds a **4×4 systolic array** that computes `C = A × B` for 4×4 matrices. The design is called `systolic_array_4x4` — not a "TPU." A TPU is a large-scale production system built around related systolic-array and dataflow ideas; our array teaches the underlying architecture honestly.

## The Teaching Spine

Everything derives from one formula:

$$
C_{ij} = \sum_{k=0}^{N-1} A_{ik} \cdot B_{kj}
$$

We translate this progressively:

```text
matrix multiplication
      ↓
one dot product
      ↓
one processing element (PE)
      ↓
4×4 PE mesh
      ↓
streaming dataflow
      ↓
pipeline timing
      ↓
hardware accelerator
```

## Why "Systolic"?

In a systolic array, data **pulses** through a grid of processing elements like a heartbeat. Operands enter at the edges and propagate:

- Matrix **A** flows **left to right** (horizontally)
- Matrix **B** flows **top to bottom** (vertically)

Each PE multiplies the passing operands and accumulates into a local register. No PE fetches data from memory — operands come from its neighbors.

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
| `pe` | `rtl/pe.sv` | Multiply + accumulate + propagate |
| `systolic_array_4x4` | `rtl/systolic_array.sv` | 4×4 mesh of PEs |
| `controller` | `rtl/controller.sv` | Skewed operand injection schedule |
| `top` | `rtl/top.sv` | Integrates controller + array |
| `streaming_top` | `rtl/streaming_top.sv` | Valid/ready streaming interface |

## Numeric Representation

We use **int8 × int8 → int32**:

```text
8-bit operands
       ↓
8×8 multiply → 16-bit product
       ↓
accumulation requires 32-bit accumulator
```

This is deliberate. After synthesis, students inspect **LUTs, DSP48s, FFs, BRAM, and Fmax** — connecting algorithm to hardware resources.

## Checkpoints

| Stage | Exercise | Artifact |
|-------|----------|----------|
| 1 | `exercises/01_pe.sv` | PE passes `make pe` |
| 2 | `exercises/02_array.sv` | 4×4 mesh passes `make array` |
| 3 | `exercises/03_streaming.sv` | Streaming interface + randomized tests |

Reference solutions are always available in `rtl/`.
