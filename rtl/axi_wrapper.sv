`timescale 1ns / 1ps

// AXI4-Lite wrapper for Zynq PS access to systolic_core.
// Register map (word-aligned) — see docs/contracts.md:
//   0x00  CTRL    — bit0 start; bit1 soft clear
//   0x04  STATUS  — bit0 done; bit1 busy; bit2 w_buf_full; bit3 a_buf_full
//   0x10  W_MEM   — N*N int8 weights (B)
//   0x50  A_MEM   — N*N int8 activations (A)
//   0x90  C_MEM   — N*N int32 results (read-only)
//
// AXI-Lite: AW and W may arrive on different cycles (either order).
module axi_wrapper #(
    parameter int N      = 4,
    parameter int DATA_W = 8,
    parameter int ACC_W  = 32,
    parameter int C_S_AXI_DATA_WIDTH = 32,
    parameter int C_S_AXI_ADDR_WIDTH = 16
) (
    input  logic                            s_axi_aclk,
    input  logic                            s_axi_aresetn,
    input  logic [C_S_AXI_ADDR_WIDTH-1:0]   s_axi_awaddr,
    input  logic [2:0]                      s_axi_awprot,
    input  logic                            s_axi_awvalid,
    output logic                            s_axi_awready,
    input  logic [C_S_AXI_DATA_WIDTH-1:0]   s_axi_wdata,
    input  logic [C_S_AXI_DATA_WIDTH/8-1:0] s_axi_wstrb,
    input  logic                            s_axi_wvalid,
    output logic                            s_axi_wready,
    output logic [1:0]                      s_axi_bresp,
    output logic                            s_axi_bvalid,
    input  logic                            s_axi_bready,
    input  logic [C_S_AXI_ADDR_WIDTH-1:0]   s_axi_araddr,
    input  logic [2:0]                      s_axi_arprot,
    input  logic                            s_axi_arvalid,
    output logic                            s_axi_arready,
    output logic [C_S_AXI_DATA_WIDTH-1:0]   s_axi_rdata,
    output logic [1:0]                      s_axi_rresp,
    output logic                            s_axi_rvalid,
    input  logic                            s_axi_rready
);

    // AXI-Lite prot is required for BD interface inference; unused in decode.
    wire unused_awprot = |s_axi_awprot;
    wire unused_arprot = |s_axi_arprot;

    localparam int NN          = N * N;
    localparam int ADDR_CTRL   = 16'h0000;
    localparam int ADDR_STATUS = 16'h0004;
    localparam int ADDR_W_BASE = 16'h0010;
    localparam int ADDR_A_BASE = 16'h0050;
    localparam int ADDR_C_BASE = 16'h0090;

    logic clk;
    logic rst;
    assign clk = s_axi_aclk;
    assign rst = ~s_axi_aresetn;

    // -------- Host-side buffers --------
    logic signed [DATA_W-1:0] w_mem [N][N];
    logic signed [DATA_W-1:0] a_mem [N][N];
    logic signed [ACC_W-1:0]  c_mem [N][N];
    logic                     w_buf_full;
    logic                     a_buf_full;
    logic [$clog2(NN+1)-1:0]  w_fill;
    logic [$clog2(NN+1)-1:0]  a_fill;

    // -------- systolic_core AXIS --------
    logic                  w_tvalid, w_tready;
    logic signed [DATA_W-1:0] w_tdata;
    logic                  a_tvalid, a_tready;
    logic signed [DATA_W-1:0] a_tdata;
    logic                  core_start, core_done;
    logic                  c_tvalid, c_tready;
    logic signed [ACC_W-1:0] c_tdata;
    logic                  soft_clear;
    logic                  core_rst;

    assign core_rst = rst | soft_clear;

    systolic_core #(
        .N     (N),
        .DATA_W(DATA_W),
        .ACC_W (ACC_W)
    ) u_core (
        .clk     (clk),
        .rst     (core_rst),
        .w_tvalid(w_tvalid),
        .w_tready(w_tready),
        .w_tdata (w_tdata),
        .a_tvalid(a_tvalid),
        .a_tready(a_tready),
        .a_tdata (a_tdata),
        .start   (core_start),
        .done    (core_done),
        .c_tvalid(c_tvalid),
        .c_tready(c_tready),
        .c_tdata (c_tdata)
    );

    // -------- Run FSM: stream buffers → start → drain C --------
    typedef enum logic [2:0] {
        RF_IDLE,
        RF_STREAM_W,
        RF_STREAM_A,
        RF_START,
        RF_WAIT_DONE,
        RF_DRAIN
    } run_state_t;

    run_state_t run_state;
    logic [$clog2(NN+1)-1:0] run_idx;
    logic                    busy;
    logic                    done_sticky;
    logic                    start_pulse;
    logic                    start_pending;
    logic                    clear_pulse;

    assign busy = (run_state != RF_IDLE);

    always_ff @(posedge clk) begin
        if (rst) begin
            run_state     <= RF_IDLE;
            run_idx       <= '0;
            w_tvalid      <= 1'b0;
            a_tvalid      <= 1'b0;
            w_tdata       <= '0;
            a_tdata       <= '0;
            core_start    <= 1'b0;
            c_tready      <= 1'b0;
            done_sticky   <= 1'b0;
            start_pending <= 1'b0;
            for (int i = 0; i < N; i++)
                for (int j = 0; j < N; j++)
                    c_mem[i][j] <= '0;
        end else if (soft_clear) begin
            run_state     <= RF_IDLE;
            run_idx       <= '0;
            w_tvalid      <= 1'b0;
            a_tvalid      <= 1'b0;
            core_start    <= 1'b0;
            c_tready      <= 1'b0;
            done_sticky   <= 1'b0;
            start_pending <= 1'b0;
        end else begin
            core_start <= 1'b0;
            if (start_pulse)
                start_pending <= 1'b1;

            case (run_state)
                RF_IDLE: begin
                    w_tvalid <= 1'b0;
                    a_tvalid <= 1'b0;
                    c_tready <= 1'b0;
                    if (start_pending && w_buf_full && a_buf_full) begin
                        start_pending <= 1'b0;
                        done_sticky   <= 1'b0;
                        run_idx       <= '0;
                        w_tvalid      <= 1'b1;
                        w_tdata       <= w_mem[0][0];
                        run_state     <= RF_STREAM_W;
                    end
                end

                RF_STREAM_W: begin
                    w_tvalid <= 1'b1;
                    if (w_tvalid && w_tready) begin
                        if (run_idx == NN - 1) begin
                            w_tvalid  <= 1'b0;
                            run_idx   <= '0;
                            a_tvalid  <= 1'b1;
                            a_tdata   <= a_mem[0][0];
                            run_state <= RF_STREAM_A;
                        end else begin
                            run_idx <= run_idx + 1'b1;
                            w_tdata <= w_mem[(run_idx + 1) / N][(run_idx + 1) % N];
                        end
                    end
                end

                RF_STREAM_A: begin
                    a_tvalid <= 1'b1;
                    if (a_tvalid && a_tready) begin
                        if (run_idx == NN - 1) begin
                            a_tvalid  <= 1'b0;
                            run_state <= RF_START;
                        end else begin
                            run_idx <= run_idx + 1'b1;
                            a_tdata <= a_mem[(run_idx + 1) / N][(run_idx + 1) % N];
                        end
                    end
                end

                RF_START: begin
                    core_start <= 1'b1;
                    run_state  <= RF_WAIT_DONE;
                end

                RF_WAIT_DONE: begin
                    c_tready <= 1'b0;
                    if (c_tvalid) begin
                        run_idx   <= '0;
                        run_state <= RF_DRAIN;
                    end
                end

                RF_DRAIN: begin
                    c_tready <= 1'b1;
                    if (c_tvalid && c_tready) begin
                        c_mem[run_idx / N][run_idx % N] <= c_tdata;
                        if (run_idx == NN - 1) begin
                            c_tready    <= 1'b0;
                            done_sticky <= 1'b1;
                            run_state   <= RF_IDLE;
                        end else begin
                            run_idx <= run_idx + 1'b1;
                        end
                    end
                end

                default: run_state <= RF_IDLE;
            endcase
        end
    end

    // -------- AXI-Lite write channel (split AW/W) --------
    logic aw_hs_done;
    logic w_hs_done;
    logic [C_S_AXI_ADDR_WIDTH-1:0] awaddr_hold;
    logic [C_S_AXI_DATA_WIDTH-1:0] wdata_hold;
    logic                          do_write;

    assign s_axi_awready = ~aw_hs_done & ~s_axi_bvalid;
    assign s_axi_wready  = ~w_hs_done  & ~s_axi_bvalid;
    assign s_axi_bresp   = 2'b00;

    assign do_write = aw_hs_done & w_hs_done & ~s_axi_bvalid;

    // soft_clear is one-cycle pulse into core_rst / run FSM
    always_ff @(posedge clk) begin
        if (rst)
            soft_clear <= 1'b0;
        else
            soft_clear <= clear_pulse;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            aw_hs_done   <= 1'b0;
            w_hs_done    <= 1'b0;
            awaddr_hold  <= '0;
            wdata_hold   <= '0;
            s_axi_bvalid <= 1'b0;
            start_pulse  <= 1'b0;
            clear_pulse  <= 1'b0;
            w_buf_full   <= 1'b0;
            a_buf_full   <= 1'b0;
            w_fill       <= '0;
            a_fill       <= '0;
            for (int i = 0; i < N; i++)
                for (int j = 0; j < N; j++) begin
                    w_mem[i][j] <= '0;
                    a_mem[i][j] <= '0;
                end
        end else begin
            start_pulse <= 1'b0;
            clear_pulse <= 1'b0;

            if (soft_clear) begin
                w_buf_full <= 1'b0;
                a_buf_full <= 1'b0;
                w_fill     <= '0;
                a_fill     <= '0;
            end

            // Capture AW
            if (s_axi_awvalid && s_axi_awready) begin
                awaddr_hold <= s_axi_awaddr;
                aw_hs_done  <= 1'b1;
            end
            // Capture W
            if (s_axi_wvalid && s_axi_wready) begin
                wdata_hold <= s_axi_wdata;
                w_hs_done  <= 1'b1;
            end

            // Commit when both halves present
            if (do_write) begin
                s_axi_bvalid <= 1'b1;
                aw_hs_done   <= 1'b0;
                w_hs_done    <= 1'b0;

                case (awaddr_hold)
                    ADDR_CTRL: begin
                        if (wdata_hold[0])
                            start_pulse <= 1'b1;
                        if (wdata_hold[1])
                            clear_pulse <= 1'b1;
                    end
                    default: begin
                        if (awaddr_hold >= ADDR_W_BASE && awaddr_hold < ADDR_A_BASE) begin
                            int widx;
                            widx = (awaddr_hold - ADDR_W_BASE) >> 2;
                            w_mem[widx / N][widx % N] <= wdata_hold[DATA_W-1:0];
                            if (w_fill < NN)
                                w_fill <= w_fill + 1'b1;
                            if (w_fill + 1'b1 >= NN)
                                w_buf_full <= 1'b1;
                        end else if (awaddr_hold >= ADDR_A_BASE && awaddr_hold < ADDR_C_BASE) begin
                            int aidx;
                            aidx = (awaddr_hold - ADDR_A_BASE) >> 2;
                            a_mem[aidx / N][aidx % N] <= wdata_hold[DATA_W-1:0];
                            if (a_fill < NN)
                                a_fill <= a_fill + 1'b1;
                            if (a_fill + 1'b1 >= NN)
                                a_buf_full <= 1'b1;
                        end
                    end
                endcase
            end

            if (s_axi_bvalid && s_axi_bready)
                s_axi_bvalid <= 1'b0;
        end
    end

    // -------- AXI-Lite read channel --------
    assign s_axi_arready = s_axi_arvalid & ~s_axi_rvalid;
    assign s_axi_rresp   = 2'b00;

    always_ff @(posedge clk) begin
        if (rst) begin
            s_axi_rvalid <= 1'b0;
            s_axi_rdata  <= '0;
        end else begin
            if (s_axi_arvalid && s_axi_arready) begin
                s_axi_rvalid <= 1'b1;
                case (s_axi_araddr)
                    ADDR_CTRL:   s_axi_rdata <= 32'h0;
                    ADDR_STATUS: s_axi_rdata <= {28'b0, a_buf_full, w_buf_full, busy, done_sticky};
                    default: begin
                        if (s_axi_araddr >= ADDR_C_BASE) begin
                            int cidx;
                            cidx = (s_axi_araddr - ADDR_C_BASE) >> 2;
                            s_axi_rdata <= c_mem[cidx / N][cidx % N];
                        end else begin
                            s_axi_rdata <= 32'h0;
                        end
                    end
                endcase
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
