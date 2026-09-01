`timescale 1ns / 1ps

// Exercise 1: Implement a single processing element (PE).
// See docs/02_pe.md for derivation from the dot product.
//
// Test: a = [2, 3, 4], b = [5, 6, 7]  =>  acc = 2*5 + 3*6 + 4*7 = 56
// Run:  make -C sim pe PE_SRC=../exercises/01_pe.sv

module pe #(
    parameter int DATA_W = 8,
    parameter int ACC_W  = 32
) (
    input  logic                  clk,
    input  logic                  rst,
    input  logic signed [DATA_W-1:0] a_in,
    input  logic signed [DATA_W-1:0] b_in,
    output logic signed [DATA_W-1:0] a_out,
    output logic signed [DATA_W-1:0] b_out,
    output logic signed [ACC_W-1:0]  acc
);

    // TODO: Declare a signed product signal wide enough for int8 * int8.

    // TODO: Compute product = a_in * b_in (use $signed for correct int8 multiply).

    always_ff @(posedge clk) begin
        if (rst) begin
            // TODO: Reset a_out, b_out, and acc to zero.
        end else begin
            // TODO: Pass a_in through to a_out (operand propagation).
            // TODO: Pass b_in through to b_out (operand propagation).
            // TODO: Accumulate: acc <= acc + product.
        end
    end

endmodule
