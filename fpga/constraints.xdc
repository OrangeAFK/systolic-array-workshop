## Cora Z7-07S constraints for systolic array demo
## Board: Digilent Cora Z7-07S (XC7Z007S-1CLG400C)
## Reference: https://github.com/Digilent/digilent-xdc/blob/master/Cora-Z7-07S-Master.xdc

## PL clock: 125 MHz from Zynq FCLK_CLK0
create_clock -period 8.000 -name clk_125mhz [get_ports clk_125mhz]
set_property -dict { PACKAGE_PIN H16 IOSTANDARD LVCMOS33 } [get_ports { clk_125mhz }]

## Reset (active-low)
set_property -dict { PACKAGE_PIN D19 IOSTANDARD LVCMOS33 } [get_ports { rst_n }]

## RGB LED 0 — green = PASS, red = FAIL
set_property -dict { PACKAGE_PIN M15 IOSTANDARD LVCMOS33 } [get_ports { led_g }]
set_property -dict { PACKAGE_PIN G14 IOSTANDARD LVCMOS33 } [get_ports { led_r }]
set_property -dict { PACKAGE_PIN L14 IOSTANDARD LVCMOS33 } [get_ports { led_b }]

## Timing: accumulator path may need an extra cycle through the DSP chain
set_multicycle_path -setup 2 -from [get_cells -hier -filter {NAME =~ *u_array*}] -to [get_cells -hier -filter {NAME =~ *acc*}]
set_multicycle_path -hold  1 -from [get_cells -hier -filter {NAME =~ *u_array*}] -to [get_cells -hier -filter {NAME =~ *acc*}]
