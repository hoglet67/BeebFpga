

set_multicycle_path -from [get_regs {bbc_micro/GenT65Core.core/*}] -to [get_regs {bbc_micro/GenT65Core.core/*}]  -setup -end 2
set_multicycle_path -from [get_regs {bbc_micro/GenT65Core.core/*}] -to [get_regs {bbc_micro/GenT65Core.core/*}]  -hold -end 1

set_operating_conditions -grade c -model fast -speed 6 -setup -hold
