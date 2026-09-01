`timescale 1ns / 1ps

// Streaming wrapper around the systolic array top module.
// Students learn that an accelerator is a datapath with an interface and schedule.
//
// Protocol:
//   1. Stream 16 int8 values for matrix A (row-major), then 16 for B.
//   2. Assert start; wait for done.
//   3. Read 16 int32 values for matrix C on c_valid/c_data.
module streaming_top #(
    parameter int N      = 4,
    parameter int DATA_W = 8,
    parameter int ACC_W  = 32
) (
    input  logic                  clk,
    input  logic                  rst,

    // Stream matrix A and B operands (int8)
    input  logic                  a_valid,
    output logic                  a_ready,
    input  logic signed [DATA_W-1:0] a_data,

    input  logic                  b_valid,
    output logic                  b_ready,
    input  logic signed [DATA_W-1:0] b_data,

    // Control
    input  logic                  start,
    output logic                  done,

    // Stream matrix C results (int32)
    output logic                  c_valid,
    output logic signed [ACC_W-1:0] c_data
);

    logic signed [DATA_W-1:0] a_load [N][N];
    logic signed [DATA_W-1:0] b_load [N][N];
    logic signed [ACC_W-1:0]  c_out  [N][N];

    logic core_start;
    logic core_done;

    typedef enum logic [1:0] {
        ST_LOAD_A,
        ST_LOAD_B,
        ST_RUN,
        ST_OUTPUT
    } state_t;

    state_t state;
    logic [$clog2(N * N + 1) - 1:0] count;
    logic [$clog2(N * N + 1) - 1:0] out_idx;

    top #(
        .N     (N),
        .DATA_W(DATA_W),
        .ACC_W (ACC_W)
    ) u_top (
        .clk   (clk),
        .rst   (rst),
        .start (core_start),
        .done  (core_done),
        .a_load(a_load),
        .b_load(b_load),
        .c_out (c_out)
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            state      <= ST_LOAD_A;
            count      <= '0;
            out_idx    <= '0;
            core_start <= 1'b0;
            c_valid    <= 1'b0;
            c_data     <= '0;
            for (int i = 0; i < N; i++)
                for (int j = 0; j < N; j++) begin
                    a_load[i][j] <= '0;
                    b_load[i][j] <= '0;
                end
        end else begin
            core_start <= 1'b0;
            c_valid    <= 1'b0;

            case (state)
                ST_LOAD_A: begin
                    if (a_valid && a_ready) begin
                        a_load[count / N][count % N] <= a_data;
                        if (count == N * N - 1) begin
                            count <= '0;
                            state <= ST_LOAD_B;
                        end else begin
                            count <= count + 1'b1;
                        end
                    end
                end

                ST_LOAD_B: begin
                    if (b_valid && b_ready) begin
                        b_load[count / N][count % N] <= b_data;
                        if (count == N * N - 1) begin
                            count <= '0;
                            state <= ST_RUN;
                        end else begin
                            count <= count + 1'b1;
                        end
                    end
                end

                ST_RUN: begin
                    if (start) begin
                        core_start <= 1'b1;
                    end
                    if (core_done) begin
                        out_idx <= '0;
                        state   <= ST_OUTPUT;
                    end
                end

                ST_OUTPUT: begin
                    c_valid <= 1'b1;
                    c_data  <= c_out[out_idx / N][out_idx % N];
                    if (out_idx == N * N - 1) begin
                        state <= ST_LOAD_A;
                        count <= '0;
                    end else begin
                        out_idx <= out_idx + 1'b1;
                    end
                end
            endcase
        end
    end

    assign a_ready = (state == ST_LOAD_A);
    assign b_ready = (state == ST_LOAD_B);
    assign done    = (state == ST_OUTPUT) && (out_idx == N * N - 1) && c_valid;

endmodule
