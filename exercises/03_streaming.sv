`timescale 1ns / 1ps

// Exercise 3: TPU-shaped streaming wrapper (or implement systolic_core).
// See docs/contracts.md and rtl/systolic_core.sv / rtl/streaming_top.sv.
//
// Protocol:
//   1. Stream N*N int8 **weights (B)** on b_* / w_* first.
//   2. Stream N*N int8 **activations (A)** on a_* (a_ready low while loading W).
//   3. Explicit start after both buffers full (no auto-start).
//   4. Stream N*N int32 results on c_valid/c_data with c_ready backpressure
//      (must stall without dropping beats).
//   5. done sticky until next start.
//
// Run:  make -C sim stream

module streaming_top #(
    parameter int N      = 4,
    parameter int DATA_W = 8,
    parameter int ACC_W  = 32
) (
    input  logic                  clk,
    input  logic                  rst,

    // Activations (A)
    input  logic                  a_valid,
    output logic                  a_ready,
    input  logic signed [DATA_W-1:0] a_data,

    // Weights (B) — stream these first
    input  logic                  b_valid,
    output logic                  b_ready,
    input  logic signed [DATA_W-1:0] b_data,

    input  logic                  start,
    output logic                  done,

    output logic                  c_valid,
    input  logic                  c_ready,
    output logic signed [ACC_W-1:0] c_data
);

    // TODO: Instantiate systolic_core (or reimplement its FSM) and map:
    //         b_* → w_t*,  a_* → a_t*,  c_ready → c_tready
    //
    // Preferred: thin wrapper — see rtl/streaming_top.sv.

endmodule
