# Vivado synthesis script for Cora Z7-07S systolic array
# Usage: vivado -mode batch -source scripts/run_synth.tcl

set project_dir [file normalize "../fpga/project"]
set rtl_dir     [file normalize "../rtl"]
set fpga_dir    [file normalize "../fpga"]

set part "xc7z007sclg400-1"

# Create project
create_project systolic_array $project_dir -part $part -force

# Add RTL sources
add_files [glob $rtl_dir/*.sv]
set_property top top [current_fileset]

# Add constraints
add_files -fileset constrs_1 $fpga_dir/constraints.xdc

# Run synthesis
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Print utilization
open_run synth_1
report_utilization -file $project_dir/utilization_synth.rpt
puts "=== Synthesis Utilization ==="
exec cat $project_dir/utilization_synth.rpt

# Run implementation
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

# Print timing
open_run impl_1
report_timing_summary -file $project_dir/timing.rpt
puts "=== Timing Summary ==="
exec cat $project_dir/timing.rpt

puts "=== Build complete ==="
puts "Bitstream: $project_dir/systolic_array.runs/impl_1/top.bit"
