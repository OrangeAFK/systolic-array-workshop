# FPGA Build — Cora Z7-07S

Deployable path: Digilent PS preset + `axi_wrapper_bd` (Verilog BD shell) → `axi_wrapper` → **`systolic_core`** (AXIS drop-in).

## SoC / TPU vs demo adapter

| Integrate | Role |
|-----------|------|
| [`rtl/systolic_core.sv`](../rtl/systolic_core.sv) | **Drop-in** for TPU/SoC — AXIS weights / activations / results |
| `axi_wrapper` + this BD | **Cora demo only** — AXI-Lite MMIO at `0x43C0_0000` |

See [`docs/contracts.md`](../docs/contracts.md).

## Board Summary

| Property | Value |
|----------|-------|
| Part | XC7Z007S-1CLG400C |
| Board part | `digilentinc.com:cora-z7-07s:part0:1.1` |
| Board files | `C:/Xilinx/vivado-boards/new/board_files` |
| PL clock | 125 MHz (`FCLK_CLK0`) |
| AXI base | `0x43C0_0000` (64 KiB) |

## Prerequisites

- Vivado 2022.1+ (tested 2025.1) with Zynq-7000
- Digilent vivado-boards (Cora Z7-07S)
- Simulation green: `make -C sim pe array stream axi` (or `./scripts/run_sim.sh`)
- Python 3.10+ + numpy

## Build bitstream

From a Vivado-enabled shell (Windows example):

```bat
call C:\Xilinx\2025.1\Vivado\settings64.bat
cd C:\Users\onepl\Desktop\systolic-array-workshop
vivado -mode batch -source scripts\run_synth.tcl
```

This:
1. Sets Digilent board repo + board part
2. Adds RTL (`.sv` + `axi_wrapper_bd.v`)
3. Builds BD: PS7 (board preset) + `proc_sys_reset` + interconnect + `axi_wrapper_bd`
4. Synth → impl → bitstream
5. Writes `fpga/project/utilization_synth.rpt`, `timing.rpt`
6. Regenerates `fpga/program.tcl`

### Expected utilization (fill after first successful build)

| Resource | Expectation |
|----------|-------------|
| DSP48E1 | ~16 |
| LUTs / FFs | control + AXI shim |
| WNS @ 125 MHz | ≥ 0 |

## Program

```bat
vivado -mode batch -source fpga\program.tcl
```

## Host demo (`/dev/mem`)

On Cora Linux **as root**, after bitstream is loaded and the PL clock is running:

```bash
sudo python3 fpga/demo_host.py
```

Laptop / CI:

```bash
python fpga/demo_host.py --simulate
```

`MemDevice` mmaps 64 KiB at `0x43C00000` and uses the register map below.

## AXI Register Map

| Offset | Name | Access | Description |
|--------|------|--------|-------------|
| `0x00` | CTRL | W | bit0 = start; bit1 = soft clear |
| `0x04` | STATUS | R | bit0 = done; bit1 = busy; bit2 = w_buf_full; bit3 = a_buf_full |
| `0x10–0x4C` | W_MEM | W | Weights **B** (int8) |
| `0x50–0x8C` | A_MEM | W | Activations **A** (int8) |
| `0x90–0xCC` | C_MEM | R | Results **C** (int32) |

## Block Design

```text
Zynq PS ── GP0 ── axi_interconnect ── axi_wrapper_bd ── axi_wrapper ── systolic_core
                         ▲
                  proc_sys_reset (125 MHz)
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| SV module-ref rejected | Use `axi_wrapper_bd.v` (already the BD reference) |
| Board part missing | Install Digilent board files; check `board.repoPaths` in `run_synth.tcl` |
| `/dev/mem` PermissionError | `sudo python3 fpga/demo_host.py` |
| Sim not green | Do not run Vivado until `pe`/`array`/`stream`/`axi` pass |
| Timing fail @ 125 MHz | Inspect `fpga/project/timing.rpt`; lower `PCW_FPGA0_PERIPHERAL_FREQMHZ` if needed |
