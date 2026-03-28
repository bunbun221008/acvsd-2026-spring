set company {NTUGIEE}
set designer {student}

# set hdlin_translate_off_ship_text "TRUE"
# set edifout_netlist_only "TRUE"
set verilogout_no_tri TRUE

# set hdlin_enable_presto_for_vhdl "TRUE"
set sh_enable_line_editing true
set sh_line_editing_mode emacs
history keep 100
alias h history

############################################
# set libraries
############################################
set search_path    "/share1/tech/ADFP/Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/CCS/ \
                    /share1/tech/ADFP/Executable_Package/Collaterals/IP/stdio/N16ADFP_StdIO/NLDM/ \
                    /share1/tech/ADFP/Executable_Package/Collaterals/IP/sram/N16ADFP_SRAM/NLDM/ \
                    $search_path .\
                    "

set target_library "N16ADFP_StdCellff0p88v125c_ccs.db \
                    N16ADFP_StdCellff0p88vm40c_ccs.db \
                    N16ADFP_StdCellss0p72v125c_ccs.db \
                    N16ADFP_StdCellss0p72vm40c_ccs.db \
                    N16ADFP_StdCelltt0p8v25c_ccs.db \
                    N16ADFP_StdIOff0p88v1p98v125c.db \
                    N16ADFP_StdIOff0p88v1p98vm40c.db \
                    N16ADFP_StdIOss0p72v1p62v125c.db \
                    N16ADFP_StdIOss0p72v1p62vm40c.db \
                    N16ADFP_StdIOtt0p8v1p8v25c.db \
                    N16ADFP_SRAM_ff0p88v0p88v125c_100a.db \
                    N16ADFP_SRAM_ff0p88v0p88vm40c_100a.db \
                    N16ADFP_SRAM_ss0p72v0p72v125c_100a.db \
                    N16ADFP_SRAM_ss0p72v0p72vm40c_100a.db \
                    N16ADFP_SRAM_tt0p8v0p8v25c_100a.db \
                    "

set link_library "* $target_library dw_foundation.sldb"
set symbol_library "generic.sdb"
set synthetic_library "dw_foundation.sldb"

############################################
# create path
############################################
sh mkdir -p Netlist
sh mkdir -p Report

############################################
# import design
############################################
set DESIGN "top"

analyze -format verilog "../01_RTL/top.v"
elaborate $DESIGN
link
current_design $DESIGN

# Explicit operating condition (avoid MV-028 default assumption warning)
set_operating_conditions tt0p8v25c -library N16ADFP_StdCelltt0p8v25c_ccs

############################################
# load UPF (RTL UPF)
############################################
load_upf ../04_UPF/top.rtl_syn.upf

# Explicit MV supply voltages for DC checks (resolves UPF-057)
if {[llength [info commands set_voltage]] > 0} {
    foreach obj { \
        VDD \
        VVDD_SRAM \
        SS_VDD.power \
        SS_VVDD_SRAM.power \
        PD_BLK.primary.power \
        PD_SRAM.primary.power \
        SS_VDD.nwell \
        SS_VVDD_SRAM.nwell \
        PD_BLK.primary.nwell \
        PD_SRAM.primary.nwell \
    } {
        catch {set_voltage 0.80 -object_list $obj}
    }

    foreach obj { \
        VSS \
        SS_VDD.ground \
        SS_VVDD_SRAM.ground \
        PD_BLK.primary.ground \
        PD_SRAM.primary.ground \
        SS_VDD.pwell \
        SS_VVDD_SRAM.pwell \
        PD_BLK.primary.pwell \
        PD_SRAM.primary.pwell \
    } {
        catch {set_voltage 0.00 -object_list $obj}
    }
}

############################################
# source sdc
############################################
source -echo -verbose ./top_syn.sdc

check_design > Report/check_design.txt
check_timing > Report/check_timing.txt

# Preserve hierarchy and instance names for UPF gate-level references
# (use compile options/per-instance constraints for tool-version compatibility)

# Protect SRAM instance names and structures from collapsing/renaming
set sram_cells [get_cells -hier *sram*]
if {[sizeof_collection $sram_cells] > 0} {
    set_dont_ungroup $sram_cells true
}

# Do not dont_touch shutdown flops; allow DC to map them to real std cells

############################################
# compile
############################################
uniquify
set_fix_multiple_port_nets -all -buffer_constants [get_designs *]

# Keep hierarchy for UPF path consistency
compile_ultra -no_autoungroup
compile_ultra -inc -no_autoungroup
compile -inc -only_hold_time

############################################
# report output
############################################
current_design $DESIGN
report_timing > Report/${DESIGN}_syn.timing
report_area   > Report/${DESIGN}_syn.area

############################################
# output design
############################################
current_design $DESIGN

set bus_inference_style {%s[%d]}
set bus_naming_style {%s[%d]}
set hdlout_internal_busses true

change_names -hierarchy -rule verilog
define_name_rules name_rule -allowed {a-z A-Z 0-9 _} -max_length 255 -type cell
define_name_rules name_rule -allowed {a-z A-Z 0-9 _[]} -max_length 255 -type net
define_name_rules name_rule -map {{"\\*cell\\*" "cell"}}
define_name_rules name_rule -case_insensitive
change_names -hierarchy -rules name_rule

remove_unconnected_ports -blast buses [get_cells -hierarchical *]
set verilogout_higher_designs_first true
write -format ddc      -hierarchy -output "./Netlist/${DESIGN}_syn.ddc"
write -format verilog  -hierarchy -output "./Netlist/${DESIGN}_syn.v"
write_sdf -version 3.0 -context verilog ./Netlist/${DESIGN}_syn.sdf
write_sdc ./Netlist/${DESIGN}_syn.sdc -version 1.8

############################################
# save UPF (synthesis UPF)
############################################
# Save UPF after final naming so it matches written gate netlist names.
save_upf ./Netlist/top.syn.upf

report_timing
report_area
