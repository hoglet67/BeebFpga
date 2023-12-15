create_clock -period 20.000 [get_ports clock_50_i]

# Ignore timing paths from the main to the HDMI video clock domain, as
# these should all be correctly synchronized through the scan converter.
#   clk1 is the 48MHz domain
#   hclk0 is the 27MHz domain
#   hclk1 is the 135MHz domain

set_clock_groups -name async_clk1_hclk01 -asynchronous -group {clk1} -group {hclk0 hclk1}

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

set_property IOSTANDARD LVCMOS33 [get_ports flash_sclk_o]
set_property IOSTANDARD LVCMOS33 [get_ports clock_50_i]
set_property IOSTANDARD LVCMOS33 [get_ports flash_cs_n_o]
set_property IOSTANDARD LVCMOS33 [get_ports flash_mosi_o]
set_property SLEW SLOW [get_ports flash_mosi_o]
set_property IOSTANDARD LVCMOS33 [get_ports flash_miso_i]
set_property PULLUP true [get_ports flash_miso_i]
set_property IOSTANDARD LVCMOS33 [get_ports flash_wp_o]
set_property IOSTANDARD LVCMOS33 [get_ports flash_hold_o]
set_property IOSTANDARD LVCMOS33 [get_ports audioint_o]
set_property DRIVE 8 [get_ports audioint_o]
set_property SLEW SLOW [get_ports audioint_o]
set_property IOSTANDARD LVCMOS33 [get_ports audioext_l_o]
set_property DRIVE 16 [get_ports audioext_l_o]
set_property DRIVE 16 [get_ports audioext_r_o]
set_property IOSTANDARD LVCMOS33 [get_ports audioext_r_o]
set_property IOSTANDARD LVCMOS33 [get_ports btn_reset_n_i]
set_property PULLUP true [get_ports btn_reset_n_i]
set_property IOSTANDARD LVCMOS33 [get_ports {bus_addr_o[0]}]
set_property DRIVE 4 [get_ports {bus_addr_o[0]}]
set_property PULLUP true [get_ports {bus_addr_o[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {bus_addr_o[1]}]
set_property DRIVE 4 [get_ports {bus_addr_o[1]}]
set_property PULLUP true [get_ports {bus_addr_o[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {bus_addr_o[10]}]
set_property DRIVE 4 [get_ports {bus_addr_o[10]}]
set_property PULLUP true [get_ports {bus_addr_o[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {bus_addr_o[11]}]
set_property DRIVE 4 [get_ports {bus_addr_o[11]}]
set_property PULLUP true [get_ports {bus_addr_o[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {bus_addr_o[12]}]
set_property DRIVE 4 [get_ports {bus_addr_o[12]}]
set_property PULLUP true [get_ports {bus_addr_o[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {bus_addr_o[13]}]
set_property DRIVE 4 [get_ports {bus_addr_o[13]}]
set_property PULLUP true [get_ports {bus_addr_o[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {bus_addr_o[14]}]
set_property DRIVE 4 [get_ports {bus_addr_o[14]}]
set_property PULLUP true [get_ports {bus_addr_o[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {bus_addr_o[15]}]
set_property DRIVE 4 [get_ports {bus_addr_o[15]}]
set_property PULLUP true [get_ports {bus_addr_o[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {bus_addr_o[2]}]
set_property DRIVE 4 [get_ports {bus_addr_o[2]}]
set_property PULLUP true [get_ports {bus_addr_o[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {bus_addr_o[3]}]
set_property DRIVE 4 [get_ports {bus_addr_o[3]}]
set_property PULLUP true [get_ports {bus_addr_o[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {bus_addr_o[4]}]
set_property DRIVE 4 [get_ports {bus_addr_o[4]}]
set_property PULLUP true [get_ports {bus_addr_o[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {bus_addr_o[5]}]
set_property DRIVE 4 [get_ports {bus_addr_o[5]}]
set_property PULLUP true [get_ports {bus_addr_o[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {bus_addr_o[6]}]
set_property DRIVE 4 [get_ports {bus_addr_o[6]}]
set_property PULLUP true [get_ports {bus_addr_o[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {bus_addr_o[7]}]
set_property DRIVE 4 [get_ports {bus_addr_o[7]}]
set_property PULLUP true [get_ports {bus_addr_o[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {bus_addr_o[8]}]
set_property DRIVE 4 [get_ports {bus_addr_o[8]}]
set_property PULLUP true [get_ports {bus_addr_o[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {bus_addr_o[9]}]
set_property DRIVE 4 [get_ports {bus_addr_o[9]}]
set_property PULLUP true [get_ports {bus_addr_o[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports bus_busack_n_o]
set_property DRIVE 4 [get_ports bus_busack_n_o]
set_property PULLUP true [get_ports bus_busack_n_o]
set_property IOSTANDARD LVCMOS33 [get_ports bus_clk35_o]
set_property DRIVE 4 [get_ports bus_clk35_o]
set_property PULLUP true [get_ports bus_clk35_o]
set_property IOSTANDARD LVCMOS33 [get_ports {bus_data_io[0]}]
set_property DRIVE 4 [get_ports {bus_data_io[0]}]
set_property PULLUP true [get_ports {bus_data_io[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {bus_data_io[1]}]
set_property DRIVE 4 [get_ports {bus_data_io[1]}]
set_property PULLUP true [get_ports {bus_data_io[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {bus_data_io[2]}]
set_property DRIVE 4 [get_ports {bus_data_io[2]}]
set_property PULLUP true [get_ports {bus_data_io[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {bus_data_io[3]}]
set_property DRIVE 4 [get_ports {bus_data_io[3]}]
set_property PULLUP true [get_ports {bus_data_io[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {bus_data_io[4]}]
set_property DRIVE 4 [get_ports {bus_data_io[4]}]
set_property PULLUP true [get_ports {bus_data_io[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {bus_data_io[5]}]
set_property DRIVE 4 [get_ports {bus_data_io[5]}]
set_property PULLUP true [get_ports {bus_data_io[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {bus_data_io[6]}]
set_property DRIVE 4 [get_ports {bus_data_io[6]}]
set_property PULLUP true [get_ports {bus_data_io[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {bus_data_io[7]}]
set_property DRIVE 4 [get_ports {bus_data_io[7]}]
set_property PULLUP true [get_ports {bus_data_io[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports bus_halt_n_o]
set_property DRIVE 4 [get_ports bus_halt_n_o]
set_property PULLUP true [get_ports bus_halt_n_o]
set_property IOSTANDARD LVCMOS33 [get_ports bus_iorq_n_o]
set_property DRIVE 4 [get_ports bus_iorq_n_o]
set_property PULLUP true [get_ports bus_iorq_n_o]
set_property IOSTANDARD LVCMOS33 [get_ports bus_iorqula_n_i]
set_property IOSTANDARD LVCMOS33 [get_ports bus_m1_n_o]
set_property DRIVE 4 [get_ports bus_m1_n_o]
set_property PULLUP true [get_ports bus_m1_n_o]
set_property IOSTANDARD LVCMOS33 [get_ports bus_mreq_n_o]
set_property DRIVE 4 [get_ports bus_mreq_n_o]
set_property PULLUP true [get_ports bus_mreq_n_o]
set_property IOSTANDARD LVCMOS33 [get_ports bus_nmi_n_i]
set_property IOSTANDARD LVCMOS33 [get_ports bus_ramcs_io]
set_property DRIVE 4 [get_ports bus_ramcs_io]
set_property PULLDOWN true [get_ports bus_ramcs_io]
set_property IOSTANDARD LVCMOS33 [get_ports bus_rd_n_io]
set_property DRIVE 4 [get_ports bus_rd_n_io]
set_property PULLUP true [get_ports bus_rd_n_io]
set_property IOSTANDARD LVCMOS33 [get_ports bus_rfsh_n_o]
set_property DRIVE 4 [get_ports bus_rfsh_n_o]
set_property PULLUP true [get_ports bus_rfsh_n_o]
set_property IOSTANDARD LVCMOS33 [get_ports bus_romcs_i]
set_property IOSTANDARD LVCMOS33 [get_ports bus_rst_n_io]
set_property DRIVE 8 [get_ports bus_rst_n_io]
set_property PULLUP true [get_ports bus_rst_n_io]
set_property IOSTANDARD LVCMOS33 [get_ports bus_wait_n_i]
set_property PULLUP true [get_ports bus_wait_n_i]
set_property IOSTANDARD LVCMOS33 [get_ports bus_wr_n_o]
set_property DRIVE 4 [get_ports bus_wr_n_o]
set_property PULLUP true [get_ports bus_wr_n_o]
set_property IOSTANDARD LVCMOS33 [get_ports bus_y_o]
set_property DRIVE 4 [get_ports bus_y_o]
set_property PULLUP true [get_ports bus_y_o]
set_property IOSTANDARD LVCMOS33 [get_ports ear_port_i]
set_property IOSTANDARD LVCMOS33 [get_ports esp_gpio0_io]
set_property DRIVE 4 [get_ports esp_gpio0_io]
set_property PULLUP true [get_ports esp_gpio0_io]
set_property IOSTANDARD LVCMOS33 [get_ports esp_gpio2_io]
set_property DRIVE 4 [get_ports esp_gpio2_io]
set_property PULLUP true [get_ports esp_gpio2_io]
set_property IOSTANDARD LVCMOS33 [get_ports esp_rx_i]
set_property PULLUP true [get_ports esp_rx_i]
set_property IOSTANDARD LVCMOS33 [get_ports esp_tx_o]
set_property DRIVE 4 [get_ports esp_tx_o]
set_property IOSTANDARD LVCMOS33 [get_ports {accel_io[0]}]
set_property DRIVE 4 [get_ports {accel_io[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {accel_io[1]}]
set_property DRIVE 4 [get_ports {accel_io[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {accel_io[10]}]
set_property DRIVE 4 [get_ports {accel_io[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {accel_io[11]}]
set_property DRIVE 4 [get_ports {accel_io[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {accel_io[12]}]
set_property DRIVE 4 [get_ports {accel_io[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {accel_io[13]}]
set_property DRIVE 4 [get_ports {accel_io[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {accel_io[14]}]
set_property DRIVE 4 [get_ports {accel_io[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {accel_io[15]}]
set_property DRIVE 4 [get_ports {accel_io[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {accel_io[16]}]
set_property DRIVE 4 [get_ports {accel_io[16]}]
set_property IOSTANDARD LVCMOS33 [get_ports {accel_io[19]}]
set_property DRIVE 4 [get_ports {accel_io[19]}]
set_property IOSTANDARD LVCMOS33 [get_ports {accel_io[2]}]
set_property DRIVE 4 [get_ports {accel_io[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {accel_io[20]}]
set_property DRIVE 4 [get_ports {accel_io[20]}]
set_property IOSTANDARD LVCMOS33 [get_ports {accel_io[21]}]
set_property DRIVE 4 [get_ports {accel_io[21]}]
set_property IOSTANDARD LVCMOS33 [get_ports {accel_io[22]}]
set_property DRIVE 4 [get_ports {accel_io[22]}]
set_property IOSTANDARD LVCMOS33 [get_ports {accel_io[23]}]
set_property DRIVE 4 [get_ports {accel_io[23]}]
set_property IOSTANDARD LVCMOS33 [get_ports {accel_io[24]}]
set_property DRIVE 4 [get_ports {accel_io[24]}]
set_property IOSTANDARD LVCMOS33 [get_ports {accel_io[25]}]
set_property DRIVE 4 [get_ports {accel_io[25]}]
set_property IOSTANDARD LVCMOS33 [get_ports {accel_io[26]}]
set_property DRIVE 4 [get_ports {accel_io[26]}]
set_property IOSTANDARD LVCMOS33 [get_ports {accel_io[3]}]
set_property DRIVE 4 [get_ports {accel_io[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {accel_io[4]}]
set_property DRIVE 4 [get_ports {accel_io[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {accel_io[5]}]
set_property DRIVE 4 [get_ports {accel_io[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {accel_io[6]}]
set_property DRIVE 4 [get_ports {accel_io[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {accel_io[7]}]
set_property DRIVE 4 [get_ports {accel_io[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {accel_io[8]}]
set_property DRIVE 4 [get_ports {accel_io[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports hsync_o]
set_property DRIVE 8 [get_ports hsync_o]
set_property IOSTANDARD LVTTL [get_ports i2c_scl_io]
set_property DRIVE 4 [get_ports i2c_scl_io]
set_property PULLUP true [get_ports i2c_scl_io]
set_property IOSTANDARD LVTTL [get_ports i2c_sda_io]
set_property DRIVE 4 [get_ports i2c_sda_io]
set_property PULLUP true [get_ports i2c_sda_io]
set_property IOSTANDARD LVTTL [get_ports joyp1_i]
set_property IOSTANDARD LVTTL [get_ports joyp2_i]
set_property IOSTANDARD LVTTL [get_ports joyp3_i]
set_property IOSTANDARD LVTTL [get_ports joyp4_i]
set_property IOSTANDARD LVTTL [get_ports joyp6_i]
set_property IOSTANDARD LVTTL [get_ports joyp7_o]
set_property DRIVE 4 [get_ports joyp7_o]
set_property IOSTANDARD LVTTL [get_ports joyp9_i]
set_property IOSTANDARD LVTTL [get_ports joysel_o]
set_property DRIVE 4 [get_ports joysel_o]
set_property IOSTANDARD LVTTL [get_ports {keyb_col_i[4]}]
set_property IOSTANDARD LVTTL [get_ports {keyb_col_i[3]}]
set_property IOSTANDARD LVTTL [get_ports {keyb_col_i[2]}]
set_property IOSTANDARD LVTTL [get_ports {keyb_col_i[1]}]
set_property IOSTANDARD LVTTL [get_ports {keyb_col_i[0]}]
set_property PULLUP true [get_ports {keyb_col_i[0]}]
set_property PULLUP true [get_ports {keyb_col_i[1]}]
set_property PULLUP true [get_ports {keyb_col_i[2]}]
set_property PULLUP true [get_ports {keyb_col_i[3]}]
set_property PULLUP true [get_ports {keyb_col_i[4]}]

set_property IOSTANDARD TMDS_33 [get_ports {hdmi_p_o[3]}]

set_property IOSTANDARD TMDS_33 [get_ports {hdmi_p_o[2]}]
set_property IOSTANDARD TMDS_33 [get_ports {hdmi_n_o[2]}]
set_property IOSTANDARD TMDS_33 [get_ports {hdmi_p_o[1]}]
set_property IOSTANDARD TMDS_33 [get_ports {hdmi_n_o[1]}]
set_property IOSTANDARD TMDS_33 [get_ports {hdmi_p_o[0]}]
set_property IOSTANDARD TMDS_33 [get_ports {hdmi_n_o[0]}]
set_property IOSTANDARD LVTTL [get_ports {keyb_row_o[3]}]

set_property IOSTANDARD LVCMOS33 [get_ports {accel_io[27]}]
set_property IOSTANDARD LVCMOS33 [get_ports {accel_io[18]}]
set_property IOSTANDARD LVCMOS33 [get_ports {accel_io[17]}]
set_property IOSTANDARD LVCMOS33 [get_ports {accel_io[9]}]
set_property DRIVE 4 [get_ports {accel_io[27]}]
set_property DRIVE 4 [get_ports {accel_io[18]}]
set_property DRIVE 4 [get_ports {accel_io[17]}]
set_property DRIVE 4 [get_ports {accel_io[9]}]
set_property IOSTANDARD LVTTL [get_ports {keyb_col_i[6]}]
set_property IOSTANDARD LVTTL [get_ports {keyb_col_i[5]}]
set_property PULLUP true [get_ports {keyb_col_i[6]}]
set_property PULLUP true [get_ports {keyb_col_i[5]}]
set_property IOSTANDARD LVTTL [get_ports {keyb_row_o[7]}]
set_property IOSTANDARD LVTTL [get_ports {keyb_row_o[6]}]
set_property IOSTANDARD LVTTL [get_ports {keyb_row_o[5]}]
set_property IOSTANDARD LVTTL [get_ports {keyb_row_o[4]}]
set_property IOSTANDARD LVTTL [get_ports {keyb_row_o[2]}]
set_property IOSTANDARD LVTTL [get_ports {keyb_row_o[1]}]
set_property IOSTANDARD LVTTL [get_ports {keyb_row_o[0]}]
set_property DRIVE 4 [get_ports {keyb_row_o[7]}]
set_property DRIVE 4 [get_ports {keyb_row_o[6]}]
set_property DRIVE 4 [get_ports {keyb_row_o[5]}]
set_property DRIVE 4 [get_ports {keyb_row_o[4]}]
set_property DRIVE 4 [get_ports {keyb_row_o[3]}]
set_property DRIVE 4 [get_ports {keyb_row_o[2]}]
set_property DRIVE 4 [get_ports {keyb_row_o[1]}]
set_property DRIVE 4 [get_ports {keyb_row_o[0]}]
set_property PULLUP true [get_ports {keyb_row_o[7]}]
set_property PULLUP true [get_ports {keyb_row_o[6]}]
set_property PULLUP true [get_ports {keyb_row_o[5]}]
set_property PULLUP true [get_ports {keyb_row_o[4]}]
set_property PULLUP true [get_ports {keyb_row_o[3]}]
set_property PULLUP true [get_ports {keyb_row_o[2]}]
set_property PULLUP true [get_ports {keyb_row_o[1]}]
set_property PULLUP true [get_ports {keyb_row_o[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_addr_o[18]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_addr_o[17]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_addr_o[16]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_addr_o[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_addr_o[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_addr_o[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_addr_o[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_addr_o[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_addr_o[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_addr_o[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_addr_o[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_addr_o[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_addr_o[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_addr_o[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_addr_o[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_addr_o[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_addr_o[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_addr_o[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_addr_o[0]}]
set_property DRIVE 8 [get_ports {ram_addr_o[18]}]
set_property DRIVE 8 [get_ports {ram_addr_o[17]}]
set_property DRIVE 8 [get_ports {ram_addr_o[16]}]
set_property DRIVE 8 [get_ports {ram_addr_o[15]}]
set_property DRIVE 8 [get_ports {ram_addr_o[14]}]
set_property DRIVE 8 [get_ports {ram_addr_o[13]}]
set_property DRIVE 8 [get_ports {ram_addr_o[12]}]
set_property DRIVE 8 [get_ports {ram_addr_o[11]}]
set_property DRIVE 8 [get_ports {ram_addr_o[10]}]
set_property DRIVE 8 [get_ports {ram_addr_o[9]}]
set_property DRIVE 8 [get_ports {ram_addr_o[8]}]
set_property DRIVE 8 [get_ports {ram_addr_o[7]}]
set_property DRIVE 8 [get_ports {ram_addr_o[6]}]
set_property DRIVE 8 [get_ports {ram_addr_o[5]}]
set_property DRIVE 8 [get_ports {ram_addr_o[4]}]
set_property DRIVE 8 [get_ports {ram_addr_o[3]}]
set_property DRIVE 8 [get_ports {ram_addr_o[2]}]
set_property DRIVE 8 [get_ports {ram_addr_o[1]}]
set_property DRIVE 8 [get_ports {ram_addr_o[0]}]
set_property SLEW FAST [get_ports {ram_addr_o[18]}]
set_property SLEW FAST [get_ports {ram_addr_o[17]}]
set_property SLEW FAST [get_ports {ram_addr_o[16]}]
set_property SLEW FAST [get_ports {ram_addr_o[15]}]
set_property SLEW FAST [get_ports {ram_addr_o[14]}]
set_property SLEW FAST [get_ports {ram_addr_o[13]}]
set_property SLEW FAST [get_ports {ram_addr_o[12]}]
set_property SLEW FAST [get_ports {ram_addr_o[11]}]
set_property SLEW FAST [get_ports {ram_addr_o[10]}]
set_property SLEW FAST [get_ports {ram_addr_o[9]}]
set_property SLEW FAST [get_ports {ram_addr_o[8]}]
set_property SLEW FAST [get_ports {ram_addr_o[7]}]
set_property SLEW FAST [get_ports {ram_addr_o[6]}]
set_property SLEW FAST [get_ports {ram_addr_o[5]}]
set_property SLEW FAST [get_ports {ram_addr_o[4]}]
set_property SLEW FAST [get_ports {ram_addr_o[3]}]
set_property SLEW FAST [get_ports {ram_addr_o[2]}]
set_property SLEW FAST [get_ports {ram_addr_o[1]}]
set_property SLEW FAST [get_ports {ram_addr_o[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_data_io[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_data_io[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_data_io[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_data_io[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_data_io[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_data_io[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_data_io[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_data_io[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_data_io[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_data_io[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_data_io[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_data_io[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_data_io[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_data_io[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_data_io[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_data_io[0]}]
set_property DRIVE 8 [get_ports {ram_data_io[15]}]
set_property DRIVE 8 [get_ports {ram_data_io[14]}]
set_property DRIVE 8 [get_ports {ram_data_io[13]}]
set_property DRIVE 8 [get_ports {ram_data_io[12]}]
set_property DRIVE 8 [get_ports {ram_data_io[11]}]
set_property DRIVE 8 [get_ports {ram_data_io[10]}]
set_property DRIVE 8 [get_ports {ram_data_io[9]}]
set_property DRIVE 8 [get_ports {ram_data_io[8]}]
set_property DRIVE 8 [get_ports {ram_data_io[7]}]
set_property DRIVE 8 [get_ports {ram_data_io[6]}]
set_property DRIVE 8 [get_ports {ram_data_io[5]}]
set_property DRIVE 8 [get_ports {ram_data_io[4]}]
set_property DRIVE 8 [get_ports {ram_data_io[3]}]
set_property DRIVE 8 [get_ports {ram_data_io[2]}]
set_property DRIVE 8 [get_ports {ram_data_io[1]}]
set_property DRIVE 8 [get_ports {ram_data_io[0]}]
set_property SLEW FAST [get_ports {ram_data_io[15]}]
set_property SLEW FAST [get_ports {ram_data_io[14]}]
set_property SLEW FAST [get_ports {ram_data_io[13]}]
set_property SLEW FAST [get_ports {ram_data_io[12]}]
set_property SLEW FAST [get_ports {ram_data_io[11]}]
set_property SLEW FAST [get_ports {ram_data_io[10]}]
set_property SLEW FAST [get_ports {ram_data_io[9]}]
set_property SLEW FAST [get_ports {ram_data_io[8]}]
set_property SLEW FAST [get_ports {ram_data_io[7]}]
set_property SLEW FAST [get_ports {ram_data_io[6]}]
set_property SLEW FAST [get_ports {ram_data_io[5]}]
set_property SLEW FAST [get_ports {ram_data_io[4]}]
set_property SLEW FAST [get_ports {ram_data_io[3]}]
set_property SLEW FAST [get_ports {ram_data_io[2]}]
set_property SLEW FAST [get_ports {ram_data_io[1]}]
set_property SLEW FAST [get_ports {ram_data_io[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rgb_b_o[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rgb_b_o[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rgb_b_o[0]}]
set_property DRIVE 8 [get_ports {rgb_b_o[2]}]
set_property DRIVE 8 [get_ports {rgb_b_o[1]}]
set_property DRIVE 8 [get_ports {rgb_b_o[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rgb_g_o[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rgb_g_o[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rgb_g_o[0]}]
set_property DRIVE 8 [get_ports {rgb_g_o[2]}]
set_property DRIVE 8 [get_ports {rgb_g_o[1]}]
set_property DRIVE 8 [get_ports {rgb_g_o[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rgb_r_o[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rgb_r_o[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rgb_r_o[0]}]
set_property DRIVE 8 [get_ports {rgb_r_o[2]}]
set_property DRIVE 8 [get_ports {rgb_r_o[1]}]
set_property DRIVE 8 [get_ports {rgb_r_o[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports btn_divmmc_n_i]
set_property PULLUP true [get_ports btn_divmmc_n_i]
set_property IOSTANDARD LVCMOS33 [get_ports btn_multiface_n_i]
set_property PULLUP true [get_ports btn_multiface_n_i]
set_property IOSTANDARD LVCMOS33 [get_ports bus_busreq_n_i]
set_property DRIVE 4 [get_ports flash_cs_n_o]
set_property DRIVE 4 [get_ports flash_hold_o]
set_property DRIVE 4 [get_ports flash_mosi_o]
set_property DRIVE 4 [get_ports flash_sclk_o]
set_property DRIVE 4 [get_ports flash_wp_o]
set_property IOSTANDARD LVCMOS33 [get_ports mic_port_o]
set_property DRIVE 4 [get_ports mic_port_o]
set_property IOSTANDARD LVCMOS33 [get_ports ps2_clk_io]
set_property DRIVE 16 [get_ports ps2_clk_io]
set_property PULLUP true [get_ports ps2_clk_io]
set_property IOSTANDARD LVCMOS33 [get_ports ps2_data_io]
set_property DRIVE 16 [get_ports ps2_data_io]
set_property PULLUP true [get_ports ps2_data_io]
set_property IOSTANDARD LVCMOS33 [get_ports ps2_pin2_io]
set_property DRIVE 16 [get_ports ps2_pin2_io]
set_property PULLUP true [get_ports ps2_pin2_io]
set_property IOSTANDARD LVCMOS33 [get_ports ps2_pin6_io]
set_property DRIVE 16 [get_ports ps2_pin6_io]
set_property PULLUP true [get_ports ps2_pin6_io]
set_property IOSTANDARD LVCMOS33 [get_ports ram_oe_n_o]
set_property DRIVE 8 [get_ports ram_oe_n_o]
set_property SLEW FAST [get_ports ram_oe_n_o]
set_property IOSTANDARD LVCMOS33 [get_ports ram_we_n_o]
set_property DRIVE 8 [get_ports ram_we_n_o]
set_property SLEW FAST [get_ports ram_we_n_o]

set_property IOSTANDARD LVTTL [get_ports sd_cs0_n_o]
set_property DRIVE 4 [get_ports sd_cs0_n_o]
set_property IOSTANDARD LVTTL [get_ports sd_cs1_n_o]
set_property DRIVE 4 [get_ports sd_cs1_n_o]
set_property IOSTANDARD LVTTL [get_ports sd_miso_i]
set_property PULLUP true [get_ports sd_miso_i]
set_property IOSTANDARD LVTTL [get_ports sd_mosi_o]
set_property DRIVE 4 [get_ports sd_mosi_o]
set_property IOSTANDARD LVTTL [get_ports sd_sclk_o]
set_property DRIVE 4 [get_ports sd_sclk_o]
set_property IOSTANDARD LVCMOS33 [get_ports vsync_o]
set_property DRIVE 8 [get_ports vsync_o]

set_property IOSTANDARD LVCMOS33 [get_ports XADC_7N]
set_property IOSTANDARD LVCMOS33 [get_ports XADC_7P]
set_property IOSTANDARD LVCMOS33 [get_ports XADC_15N]
set_property IOSTANDARD LVCMOS33 [get_ports XADC_15P]
set_property IOSTANDARD LVCMOS33 [get_ports XADC_VN]
set_property IOSTANDARD LVCMOS33 [get_ports XADC_VP]

set_property PACKAGE_PIN B2 [get_ports XADC_15N]
set_property PACKAGE_PIN B3 [get_ports XADC_15P]
set_property PACKAGE_PIN A1 [get_ports XADC_7N]
set_property PACKAGE_PIN B1 [get_ports XADC_7P]
set_property PACKAGE_PIN U16 [get_ports audioint_o]
set_property PACKAGE_PIN B4 [get_ports audioext_l_o]
set_property PACKAGE_PIN A4 [get_ports audioext_r_o]
set_property PACKAGE_PIN V9 [get_ports btn_reset_n_i]
set_property PACKAGE_PIN T5 [get_ports clock_50_i]
set_property PACKAGE_PIN A10 [get_ports {bus_addr_o[0]}]
set_property PACKAGE_PIN D10 [get_ports {bus_addr_o[1]}]
set_property PACKAGE_PIN D14 [get_ports {bus_addr_o[10]}]
set_property PACKAGE_PIN C15 [get_ports {bus_addr_o[11]}]
set_property PACKAGE_PIN A9 [get_ports {bus_addr_o[12]}]
set_property PACKAGE_PIN B9 [get_ports {bus_addr_o[13]}]
set_property PACKAGE_PIN D12 [get_ports {bus_addr_o[2]}]
set_property PACKAGE_PIN C12 [get_ports {bus_addr_o[3]}]
set_property PACKAGE_PIN A16 [get_ports {bus_addr_o[4]}]
set_property PACKAGE_PIN A15 [get_ports {bus_addr_o[5]}]
set_property PACKAGE_PIN B14 [get_ports {bus_addr_o[6]}]
set_property PACKAGE_PIN A14 [get_ports {bus_addr_o[7]}]
set_property PACKAGE_PIN B16 [get_ports {bus_addr_o[8]}]
set_property PACKAGE_PIN D15 [get_ports {bus_addr_o[9]}]
set_property PACKAGE_PIN P15 [get_ports bus_busack_n_o]
set_property PACKAGE_PIN N14 [get_ports bus_busreq_n_i]
set_property PACKAGE_PIN A18 [get_ports bus_clk35_o]
set_property PACKAGE_PIN D5 [get_ports {bus_data_io[0]}]
set_property PACKAGE_PIN C5 [get_ports {bus_data_io[1]}]
set_property PACKAGE_PIN C6 [get_ports {bus_data_io[2]}]
set_property PACKAGE_PIN D8 [get_ports {bus_data_io[3]}]
set_property PACKAGE_PIN C9 [get_ports {bus_data_io[4]}]
set_property PACKAGE_PIN C7 [get_ports {bus_data_io[5]}]
set_property PACKAGE_PIN D7 [get_ports {bus_data_io[6]}]
set_property PACKAGE_PIN C4 [get_ports {bus_data_io[7]}]
set_property PACKAGE_PIN C17 [get_ports bus_halt_n_o]
set_property PACKAGE_PIN D13 [get_ports bus_iorq_n_o]
set_property PACKAGE_PIN F13 [get_ports bus_mreq_n_o]
set_property PACKAGE_PIN E17 [get_ports bus_ramcs_io]
set_property PACKAGE_PIN C14 [get_ports bus_rd_n_io]
set_property PACKAGE_PIN B12 [get_ports bus_rfsh_n_o]
set_property PACKAGE_PIN D18 [get_ports bus_romcs_i]
set_property PACKAGE_PIN U8 [get_ports bus_rst_n_io]
set_property PACKAGE_PIN D17 [get_ports bus_wait_n_i]
set_property PACKAGE_PIN E7 [get_ports bus_y_o]
set_property PACKAGE_PIN B6 [get_ports ear_port_i]
set_property PACKAGE_PIN L13 [get_ports flash_cs_n_o]
set_property PACKAGE_PIN M14 [get_ports flash_hold_o]
set_property PACKAGE_PIN K18 [get_ports flash_miso_i]
set_property PACKAGE_PIN K17 [get_ports flash_mosi_o]
set_property PACKAGE_PIN D9 [get_ports flash_sclk_o]
set_property PACKAGE_PIN L14 [get_ports flash_wp_o]
set_property PACKAGE_PIN U12 [get_ports esp_gpio0_io]
set_property PACKAGE_PIN U13 [get_ports esp_gpio2_io]
set_property PACKAGE_PIN V14 [get_ports esp_rx_i]
set_property PACKAGE_PIN V12 [get_ports esp_tx_o]
set_property PACKAGE_PIN E6 [get_ports {hdmi_p_o[0]}]
set_property PACKAGE_PIN H14 [get_ports {hdmi_p_o[1]}]
set_property PACKAGE_PIN H6 [get_ports {hdmi_p_o[2]}]
set_property PACKAGE_PIN H15 [get_ports {accel_io[0]}]
set_property PACKAGE_PIN G16 [get_ports {accel_io[1]}]
set_property PACKAGE_PIN N15 [get_ports {accel_io[10]}]
set_property PACKAGE_PIN J17 [get_ports {accel_io[11]}]
set_property PACKAGE_PIN F15 [get_ports {accel_io[12]}]
set_property PACKAGE_PIN E16 [get_ports {accel_io[13]}]
set_property PACKAGE_PIN N17 [get_ports {accel_io[14]}]
set_property PACKAGE_PIN M17 [get_ports {accel_io[15]}]
set_property PACKAGE_PIN G17 [get_ports {accel_io[16]}]
set_property PACKAGE_PIN M18 [get_ports {accel_io[17]}]
set_property PACKAGE_PIN L18 [get_ports {accel_io[18]}]
set_property PACKAGE_PIN E15 [get_ports {accel_io[19]}]
set_property PACKAGE_PIN E18 [get_ports {accel_io[20]}]
set_property PACKAGE_PIN R18 [get_ports {accel_io[2]}]
set_property PACKAGE_PIN B7 [get_ports {accel_io[21]}]
set_property PACKAGE_PIN T15 [get_ports {accel_io[22]}]
set_property PACKAGE_PIN R15 [get_ports {accel_io[23]}]
set_property PACKAGE_PIN R16 [get_ports {accel_io[24]}]
set_property PACKAGE_PIN J18 [get_ports {accel_io[25]}]
set_property PACKAGE_PIN F18 [get_ports {accel_io[26]}]
set_property PACKAGE_PIN T14 [get_ports {accel_io[27]}]
set_property PACKAGE_PIN P17 [get_ports {accel_io[3]}]
set_property PACKAGE_PIN P18 [get_ports {accel_io[4]}]
set_property PACKAGE_PIN F14 [get_ports {accel_io[5]}]
set_property PACKAGE_PIN F16 [get_ports {accel_io[6]}]
set_property PACKAGE_PIN G18 [get_ports {accel_io[7]}]
set_property PACKAGE_PIN H17 [get_ports {accel_io[8]}]
set_property PACKAGE_PIN H16 [get_ports {accel_io[9]}]
set_property PACKAGE_PIN A13 [get_ports hsync_o]
set_property PACKAGE_PIN V10 [get_ports i2c_scl_io]
set_property PACKAGE_PIN V11 [get_ports i2c_sda_io]
set_property PACKAGE_PIN T13 [get_ports joyp1_i]
set_property PACKAGE_PIN R12 [get_ports joyp2_i]
set_property PACKAGE_PIN V16 [get_ports joyp3_i]
set_property PACKAGE_PIN U17 [get_ports joyp4_i]
set_property PACKAGE_PIN V15 [get_ports joyp6_i]
set_property PACKAGE_PIN R13 [get_ports joyp7_o]
set_property PACKAGE_PIN V17 [get_ports joyp9_i]
set_property PACKAGE_PIN U14 [get_ports joysel_o]
set_property PACKAGE_PIN U6 [get_ports {keyb_col_i[4]}]
set_property PACKAGE_PIN V7 [get_ports {keyb_col_i[3]}]
set_property PACKAGE_PIN T6 [get_ports {keyb_col_i[2]}]
set_property PACKAGE_PIN R7 [get_ports {keyb_col_i[1]}]
set_property PACKAGE_PIN R8 [get_ports {keyb_col_i[0]}]
set_property PACKAGE_PIN N16 [get_ports {keyb_row_o[3]}]
set_property PACKAGE_PIN M13 [get_ports {keyb_row_o[2]}]
set_property PACKAGE_PIN M16 [get_ports {keyb_row_o[1]}]
set_property PACKAGE_PIN K16 [get_ports {keyb_row_o[4]}]
set_property PACKAGE_PIN K15 [get_ports {keyb_row_o[5]}]
set_property PACKAGE_PIN J14 [get_ports {keyb_row_o[0]}]
set_property PACKAGE_PIN K13 [get_ports {keyb_row_o[6]}]
set_property PACKAGE_PIN J15 [get_ports {keyb_row_o[7]}]
set_property PACKAGE_PIN V5 [get_ports mic_port_o]
set_property PACKAGE_PIN T9 [get_ports btn_divmmc_n_i]
set_property PACKAGE_PIN T8 [get_ports btn_multiface_n_i]
set_property PACKAGE_PIN K1 [get_ports ps2_clk_io]
set_property PACKAGE_PIN L4 [get_ports ps2_data_io]
set_property PACKAGE_PIN L3 [get_ports ps2_pin2_io]
set_property PACKAGE_PIN L5 [get_ports ps2_pin6_io]
set_property PACKAGE_PIN C1 [get_ports {ram_addr_o[0]}]
set_property PACKAGE_PIN D2 [get_ports {ram_addr_o[1]}]
set_property PACKAGE_PIN P4 [get_ports {ram_addr_o[10]}]
set_property PACKAGE_PIN N4 [get_ports {ram_addr_o[11]}]
set_property PACKAGE_PIN P5 [get_ports {ram_addr_o[12]}]
set_property PACKAGE_PIN P3 [get_ports {ram_addr_o[13]}]
set_property PACKAGE_PIN R1 [get_ports {ram_addr_o[14]}]
set_property PACKAGE_PIN T1 [get_ports {ram_addr_o[15]}]
set_property PACKAGE_PIN R2 [get_ports {ram_addr_o[16]}]
set_property PACKAGE_PIN P2 [get_ports {ram_addr_o[17]}]
set_property PACKAGE_PIN V2 [get_ports {ram_addr_o[18]}]
set_property PACKAGE_PIN E1 [get_ports {ram_addr_o[2]}]
set_property PACKAGE_PIN F3 [get_ports {ram_addr_o[3]}]
set_property PACKAGE_PIN E2 [get_ports {ram_addr_o[4]}]
set_property PACKAGE_PIN G4 [get_ports {ram_addr_o[5]}]
set_property PACKAGE_PIN J2 [get_ports {ram_addr_o[6]}]
set_property PACKAGE_PIN N2 [get_ports {ram_addr_o[7]}]
set_property PACKAGE_PIN T3 [get_ports {ram_addr_o[8]}]
set_property PACKAGE_PIN R3 [get_ports {ram_addr_o[9]}]
set_property PACKAGE_PIN G2 [get_ports {ram_data_io[0]}]
set_property PACKAGE_PIN G1 [get_ports {ram_data_io[1]}]
set_property PACKAGE_PIN D4 [get_ports {ram_data_io[10]}]
set_property PACKAGE_PIN A6 [get_ports {ram_data_io[11]}]
set_property PACKAGE_PIN V6 [get_ports {ram_data_io[13]}]
set_property PACKAGE_PIN U7 [get_ports {ram_data_io[14]}]
set_property PACKAGE_PIN U3 [get_ports {ram_data_io[15]}]
set_property PACKAGE_PIN H2 [get_ports {ram_data_io[2]}]
set_property PACKAGE_PIN H1 [get_ports {ram_data_io[3]}]
set_property PACKAGE_PIN U1 [get_ports {ram_data_io[4]}]
set_property PACKAGE_PIN V1 [get_ports {ram_data_io[5]}]
set_property PACKAGE_PIN U2 [get_ports {ram_data_io[6]}]
set_property PACKAGE_PIN M3 [get_ports {ram_data_io[7]}]
set_property PACKAGE_PIN D3 [get_ports {ram_data_io[8]}]
set_property PACKAGE_PIN A5 [get_ports {ram_data_io[9]}]
set_property PACKAGE_PIN F4 [get_ports ram_oe_n_o]
set_property PACKAGE_PIN M4 [get_ports ram_we_n_o]
set_property PACKAGE_PIN N1 [get_ports sd_cs0_n_o]
set_property PACKAGE_PIN K2 [get_ports sd_cs1_n_o]
set_property PACKAGE_PIN L1 [get_ports sd_miso_i]
set_property PACKAGE_PIN M2 [get_ports sd_mosi_o]
set_property PACKAGE_PIN M1 [get_ports sd_sclk_o]
set_property PACKAGE_PIN A3 [get_ports {rgb_b_o[0]}]
set_property PACKAGE_PIN C2 [get_ports {rgb_b_o[1]}]
set_property PACKAGE_PIN G3 [get_ports {rgb_b_o[2]}]
set_property PACKAGE_PIN H4 [get_ports {rgb_g_o[0]}]
set_property PACKAGE_PIN J4 [get_ports {rgb_g_o[1]}]
set_property PACKAGE_PIN J3 [get_ports {rgb_g_o[2]}]
set_property PACKAGE_PIN J5 [get_ports {rgb_r_o[0]}]
set_property PACKAGE_PIN K5 [get_ports {rgb_r_o[1]}]
set_property PACKAGE_PIN K3 [get_ports {rgb_r_o[2]}]
set_property PACKAGE_PIN B13 [get_ports vsync_o]
set_property PACKAGE_PIN T18 [get_ports {keyb_col_i[5]}]
set_property PACKAGE_PIN R17 [get_ports {keyb_col_i[6]}]



set_property PACKAGE_PIN A8 [get_ports {bus_addr_o[15]}]
set_property PACKAGE_PIN B8 [get_ports {bus_addr_o[14]}]
set_property PACKAGE_PIN A11 [get_ports bus_m1_n_o]
set_property PACKAGE_PIN B11 [get_ports bus_wr_n_o]
set_property PACKAGE_PIN B17 [get_ports bus_iorqula_n_i]
set_property PACKAGE_PIN B18 [get_ports bus_nmi_n_i]
set_property PACKAGE_PIN C11 [get_ports {hdmi_p_o[3]}]

set_property PACKAGE_PIN U18 [get_ports bus_int_in_i]
set_property IOSTANDARD LVCMOS33 [get_ports bus_int_in_i]
set_property PULLUP true [get_ports bus_int_in_i]
set_property PACKAGE_PIN C16 [get_ports bus_int_n_o]
set_property IOSTANDARD LVCMOS33 [get_ports bus_int_n_o]
set_property DRIVE 4 [get_ports bus_int_n_o]
set_property PULLUP true [get_ports bus_int_n_o]
set_property PACKAGE_PIN T11 [get_ports esp_cts_n_o]
set_property IOSTANDARD LVCMOS33 [get_ports esp_cts_n_o]
set_property DRIVE 4 [get_ports esp_cts_n_o]
set_property PACKAGE_PIN R11 [get_ports esp_rtr_n_i]
set_property IOSTANDARD LVCMOS33 [get_ports esp_rtr_n_i]
set_property PACKAGE_PIN J13 [get_ports adc_control_o]
set_property IOSTANDARD LVCMOS33 [get_ports adc_control_o]
set_property DRIVE 4 [get_ports adc_control_o]
set_property PULLUP true [get_ports adc_control_o]
set_property PACKAGE_PIN R10 [get_ports extras_3_io]
set_property IOSTANDARD LVCMOS33 [get_ports extras_3_io]
set_property DRIVE 4 [get_ports extras_3_io]
set_property PULLUP true [get_ports extras_3_io]
set_property PACKAGE_PIN R5 [get_ports {ram_addr_o[19]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_addr_o[19]}]
set_property DRIVE 8 [get_ports {ram_addr_o[19]}]
set_property SLEW FAST [get_ports {ram_addr_o[19]}]
set_property PULLUP true [get_ports {ram_data_io[15]}]
set_property PULLUP true [get_ports {ram_data_io[14]}]
set_property PULLUP true [get_ports {ram_data_io[13]}]
set_property PULLUP true [get_ports {ram_data_io[12]}]
set_property PULLUP true [get_ports {ram_data_io[11]}]
set_property PULLUP true [get_ports {ram_data_io[10]}]
set_property PULLUP true [get_ports {ram_data_io[9]}]
set_property PULLUP true [get_ports {ram_data_io[8]}]
set_property PULLUP true [get_ports {ram_data_io[7]}]
set_property PULLUP true [get_ports {ram_data_io[6]}]
set_property PULLUP true [get_ports {ram_data_io[5]}]
set_property PULLUP true [get_ports {ram_data_io[4]}]
set_property PULLUP true [get_ports {ram_data_io[3]}]
set_property PULLUP true [get_ports {ram_data_io[2]}]
set_property PULLUP true [get_ports {ram_data_io[1]}]
set_property PULLUP true [get_ports {ram_data_io[0]}]
set_property PACKAGE_PIN F1 [get_ports ram_cs_n_o]
set_property IOSTANDARD LVCMOS33 [get_ports ram_cs_n_o]
set_property DRIVE 8 [get_ports ram_cs_n_o]
set_property SLEW FAST [get_ports ram_cs_n_o]
set_property PACKAGE_PIN U9 [get_ports {ram_data_io[12]}]
set_property PACKAGE_PIN F5 [get_ports ram_lb_n_o]
set_property IOSTANDARD LVCMOS33 [get_ports ram_lb_n_o]
set_property DRIVE 8 [get_ports ram_lb_n_o]
set_property SLEW FAST [get_ports ram_lb_n_o]
set_property PACKAGE_PIN E3 [get_ports ram_ub_n_o]
set_property IOSTANDARD LVCMOS33 [get_ports ram_ub_n_o]
set_property SLEW FAST [get_ports ram_ub_n_o]
set_property DRIVE 8 [get_ports ram_ub_n_o]
set_property PACKAGE_PIN T10 [get_ports extras_2_io]
set_property IOSTANDARD LVCMOS33 [get_ports extras_2_io]
set_property DRIVE 4 [get_ports extras_2_io]
set_property PULLUP true [get_ports extras_2_io]
set_property PACKAGE_PIN U11 [get_ports extras_o]
set_property IOSTANDARD LVCMOS33 [get_ports extras_o]
set_property DRIVE 4 [get_ports extras_o]
set_property PULLUP true [get_ports extras_o]

set_property OFFCHIP_TERM NONE [get_ports audioext_l_o]
set_property OFFCHIP_TERM NONE [get_ports audioext_r_o]
set_property OFFCHIP_TERM NONE [get_ports ps2_clk_io]
set_property OFFCHIP_TERM NONE [get_ports ps2_data_io]
set_property OFFCHIP_TERM NONE [get_ports ps2_pin2_io]
set_property OFFCHIP_TERM NONE [get_ports ps2_pin6_io]
set_property BITSTREAM.GENERAL.XADCENHANCEDLINEARITY ON [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 40 [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR YES [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]
set_property BITSTREAM.CONFIG.CONFIGFALLBACK DISABLE [current_design]
set_property BITSTREAM.CONFIG.NEXT_CONFIG_REBOOT DISABLE [current_design]
set_property BITSTREAM.CONFIG.INITPIN PULLNONE [current_design]
set_property BITSTREAM.CONFIG.M0PIN PULLNONE [current_design]
set_property BITSTREAM.CONFIG.M1PIN PULLNONE [current_design]
set_property BITSTREAM.CONFIG.M2PIN PULLNONE [current_design]
set_property BITSTREAM.CONFIG.PROGPIN PULLNONE [current_design]
set_property CONFIG_MODE SPIx4 [current_design]

set_property BMM_INFO_DESIGN spec_next_issue4_config_master_bd.bmm [current_design]
