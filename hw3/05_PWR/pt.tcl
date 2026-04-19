############################################
#  Set Environment
############################################
set_host_options -max_core 8

############################################
# Set Libraries
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

set link_library "* $target_library"

############################################
# Import Design
############################################
set DESIGN "top"

read_file -format verilog ../04_GATE/$DESIGN\_syn.v
current_design $DESIGN
link

# TODO: Load UPF

############################################
# Source sdc
############################################
source -echo -verbose ../02_SYN/Netlist/$DESIGN\_syn.sdc

############################################
# Read FSDB
############################################
set power_enable_analysis true
set power_analysis_mode time_based
read_fsdb -strip_path testbench/u_$DESIGN ../04_GATE/$DESIGN\.fsdb

############################################
# Measure Power
############################################
update_power
report_power
# report_power > $DESIGN\_SIMD.power
# report_power > $DESIGN\_GEMM.power

exit
