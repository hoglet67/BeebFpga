-- 2025 - adapted from Megawizard function with renamed signals for DE0


LIBRARY ieee;
USE ieee.std_logic_1164.all;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

ENTITY Ram2K IS
	PORT
	(
		addra		: IN STD_LOGIC_VECTOR (10 DOWNTO 0);
		addrb		: IN STD_LOGIC_VECTOR (10 DOWNTO 0);
		clka		: IN STD_LOGIC  := '1';
		clkb		: IN STD_LOGIC ;
		dina		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		dinb		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		ena		: IN STD_LOGIC  := '1';
		enb		: IN STD_LOGIC  := '1';
		wea		: IN STD_LOGIC  := '0';
		web		: IN STD_LOGIC  := '0';
		douta		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
		doutb		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
	);
END Ram2K;


ARCHITECTURE SYN OF ram2k IS

	SIGNAL sub_wire0	: STD_LOGIC_VECTOR (7 DOWNTO 0);
	SIGNAL sub_wire1	: STD_LOGIC_VECTOR (7 DOWNTO 0);

BEGIN
	douta    <= sub_wire0(7 DOWNTO 0);
	doutb    <= sub_wire1(7 DOWNTO 0);

	altsyncram_component : altsyncram
	GENERIC MAP (
		address_reg_b => "CLOCK1",
		clock_enable_input_a => "NORMAL",
		clock_enable_input_b => "NORMAL",
		clock_enable_output_a => "BYPASS",
		clock_enable_output_b => "BYPASS",
		indata_reg_b => "CLOCK1",
		intended_device_family => "Cyclone IV E",
		lpm_type => "altsyncram",
		numwords_a => 2048,
		numwords_b => 2048,
		operation_mode => "BIDIR_DUAL_PORT",
		outdata_aclr_a => "NONE",
		outdata_aclr_b => "NONE",
		outdata_reg_a => "UNREGISTERED",
		outdata_reg_b => "UNREGISTERED",
		power_up_uninitialized => "FALSE",
		read_during_write_mode_port_a => "NEW_DATA_NO_NBE_READ",
		read_during_write_mode_port_b => "NEW_DATA_NO_NBE_READ",
		widthad_a => 11,
		widthad_b => 11,
		width_a => 8,
		width_b => 8,
		width_byteena_a => 1,
		width_byteena_b => 1,
		wrcontrol_wraddress_reg_b => "CLOCK1"
	)
	PORT MAP (
		address_a => addra,
		address_b => addrb,
		clock0 => clka,
		clock1 => clkb,
		clocken0 => ena,
		clocken1 => enb,
		data_a => dina,
		data_b => dinb,
		wren_a => wea,
		wren_b => web,
		q_a => sub_wire0,
		q_b => sub_wire1
	);



END SYN;

