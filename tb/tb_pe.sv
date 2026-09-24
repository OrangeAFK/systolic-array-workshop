`timescale 1ns / 1ps

// Testbench for the processing element (Stage 1).
// Contract: docs/contracts.md — en hold, clear, idle no-MAC.
//
// Cases:
//   1. MAC when en=1: a=[2,3,4], b=[5,6,7] → acc=56
//   2. Hold when en=0: non-zero inputs must not change acc/a_out/b_out
//   3. clear zeros acc without full rst
//   4. Idle multi-cycle with stuck inputs → acc unchanged

module tb_pe (
    input logic clk
);

    localparam int DATA_W = 8;
    localparam int ACC_W  = 32;

    logic                  rst;
    logic                  en;
    logic                  clear;
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
        .en   (en),
        .clear(clear),
        .a_in (a_in),
        .b_in (b_in),
        .a_out(a_out),
        .b_out(b_out),
        .acc  (acc)
    );

    int errors;

    task automatic check_eq_s32(input string name, input logic signed [ACC_W-1:0] got,
                                input logic signed [ACC_W-1:0] exp);
        if (got !== exp) begin
            $display("FAIL [%s]: got %0d, expected %0d", name, got, exp);
            errors++;
        end else begin
            $display("PASS [%s]: %0d", name, got);
        end
    endtask

    task automatic check_eq_s8(input string name, input logic signed [DATA_W-1:0] got,
                               input logic signed [DATA_W-1:0] exp);
        if (got !== exp) begin
            $display("FAIL [%s]: got %0d, expected %0d", name, got, exp);
            errors++;
        end else begin
            $display("PASS [%s]: %0d", name, got);
        end
    endtask

    initial begin
        logic signed [DATA_W-1:0] a_vals [3];
        logic signed [DATA_W-1:0] b_vals [3];
        logic signed [ACC_W-1:0]  acc_snap;
        logic signed [DATA_W-1:0] a_snap;
        logic signed [DATA_W-1:0] b_snap;

        a_vals[0] = 8'sd2;
        a_vals[1] = 8'sd3;
        a_vals[2] = 8'sd4;
        b_vals[0] = 8'sd5;
        b_vals[1] = 8'sd6;
        b_vals[2] = 8'sd7;

        errors = 0;
        rst   = 1;
        en    = 0;
        clear = 0;
        a_in  = 0;
        b_in  = 0;

        repeat (2) @(posedge clk);
        rst = 0;
        @(posedge clk);

        // ---------------------------------------------------------------
        // Case 1: MAC when en=1
        // ---------------------------------------------------------------
        en = 1;
        for (int i = 0; i < 3; i++) begin
            @(negedge clk);
            a_in = a_vals[i];
            b_in = b_vals[i];
            @(posedge clk);
        end
        @(posedge clk);
        check_eq_s32("mac_en1", acc, 32'sd56);

        // ---------------------------------------------------------------
        // Case 2: Hold when en=0 — non-zero inputs must not accumulate
        // ---------------------------------------------------------------
        @(negedge clk);
        en   = 0;
        a_in = 8'sd9;
        b_in = 8'sd9;
        acc_snap = acc;
        a_snap   = a_out;
        b_snap   = b_out;
        repeat (5) @(posedge clk);
        check_eq_s32("hold_acc", acc, acc_snap);
        check_eq_s8("hold_a_out", a_out, a_snap);
        check_eq_s8("hold_b_out", b_out, b_snap);

        // ---------------------------------------------------------------
        // Case 3: clear zeros acc without full rst
        // ---------------------------------------------------------------
        @(negedge clk);
        clear = 1;
        en    = 0;
        @(posedge clk);
        @(negedge clk);
        clear = 0;
        @(posedge clk);
        check_eq_s32("clear_acc", acc, 32'sd0);
        // a_out/b_out should still be held (en=0 during clear)
        check_eq_s8("clear_hold_a", a_out, a_snap);
        check_eq_s8("clear_hold_b", b_out, b_snap);

        // ---------------------------------------------------------------
        // Case 4: Idle multi-cycle with stuck inputs → acc unchanged
        // ---------------------------------------------------------------
        @(negedge clk);
        en   = 0;
        a_in = 8'sd7;
        b_in = 8'sd3;
        acc_snap = acc;
        repeat (10) @(posedge clk);
        check_eq_s32("idle_stuck", acc, acc_snap);

        // Resume MAC briefly to confirm still functional after clear/hold
        @(negedge clk);
        en   = 1;
        a_in = 8'sd2;
        b_in = 8'sd4;
        @(posedge clk);
        @(posedge clk);
        check_eq_s32("mac_after_clear", acc, 32'sd8);

        if (errors == 0)
            $display("=== tb_pe: ALL TESTS PASSED ===");
        else
            $display("=== tb_pe: %0d TEST(S) FAILED ===", errors);

        $finish;
    end

endmodule
