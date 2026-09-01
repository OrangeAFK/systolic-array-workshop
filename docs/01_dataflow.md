# Dataflow and Timing

The systolic array is **not** doing 64 multiplications at once. It is a **spatially pipelined** computation whose partial results move through time.

## Operand Skew Schedule

For an N×N array, operands must be injected with a time skew so that `A[i][k]` and `B[k][j]` arrive at `PE[i][j]` on the same cycle.

| Operand | Injection rule | Example (N=4) |
|---------|---------------|---------------|
| `A[i][k]` | Row `i` at cycle `i + k` | `A[2][1]` at cycle 3 |
| `B[k][j]` | Column `j` at cycle `k + j` | `B[1][3]` at cycle 4 |

At cycle `t`, the controller drives:

```text
a_drv[i] = A[i][t - i]   if 0 ≤ t - i < N, else 0
b_drv[j] = B[t - j][j]   if 0 ≤ t - j < N, else 0
```

## Cycle-by-Cycle Table (N=4, excerpt)

Showing which matrix elements enter the array edges at each cycle:

| Cycle | a_drv[0] | a_drv[1] | a_drv[2] | a_drv[3] | b_drv[0] | b_drv[1] | b_drv[2] | b_drv[3] |
|-------|----------|----------|----------|----------|----------|----------|----------|----------|
| 0 | A[0][0] | 0 | 0 | 0 | B[0][0] | 0 | 0 | 0 |
| 1 | A[0][1] | A[1][0] | 0 | 0 | B[1][0] | B[0][1] | 0 | 0 |
| 2 | A[0][2] | A[1][1] | A[2][0] | 0 | B[2][0] | B[1][1] | B[0][2] | 0 |
| 3 | A[0][3] | A[1][2] | A[2][1] | A[3][0] | B[3][0] | B[2][1] | B[1][2] | B[0][3] |
| ... | ... | ... | ... | ... | ... | ... | ... | ... |
| 9 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | B[3][3] |

Total compute cycles: **3N − 2 = 10** for N=4.

## Propagation Through the Mesh

After injection, operands take additional cycles to propagate:

- `A[i][k]` injected at row `i`, reaches `PE[i][j]` after `j` cycles
- `B[k][j]` injected at column `j`, reaches `PE[i][j]` after `i` cycles

Both arrive at `PE[i][j]` at cycle `i + k + j` — the cycle of the `k`-th partial product.

## The Key Teaching Moment

> The array is not "doing 64 multiplications at once." It is a spatially pipelined computation whose partial results move through time.

Open the waveform after running:

```bash
make -C sim array
# Then open sim/obj/array/*.vcd in GTKWave
```

Look for:
1. Operands entering the left column and top row with skew
2. Values propagating horizontally and vertically through the mesh
3. Accumulators in each PE growing over 4 cycles
4. `done` asserting after cycle 10

## Streaming Interface (Exercise 3)

Once the array works, the final exercise adds a **valid/ready** interface:

```text
input:  a_valid, a_data, b_valid, b_data
output: c_valid, c_data
```

This teaches the concept that matters for StreamState:

> An accelerator isn't just a computation. It's a datapath with an interface and a dataflow schedule.

See `rtl/streaming_top.sv` for the reference implementation.
