# FPGA Build — Cora Z7-07S

Build and run the TPU-shaped systolic core on the Digilent Cora Z7-07S (XC7Z007S-1CLG400C) via AXI-Lite.

## Board Summary

| Property | Value |
|----------|-------|
| Part | XC7Z007S-1CLG400C |
| PL clock | 125 MHz (`FCLK_CLK0` from Zynq PS) |
| DSP slices | 66 |
| LUTs | 14,400 |
| AXI base | `0x43C0_0000` |
| Master XDC | [Digilent Cora-Z7-07S-Master.xdc](https://github.com/Digilent/digilent-xdc/blob/master/Cora-Z7-07S-Master.xdc) |

## Prerequisites

- Vivado 2022.1+ with Zynq-7000 support
- Cora Z7-07S + USB-JTAG
- Simulation green first: `make -C sim pe array stream axi` (or `./scripts/run_sim.sh`)
- Python 3.10+ with numpy (host demo)

## Build Steps

### 1. Create project, BD, bitstream

```bash
vivado -mode batch -source scripts/run_synth.tcl
```

This will:
1. Create a project targeting `xc7z007sclg400-1`
2. Add RTL (`pe`, `systolic_array`, `controller`, `top`, `systolic_core`, `axi_wrapper`, …)
3. Source `fpga/block_design.tcl` (PS7 + interconnect + `axi_wrapper` @ `0x43C0_0000`)
4. Run synthesis and implementation through bitstream
5. Write utilization/timing reports under `fpga/project/`
6. Emit `fpga/program.tcl` with the bitstream path

### 2. Inspect utilization

| Resource | Expectation |
|----------|-------------|
| DSP48E1 | ~16 (one multiply per PE) |
| LUTs / FFs | Control + AXIS/AXI shim |
| Fmax | ≥ 125 MHz target |

### 3. Program the board

```bash
vivado -mode batch -source fpga/program.tcl
```

## AXI Register Map

| Offset | Name | Access | Description |
|--------|------|--------|-------------|
| `0x00` | CTRL | W | bit0 = start; bit1 = soft clear |
| `0x04` | STATUS | R | bit0 = done; bit1 = busy; bit2 = w_buf_full; bit3 = a_buf_full |
| `0x10–0x4C` | W_MEM[16] | W | Weights **B** (int8, row-major) |
| `0x50–0x8C` | A_MEM[16] | W | Activations **A** (int8, row-major) |
| `0x90–0xCC` | C_MEM[16] | R | Results **C** (int32, row-major) |

See [`docs/contracts.md`](../docs/contracts.md) for the locked AXIS + MMIO contracts.

## Host Demo

```bash
# Software-only (no hardware)
python fpga/demo_host.py --simulate

# On Cora Z7 after bitstream load (requires /dev/mem or UIO — extend as needed)
python fpga/demo_host.py
```

Expected:

```text
Software:
[[...]]
FPGA:
[[...]]
PASS
```

## Block Design

```text
Zynq PS ── AXI GP0 ── axi_interconnect ── axi_wrapper ── systolic_core ── top ── systolic_array
```

- Address: `axi_wrapper` S_AXI → `0x43C0_0000` (64 KiB)
- Host fills W_MEM then A_MEM, writes CTRL.start, polls STATUS.done, reads C_MEM

## Timing Notes

PE MAC paths are single-cycle at 125 MHz in this design. `constraints.xdc` intentionally **does not** apply multicycle exceptions on accumulator registers.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Module reference `axi_wrapper` missing | Ensure RTL is added before sourcing `block_design.tcl` |
| Fmax < 125 MHz | Check timing report; reduce FCLK if needed |
| Wrong matrix result | Confirm W_MEM=B and A_MEM=A (not the old A@0x10 / B@0x50 map) |
| `demo_host.py` exits immediately | Use `--simulate`, or add a hardware backend for your image |
| Sim not green | Do not run Vivado until `pe`/`array`/`stream`/`axi` pass |
