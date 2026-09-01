`timescale 1ns / 1ps

// Top-level module: controller + systolic_array_4x4.
// Flat memory interface for testbench and FPGA wrapper.
module top #(
    parameter int N      = 4,
    parameter int DATA_W = 8,
    parameter int ACC_W  = 32
) (
    input  logic                  clk,
    input  logic                  rst,
    input  logic                  start,
    output logic                  done,
    input  logic signed [DATA_W-1:0] a_load [N][N],
    input  logic signed [DATA_W-1:0] b_load [N][N],
    output logic signed [ACC_W-1:0]  c_out  [N][N]
);

    logic                  clear_acc;
    logic signed [DATA_W-1:0] a_drv [N];
    logic signed [DATA_W-1:0] b_drv [N];

    controller #(
        .N     (N),
        .DATA_W(DATA_W)
    ) u_controller (
        .clk      (clk),
        .rst      (rst),
        .start    (start),
        .done     (done),
        .clear_acc(clear_acc),
        .a_drv    (a_drv),
        .b_drv    (b_drv),
        .a_mem    (a_load),
        .b_mem    (b_load)
    );

    systolic_array_4x4 #(
        .N     (N),
        .DATA_W(DATA_W),
        .ACC_W (ACC_W)
    ) u_array (
        .clk      (clk),
        .rst      (rst),
        .clear_acc(clear_acc),
        .a_in     (a_drv),
        .b_in     (b_drv),
        .c_out    (c_out)
    );

endmodule
