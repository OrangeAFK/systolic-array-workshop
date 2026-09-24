# Verification

Verification is test-driven: **lock contract → failing TB → RTL → green gate → next layer.**

## Contracts

Executable interface rules live in [`docs/contracts.md`](contracts.md) and in TB headers. Do not change MMIO offsets or AXIS ordering without updating TBs and `fpga/demo_host.py`.

## Workflow

```text
contracts.md
     ↓
failing SystemVerilog TB
     ↓
minimum RTL to pass
     ↓
Verilator (make -C sim …)
     ↓
golden_model.py check (array suite)
     ↓
(only then) Vivado / Cora Z7
```

## Golden Model

```python
def golden(A, B):
    return A.astype(np.int8).astype(np.int32) @ B.astype(np.int8).astype(np.int32)
```

## Randomized Testing

```bash
python tb/golden_model.py generate --random 100
```

Produces `tb/test_vectors/manifest.list`, per-case `.txt` files, and expected `C` in `manifest.json`.

## Simulation Targets

```bash
./scripts/run_sim.sh
# or:
make -C sim pe       # PE en/clear/hold
make -C sim array    # identity + post-done stability
make -C sim all      # full manifest → results.json
python tb/golden_model.py check
make -C sim stream   # systolic_core AXIS (backpressure, double-run, …)
make -C sim axi      # axi_wrapper Lite BFM (split AW/W, STATUS bits)
```

### What each TB proves

| TB | Key checks |
|----|------------|
| `tb_pe` | MAC when `en=1`; hold when `en=0`; `clear` zeros acc; idle stuck inputs |
| `tb_systolic_array` | Golden matmul; `pe_en` low after done; `c_out` stable over idle |
| `tb_systolic_core` | W then A streams; explicit start; `c_tready` stall; bubbles; double-run; sticky done |
| `tb_axi_wrapper` | AW-then-W and W-then-AW; CTRL/STATUS; soft clear; C_MEM vs golden |

## Waveforms

```bash
make -C sim array
# Open sim/obj/array/*.vcd
```

Inspect `dut.u_controller.pe_en`, `a_drv`/`b_drv`, and PE `acc`.

## FPGA Verification

After sim is green, build with `scripts/run_synth.tcl` and compare on hardware (or `--simulate`) via `fpga/demo_host.py` using the same golden model.
