`timescale 1ns / 1ps

// Exercise 3: Add a streaming interface to the systolic array.
// See docs/01_dataflow.md and the reference rtl/streaming_top.sv.
//
// Your module should:
//   1. Accept matrix A and B via valid/ready streaming ports (16 int8 values each).
//   2. Pulse start on the internal top module and wait for done.
//   3. Stream out matrix C via c_valid/c_data (16 int32 values).
//
// Run:  make -C sim array  (after completing this exercise)

module streaming_top #(
    parameter int N      = 4,
    parameter int DATA_W = 8,
    parameter int ACC_W  = 32
) (
    input  logic                  clk,
    input  logic                  rst,

    input  logic                  a_valid,
    output logic                  a_ready,
    input  logic signed [DATA_W-1:0] a_data,

    input  logic                  b_valid,
    output logic                  b_ready,
    input  logic signed [DATA_W-1:0] b_data,

    input  logic                  start,
    output logic                  done,

    output logic                  c_valid,
    output logic signed [ACC_W-1:0] c_data
);

    // TODO: Instantiate top and wire a_load/b_load/c_out arrays.

    // TODO: Implement a state machine with states:
    //       ST_LOAD_A, ST_LOAD_B, ST_RUN, ST_OUTPUT

    // TODO: In ST_LOAD_A, accept 16 a_data values when a_valid && a_ready.

    // TODO: In ST_LOAD_B, accept 16 b_data values when b_valid && b_ready.

    // TODO: In ST_RUN, pulse core_start when start is asserted; wait for core_done.

    // TODO: In ST_OUTPUT, stream 16 c_data values with c_valid asserted.

    // TODO: Drive a_ready and b_ready based on current state.

endmodule
