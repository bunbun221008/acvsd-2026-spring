############################################
#  Set Environment
############################################
set_host_options -max_core 8

############################################
#  Set Libraries
############################################
set search_path " \
    /share1/tech/ADFP/Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/CCS/ \
    /share1/tech/ADFP/Executable_Package/Collaterals/IP/sram/N16ADFP_SRAM/NLDM/ \
    ./ \
    $search_path \
"

set target_library " \
    N16ADFP_StdCellss0p72vm40c_ccs.db \
    N16ADFP_SRAM_ss0p72v0p72vm40c_100a.db \
"

set link_library "* $target_library dw_foundation.sldb"
set symbol_library "generic.sdb"
set synthetic_library "dw_foundation.sldb"

############################################
#  Create Directories
############################################
sh mkdir -p Netlist
sh mkdir -p Report

############################################
#  Import Design
############################################
set DESIGN "top"

analyze -format sverilog "filelist.sv"
elaborate $DESIGN
current_design $DESIGN
link

# TODO: Load UPF
# set_voltage 0.72 -object_list [get_supply_nets {VDD}]

############################################
#  Global Settings
############################################
set_min_library N16ADFP_StdCellss0p72vm40c_ccs.db -min_version N16ADFP_StdCellff0p88v125c_ccs.db
set_operating_conditions -max ss0p72vm40c -max_library N16ADFP_StdCellss0p72vm40c_ccs \
                         -min ff0p88v125c -min_library N16ADFP_StdCellff0p88v125c_ccs

############################################
#  Set Design Constraints
############################################
source ./top.sdc

check_design > Report/check_design.txt
check_timing > Report/check_timing.txt

############################################
#  Compile
############################################
set_ungroup [get_designs SIMD_Core*    ] false
set_ungroup [get_designs GEMM_Core*    ] false
set_ungroup [get_designs Shared_Memory*] false
set_ungroup [get_designs Interconnect* ] false

uniquify
set_fix_multiple_port_nets -all -buffer_constants [get_designs *]
# TODO: Clock Gating

compile_ultra -scan
# compile_ultra -scan -gate_clock

############################################
#  Output Reports
############################################
report_area   > Report/$DESIGN\_predft.area
report_timing > Report/$DESIGN\_predft.timing
report_timing -delay min -max_paths 5 > Report/$DESIGN\_predft.timing_min
report_timing -delay max -max_paths 5 > Report/$DESIGN\_predft.timing_max

############################################
#  DFT
############################################
# TODO: Scan Chains

set_scan_configuration -clock_mixing no_mix
set_scan_configuration -power_domain_mixing true

set_dft_signal -view existing -type TestMode   -port test_mode   -active_state 1
set_dft_signal -view spec     -type ScanEnable -port scan_enable -active_state 1
set_case_analysis 1 [get_ports test_mode]

dft_drc -pre_dft -verbose > Report/$DESIGN\_predft.drc

compile_ultra -inc -scan

############################################
#  Fix Hold Time (Optional, might fail)
############################################
# compile -inc -only_hold_time

############################################
#  Output Reports
############################################
report_area -hierarchy > Report/$DESIGN\_syn.area
report_timing > Report/$DESIGN\_syn.timing
report_timing -delay min -max_paths 5 > Report/$DESIGN\_syn.timing_min
report_timing -delay max -max_paths 5 > Report/$DESIGN\_syn.timing_max
report_scan_path -view existing -chain all > Report/$DESIGN\_syn.scan_path
report_scan_path -view existing -cell all  > Report/$DESIGN\_syn.scan_cell

############################################
#  Change Naming Rule
############################################
set bus_inference_style {%s[%d]}
set bus_naming_style {%s[%d]}
set hdlout_internal_busses true
change_names -hierarchy -rule verilog
define_name_rules name_rule -allowed {a-z A-Z 0-9 _} -max_length 255 -type cell
define_name_rules name_rule -allowed {a-z A-Z 0-9 _[]} -max_length 255 -type net
define_name_rules name_rule -map {{"\\*cell\\*" "cell"}}
define_name_rules name_rule -case_insensitive
change_names -hierarchy -rules name_rule

############################################
#  Output Results
############################################
# remove_unconnected_ports -blast_buses [get_cells -hierarchical *]
set verilogout_higher_designs_first true
write -format ddc     -hierarchy -output Netlist/$DESIGN\_syn.ddc
write -format verilog -hierarchy -output Netlist/$DESIGN\_syn.v
write_sdf -version 3.0 -context verilog -load_delay cell Netlist/$DESIGN\_syn.sdf
write_sdc -version 1.8 Netlist/$DESIGN\_syn.sdc
# write_scan_def      -output Netlist/$DESIGN\_syn.scandef
# write_test_protocol -output Netlist/$DESIGN\_syn.spf
# save_upf Netlist/$DESIGN\_syn.upf

############################################
#  finish and quit
############################################
report_timing
report_area

exit
