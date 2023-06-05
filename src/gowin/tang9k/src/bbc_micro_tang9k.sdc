create_clock -name sys_clk -period 37.037 -waveform {0 18.518} [get_ports {sys_clk}] -add

// Create clock definitions for each of the derived clocks
create_generated_clock -name clock_27 -source [get_ports {sys_clk}] -master_clock sys_clk -divide_by 27 -multiply_by 27 [get_nets {clock_27}]
create_generated_clock -name clock_48 -source [get_ports {sys_clk}] -master_clock sys_clk -divide_by 27 -multiply_by 48 [get_nets {clock_48}]
create_generated_clock -name clock_96 -source [get_ports {sys_clk}] -master_clock sys_clk -divide_by 27 -multiply_by 96 [get_nets {clock_96}]

// Ignore any timing paths between the main and video clocks
set_clock_groups -asynchronous -group [get_clocks {clock_48}] -group [get_clocks {clock_27}]
set_clock_groups -asynchronous -group [get_clocks {clock_27}] -group [get_clocks {clock_48}]

// Ingore any timing paths involving m128_main
set_false_path -from [get_clocks {clock_48}] -through [get_nets {m128_mode*}] -to [get_clocks {clock_48}]

set_multicycle_path -from [get_regs {bbc_micro/Gen*Core.core/*}] -to [get_regs {bbc_micro/Gen*Core.core/*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/Gen*Core.core/*}] -to [get_regs {bbc_micro/Gen*Core.core/*}]  -hold -end 1

set_multicycle_path -from [get_regs {bbc_micro/Gen*Core.core/*}] -to [get_regs {bbc_micro/trace*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/Gen*Core.core/*}] -to [get_regs {bbc_micro/trace*}]  -hold -end 1

set_multicycle_path -from [get_regs {bbc_micro/Gen*Core.core/*}] -to [get_regs {bbc_micro/crtc/*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/Gen*Core.core/*}] -to [get_regs {bbc_micro/crtc/*}]  -hold -end 1

set_multicycle_path -from [get_regs {bbc_micro/Gen*Core.core/*}] -to [get_regs {bbc_micro/vidproc*/*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/Gen*Core.core/*}] -to [get_regs {bbc_micro/vidproc*/*}]  -hold -end 1

set_multicycle_path -from [get_regs {bbc_micro/Gen*Core.core/*}] -to [get_regs {bbc_micro/user_via/*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/Gen*Core.core/*}] -to [get_regs {bbc_micro/user_via/*}]  -hold -end 1

set_multicycle_path -from [get_regs {bbc_micro/user_via/*}] -to [get_regs {bbc_micro/Gen*Core.core/*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/user_via/*}] -to [get_regs {bbc_micro/Gen*Core.core/*}]  -hold -end 1

set_multicycle_path -from [get_regs {bbc_micro/Gen*Core.core/*}] -to [get_regs {bbc_micro/system_via/*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/Gen*Core.core/*}] -to [get_regs {bbc_micro/system_via/*}]  -hold -end 1

set_multicycle_path -from [get_regs {bbc_micro/system_via/*}] -to [get_regs {bbc_micro/Gen*Core.core/*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/system_via/*}] -to [get_regs {bbc_micro/Gen*Core.core/*}]  -hold -end 1

# set_operating_conditions -grade c -model fast -speed 6 -setup -hold
