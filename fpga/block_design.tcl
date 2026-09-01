# Zynq block design for Cora Z7-07S
# Creates PS + AXI interconnect + axi_wrapper for systolic array
#
# Usage (from Vivado Tcl console after creating a project):
#   source fpga/block_design.tcl
#   make_wrapper -files [get_files block_design.bd] -top
#   launch_runs impl_1 -to_step write_bitstream

set design_name block_design

# Create block design
create_bd_design $design_name

# Zynq PS7
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "Fixed IO and DDR" Master "Disable" Slave "Disable"} \
    [get_bd_cells processing_system7_0]

# AXI interconnect
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0
set_property -dict [list CONFIG.NUM_MI {1}] [get_bd_cells axi_interconnect_0]

# AXI wrapper for systolic array (add as module reference)
# Note: after adding RTL sources to the project, use:
#   create_bd_cell -type module -reference axi_wrapper axi_wrapper_0

# Connect PS GP0 to interconnect
connect_bd_intf_net [get_bd_intf_pins processing_system7_0/M_AXI_GP0] \
    [get_bd_intf_pins axi_interconnect_0/S00_AXI]

# Connect interconnect to wrapper
# connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M00_AXI] \
#     [get_bd_intf_pins axi_wrapper_0/S_AXI]

# Clock: FCLK_CLK0 (125 MHz) to PL
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] \
    [get_bd_pins axi_interconnect_0/ACLK] \
    [get_bd_pins axi_interconnect_0/S00_ACLK] \
    [get_bd_pins axi_interconnect_0/M00_ACLK]

# Reset
connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] \
    [get_bd_pins axi_interconnect_0/ARESETN] \
    [get_bd_pins axi_interconnect_0/S00_ARESETN] \
    [get_bd_pins axi_interconnect_0/M00_ARESETN]

# Address map (after wrapper is connected):
#   axi_wrapper_0/S_AXI  →  0x43C0_0000, 64K

regenerate_bd_layout
validate_bd_design
save_bd_design

puts "Block design created. Add axi_wrapper as module reference and connect S_AXI."
puts "See fpga/README.md for full build instructions."
