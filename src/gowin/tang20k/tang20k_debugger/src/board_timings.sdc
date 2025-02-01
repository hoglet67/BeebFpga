create_clock -name sys_clk -period 37.037 -waveform {0 18.518} [get_ports {sys_clk}] -add

// Create clock definitions for each of the derived clocks
create_generated_clock -name clock_24 -source [get_ports {sys_clk}] -master_clock sys_clk -divide_by 27 -multiply_by 24 [get_nets {clock_24}]
create_generated_clock -name clock_27 -source [get_ports {sys_clk}] -master_clock sys_clk -divide_by 27 -multiply_by 27 [get_nets {clock_27}]
create_generated_clock -name clock_48 -source [get_ports {sys_clk}] -master_clock sys_clk -divide_by 27 -multiply_by 48 [get_nets {clock_48}]
create_generated_clock -name clock_96 -source [get_ports {sys_clk}] -master_clock sys_clk -divide_by 27 -multiply_by 96 [get_nets {clock_96}]

// Ignore any timing paths between the main and video clocks
set_clock_groups -asynchronous -group [get_clocks {clock_48}] -group [get_clocks {clock_27}]
set_clock_groups -asynchronous -group [get_clocks {clock_27}] -group [get_clocks {clock_48}]

// Ignore any timing paths between the main and AVR clocks
set_clock_groups -asynchronous -group [get_clocks {clock_48}] -group [get_clocks {clock_24}]
set_clock_groups -asynchronous -group [get_clocks {clock_24}] -group [get_clocks {clock_48}]

// Ingore any timing paths involving m128_main
set_false_path -from [get_clocks {clock_48}] -through [get_nets {m128_mode*}] -to [get_clocks {clock_48}]

// Tracing currently disabled in project
//set_multicycle_path -from [get_regs {bbc_micro/GenDebug.core/GenAlanDCore.inst_r65c02/*}] -to [get_regs {bbc_micro/trace*}]  -setup -end 2
//set_multicycle_path -from [get_regs {bbc_micro/GenDebug.core/GenAlanDCore.inst_r65c02/*}] -to [get_regs {bbc_micro/trace*}]  -hold -end 1

// MULTI CYCLE PATHS

// Debugger 65C02 -> Debugger 65C02 has 24 cycles in practice!
set_multicycle_path -from [get_regs {bbc_micro/GenDebug.core/GenAlanDCore.inst_r65c02/*}] -to [get_regs {bbc_micro/GenDebug.core/GenAlanDCore.inst_r65c02/*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/GenDebug.core/GenAlanDCore.inst_r65c02/*}] -to [get_regs {bbc_micro/GenDebug.core/GenAlanDCore.inst_r65c02/*}]  -hold -end 1

// Debugger 65C02 -> MOS6502CPUMonCore has 24 cycles in practice!
set_multicycle_path -from [get_regs {bbc_micro/GenDebug.core/GenAlanDCore.inst_r65c02/*}] -to [get_regs {bbc_micro/GenDebug.core/*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/GenDebug.core/GenAlanDCore.inst_r65c02/*}] -to [get_regs {bbc_micro/GenDebug.core/*}]  -hold -end 1

// MOS6502CPUMonCore -> Debugger 65C02 has 24 cycles in practice!
set_multicycle_path -from [get_regs {bbc_micro/GenDebug.core/*}] -to [get_regs {bbc_micro/GenDebug.core/GenAlanDCore.inst_r65c02/*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/GenDebug.core/*}] -to [get_regs {bbc_micro/GenDebug.core/GenAlanDCore.inst_r65c02/*}]  -hold -end 1

// Bus Monitor -> Debugger 65C02 has 22 cycles (cpu_clken2 -> cpu_clken)
set_multicycle_path -from [get_regs {bbc_micro/GenDebug.core/mon/*}] -to [get_regs {bbc_micro/GenDebug.core/GenAlanDCore.inst_r65c02/*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/GenDebug.core/mon/*}] -to [get_regs {bbc_micro/GenDebug.core/GenAlanDCore.inst_r65c02/*}]  -hold -end 1

// Debugger 65C02 -> Bus Monitor has 2 cycles (cpu_clken -> cpu_clken2)
set_multicycle_path -from [get_regs {bbc_micro/GenDebug.core/GenAlanDCore.inst_r65c02/*}] -to [get_regs {bbc_micro/GenDebug.core/mon/*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/GenDebug.core/GenAlanDCore.inst_r65c02/*}] -to [get_regs {bbc_micro/GenDebug.core/mon/*}]  -hold -end 1

// Debugger 65C02 -> Peripherals

set_multicycle_path -from [get_regs {bbc_micro/GenDebug.core/GenAlanDCore.inst_r65c02/*}] -to [get_regs {bbc_micro/crtc/*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/GenDebug.core/GenAlanDCore.inst_r65c02/*}] -to [get_regs {bbc_micro/crtc/*}]  -hold -end 1

set_multicycle_path -from [get_regs {bbc_micro/GenDebug.core/GenAlanDCore.inst_r65c02/*}] -to [get_regs {bbc_micro/vidproc*/*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/GenDebug.core/GenAlanDCore.inst_r65c02/*}] -to [get_regs {bbc_micro/vidproc*/*}]  -hold -end 1

set_multicycle_path -from [get_regs {bbc_micro/GenDebug.core/GenAlanDCore.inst_r65c02/*}] -to [get_regs {bbc_micro/user_via/*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/GenDebug.core/GenAlanDCore.inst_r65c02/*}] -to [get_regs {bbc_micro/user_via/*}]  -hold -end 1

set_multicycle_path -from [get_regs {bbc_micro/GenDebug.core/GenAlanDCore.inst_r65c02/*}] -to [get_regs {bbc_micro/system_via/*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/GenDebug.core/GenAlanDCore.inst_r65c02/*}] -to [get_regs {bbc_micro/system_via/*}]  -hold -end 1

// Peripherals -> Debugger 65C02

set_multicycle_path -from [get_regs {bbc_micro/user_via/*}] -to [get_regs {bbc_micro/GenDebug.core/GenAlanDCore.inst_r65c02/*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/user_via/*}] -to [get_regs {bbc_micro/GenDebug.core/GenAlanDCore.inst_r65c02/*}]  -hold -end 1

set_multicycle_path -from [get_regs {bbc_micro/system_via/*}] -to [get_regs {bbc_micro/GenDebug.core/GenAlanDCore.inst_r65c02/*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/system_via/*}] -to [get_regs {bbc_micro/GenDebug.core/GenAlanDCore.inst_r65c02/*}]  -hold -end 1

// COPROCESSOR

// Tube ULA -> Debugger 65C02
set_multicycle_path -from [get_regs {bbc_micro/GenCoPro6502.copro1/inst_tube/*}] -to [get_regs {bbc_micro/GenDebug.core/GenAlanDCore.inst_r65c02/*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/GenCoPro6502.copro1/inst_tube/*}] -to [get_regs {bbc_micro/GenDebug.core/GenAlanDCore.inst_r65c02/*}]  -hold -end 1

// Debugger 65C02 -> Tube ULA
set_multicycle_path -from [get_regs {bbc_micro/GenDebug.core/GenAlanDCore.inst_r65c02/*}] -to [get_regs {bbc_micro/GenCoPro6502.copro1/inst_tube/*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/GenDebug.core/GenAlanDCore.inst_r65c02/*}] -to [get_regs {bbc_micro/GenCoPro6502.copro1/inst_tube/*}]  -hold -end 1

// Co Pro 65C02 -> Co Pro 65C02 has 12 cycles (4MHz)
set_multicycle_path -from [get_regs {bbc_micro/GenCoPro6502.copro1/inst_r65c02/*}] -to [get_regs {bbc_micro/GenCoPro6502.copro1/inst_r65c02/*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/GenCoPro6502.copro1/inst_r65c02/*}] -to [get_regs {bbc_micro/GenCoPro6502.copro1/inst_r65c02/*}]  -hold -end 1

// Tube ULA -> Co Pro 65C02
set_multicycle_path -from [get_regs {bbc_micro/GenCoPro6502.copro1/inst_tube/*}] -to [get_regs {bbc_micro/GenCoPro6502.copro1/inst_r65c02/*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/GenCoPro6502.copro1/inst_tube/*}] -to [get_regs {bbc_micro/GenCoPro6502.copro1/inst_r65c02/*}]  -hold -end 1

// Co Pro 65C02 -> Tube ULA
set_multicycle_path -from [get_regs {bbc_micro/GenCoPro6502.copro1/inst_r65c02/*}] -to [get_regs {bbc_micro/GenCoPro6502.copro1/inst_tube/*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/GenCoPro6502.copro1/inst_r65c02/*}] -to [get_regs {bbc_micro/GenCoPro6502.copro1/inst_tube/*}]  -hold -end 1

// OPERATING CONDITIONS

set_operating_conditions -grade c -model slow -speed 8 -setup -hold
