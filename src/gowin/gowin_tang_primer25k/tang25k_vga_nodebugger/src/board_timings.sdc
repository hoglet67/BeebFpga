create_clock -name brd_clk_50 -period 20.0 -waveform {0 10} [get_ports {brd_clk_50}] -add

// Create clock definitions for each of the derived clocks

//HDMI clocks
create_generated_clock -name clock_27 -source [get_ports {brd_clk_50}] -master_clock brd_clk_50 -divide_by 50 -multiply_by 27 [get_nets {clock_27}]
//create_generated_clock -name clock_135 -source [get_ports {brd_clk_50}] -master_clock brd_clk_50 -divide_by 10 -multiply_by 27 [get_nets {clock_135}]

create_generated_clock -name clock_dac -source [get_nets {clock_27}] -master_clock clock_27 -divide_by 1 -multiply_by 20 [get_nets {i_clk_dac}]
create_generated_clock -name clk_dac_px -source [get_nets {i_clk_dac}] -master_clock clock_dac -divide_by 5 -multiply_by 1 [get_nets {i_clk_dac_px}]


//Core clocks - derived from HDMI clocks
create_generated_clock -name clock_48 -source [get_nets {clock_27}] -master_clock clock_27 -divide_by 18 -multiply_by 32 [get_nets {clock_48}]
create_generated_clock -name clock_96 -source [get_nets {clock_27}] -master_clock clock_27 -divide_by 9 -multiply_by 32 [get_nets {clock_96}]

// Ignore any timing paths between the main and video clocks
set_clock_groups -asynchronous -group [get_clocks {clock_48}] -group [get_clocks {clock_27}]
set_clock_groups -asynchronous -group [get_clocks {clock_27}] -group [get_clocks {clock_48}]

// Ingore any timing paths involving m128_main
set_false_path -from [get_clocks {clock_48}] -through [get_nets {m128_mode*}] -to [get_clocks {clock_48}]

set_multicycle_path -from [get_regs {bbc_micro/Gen*Core.core/*}] -to [get_regs {bbc_micro/Gen*Core.core/*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/Gen*Core.core/*}] -to [get_regs {bbc_micro/Gen*Core.core/*}]  -hold -end 1

//set_multicycle_path -from [get_regs {bbc_micro/Gen*Core.core/*}] -to [get_regs {bbc_micro/trace*}]  -setup -end 2
//set_multicycle_path -from [get_regs {bbc_micro/Gen*Core.core/*}] -to [get_regs {bbc_micro/trace*}]  -hold -end 1

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

 // Set some multi-cycle paths for the host reading/writing the tube

set_multicycle_path -from [get_regs {bbc_micro/GenCoPro6502.copro1/inst_r65c02/*}] -to [get_regs {bbc_micro/GenCoPro6502.copro1/inst_r65c02/*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/GenCoPro6502.copro1/inst_r65c02/*}] -to [get_regs {bbc_micro/GenCoPro6502.copro1/inst_r65c02/*}]  -hold -end 1

set_multicycle_path -from [get_regs {bbc_micro/GenCoPro6502.copro1/inst_tube/*}] -to [get_regs {bbc_micro/Gen*Core.core/*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/GenCoPro6502.copro1/inst_tube/*}] -to [get_regs {bbc_micro/Gen*Core.core/*}]  -hold -end 1

set_multicycle_path -from [get_regs {bbc_micro/Gen*Core.core/*}] -to [get_regs {bbc_micro/GenCoPro6502.copro1/inst_tube/*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/Gen*Core.core/*}] -to [get_regs {bbc_micro/GenCoPro6502.copro1/inst_tube/*}]  -hold -end 1

set_multicycle_path -from [get_regs {bbc_micro/GenCoPro6502.copro1/inst_tube/*}] -to [get_regs {bbc_micro/GenCoPro6502.copro1/inst_r65c02/*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/GenCoPro6502.copro1/inst_tube/*}] -to [get_regs {bbc_micro/GenCoPro6502.copro1/inst_r65c02/*}]  -hold -end 1

set_multicycle_path -from [get_regs {bbc_micro/GenCoPro6502.copro1/inst_r65c02/*}] -to [get_regs {bbc_micro/GenCoPro6502.copro1/inst_tube/*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/GenCoPro6502.copro1/inst_r65c02/*}] -to [get_regs {bbc_micro/GenCoPro6502.copro1/inst_tube/*}]  -hold -end 1

