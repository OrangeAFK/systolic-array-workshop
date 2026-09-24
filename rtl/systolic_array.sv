`timescale 1ns / 1ps

/* verilator lint_off DECLFILENAME */

// N×N systolic array for matrix multiply C = A * B.
// A flows left-to-right; B flows top-to-bottom.
// Each PE[i][j] accumulates C[i][j].
// Contract: en broadcasts to PEs; clear_acc maps to PE clear (not rst).
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

    // Horizontal A wires between PEs
    logic signed [DATA_W-1:0] a_wire [N][N+1];
    // Vertical B wires between PEs
    logic signed [DATA_W-1:0] b_wire [N+1][N];

    // Drive left column and top row from controller
    genvar gi, gj;
    generate
        for (gi = 0; gi < N; gi++) begin : gen_a_in
            assign a_wire[gi][0] = a_in[gi];
        end
        for (gj = 0; gj < N; gj++) begin : gen_b_in
            assign b_wire[0][gj] = b_in[gj];
        end
    endgenerate

    // N×N mesh of processing elements
    generate
        for (gi = 0; gi < N; gi++) begin : row
            for (gj = 0; gj < N; gj++) begin : col
                pe #(
                    .DATA_W(DATA_W),
                    .ACC_W (ACC_W)
                ) pe_inst (
                    .clk  (clk),
                    .rst  (rst),
                    .en   (en),
                    .clear(clear_acc),
                    .a_in (a_wire[gi][gj]),
                    .b_in (b_wire[gi][gj]),
                    .a_out(a_wire[gi][gj+1]),
                    .b_out(b_wire[gi+1][gj]),
                    .acc  (c_out[gi][gj])
                );
            end
        end
    endgenerate

endmodule
