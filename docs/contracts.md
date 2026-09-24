# Locked Contracts — TPU-shaped Systolic Core

Executable interface contracts for portable IP and the Cora Z7 AXI path.
Testbenches assert these behaviors; RTL must match.

## `pe` — Processing Element

| Port | Dir | Width | Meaning |
|------|-----|-------|---------|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Sync reset: zeros `a_out`, `b_out`, `acc` |
| `en` | in | 1 | When 1: MAC + propagate; when 0: hold all regs |
| `clear` | in | 1 | Sync clear of `acc` only (does not require `rst`) |
| `a_in` / `b_in` | in | DATA_W | Operand inputs |
| `a_out` / `b_out` | out | DATA_W | Registered pass-through when `en` |
| `acc` | out | ACC_W | Accumulator |

**Priority (posedge):** `rst` → `clear` (zeros `acc`; hold/pass a/b per `en`) → `en` MAC → hold.

**Rules:**
1. MAC only when `en=1` and not `rst`/`clear`.
2. When `en=0`, non-zero `a_in`/`b_in` must not change `acc`, `a_out`, or `b_out`.
3. `clear` zeros `acc` without a full `rst`.

---

## `systolic_array` — N×N Mesh

Module name: `systolic_array` (parameterized `N`, default 4).

| Port | Dir | Meaning |
|------|-----|---------|
| `clk`, `rst` | in | Clock / sync reset |
| `en` | in | Broadcast PE enable |
| `clear_acc` | in | Maps to PE `clear` (not PE `rst`) |
| `a_in[N]`, `b_in[N]` | in | Left / top edge operands |
| `c_out[N][N]` | out | Accumulators |

Existing output-stationary mesh and skew schedule are unchanged.

---

## `controller`

| Port | Dir | Meaning |
|------|-----|---------|
| `start` | in | Pulse to begin clear → run |
| `done` | out | Sticky until next `start` |
| `clear_acc` | out | One-cycle pulse before run |
| `pe_en` | out | High only in `ST_RUN` |
| `a_drv[N]`, `b_drv[N]` | out | Skewed operands; **zero outside `ST_RUN`** |
| `a_mem` / `b_mem` | in | Source matrices |

Skew: `A[i][k]` at cycle `i+k`; `B[k][j]` at cycle `k+j`. Run length `3*N-2` cycles.

---

## `top` — Memory-mapped shell

Flat `a_load` / `b_load` / `c_out` + `start` / `done`. Wires controller `pe_en` into the array.
Used by the array TB; `systolic_core` wraps this shell.

---

## Integration boundary (SoC / TPU vs Cora demo)

| Use this | When |
|----------|------|
| **`systolic_core`** (AXIS `w_*` / `a_*` / `c_*` + `start` / `done`) | Drop-in for a TPU / SoC / StreamState — DMA or NoC feeds streams |
| **`axi_wrapper` + block design** | Cora Z7 workshop demo only — AXI-Lite MMIO adapter around the core |

Do **not** treat AXI-Lite as the long-term SoC API. Swap the shell; keep this core contract.

---

## `systolic_core` — TPU drop-in (AXIS)

```text
w_*  → weights (B)     N*N × int8
a_*  → activations (A) N*N × int8
c_*  → results (C)     N*N × int32
```

| Port | Dir | Meaning |
|------|-----|---------|
| `w_tvalid` / `w_tready` / `w_tdata` | AXIS-S | Weight stream |
| `a_tvalid` / `a_tready` / `a_tdata` | AXIS-S | Activation stream |
| `c_tvalid` / `c_tready` / `c_tdata` | AXIS-M | Result stream |
| `start` | in | Explicit start after both buffers full (no auto-start) |
| `done` | out | Sticky until next `start` |

**Protocol:**
1. Stream `N*N` int8 **weights (B)** first (row-major).
2. Stream `N*N` int8 **activations (A)** (row-major). While loading weights, `a_tready` is low.
3. Assert `start` only after both buffers are full.
4. Compute with PE `en` only while running; hold accumulators when `!en`.
5. Stream `N*N` int32 on `c_*`; **must stall** drain when `!c_tready` without dropping or duplicating beats.
6. `done` sticky until next `start`; results stable after drain even across many idle cycles.

FSM sketch: `LOAD_W` → `LOAD_A` → `WAIT_START` → `RUN` → `DRAIN`.

---

## `streaming_top`

Thin wrapper over `systolic_core`. Maps legacy `a_*`/`b_*` ports to core `a_*`/`w_*` and exposes `c_ready` (= `c_tready`).

---

## `axi_wrapper` — AXI4-Lite MMIO (host-stable)

Base address on Cora Z7: `0x43C0_0000`.

| Offset | Name | Access | Description |
|--------|------|--------|-------------|
| `0x00` | CTRL | W | bit0 = start; bit1 = soft clear |
| `0x04` | STATUS | R | bit0 = done; bit1 = busy; bit2 = w_buf_full; bit3 = a_buf_full |
| `0x10..` | W_MEM | W | `N*N` int8 weights (B), word-aligned |
| `0x50..` | A_MEM | W | `N*N` int8 activations (A), word-aligned |
| `0x90..` | C_MEM | R | `N*N` int32 results, word-aligned |

**AXI-Lite rules:**
- Address width 16 bits (64 KiB map); register offsets unchanged.
- Ports include `s_axi_awprot` / `s_axi_arprot` (ignored) for Vivado BD inference.
- AW and W may arrive on different cycles; slave must accept both orders (AW-then-W and W-then-AW).
- Instantiates `systolic_core`; MMIO fills weight/activation buffers and polls `done`.

Host: [`fpga/demo_host.py`](../fpga/demo_host.py) — `/dev/mem` mmap at `0x43C0_0000`, or `--simulate`.
