`timescale 1ns / 1ps

// AXI4-Lite BFM testbench for axi_wrapper.
// Contract: docs/contracts.md — register map + split AW/W.
//
// Cases:
//   1. Write W_MEM/A_MEM with AW-then-W and W-then-AW
//   2. CTRL start, poll STATUS.done, read C_MEM vs golden
//   3. STATUS bits: busy, w_buf_full, a_buf_full
//   4. Soft clear (CTRL bit1)
//   5. Back-to-back / wait states on RREADY/BREADY

module tb_axi_wrapper (
    input logic clk
);

    localparam int N      = 4;
    localparam int DATA_W = 8;
    localparam int ACC_W  = 32;
    localparam int AW     = 16;
    localparam int DW     = 32;
    localparam int NN     = N * N;

    localparam logic [15:0] ADDR_CTRL   = 16'h0000;
    localparam logic [15:0] ADDR_STATUS = 16'h0004;
    localparam logic [15:0] ADDR_W_BASE = 16'h0010;
    localparam logic [15:0] ADDR_A_BASE = 16'h0050;
    localparam logic [15:0] ADDR_C_BASE = 16'h0090;

    logic        rstn;
    logic [AW-1:0]  awaddr;
    logic [2:0]     awprot;
    logic           awvalid;
    logic           awready;
    logic [DW-1:0]  wdata;
    logic [DW/8-1:0] wstrb;
    logic           wvalid;
    logic           wready;
    logic [1:0]     bresp;
    logic           bvalid;
    logic           bready;
    logic [AW-1:0]  araddr;
    logic [2:0]     arprot;
    logic           arvalid;
    logic           arready;
    logic [DW-1:0]  rdata;
    logic [1:0]     rresp;
    logic           rvalid;
    logic           rready;

    axi_wrapper #(
        .N(N), .DATA_W(DATA_W), .ACC_W(ACC_W),
        .C_S_AXI_DATA_WIDTH(DW),
        .C_S_AXI_ADDR_WIDTH(AW)
    ) dut (
        .s_axi_aclk   (clk),
        .s_axi_aresetn(rstn),
        .s_axi_awaddr (awaddr),
        .s_axi_awprot (awprot),
        .s_axi_awvalid(awvalid),
        .s_axi_awready(awready),
        .s_axi_wdata  (wdata),
        .s_axi_wstrb  (wstrb),
        .s_axi_wvalid (wvalid),
        .s_axi_wready (wready),
        .s_axi_bresp  (bresp),
        .s_axi_bvalid (bvalid),
        .s_axi_bready (bready),
        .s_axi_araddr (araddr),
        .s_axi_arprot (arprot),
        .s_axi_arvalid(arvalid),
        .s_axi_arready(arready),
        .s_axi_rdata  (rdata),
        .s_axi_rresp  (rresp),
        .s_axi_rvalid (rvalid),
        .s_axi_rready (rready)
    );

    logic signed [DATA_W-1:0] A_mat [N][N];
    logic signed [DATA_W-1:0] B_mat [N][N];
    logic signed [ACC_W-1:0]  C_exp [N][N];
    logic signed [ACC_W-1:0]  C_got [N][N];

    int errors;

    task automatic fail(input string msg);
        $display("FAIL: %s", msg);
        errors++;
    endtask

    task automatic pass(input string msg);
        $display("PASS: %s", msg);
    endtask

    task automatic abort_sim(input string msg);
        fail(msg);
        $display("=== tb_axi_wrapper: ABORTED (%0d failures) ===", errors);
        $finish;
    endtask

    task automatic compute_golden();
        for (int i = 0; i < N; i++)
            for (int j = 0; j < N; j++) begin
                logic signed [ACC_W-1:0] sum;
                sum = '0;
                for (int k = 0; k < N; k++)
                    sum += ACC_W'(A_mat[i][k]) * ACC_W'(B_mat[k][j]);
                C_exp[i][j] = sum;
            end
    endtask

    task automatic set_identity();
        for (int i = 0; i < N; i++)
            for (int j = 0; j < N; j++) begin
                A_mat[i][j] = (i == j) ? 8'sd1 : 8'sd0;
                B_mat[i][j] = (i == j) ? 8'sd1 : 8'sd0;
            end
        compute_golden();
    endtask

    // ---------- AXI-Lite BFM ----------
    task automatic axi_write_split_aw_then_w(input logic [AW-1:0] addr,
                                             input logic [DW-1:0] data);
        int guard;
        @(negedge clk);
        awaddr  = addr;
        awvalid = 1;
        wvalid  = 0;
        guard = 0;
        forever begin
            @(posedge clk);
            if (awready) break;
            guard++;
            if (guard > 100) abort_sim("timeout AW ready");
        end
        @(negedge clk);
        awvalid = 0;
        wdata   = data;
        wstrb   = 4'hF;
        wvalid  = 1;
        guard = 0;
        forever begin
            @(posedge clk);
            if (wready) break;
            guard++;
            if (guard > 100) abort_sim("timeout W ready");
        end
        @(negedge clk);
        wvalid = 0;
        bready = 1;
        guard = 0;
        forever begin
            @(posedge clk);
            if (bvalid) break;
            guard++;
            if (guard > 100) abort_sim("timeout B valid");
        end
        @(negedge clk);
        bready = 0;
    endtask

    task automatic axi_write_split_w_then_aw(input logic [AW-1:0] addr,
                                             input logic [DW-1:0] data);
        int guard;
        @(negedge clk);
        wdata   = data;
        wstrb   = 4'hF;
        wvalid  = 1;
        awvalid = 0;
        guard = 0;
        forever begin
            @(posedge clk);
            if (wready) break;
            guard++;
            if (guard > 100) abort_sim("timeout W ready (W-first)");
        end
        @(negedge clk);
        wvalid  = 0;
        awaddr  = addr;
        awvalid = 1;
        guard = 0;
        forever begin
            @(posedge clk);
            if (awready) break;
            guard++;
            if (guard > 100) abort_sim("timeout AW ready (W-first)");
        end
        @(negedge clk);
        awvalid = 0;
        bready  = 1;
        guard = 0;
        forever begin
            @(posedge clk);
            if (bvalid) break;
            guard++;
            if (guard > 100) abort_sim("timeout B valid (W-first)");
        end
        @(negedge clk);
        bready = 0;
    endtask

    task automatic axi_write(input logic [AW-1:0] addr, input logic [DW-1:0] data,
                             input bit use_w_first);
        if (use_w_first)
            axi_write_split_w_then_aw(addr, data);
        else
            axi_write_split_aw_then_w(addr, data);
    endtask

    task automatic axi_read(input logic [AW-1:0] addr, output logic [DW-1:0] data,
                            input int rready_delay);
        int d;
        @(negedge clk);
        araddr  = addr;
        arvalid = 1;
        rready  = 0;
        forever begin
            @(posedge clk);
            if (arready) break;
        end
        @(negedge clk);
        arvalid = 0;
        for (d = 0; d < rready_delay; d++)
            @(posedge clk);
        @(negedge clk);
        rready = 1;
        forever begin
            @(posedge clk);
            if (rvalid) begin
                data = rdata;
                break;
            end
        end
        @(negedge clk);
        rready = 0;
    endtask

    task automatic load_matrices_mmio(input bit alt_order);
        int idx;
        // Weights (B) at W_MEM, activations (A) at A_MEM
        for (idx = 0; idx < NN; idx++) begin
            axi_write(ADDR_W_BASE + (idx * 4),
                      {{(DW-DATA_W){B_mat[idx/N][idx%N][DATA_W-1]}}, B_mat[idx/N][idx%N]},
                      alt_order && (idx[0]));
        end
        for (idx = 0; idx < NN; idx++) begin
            axi_write(ADDR_A_BASE + (idx * 4),
                      {{(DW-DATA_W){A_mat[idx/N][idx%N][DATA_W-1]}}, A_mat[idx/N][idx%N]},
                      !alt_order && (idx[0]));
        end
    endtask

    task automatic read_status(output logic [DW-1:0] st);
        axi_read(ADDR_STATUS, st, 0);
    endtask

    task automatic read_c_mem();
        int idx;
        logic [DW-1:0] d;
        for (idx = 0; idx < NN; idx++) begin
            axi_read(ADDR_C_BASE + (idx * 4), d, (idx == 2) ? 2 : 0);
            C_got[idx/N][idx%N] = d;
        end
    endtask

    task automatic compare_c(input string name);
        int mism;
        mism = 0;
        for (int i = 0; i < N; i++)
            for (int j = 0; j < N; j++)
                if (C_got[i][j] !== C_exp[i][j]) begin
                    $display("  mismatch C[%0d][%0d]: got %0d exp %0d",
                             i, j, C_got[i][j], C_exp[i][j]);
                    mism++;
                end
        if (mism)
            fail($sformatf("%s: %0d mismatches", name, mism));
        else
            pass(name);
    endtask

    task automatic poll_done(input int timeout_max);
        int t;
        logic [DW-1:0] st;
        t = 0;
        forever begin
            read_status(st);
            if (st[0]) break;
            t++;
            if (t > timeout_max)
                abort_sim("timeout polling STATUS.done");
        end
    endtask

    initial begin
        logic [DW-1:0] st;
        errors  = 0;
        rstn    = 0;
        awvalid = 0;
        wvalid  = 0;
        bready  = 0;
        arvalid = 0;
        rready  = 0;
        awaddr  = '0;
        awprot  = 3'b000;
        wdata   = '0;
        wstrb   = 4'hF;
        araddr  = '0;
        arprot  = 3'b000;

        repeat (4) @(posedge clk);
        rstn = 1;
        repeat (2) @(posedge clk);

        // ---------------------------------------------------------------
        // 1+2: Split AW/W loads, start, poll done, read C (identity)
        // ---------------------------------------------------------------
        set_identity();
        load_matrices_mmio(1'b0);  // AW-then-W dominant

        read_status(st);
        if (!st[2]) fail("STATUS.w_buf_full not set after W load");
        else pass("status_w_buf_full");
        if (!st[3]) fail("STATUS.a_buf_full not set after A load");
        else pass("status_a_buf_full");

        axi_write(ADDR_CTRL, 32'h1, 1'b0);  // start
        // Busy should assert during run (poll a few times)
        begin
            int saw_busy;
            saw_busy = 0;
            repeat (5) begin
                read_status(st);
                if (st[1]) saw_busy = 1;
                if (st[0]) break;
            end
            if (!saw_busy && !st[0])
                fail("STATUS.busy never seen");
            else
                pass("status_busy_or_fast_done");
        end
        poll_done(200);
        pass("poll_done");
        read_c_mem();
        compare_c("axi_identity_aw_then_w");

        // ---------------------------------------------------------------
        // Split W-then-AW path + ones matmul
        // ---------------------------------------------------------------
        for (int i = 0; i < N; i++)
            for (int j = 0; j < N; j++) begin
                A_mat[i][j] = 8'sd1;
                B_mat[i][j] = 8'sd1;
            end
        compute_golden();
        load_matrices_mmio(1'b1);
        axi_write(ADDR_CTRL, 32'h1, 1'b1);  // start via W-then-AW
        poll_done(200);
        read_c_mem();
        compare_c("axi_ones_w_then_aw");

        // ---------------------------------------------------------------
        // Soft clear: CTRL bit1 — clears done / returns toward idle
        // ---------------------------------------------------------------
        axi_write(ADDR_CTRL, 32'h2, 1'b0);
        read_status(st);
        if (st[0])
            fail("soft clear left done set");
        else
            pass("soft_clear_done");

        // ---------------------------------------------------------------
        // Back-to-back identity again after clear
        // ---------------------------------------------------------------
        set_identity();
        load_matrices_mmio(1'b0);
        axi_write(ADDR_CTRL, 32'h1, 1'b0);
        poll_done(200);
        read_c_mem();
        compare_c("axi_after_clear");

        if (errors == 0)
            $display("=== tb_axi_wrapper: ALL TESTS PASSED ===");
        else
            $display("=== tb_axi_wrapper: %0d TEST(S) FAILED ===", errors);
        $finish;
    end

endmodule
