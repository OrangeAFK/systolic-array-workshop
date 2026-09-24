# Zynq block design for Digilent Cora Z7-07S
# PS GP0 → AXI interconnect → axi_wrapper @ 0x43C0_0000
#
# Prerequisites (set by scripts/run_synth.tcl):
#   - Project created with part xc7z007sclg400-1 / board digilentinc.com:cora-z7-07s:*
#   - RTL including axi_wrapper already added to the project
#
# Sourced by scripts/run_synth.tcl after add_files.

set design_name block_design

# Fresh BD
create_bd_design $design_name

# -------------------------------------------------------------------------
# Zynq PS7 with Digilent board preset (DDR / MIO / clocks)
# -------------------------------------------------------------------------
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0

apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXEDIO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable"} \
    [get_bd_cells processing_system7_0]

set_property -dict [list \
    CONFIG.PCW_USE_M_AXI_GP0 {1} \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {125} \
] [get_bd_cells processing_system7_0]

# -------------------------------------------------------------------------
# Clock / reset for PL
# -------------------------------------------------------------------------
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps7_0_125M

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0
set_property -dict [list CONFIG.NUM_MI {1}] [get_bd_cells axi_interconnect_0]

# Systolic array AXI-Lite slave (module reference)
create_bd_cell -type module -reference axi_wrapper axi_wrapper_0

# -------------------------------------------------------------------------
# Connectivity
# -------------------------------------------------------------------------
connect_bd_intf_net [get_bd_intf_pins processing_system7_0/M_AXI_GP0] \
    [get_bd_intf_pins axi_interconnect_0/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M00_AXI] \
    [get_bd_intf_pins axi_wrapper_0/S_AXI]

# FCLK 125 MHz
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] \
    [get_bd_pins processing_system7_0/M_AXI_GP0_ACLK] \
    [get_bd_pins axi_interconnect_0/ACLK] \
    [get_bd_pins axi_interconnect_0/S00_ACLK] \
    [get_bd_pins axi_interconnect_0/M00_ACLK] \
    [get_bd_pins axi_wrapper_0/s_axi_aclk] \
    [get_bd_pins rst_ps7_0_125M/slowest_sync_clk]

# PS reset into proc_sys_reset
connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] \
    [get_bd_pins rst_ps7_0_125M/ext_reset_in]

# Interconnect / peripheral resets from proc_sys_reset
connect_bd_net [get_bd_pins rst_ps7_0_125M/interconnect_aresetn] \
    [get_bd_pins axi_interconnect_0/ARESETN]
connect_bd_net [get_bd_pins rst_ps7_0_125M/peripheral_aresetn] \
    [get_bd_pins axi_interconnect_0/S00_ARESETN] \
    [get_bd_pins axi_interconnect_0/M00_ARESETN] \
    [get_bd_pins axi_wrapper_0/s_axi_aresetn]

# -------------------------------------------------------------------------
# Address map
# -------------------------------------------------------------------------
assign_bd_address -offset 0x43C00000 -range 0x00010000 \
    -target_address_space [get_bd_addr_spaces processing_system7_0/Data] \
    [get_bd_addr_segs axi_wrapper_0/S_AXI/Reg] -force

regenerate_bd_layout
validate_bd_design
save_bd_design

puts "Block design '$design_name' ready: PS GP0 → axi_wrapper @ 0x43C0_0000 (125 MHz)"
