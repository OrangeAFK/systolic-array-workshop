`timescale 1ns / 1ps

// Testbench for the processing element (Stage 1).
// Feeds a = [2, 3, 4] and b = [5, 6, 7] over 3 cycles.
// Expected accumulator result: 2*5 + 3*6 + 4*7 = 56

module tb_pe (
    input logic clk
);

    localparam int DATA_W = 8;
    localparam int ACC_W  = 32;

    logic                  rst;
    logic signed [DATA_W-1:0] a_in;
    logic signed [DATA_W-1:0] b_in;
    logic signed [DATA_W-1:0] a_out;
    logic signed [DATA_W-1:0] b_out;
    logic signed [ACC_W-1:0]  acc;

    pe #(
        .DATA_W(DATA_W),
        .ACC_W (ACC_W)
    ) dut (
        .clk  (clk),
        .rst  (rst),
        .a_in (a_in),
        .b_in (b_in),
        .a_out(a_out),
        .b_out(b_out),
        .acc  (acc)
    );

    // Clock driven from C++ main (Verilator-compatible)
    logic signed [DATA_W-1:0] a_vals [3];
    logic signed [DATA_W-1:0] b_vals [3];
    int errors;

    initial begin
        a_vals[0] = 8'sd2;
        a_vals[1] = 8'sd3;
        a_vals[2] = 8'sd4;
        b_vals[0] = 8'sd5;
        b_vals[1] = 8'sd6;
        b_vals[2] = 8'sd7;

        errors = 0;
        rst = 1;
        a_in = 0;
        b_in = 0;

        repeat (2) @(posedge clk);
        rst = 0;

        for (int i = 0; i < 3; i++) begin
            @(negedge clk);
            a_in = a_vals[i];
            b_in = b_vals[i];
            @(posedge clk);
        end

        // One more cycle for registered acc to settle
        @(posedge clk);

        if (acc !== 32'sd56) begin
            $display("FAIL: acc = %0d, expected 56", acc);
            errors++;
        end else begin
            $display("PASS: PE accumulator = 56");
        end

        if (errors == 0)
            $display("=== tb_pe: ALL TESTS PASSED ===");
        else
            $display("=== tb_pe: %0d TEST(S) FAILED ===", errors);

        $finish;
    end

endmodule
