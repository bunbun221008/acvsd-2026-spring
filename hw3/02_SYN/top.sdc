set PERIOD      10.0    ;# DO NOT MODIFY
set PERIOD_CORE 10.0

create_clock -name "CLK"      -period $PERIOD      [get_ports CLK     ]
create_clock -name "CLK_CORE" -period $PERIOD_CORE [get_ports CLK_CORE]

set_ideal_network         [get_ports CLK*]
set_dont_touch_network    [get_clocks *]
set_fix_hold              [get_clocks *]
set_clock_uncertainty 0.1 [get_clocks *]    ;# DO NOT MODIFY
set_clock_latency     0.5 [get_clocks *]    ;# DO NOT MODIFY
set_clock_transition  0.1 [get_clocks *]    ;# DO NOT MODIFY

set_false_path -from [get_ports RST*]
set_ideal_network    [get_ports RST*]
# set_ideal_network    [get_pins u_rst_sync/rst2_reg/Q]
set_input_transition 0.5 [get_ports RST*]

set delay_exclude_ports [get_ports {CLK* RST* test_mode}]
set_input_delay  1.0 -clock CLK [remove_from_collection [all_inputs] $delay_exclude_ports]    ;# DO NOT MODIFY
set_output_delay 0.5 -clock CLK [all_outputs]     ;# DO NOT MODIFY

set_drive 1    [all_inputs ]    ;# DO NOT MODIFY
set_load  0.05 [all_outputs]    ;# DO NOT MODIFY

# TODO: Clock Domain Crossing
