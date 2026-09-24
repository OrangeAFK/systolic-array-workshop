`timescale 1ns / 1ps

// Exercise 1: Implement a single processing element (PE).
// See docs/02_pe.md and docs/contracts.md (en / clear / hold).
//
// Test: a = [2, 3, 4], b = [5, 6, 7] with en=1  =>  acc = 56
// Also: en=0 must hold; clear zeros acc without full rst.
// Run:  make -C sim pe PE_SRC=../exercises/01_pe.sv

module pe #(
    parameter int DATA_W = 8,
    parameter int ACC_W  = 32
) (
    input  logic                  clk,
    input  logic                  rst,
    input  logic                  en,
    input  logic                  clear,
    input  logic signed [DATA_W-1:0] a_in,
    input  logic signed [DATA_W-1:0] b_in,
    output logic signed [DATA_W-1:0] a_out,
    output logic signed [DATA_W-1:0] b_out,
    output logic signed [ACC_W-1:0]  acc
);

    // TODO: Declare a signed product signal wide enough for int8 * int8.

    // TODO: Compute product = a_in * b_in (use $signed for correct int8 multiply).

    // Priority: rst → clear (zero acc) → en MAC+propagate → hold
    always_ff @(posedge clk) begin
        if (rst) begin
            // TODO: Reset a_out, b_out, and acc to zero.
        end else begin
            // TODO: if (clear) acc <= 0;
            // TODO: else if (en) acc <= acc + product;
            // TODO: if (en) propagate a_in→a_out and b_in→b_out; else hold.
        end
    end

endmodule
