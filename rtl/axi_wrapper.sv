`timescale 1ns / 1ps

// AXI4-Lite wrapper for Zynq PS access to the systolic array.
// Register map (word-aligned, 4-byte offsets):
//   0x00  CTRL    — bit 0: start pulse
//   0x04  STATUS  — bit 0: done flag
//   0x10  A_MEM   — 16 x int8 matrix A (row-major)
//   0x50  B_MEM   — 16 x int8 matrix B (row-major)
//   0x90  C_MEM   — 16 x int32 matrix C (row-major, read-only)
module axi_wrapper #(
    parameter int N      = 4,
    parameter int DATA_W = 8,
    parameter int ACC_W  = 32,
    parameter int C_S_AXI_DATA_WIDTH = 32,
    parameter int C_S_AXI_ADDR_WIDTH = 8
) (
    input  logic                            s_axi_aclk,
    input  logic                            s_axi_aresetn,
    input  logic [C_S_AXI_ADDR_WIDTH-1:0]   s_axi_awaddr,
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
    input  logic                            s_axi_arvalid,
    output logic                            s_axi_arready,
    output logic [C_S_AXI_DATA_WIDTH-1:0]   s_axi_rdata,
    output logic [1:0]                      s_axi_rresp,
    output logic                            s_axi_rvalid,
    input  logic                            s_axi_rready
);

    localparam int ADDR_CTRL   = 8'h00;
    localparam int ADDR_STATUS = 8'h04;
    localparam int ADDR_A_BASE = 8'h10;
    localparam int ADDR_B_BASE = 8'h50;
    localparam int ADDR_C_BASE = 8'h90;

    logic clk;
    logic rst;
    logic start_pulse;
    logic done_flag;
    logic signed [DATA_W-1:0] a_load [N][N];
    logic signed [DATA_W-1:0] b_load [N][N];
    logic signed [ACC_W-1:0]  c_out  [N][N];

    assign clk = s_axi_aclk;
    assign rst = ~s_axi_aresetn;

    top #(
        .N     (N),
        .DATA_W(DATA_W),
        .ACC_W (ACC_W)
    ) u_top (
        .clk   (clk),
        .rst   (rst),
        .start (start_pulse),
        .done  (done_flag),
        .a_load(a_load),
        .b_load(b_load),
        .c_out (c_out)
    );

    // AXI-lite write channel
    logic aw_en;
    logic [C_S_AXI_ADDR_WIDTH-1:0] awaddr_reg;
    logic [C_S_AXI_DATA_WIDTH-1:0] wdata_reg;

    assign s_axi_awready = s_axi_awvalid & ~s_axi_bvalid;
    assign s_axi_wready  = s_axi_wvalid & ~s_axi_bvalid;

  always_ff @(posedge clk) begin
        if (rst) begin
            s_axi_bvalid <= 1'b0;
            aw_en        <= 1'b1;
            start_pulse  <= 1'b0;
            for (int i = 0; i < N; i++)
                for (int j = 0; j < N; j++) begin
                    a_load[i][j] <= '0;
                    b_load[i][j] <= '0;
                end
        end else begin
            start_pulse <= 1'b0;

            if (s_axi_awvalid && s_axi_wvalid && aw_en) begin
                awaddr_reg <= s_axi_awaddr;
                wdata_reg  <= s_axi_wdata;
                s_axi_bvalid <= 1'b1;
                aw_en        <= 1'b0;

                case (s_axi_awaddr)
                    ADDR_CTRL: begin
                        if (s_axi_wdata[0])
                            start_pulse <= 1'b1;
                    end
                    default: begin
                        if (s_axi_awaddr >= ADDR_A_BASE && s_axi_awaddr < ADDR_B_BASE) begin
                            int idx = (s_axi_awaddr - ADDR_A_BASE) >> 2;
                            a_load[idx / N][idx % N] <= s_axi_wdata[DATA_W-1:0];
                        end else if (s_axi_awaddr >= ADDR_B_BASE && s_axi_awaddr < ADDR_C_BASE) begin
                            int idx = (s_axi_awaddr - ADDR_B_BASE) >> 2;
                            b_load[idx / N][idx % N] <= s_axi_wdata[DATA_W-1:0];
                        end
                    end
                endcase
            end

            if (s_axi_bready && s_axi_bvalid) begin
                s_axi_bvalid <= 1'b0;
                aw_en        <= 1'b1;
            end
        end
    end

    assign s_axi_bresp = 2'b00;

    // AXI-lite read channel
    logic [C_S_AXI_ADDR_WIDTH-1:0] araddr_reg;

    assign s_axi_arready = s_axi_arvalid & ~s_axi_rvalid;

    always_ff @(posedge clk) begin
        if (rst) begin
            s_axi_rvalid <= 1'b0;
            s_axi_rdata  <= '0;
        end else begin
            if (s_axi_arvalid && ~s_axi_rvalid) begin
                araddr_reg   <= s_axi_araddr;
                s_axi_rvalid <= 1'b1;

                case (s_axi_araddr)
                    ADDR_CTRL:   s_axi_rdata <= 32'h0;
                    ADDR_STATUS: s_axi_rdata <= {31'b0, done_flag};
                    default: begin
                        if (s_axi_araddr >= ADDR_C_BASE) begin
                            int idx = (s_axi_araddr - ADDR_C_BASE) >> 2;
                            s_axi_rdata <= c_out[idx / N][idx % N];
                        end else begin
                            s_axi_rdata <= 32'h0;
                        end
                    end
                endcase
            end else if (s_axi_rready && s_axi_rvalid) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

    assign s_axi_rresp = 2'b00;

endmodule
