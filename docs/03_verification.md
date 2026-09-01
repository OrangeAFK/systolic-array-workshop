# Verification

This workshop treats verification as an engineering discipline, not an afterthought.

## The Workflow

```text
specification
     ↓
golden model (Python)
     ↓
RTL (SystemVerilog)
     ↓
simulation (Verilator)
     ↓
hardware (Cora Z7 FPGA)
     ↓
hardware-vs-golden comparison
```

## Golden Model

The reference implementation is intentionally simple:

```python
def golden(A, B):
    return A.astype(np.int8).astype(np.int32) @ B.astype(np.int8).astype(np.int32)
```

This is `numpy` matrix multiply with int8 operands and int32 accumulation — matching the RTL semantics.

## Randomized Testing

We do **not** rely on a single hard-coded test case. The golden model generates:

- **100 random** 4×4 int8 matrices (values in [-8, 7])
- **8 edge cases**: zeros, ones, identity, max positive, max negative, mixed signs, sparse, fixed small

```bash
python tb/golden_model.py generate --random 100
```

This writes:
- `tb/test_vectors/manifest.json` — full test spec with expected results
- `tb/test_vectors/manifest.list` — case names for the SV testbench
- `tb/test_vectors/<name>.txt` — per-case A/B matrices in simple text format

## Running Verification

```bash
# Full flow
./scripts/run_sim.sh

# Or step by step:
python tb/golden_model.py generate --random 100
make -C sim pe       # Stage 1
make -C sim array    # Stage 2 (identity test)
make -C sim all      # Stage 3 (all cases)
python tb/golden_model.py check
```

The SystemVerilog testbench:
1. Reads test vectors from `tb/test_vectors/`
2. Drives the RTL through load → compute → readback
3. Writes `tb/test_vectors/results.json`

Python compares `results.json` against the golden model and prints PASS/FAIL per case.

## Reading Waveforms

Generate a waveform for the pipeline timing lesson:

```bash
make -C sim array
# Open sim/obj/array/*.vcd in GTKWave or Surfer
```

Signals to inspect:
- `dut.u_controller.cycle` — injection cycle counter
- `dut.u_controller.a_drv` / `b_drv` — skewed operands
- `dut.u_array.c_out` — accumulator values growing over time
- `done` — completion flag

See [`docs/01_dataflow.md`](01_dataflow.md) for the cycle-by-cycle schedule.

## What a Failing Test Looks Like

```text
FAIL [mixed_sign]:
  Expected:
[[  8 -32  18 -20]
 [ 34 -14  26 -30]
 ...
  Actual:
[[  8 -32  18 -20]
 [ 34 -14  25 -30]
 ...
```

The mismatch index tells you exactly which PE or cycle to investigate.

## FPGA Verification

On the Cora Z7, the host script (`fpga/demo_host.py`) performs the same comparison:

```text
Software:
[[...]]
FPGA:
[[...]]
PASS ✓
```

Same golden model, different execution target — that's the industrial verification pattern.
