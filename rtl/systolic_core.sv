`timescale 1ns / 1ps

// TPU-shaped systolic core — AXIS weight/activation/result streams.
// Contract: docs/contracts.md
// FSM: LOAD_W → LOAD_A → WAIT_START → RUN → DRAIN
module systolic_core #(
    parameter int N      = 4,
    parameter int DATA_W = 8,
    parameter int ACC_W  = 32
) (
    input  logic                  clk,
    input  logic                  rst,

    // Weights (B) — stream N*N int8
    input  logic                  w_tvalid,
    output logic                  w_tready,
    input  logic signed [DATA_W-1:0] w_tdata,

    // Activations (A) — stream N*N int8
    input  logic                  a_tvalid,
    output logic                  a_tready,
    input  logic signed [DATA_W-1:0] a_tdata,

    // Control
    input  logic                  start,
    output logic                  done,

    // Results (C) — stream N*N int32
    output logic                  c_tvalid,
    input  logic                  c_tready,
    output logic signed [ACC_W-1:0] c_tdata
);

    localparam int NN = N * N;

    typedef enum logic [2:0] {
        ST_LOAD_W,
        ST_LOAD_A,
        ST_WAIT_START,
        ST_RUN,
        ST_DRAIN
    } state_t;

    state_t state;
    logic [$clog2(NN+1)-1:0] load_idx;
    logic [$clog2(NN+1)-1:0] out_idx;
    logic                    saw_running;  // core_done fell after our start

    logic signed [DATA_W-1:0] a_buf [N][N];
    logic signed [DATA_W-1:0] b_buf [N][N];
    logic signed [ACC_W-1:0]  c_out [N][N];

    logic core_start;
    logic core_done;
    logic drain_active;
    logic c_beat_fire;

    top #(
        .N     (N),
        .DATA_W(DATA_W),
        .ACC_W (ACC_W)
    ) u_top (
        .clk   (clk),
        .rst   (rst),
        .start (core_start),
        .done  (core_done),
        .a_load(a_buf),
        .b_load(b_buf),
        .c_out (c_out)
    );

    assign w_tready = (state == ST_LOAD_W);
    assign a_tready = (state == ST_LOAD_A);

    assign c_beat_fire = c_tvalid && c_tready;

    always_ff @(posedge clk) begin
        if (rst) begin
            state      <= ST_LOAD_W;
            load_idx   <= '0;
            out_idx      <= '0;
            core_start   <= 1'b0;
            done         <= 1'b0;
            c_tvalid     <= 1'b0;
            c_tdata      <= '0;
            drain_active <= 1'b0;
            saw_running  <= 1'b0;
            for (int i = 0; i < N; i++)
                for (int j = 0; j < N; j++) begin
                    a_buf[i][j] <= '0;
                    b_buf[i][j] <= '0;
                end
        end else begin
            core_start <= 1'b0;

            case (state)
                ST_LOAD_W: begin
                    if (w_tvalid) begin
                        b_buf[load_idx / N][load_idx % N] <= w_tdata;
                        if (load_idx == NN - 1) begin
                            load_idx <= '0;
                            state    <= ST_LOAD_A;
                        end else begin
                            load_idx <= load_idx + 1'b1;
                        end
                    end
                end

                ST_LOAD_A: begin
                    if (a_tvalid) begin
                        a_buf[load_idx / N][load_idx % N] <= a_tdata;
                        if (load_idx == NN - 1) begin
                            load_idx <= '0;
                            state    <= ST_WAIT_START;
                        end else begin
                            load_idx <= load_idx + 1'b1;
                        end
                    end
                end

                ST_WAIT_START: begin
                    if (start) begin
                        core_start  <= 1'b1;
                        done        <= 1'b0;
                        saw_running <= 1'b0;
                        state       <= ST_RUN;
                    end
                end

                ST_RUN: begin
                    // Wait for sticky core_done to clear after start, then rise again
                    if (!core_done)
                        saw_running <= 1'b1;
                    if (saw_running && core_done) begin
                        out_idx      <= '0;
                        drain_active <= 1'b1;
                        c_tvalid     <= 1'b1;
                        c_tdata      <= c_out[0][0];
                        state        <= ST_DRAIN;
                    end
                end

                ST_DRAIN: begin
                    // Hold c_tdata/c_tvalid when !c_tready (stall, no drop)
                    if (c_beat_fire) begin
                        if (out_idx == NN - 1) begin
                            c_tvalid     <= 1'b0;
                            c_tdata      <= '0;
                            out_idx      <= '0;
                            drain_active <= 1'b0;
                            done         <= 1'b1;  // sticky until next start
                            state        <= ST_LOAD_W;
                        end else begin
                            out_idx  <= out_idx + 1'b1;
                            c_tvalid <= 1'b1;
                            c_tdata  <= c_out[(out_idx + 1) / N][(out_idx + 1) % N];
                        end
                    end
                end

                default: state <= ST_LOAD_W;
            endcase
        end
    end

endmodule
