`timescale 1ns / 1ps

// Exercise 2: Build an N×N systolic array mesh.
// See docs/01_dataflow.md and docs/contracts.md.
//
// Module name: systolic_array (not systolic_array_4x4).
// Pass en to every PE; map clear_acc → PE clear (not PE rst).
// Run:  make -C sim array ARRAY_SRC=../exercises/02_array.sv

module systolic_array #(
    parameter int N      = 4,
    parameter int DATA_W = 8,
    parameter int ACC_W  = 32
) (
    input  logic                  clk,
    input  logic                  rst,
    input  logic                  en,
    input  logic                  clear_acc,
    input  logic signed [DATA_W-1:0] a_in  [N],
    input  logic signed [DATA_W-1:0] b_in  [N],
    output logic signed [ACC_W-1:0]  c_out [N][N]
);

    // TODO: Declare horizontal A wires and vertical B wires between PEs.
    //       a_wire[row][col] connects PE[row][col-1] to PE[row][col] horizontally.
    //       b_wire[row][col] connects PE[row-1][col] to PE[row][col] vertically.

    // TODO: Connect a_in[i] to the left edge of row i.
    // TODO: Connect b_in[j] to the top edge of column j.

    // TODO: Instantiate N x N processing elements.
    //       Wire .en(en), .clear(clear_acc), .rst(rst) — do not OR clear into rst.
    //       Hint: see rtl/systolic_array.sv for the reference wiring pattern.

endmodule
