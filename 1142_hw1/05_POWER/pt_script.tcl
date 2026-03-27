#PrimeTime Script
set power_enable_analysis TRUE
set power_analysis_mode time_based

read_file -format verilog  ../03_SYN/Netlist/top_syn.v
current_design top
link

read_sdf -load_delay net ../03_SYN/Netlist/top_syn.sdf
## Measure  power
#report_switching_activity -list_not_annotated -show_pin

read_vcd  -strip_path testbench/u_top  ../02_GATE/top.fsdb
update_power
report_power 
report_power > H6.power

exit



