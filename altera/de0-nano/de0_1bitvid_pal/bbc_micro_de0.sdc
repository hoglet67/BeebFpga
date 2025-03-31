#**************************************************************
# Altera DE1-SoC SDC settings
# Users are recommended to modify this file to match users logic.
#**************************************************************

#**************************************************************
# Create Clock
#**************************************************************

# External clock input
create_clock -period "24 MHz"  -name clock_24 [get_ports CLOCK_24_0]

# External clock input
create_clock -period "27 MHz" -name clock_27 [get_ports CLOCK_27_0]

# Generated clock (via a PLL from the 24MHz)
create_generated_clock -source {pll|altpll_component|pll|inclk[0]} -divide_by 3 -multiply_by 4 -duty_cycle 50.00 -name clock_32 {pll|altpll_component|pll|clk[0]}

# Include this if building with IncludeICEDebugger
# create_clock -period "16 MHz"  -name clock_avr {bbc_micro_core:bbc_micro|clock_avr}

# Include this if building with IncludeMusic5000
create_clock -period  "6 MHz"  -name clock_6 {bbc_micro_core:bbc_micro|clock_6}

# Include this if building with IncludeSID
create_clock -period  "1 MHz"  -name clock_1 {bbc_micro_core:bbc_micro|clken_counter[0]}
	
#**************************************************************
# Create Generated Clock
#**************************************************************

# Doing this manually above so we can name the clock
#derive_pll_clocks


#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************
derive_clock_uncertainty


#**************************************************************
# Constrain the SRAM Interface
#**************************************************************

# See http://www.alteraforum.com/forum/showthread.php?t=31457

# Quote from Rysc:
#
# Asynchronous RAMs are a pain. The recipe I follow is to treat the
# output and input side almost as if constraining between two different
# FPGAs. I generally do something like the following:
# - Create a virtual clock.
# - Constrain the address going off chip as tight as possible. That means
#   first putting in a -max delay and increasing it to the point it doesn't
#   fail. That means the output timing is as quick as possible.
#   Then add in a -min value to catch the other side.
#   You now have a Tco max and min for the address going out.
# - Add those values + the max and min round-trip external delays through
#   the SRAM and across the board. This is the external delay for the
#   set_input_delay on the data. (If you are taking multiple cycles to do a
#   read, then multicycles may be necessary). 
# That covers the read side. The write side is treated like any
# source-synchronous interface, except the WRITE strobe is treated as a clock.

###############
# SRAM
##############

# IS61LV25616AL-10TL
# http://www.issi.com/WW/pdf/61LV25616AL.pdf

###############
# Reads
###############

# Read timings
# - Address access time = 10ns
# -      CE access time = 10ns (CE is held active, so this is not relevant)
# -      OE access time = 4ns

# All the mins are zero - these are use for hold times, and this won't be problem

set_output_delay -clock clock_32 -min   0.0 -source_latency_included [get_ports SRAM_ADDR*]
set_output_delay -clock clock_32 -min   0.0 -source_latency_included [get_ports SRAM_OE_N]
set_input_delay  -clock clock_32 -min   0.0 -source_latency_included [get_ports SRAM_DQ*]

# Try to constrain address/oe timings as tightly as possible
# 25.75 means the xilinx output delay (x) should be < (31.25-25.75) i.e. < 5.5ns
# Any higher and the part fails to meet timing
# - longest path with ICE off = 4.613ns
# - longest path with ICE on  = 4.519ns
# There must be a fair amount of logic in the path here!

set_output_delay -clock clock_32 -max  25.75 -source_latency_included [get_ports SRAM_ADDR*]
set_output_delay -clock clock_32 -max  25.75 -source_latency_included [get_ports SRAM_OE_N]

# Try to constrain address/oe timings as tightly as possible
# 22.75 means the xilinx input delay (y) should be < (31.25-22.75) i.e. < 8.5ns
# Any higher and the part fails to meet timing
# - longest path with ICE off = 8.562ns (there is a small amount of clock skew internally)
# - longest path with ICE on  = 8.245ns
# There must be a fair amount of logic in the path here!

set_input_delay  -clock clock_32 -max  22.75 -source_latency_included [get_ports SRAM_DQ*]

# max address output delay (x) + pcb routing + address access time + pcb routing + data input delay (y) << 31.25ns
# 5.5ns + 3ns + 10ns + 3ns + 8.5ns < 31.25ns
# 3ns for PCB routing delays is very conservative!

###############
# Writes
###############

# Write timings
# - Address setup to start of write = 0ns
# - Address setup to   end of write = 8ns
# - Address  hold from end of write = 0ns
# - Data    setup to   end of write = 6ns
# - Data     hold from end of write = 0ns
# - Min write pluse width           = 8ns

# SRAM_WE_N is gated with an inverted clock to try to place
# the active edge in the middle of the clock cycle.

# SRAM_WE_N <= ext_nWE or not clock_32;

# Min WE delay should be greater than the max address output delay to meed 0ns setup
# 25.75 means the xilinx output delay (x) should be > (31.25-25.75) i.e. > 5.5ns
set_output_delay -clock clock_32 -min 25.75 -source_latency_included [get_ports SRAM_WE_N]

# Max WE delay should be fairly tightly controlled, wrt min
# 23.75 means the xilinx output delay (x) should be < (31.25-23.75) i.e. < 7.5ns
set_output_delay -clock clock_32 -max 25.25 -source_latency_included [get_ports SRAM_WE_N]

# Window for data writes is in the middle of the cycle
# Clock cycle 31.25ns; rising edge at 0ns; falling edge at 15.625ns
# falling edge WE is 5.5ns to 7.5ns
# rising edge of WE is 21.125 to 23.125ns
# data needs to be stable 21.125-Tds <-> 23.125 + Tdh
#                        =    15.125 <-> 23.125

# These values give a setup margin of 9.125ns and a hold margin of 8.125ns
set_output_delay -clock clock_32 -min 0     -source_latency_included [get_ports SRAM_DQ*]
set_output_delay -clock clock_32 -max 25.25 -source_latency_included [get_ports SRAM_DQ*]

# In practice:
# - path from ext_nWE was 5.807ns
# - path from clock_32 was 6.792ns

#**************************************************************
# Set Input Delay (other inputs)
#**************************************************************
# Board Delay (Data) + Propagation Delay - Board Delay (Clock)

# Design with CPU running at 2MHz allows for ~14 32MHz cycles
# so probably safe to leave unconstrained:

#set_input_delay -min -clock clock_32    0.0 [get_ports FL_DQ]
#set_input_delay -max -clock clock_32    0.0 [get_ports FL_DQ]

# Asynchronous, so don't bother constraining:

#set_input_delay -min -clock clock_32    0.0 [get_ports SW]
#set_input_delay -max -clock clock_32    0.0 [get_ports SW]
#set_input_delay -min -clock clock_32    0.0 [get_ports KEY]
#set_input_delay -max -clock clock_32    0.0 [get_ports KEY]
#set_input_delay -min -clock clock_32    0.0 [get_ports UART_RXD]
#set_input_delay -max -clock clock_32    0.0 [get_ports UART_RXD]

# More complex, so don't bother constraining:

#set_input_delay -min -clock clock_32    0.0 [get_ports PS2_CLK]
#set_input_delay -max -clock clock_32    0.0 [get_ports PS2_CLK]
#set_input_delay -min -clock clock_32    0.0 [get_ports PS2_DAT]
#set_input_delay -max -clock clock_32    0.0 [get_ports PS2_DAT]
#set_input_delay -min -clock clock_32    0.0 [get_ports I2C_SCLK]
#set_input_delay -max -clock clock_32    0.0 [get_ports I2C_SCLK]
#set_input_delay -min -clock clock_32    0.0 [get_ports I2C_SDAT]
#set_input_delay -max -clock clock_32    0.0 [get_ports I2C_SDAT]
#set_input_delay -min -clock clock_32    0.0 [get_ports SD_MISO]
#set_input_delay -max -clock clock_32    0.0 [get_ports SD_MISO]

# Unused:
#    AUD_ADCDAT
#    DRAM_DQ
#    DRAM_BA_0
#    DRAM_BA_1
#    DRAM_CAS_N
#    DRAM_CKE
#    DRAM_CLK
#    DRAM_CS_N
#    DRAM_LDQM
#    DRAM_RAS_N
#    DRAM_UDQM
#    DRAM_WE_N
#    GPIO_0
#    GPIO_1

#**************************************************************
# Set Output Delay (other outputs)
#**************************************************************
# max : Board Delay (Data) - Board Delay (Clock) + tsu (External Device)
# min : Board Delay (Data) - Board Delay (Clock) - th (External Device)

# Design with CPU running at 2MHz allows for ~14 32MHz cycles
# for FLASH data reads, so this is not important

set_output_delay -clock clock_32 -min 0    [get_ports FL_ADDR*]
set_output_delay -clock clock_32 -max 20   [get_ports FL_ADDR*]
set_output_delay -clock clock_32 -min 0    [get_ports FL_RST_N]
set_output_delay -clock clock_32 -max 20   [get_ports FL_RST_N]

# Setting a max of 0 allows the data delay to be a whole clock cycle, less any notional clock skew
# Add -source_latency_included to prevent clock skew being included

set_output_delay -clock clock_32 -min 0   [get_ports UART_TXD]
set_output_delay -clock clock_32 -max 0   [get_ports UART_TXD]
set_output_delay -clock clock_32 -min 0   [get_ports I2C_SCLK]
set_output_delay -clock clock_32 -max 0   [get_ports I2C_SCLK]
set_output_delay -clock clock_32 -min 0   [get_ports I2C_SDAT]
set_output_delay -clock clock_32 -max 0   [get_ports I2C_SDAT]
set_output_delay -clock clock_32 -min 0   [get_ports AUD_XCK]
set_output_delay -clock clock_32 -max 0   [get_ports AUD_XCK]
set_output_delay -clock clock_32 -min 0   [get_ports AUD_BCLK]
set_output_delay -clock clock_32 -max 0   [get_ports AUD_BCLK]
set_output_delay -clock clock_32 -min 0   [get_ports AUD_ADCLRCK]
set_output_delay -clock clock_32 -max 0   [get_ports AUD_ADCLRCK]
set_output_delay -clock clock_32 -min 0   [get_ports AUD_DACLRCK]
set_output_delay -clock clock_32 -max 0   [get_ports AUD_DACLRCK]
set_output_delay -clock clock_32 -min 0   [get_ports AUD_DACDAT]
set_output_delay -clock clock_32 -max 0   [get_ports AUD_DACDAT]
set_output_delay -clock clock_32 -min 0   [get_ports SD_MOSI]
set_output_delay -clock clock_32 -max 0   [get_ports SD_MOSI]
set_output_delay -clock clock_32 -min 0   [get_ports SD_SCLK]
set_output_delay -clock clock_32 -max 0   [get_ports SD_SCLK]

# Not critical
set_false_path -from * -to [get_ports HEX*]
set_false_path -from * -to [get_ports LED*]
set_false_path -from * -to [get_ports VGA*]

#set_output_delay -clock clock_32 -min 0   [get_ports HEX*]
#set_output_delay -clock clock_32 -max 0   [get_ports HEX*]
#set_output_delay -clock clock_32 -min 0   [get_ports LED*]
#set_output_delay -clock clock_32 -max 0   [get_ports LED*]
#set_output_delay -clock clock_32 -min 0   [get_ports VGA*]
#set_output_delay -clock clock_32 -max 0   [get_ports VGA*]
#set_output_delay -clock clock_24 -min 0   [get_ports VGA*] -add_delay
#set_output_delay -clock clock_24 -max 0   [get_ports VGA*] -add_delay
#set_output_delay -clock clock_27 -min 0   [get_ports VGA*] -add_delay
#set_output_delay -clock clock_27 -max 0   [get_ports VGA*] -add_delay

# Ununsed or fixed
set_false_path -from * -to [get_ports SRAM_CE_N]
set_false_path -from * -to [get_ports SRAM_UB_N]
set_false_path -from * -to [get_ports SRAM_LB_N]
set_false_path -from * -to [get_ports DRAM_ADDR*]
set_false_path -from * -to [get_ports DRAM_DQ*]
set_false_path -from * -to [get_ports FL_OE_N]
set_false_path -from * -to [get_ports FL_WE_N]
set_false_path -from * -to [get_ports FL_CE_N]
set_false_path -from * -to [get_ports SD_nCS]
set_false_path -from * -to [get_ports GPIO_0*]
set_false_path -from * -to [get_ports GPIO_1*]
    
#**************************************************************
# Set Clock Groups
#**************************************************************

set_clock_groups -asynchronous -group {clock_32}  -group {clock_24}
set_clock_groups -asynchronous -group {clock_24}  -group {clock_32}

set_clock_groups -asynchronous -group {clock_32}  -group {clock_27}
set_clock_groups -asynchronous -group {clock_27}  -group {clock_32}

set_clock_groups -asynchronous -group {clock_24}  -group {clock_27}
set_clock_groups -asynchronous -group {clock_27}  -group {clock_24}

set_clock_groups -asynchronous -group {clock_32}  -group {clock_avr}
set_clock_groups -asynchronous -group {clock_avr} -group {clock_32}

set_clock_groups -asynchronous -group {clock_32}  -group {clock_6}
set_clock_groups -asynchronous -group {clock_6}   -group {clock_32}

set_clock_groups -asynchronous -group {clock_32}  -group {clock_1}
set_clock_groups -asynchronous -group {clock_1}   -group {clock_32}

#**************************************************************
# Set False Path
#**************************************************************



#**************************************************************
# Set Multicycle Path
#**************************************************************



#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************



#**************************************************************
# Set Load
#**************************************************************

