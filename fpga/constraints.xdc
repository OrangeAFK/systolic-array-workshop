## Cora Z7-07S constraints for systolic array (PS + AXI-Lite path)
## Board: Digilent Cora Z7-07S (XC7Z007S-1CLG400C)
## Reference: https://github.com/Digilent/digilent-xdc/blob/master/Cora-Z7-07S-Master.xdc
##
## Production path: Zynq PS FCLK → axi_wrapper (no external PL clock/reset
## ports on the BD wrapper). PS clocks come from processing_system7.

## Bitstream / config (Digilent Cora Z7 defaults)
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

## False paths / multicycle: none for int8×int8→int32 PE at 100 MHz.
## Do NOT apply multicycle on hierarchical *acc* registers.
