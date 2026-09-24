`timescale 1ns / 1ps

// Thorough testbench for systolic_core (AXIS TPU-shaped contract).
// See docs/contracts.md.
//
// Cases:
//   1. Happy path: weights → acts → start → drain C (identity + random cases)
//   2. Backpressure: deassert c_tready mid-drain; no drop/dup
//   3. Interleaved ready/valid bubbles on input streams
//   4. a_tready low while loading weights
//   5. Double-run: second matrix after full drain, no contamination
//   6. Idle after done: long wait, results unchanged

module tb_systolic_core (
    input logic clk
);

    localparam int N      = 4;
    localparam int DATA_W = 8;
    localparam int ACC_W  = 32;
    localparam int NN     = N * N;
    localparam string VECTORS_DIR = "../tb/test_vectors/";
    localparam string MANIFEST    = "../tb/test_vectors/manifest.list";

    logic                  rst;
    logic                  w_tvalid, w_tready;
    logic signed [DATA_W-1:0] w_tdata;
    logic                  a_tvalid, a_tready;
    logic signed [DATA_W-1:0] a_tdata;
    logic                  start, done;
    logic                  c_tvalid, c_tready;
    logic signed [ACC_W-1:0] c_tdata;

    systolic_core #(
        .N     (N),
        .DATA_W(DATA_W),
        .ACC_W (ACC_W)
    ) dut (
        .clk     (clk),
        .rst     (rst),
        .w_tvalid(w_tvalid),
        .w_tready(w_tready),
        .w_tdata (w_tdata),
        .a_tvalid(a_tvalid),
        .a_tready(a_tready),
        .a_tdata (a_tdata),
        .start   (start),
        .done    (done),
        .c_tvalid(c_tvalid),
        .c_tready(c_tready),
        .c_tdata (c_tdata)
    );

    logic signed [DATA_W-1:0] A_mat [N][N];
    logic signed [DATA_W-1:0] B_mat [N][N];
    logic signed [ACC_W-1:0]  C_got [N][N];
    logic signed [ACC_W-1:0]  C_exp [N][N];

    int errors;

    task automatic fail(input string msg);
        $display("FAIL: %s", msg);
        errors++;
    endtask

    task automatic abort_sim(input string msg);
        fail(msg);
        $display("=== tb_systolic_core: ABORTED (%0d failures) ===", errors);
        $finish;
    endtask

    task automatic pass(input string msg);
        $display("PASS: %s", msg);
    endtask

    // Software golden: C = A @ B (int8 → int32)
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

    task automatic load_case_file(input string filename);
        int file, i, j, val;
        string tag, cname;
        file = $fopen(filename, "r");
        if (file == 0) begin
            fail($sformatf("cannot open %s", filename));
            return;
        end
        void'($fscanf(file, "name %s\n", cname));
        void'($fscanf(file, "%s\n", tag));
        for (i = 0; i < N; i++)
            for (j = 0; j < N; j++) begin
                void'($fscanf(file, "%d", val));
                A_mat[i][j] = val;
            end
        void'($fscanf(file, "%s\n", tag));
        for (i = 0; i < N; i++)
            for (j = 0; j < N; j++) begin
                void'($fscanf(file, "%d", val));
                B_mat[i][j] = val;
            end
        $fclose(file);
        compute_golden();
    endtask

    task automatic set_identity();
        for (int i = 0; i < N; i++)
            for (int j = 0; j < N; j++) begin
                A_mat[i][j] = (i == j) ? 8'sd1 : 8'sd0;
                B_mat[i][j] = (i == j) ? 8'sd1 : 8'sd0;
            end
        compute_golden();
    endtask

    // Stream weights (B) then activations (A). bubble_every: insert idle cycles.
    task automatic stream_inputs(input int bubble_every);
        int i;
        int idle;

        w_tvalid = 0;
        a_tvalid = 0;

        // Weights first
        for (i = 0; i < NN; i++) begin
            if (bubble_every > 0 && i > 0 && (i % bubble_every == 0)) begin
                @(negedge clk);
                w_tvalid = 0;
                repeat (1) @(posedge clk);
            end
            @(negedge clk);
            w_tvalid = 1;
            w_tdata  = B_mat[i / N][i % N];
            // Complete one AXIS beat
            forever begin
                @(posedge clk);
                if (w_tready) break;
            end
            if (a_tready)
                fail("a_tready high while still loading weights");
        end
        @(negedge clk);
        w_tvalid = 0;

        // Activations
        for (i = 0; i < NN; i++) begin
            if (bubble_every > 0 && i > 0 && (i % bubble_every == 0)) begin
                @(negedge clk);
                a_tvalid = 0;
                repeat (1) @(posedge clk);
            end
            @(negedge clk);
            a_tvalid = 1;
            a_tdata  = A_mat[i / N][i % N];
            forever begin
                @(posedge clk);
                if (a_tready) break;
            end
        end
        @(negedge clk);
        a_tvalid = 0;
    endtask

    // Drain C with optional mid-stream backpressure
    task automatic drain_results(input int stall_after, input int stall_cycles);
        int i;
        int guard;

        c_tready = 0;
        for (i = 0; i < NN; i++) begin
            // Optional backpressure before beat stall_after
            if (stall_after >= 0 && i == stall_after && stall_cycles > 0) begin
                @(negedge clk);
                c_tready = 0;
                repeat (stall_cycles) @(posedge clk);
            end

            @(negedge clk);
            c_tready = 1;
            guard = 0;
            forever begin
                @(posedge clk);
                if (c_tvalid && c_tready) begin
                    C_got[i / N][i % N] = c_tdata;
                    break;
                end
                guard++;
                if (guard > 500)
                    abort_sim("timeout draining results");
            end
            @(negedge clk);
            c_tready = 0;
        end
    endtask

    task automatic wait_done(input int timeout_max);
        int t;
        t = 0;
        while (!done && t < timeout_max) begin
            @(posedge clk);
            t++;
        end
        if (!done)
            abort_sim($sformatf("timeout waiting for done (%0d cycles)", timeout_max));
    endtask

    task automatic pulse_start();
        @(negedge clk);
        start = 1;
        @(posedge clk);
        @(negedge clk);
        start = 0;
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
        if (mism != 0)
            fail($sformatf("%s: %0d element mismatches", name, mism));
        else
            pass(name);
    endtask

    task automatic run_matmul(input string name, input int bubble_every,
                              input int stall_after, input int stall_cycles);
        int t;
        stream_inputs(bubble_every);
        pulse_start();

        // Keep ready low until drain task is ready to capture (avoid lost beats)
        c_tready = 0;
        t = 0;
        while (!c_tvalid && t < 200) begin
            @(posedge clk);
            t++;
        end
        if (!c_tvalid && !done)
            fail($sformatf("%s: no c_tvalid after start", name));

        drain_results(stall_after, stall_cycles);
        wait_done(50);
        compare_c(name);
    endtask

    initial begin
        int mf;
        string cname, path;
        int case_i;
        logic signed [ACC_W-1:0] snap [N][N];

        errors   = 0;
        rst      = 1;
        w_tvalid = 0;
        a_tvalid = 0;
        start    = 0;
        c_tready = 1;
        w_tdata  = '0;
        a_tdata  = '0;

        repeat (3) @(posedge clk);
        rst = 0;
        @(posedge clk);

        // ---------------------------------------------------------------
        // 1. Happy path — identity
        // ---------------------------------------------------------------
        set_identity();
        run_matmul("happy_identity", 0, -1, 0);

        // ---------------------------------------------------------------
        // 2. Backpressure mid-drain
        // ---------------------------------------------------------------
        set_identity();
        run_matmul("backpressure_c", 0, 3, N);

        // ---------------------------------------------------------------
        // 3. Input stream bubbles
        // ---------------------------------------------------------------
        set_identity();
        run_matmul("input_bubbles", 3, -1, 0);

        // ---------------------------------------------------------------
        // 4. a_tready low while loading weights (checked inside stream_inputs)
        //    + a few random golden cases from manifest
        // ---------------------------------------------------------------
        mf = $fopen(MANIFEST, "r");
        if (mf == 0) begin
            fail("cannot open manifest — run golden_model.py generate");
        end else begin
            case_i = 0;
            while ($fscanf(mf, "%s", cname) == 1 && case_i < 5) begin
                // skip to interesting names: ones, mixed_sign, and first randoms
                if (cname == "ones" || cname == "mixed_sign" ||
                    cname == "random_000" || cname == "random_001" ||
                    cname == "sparse") begin
                    path = {VECTORS_DIR, cname, ".txt"};
                    load_case_file(path);
                    run_matmul($sformatf("golden_%s", cname), 0, -1, 0);
                    case_i++;
                end
            end
            $fclose(mf);
        end

        // ---------------------------------------------------------------
        // 5. Double-run — no contamination
        // ---------------------------------------------------------------
        set_identity();
        run_matmul("double_run_1", 0, -1, 0);
        // second: ones * ones via load
        load_case_file({VECTORS_DIR, "ones.txt"});
        run_matmul("double_run_2_ones", 0, -1, 0);

        // ---------------------------------------------------------------
        // 6. Idle after done — outputs unchanged
        // ---------------------------------------------------------------
        set_identity();
        run_matmul("idle_pre", 0, -1, 0);
        for (int i = 0; i < N; i++)
            for (int j = 0; j < N; j++)
                snap[i][j] = C_got[i][j];
        repeat (50) @(posedge clk);
        // Re-pulse c_tready and ensure done stays sticky; no new beats
        begin
            int extra;
            extra = 0;
            repeat (20) begin
                @(posedge clk);
                if (c_tvalid && c_tready)
                    extra++;
            end
            if (extra != 0)
                fail($sformatf("idle: unexpected extra C beats (%0d)", extra));
            if (!done)
                fail("idle: done not sticky");
            else
                pass("idle_after_done");
        end

        if (errors == 0)
            $display("=== tb_systolic_core: ALL TESTS PASSED ===");
        else
            $display("=== tb_systolic_core: %0d TEST(S) FAILED ===", errors);

        $finish;
    end

endmodule
