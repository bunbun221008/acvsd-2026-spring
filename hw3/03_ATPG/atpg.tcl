set DESIGN "top"

read_netlist -library /share1/tech/ADFP/Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/VERILOG/N16ADFP_StdCell.v
set_build -black_box TS1N16ADFPCLLLVTA512X45M4SWSHOD
set_build -black_box TS1N16ADFPCLLLVTA128X64M4SWSHOD
set_build -black_box TS1N16ADFPCLLLVTA16X88M2SWSHOD
set_build -black_box TS1N16ADFPCLLLVTA16X96M2SWSHOD
set_build -black_box TS6N16ADFPCLLLVTA128X64M4FWSHOD
set_build -black_box TS6N16ADFPCLLLVTA128X32M4FWSHOD
set_build -black_box TS6N16ADFPCLLLVTA32X32M2FWSHOD
set_build -black_box TS6N16ADFPCLLLVTA16X120M2FWSHOD
set_build -black_box TS6N16ADFPCLLLVTA16X72M2FWSHOD
set_build -black_box TS6N16ADFPCLLLVTA16X32M2FWSHOD

read_netlist ../02_SYN/Netlist/$DESIGN\_syn.v

run_build_model $DESIGN
add_pi_constraints 1 test_mode

# TODO

set_faults -report collapsed -fault_coverage
report_summaries > $DESIGN\_atpg.rpt
report_summaries

# report_patterns -all
write_patterns $DESIGN\_atpg.stil -replace -format STIL -vcs

exit
