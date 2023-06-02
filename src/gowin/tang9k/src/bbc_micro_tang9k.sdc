create_clock -name sys_clk -period 37.037 -waveform {0 18.518} [get_ports {sys_clk}] -add

// Create clock definitions for each of the derived clocks
create_generated_clock -name clock_27 -source [get_ports {sys_clk}] -master_clock sys_clk -divide_by 27 -multiply_by 27 [get_nets {clock_27}]
create_generated_clock -name clock_48 -source [get_ports {sys_clk}] -master_clock sys_clk -divide_by 27 -multiply_by 48 [get_nets {clock_48}]
create_generated_clock -name clock_96 -source [get_ports {sys_clk}] -master_clock sys_clk -divide_by 27 -multiply_by 96 [get_nets {clock_96}]
//rate_generated_clock -name clock_32 -source [get_ports {sys_clk}] -master_clock sys_clk -divide_by 27 -multiply_by 32 [get_nets {clock_32}]

// Ignore any timing paths between the main and video clocks
set_clock_groups -asynchronous -group [get_clocks {clock_48}] -group [get_clocks {clock_27}]
set_clock_groups -asynchronous -group [get_clocks {clock_27}] -group [get_clocks {clock_48}]

set_multicycle_path -from [get_regs {bbc_micro/GenT65Core.core/*}] -to [get_regs {bbc_micro/GenT65Core.core/*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/GenT65Core.core/*}] -to [get_regs {bbc_micro/GenT65Core.core/*}]  -hold -end 1

set_multicycle_path -from [get_regs {bbc_micro/GenT65Core.core/*}] -to [get_regs {bbc_micro/trace*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/GenT65Core.core/*}] -to [get_regs {bbc_micro/trace*}]  -hold -end 1

set_multicycle_path -from [get_regs {bbc_micro/GenT65Core.core/*}] -to [get_regs {bbc_micro/crtc/*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/GenT65Core.core/*}] -to [get_regs {bbc_micro/crtc/*}]  -hold -end 1

# set_operating_conditions -grade c -model fast -speed 6 -setup -hold
