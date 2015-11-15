#**************************************************************
# Altera DE1-SoC SDC settings
# Users are recommended to modify this file to match users logic.
#**************************************************************

#**************************************************************
# Create Clock
#**************************************************************
create_clock -period "24 MHz"  -name clock_24 [get_ports CLOCK_24_0]

# For some reason this can't be matched to a port
create_clock -period "27 MHz" -name clock_27 [get_ports CLOCK_27_0]

# Include this if building with UseICEDebugger
create_clock -period "16 MHz"  -name clock_avr {bbc_micro_core:bbc_micro|clock_avr}


create_generated_clock -source {pll|altpll_component|pll|inclk[0]} -divide_by 3 -multiply_by 4 -duty_cycle 50.00 -name clock_32 {pll|altpll_component|pll|clk[0]}

	
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
#derive_clock_uncertainty



#**************************************************************
# Set Input Delay
#**************************************************************
# Board Delay (Data) + Propagation Delay - Board Delay (Clock)

#set_input_delay -clock clock_32 10.0 [get_ports SW]
#set_input_delay -clock clock_32 10.0 [get_ports KEY]
#set_input_delay -clock clock_32 10.0 [get_ports UART_RXD]
#set_input_delay -clock clock_32 10.0 [get_ports PS2_CLK]
#set_input_delay -clock clock_32 10.0 [get_ports PS2_DAT]
#set_input_delay -clock clock_32 10.0 [get_ports I2C_SCLK]
#set_input_delay -clock clock_32 10.0 [get_ports I2C_SDAT]
#set_input_delay -clock clock_32 10.0 [get_ports SRAM_DQ]
#set_input_delay -clock clock_32 10.0 [get_ports FL_DQ]
#set_input_delay -clock clock_32 10.0 [get_ports SD_MISO]

# Unused
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
# Set Output Delay
#**************************************************************
# max : Board Delay (Data) - Board Delay (Clock) + tsu (External Device)
# min : Board Delay (Data) - Board Delay (Clock) - th (External Device)


set_output_delay -clock clock_24 -max 20   [get_ports VGA*] -add_delay
set_output_delay -clock clock_27 -max 20   [get_ports VGA*] -add_delay
set_output_delay -clock clock_32 -max 20   [get_ports VGA*] -add_delay
set_output_delay -clock clock_32 -max 20   [get_ports HEX*] -add_delay
set_output_delay -clock clock_32 -max 20   [get_ports LED*] -add_delay
set_output_delay -clock clock_32 -max 20   [get_ports UART_TXD] -add_delay
set_output_delay -clock clock_32 -max 20   [get_ports I2C_SCLK] -add_delay
set_output_delay -clock clock_32 -max 20   [get_ports I2C_SDAT] -add_delay
set_output_delay -clock clock_32 -max 20   [get_ports AUD_XCK] -add_delay
set_output_delay -clock clock_32 -max 20   [get_ports AUD_BCLK] -add_delay
set_output_delay -clock clock_32 -max 20   [get_ports AUD_ADCLRCK] -add_delay
set_output_delay -clock clock_32 -max 20   [get_ports AUD_DACLRCK] -add_delay
set_output_delay -clock clock_32 -max 20   [get_ports AUD_DACDAT] -add_delay
set_output_delay -clock clock_32 -max 5    [get_ports SRAM_ADDR*] -add_delay
set_output_delay -clock clock_32 -max 5    [get_ports SRAM_DQ*] -add_delay
set_output_delay -clock clock_32 -max 5    [get_ports SRAM_WE_N] -add_delay
set_output_delay -clock clock_32 -max 10   [get_ports FL_ADDR*] -add_delay
set_output_delay -clock clock_32 -max 10   [get_ports FL_RST_N] -add_delay
set_output_delay -clock clock_32 -max 20   [get_ports SD_MOSI] -add_delay
set_output_delay -clock clock_32 -max 20   [get_ports SD_SCLK] -add_delay

set_output_delay -clock clock_24 -min 0    [get_ports VGA*] -add_delay
set_output_delay -clock clock_27 -min 0    [get_ports VGA*] -add_delay
set_output_delay -clock clock_32 -min 0    [get_ports VGA*] -add_delay
set_output_delay -clock clock_32 -min 0    [get_ports HEX*] -add_delay
set_output_delay -clock clock_32 -min 0    [get_ports LED*] -add_delay
set_output_delay -clock clock_32 -min 0    [get_ports UART_TXD] -add_delay
set_output_delay -clock clock_32 -min 0    [get_ports I2C_SCLK] -add_delay
set_output_delay -clock clock_32 -min 0    [get_ports I2C_SDAT] -add_delay
set_output_delay -clock clock_32 -min 0    [get_ports AUD_XCK] -add_delay
set_output_delay -clock clock_32 -min 0    [get_ports AUD_BCLK] -add_delay
set_output_delay -clock clock_32 -min 0    [get_ports AUD_ADCLRCK] -add_delay
set_output_delay -clock clock_32 -min 0    [get_ports AUD_DACLRCK] -add_delay
set_output_delay -clock clock_32 -min 0    [get_ports AUD_DACDAT] -add_delay
set_output_delay -clock clock_32 -min 0    [get_ports SRAM_ADDR*] -add_delay
set_output_delay -clock clock_32 -min 0    [get_ports SRAM_DQ*] -add_delay
set_output_delay -clock clock_32 -min 0    [get_ports SRAM_WE_N] -add_delay
set_output_delay -clock clock_32 -min 0    [get_ports FL_ADDR*] -add_delay
set_output_delay -clock clock_32 -min 0    [get_ports FL_RST_N] -add_delay
set_output_delay -clock clock_32 -min 0    [get_ports SD_MOSI] -add_delay
set_output_delay -clock clock_32 -min 0    [get_ports SD_SCLK] -add_delay




# Ununsed or fixed
#    SRAM_CE_N
#    SRAM_OE_N
#    SRAM_UB_N
#    SRAM_LB_N
#    DRAM_ADDR
#    DRAM_DQ
#    FL_OE_N
#    FL_WE_N
#    FL_CE_N
#    SD_nCS
#    GPIO_0
#    GPIO_1
    

#**************************************************************
# Set Clock Groups
#**************************************************************

set_clock_groups -asynchronous -group {clock_24} -group {clock_27}
set_clock_groups -asynchronous -group {clock_24} -group {clock_32}
set_clock_groups -asynchronous -group {clock_27} -group {clock_24}
set_clock_groups -asynchronous -group {clock_27} -group {clock_32}
set_clock_groups -asynchronous -group {clock_32} -group {clock_24}
set_clock_groups -asynchronous -group {clock_32} -group {clock_27}


set_clock_groups -asynchronous -group {clock_32} -group {clock_avr}
set_clock_groups -asynchronous -group {clock_avr} -group {clock_32}

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

