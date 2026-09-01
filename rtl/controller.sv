`timescale 1ns / 1ps

// Controller: loads A/B matrices and drives skewed operand injection.
// Skew schedule (see docs/01_dataflow.md):
//   A[i][k] enters row i at cycle (i + k)
//   B[k][j] enters col j at cycle (k + j)
module controller #(
    parameter int N      = 4,
    parameter int DATA_W = 8
) (
    input  logic                  clk,
    input  logic                  rst,
    input  logic                  start,
    output logic                  done,
    output logic                  clear_acc,
    output logic signed [DATA_W-1:0] a_drv [N],
    output logic signed [DATA_W-1:0] b_drv [N],
    input  logic signed [DATA_W-1:0] a_mem [N][N],
    input  logic signed [DATA_W-1:0] b_mem [N][N]
);

    localparam int TOTAL_CYCLES = 3 * N - 2;

    typedef enum logic [1:0] {
        ST_IDLE,
        ST_CLEAR,
        ST_RUN,
        ST_DONE
    } state_t;

    state_t state;
    logic [$clog2(TOTAL_CYCLES + 1) - 1:0] cycle;
    logic signed [DATA_W-1:0] a_skew [N];
    logic signed [DATA_W-1:0] b_skew [N];

    // Skewed injection: at cycle t, inject matching A/B operands per row/col
    always_comb begin
        for (int i = 0; i < N; i++) begin
            int k_a = cycle - i;
            if (k_a >= 0 && k_a < N)
                a_skew[i] = a_mem[i][k_a];
            else
                a_skew[i] = '0;
        end
        for (int j = 0; j < N; j++) begin
            int k_b = cycle - j;
            if (k_b >= 0 && k_b < N)
                b_skew[j] = b_mem[k_b][j];
            else
                b_skew[j] = '0;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            state     <= ST_IDLE;
            cycle     <= '0;
            done      <= 1'b0;
            clear_acc <= 1'b0;
            for (int i = 0; i < N; i++) begin
                a_drv[i] <= '0;
                b_drv[i] <= '0;
            end
        end else begin
            clear_acc <= 1'b0;

            case (state)
                ST_IDLE: begin
                    if (start) begin
                        done      <= 1'b0;
                        clear_acc <= 1'b1;
                        state     <= ST_CLEAR;
                    end
                end

                ST_CLEAR: begin
                    state <= ST_RUN;
                    cycle <= '0;
                end

                ST_RUN: begin
                    for (int i = 0; i < N; i++) begin
                        a_drv[i] <= a_skew[i];
                        b_drv[i] <= b_skew[i];
                    end

                    if (cycle == TOTAL_CYCLES - 1) begin
                        state <= ST_DONE;
                    end else begin
                        cycle <= cycle + 1'b1;
                    end
                end

                ST_DONE: begin
                    done  <= 1'b1;
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
