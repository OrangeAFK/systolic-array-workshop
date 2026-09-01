`timescale 1ns / 1ps

// Processing element for systolic array matrix multiply.
// int8 operands, int32 accumulator.
// A flows through horizontally (a_in -> a_out).
// B flows through vertically   (b_in -> b_out).
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

    logic signed [ACC_W-1:0] product;

    assign product = $signed(a_in) * $signed(b_in);

    always_ff @(posedge clk) begin
        if (rst) begin
            a_out <= '0;
            b_out <= '0;
            acc   <= '0;
        end else begin
            a_out <= a_in;
            b_out <= b_in;
            acc   <= acc + product;
        end
    end

endmodule
