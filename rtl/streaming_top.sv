`timescale 1ns / 1ps

// Thin streaming wrapper over systolic_core (TPU-shaped AXIS contract).
// Maps legacy a_*/b_* port names to core a_*/w_* and exposes c_ready.
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

    // Weights (B)
    input  logic                  b_valid,
    output logic                  b_ready,
    input  logic signed [DATA_W-1:0] b_data,

    input  logic                  start,
    output logic                  done,

    output logic                  c_valid,
    input  logic                  c_ready,
    output logic signed [ACC_W-1:0] c_data
);

    systolic_core #(
        .N     (N),
        .DATA_W(DATA_W),
        .ACC_W (ACC_W)
    ) u_core (
        .clk     (clk),
        .rst     (rst),
        .w_tvalid(b_valid),
        .w_tready(b_ready),
        .w_tdata (b_data),
        .a_tvalid(a_valid),
        .a_tready(a_ready),
        .a_tdata (a_data),
        .start   (start),
        .done    (done),
        .c_tvalid(c_valid),
        .c_tready(c_ready),
        .c_tdata (c_data)
    );

endmodule
