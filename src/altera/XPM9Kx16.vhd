-- TODO: This is only 8K currently

LIBRARY ieee;
USE ieee.std_logic_1164.all;

LIBRARY altera_mf;
USE altera_mf.all;

entity XPM9Kx16 is port(
    cp2       : in  std_logic;
    ce        : in  std_logic;
    address   : in  std_logic_vector(13 downto 0);
    din       : in  std_logic_vector(15 downto 0);
    dout      : out std_logic_vector(15 downto 0);
    we        : in  std_logic
    );
end XPM9Kx16;

ARCHITECTURE SYN OF XPM9Kx16 IS

	SIGNAL sub_wire0	: STD_LOGIC_VECTOR (15 DOWNTO 0);



	COMPONENT altsyncram
	GENERIC (
		clock_enable_input_a		: STRING;
		clock_enable_output_a		: STRING;
		init_file		: STRING;
		intended_device_family		: STRING;
		lpm_hint		: STRING;
		lpm_type		: STRING;
		numwords_a		: NATURAL;
		operation_mode		: STRING;
		outdata_aclr_a		: STRING;
		outdata_reg_a		: STRING;
		power_up_uninitialized		: STRING;
		widthad_a		: NATURAL;
		width_a		: NATURAL;
		width_byteena_a		: NATURAL
	);
	PORT (
			address_a	: IN STD_LOGIC_VECTOR (12 DOWNTO 0);
			clock0	: IN STD_LOGIC ;
			data_a	: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
			wren_a	: IN STD_LOGIC ;
			clocken0	: IN STD_LOGIC ;
			q_a	: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
	);
	END COMPONENT;

BEGIN
	dout    <= sub_wire0(15 DOWNTO 0);

	altsyncram_component : altsyncram
	GENERIC MAP (
		clock_enable_input_a => "NORMAL",
		clock_enable_output_a => "BYPASS",
		init_file => "./avr_progmem.mif",
		intended_device_family => "Cyclone II",
		lpm_hint => "ENABLE_RUNTIME_MOD=NO",
		lpm_type => "altsyncram",
		numwords_a => 8192,
		operation_mode => "SINGLE_PORT",
		outdata_aclr_a => "NONE",
		outdata_reg_a => "UNREGISTERED",
		power_up_uninitialized => "FALSE",
		widthad_a => 13,
		width_a => 16,
		width_byteena_a => 1
	)
	PORT MAP (
		address_a => address(12 downto 0),
		clock0 => cp2,
		data_a => din,
		wren_a => we,
		clocken0 => ce,
		q_a => sub_wire0
	);



END SYN;

-- ============================================================
-- CNX file retrieval info
-- ============================================================
-- Retrieval info: PRIVATE: ADDRESSSTALL_A NUMERIC "0"
-- Retrieval info: PRIVATE: AclrAddr NUMERIC "0"
-- Retrieval info: PRIVATE: AclrByte NUMERIC "0"
-- Retrieval info: PRIVATE: AclrData NUMERIC "0"
-- Retrieval info: PRIVATE: AclrOutput NUMERIC "0"
-- Retrieval info: PRIVATE: BYTE_ENABLE NUMERIC "0"
-- Retrieval info: PRIVATE: BYTE_SIZE NUMERIC "8"
-- Retrieval info: PRIVATE: BlankMemory NUMERIC "0"
-- Retrieval info: PRIVATE: CLOCK_ENABLE_INPUT_A NUMERIC "1"
-- Retrieval info: PRIVATE: CLOCK_ENABLE_OUTPUT_A NUMERIC "0"
-- Retrieval info: PRIVATE: Clken NUMERIC "1"
-- Retrieval info: PRIVATE: DataBusSeparated NUMERIC "1"
-- Retrieval info: PRIVATE: IMPLEMENT_IN_LES NUMERIC "0"
-- Retrieval info: PRIVATE: INIT_FILE_LAYOUT STRING "PORT_A"
-- Retrieval info: PRIVATE: INIT_TO_SIM_X NUMERIC "0"
-- Retrieval info: PRIVATE: INTENDED_DEVICE_FAMILY STRING "Cyclone II"
-- Retrieval info: PRIVATE: JTAG_ENABLED NUMERIC "0"
-- Retrieval info: PRIVATE: JTAG_ID STRING "NONE"
-- Retrieval info: PRIVATE: MAXIMUM_DEPTH NUMERIC "0"
-- Retrieval info: PRIVATE: MIFfilename STRING "./altera/avr_progmem.mif"
-- Retrieval info: PRIVATE: NUMWORDS_A NUMERIC "8192"
-- Retrieval info: PRIVATE: RAM_BLOCK_TYPE NUMERIC "0"
-- Retrieval info: PRIVATE: READ_DURING_WRITE_MODE_PORT_A NUMERIC "3"
-- Retrieval info: PRIVATE: RegAddr NUMERIC "1"
-- Retrieval info: PRIVATE: RegData NUMERIC "1"
-- Retrieval info: PRIVATE: RegOutput NUMERIC "0"
-- Retrieval info: PRIVATE: SYNTH_WRAPPER_GEN_POSTFIX STRING "0"
-- Retrieval info: PRIVATE: SingleClock NUMERIC "1"
-- Retrieval info: PRIVATE: UseDQRAM NUMERIC "1"
-- Retrieval info: PRIVATE: WRCONTROL_ACLR_A NUMERIC "0"
-- Retrieval info: PRIVATE: WidthAddr NUMERIC "13"
-- Retrieval info: PRIVATE: WidthData NUMERIC "16"
-- Retrieval info: PRIVATE: rden NUMERIC "0"
-- Retrieval info: LIBRARY: altera_mf altera_mf.altera_mf_components.all
-- Retrieval info: CONSTANT: CLOCK_ENABLE_INPUT_A STRING "NORMAL"
-- Retrieval info: CONSTANT: CLOCK_ENABLE_OUTPUT_A STRING "BYPASS"
-- Retrieval info: CONSTANT: INIT_FILE STRING "./altera/avr_progmem.mif"
-- Retrieval info: CONSTANT: INTENDED_DEVICE_FAMILY STRING "Cyclone II"
-- Retrieval info: CONSTANT: LPM_HINT STRING "ENABLE_RUNTIME_MOD=NO"
-- Retrieval info: CONSTANT: LPM_TYPE STRING "altsyncram"
-- Retrieval info: CONSTANT: NUMWORDS_A NUMERIC "8192"
-- Retrieval info: CONSTANT: OPERATION_MODE STRING "SINGLE_PORT"
-- Retrieval info: CONSTANT: OUTDATA_ACLR_A STRING "NONE"
-- Retrieval info: CONSTANT: OUTDATA_REG_A STRING "UNREGISTERED"
-- Retrieval info: CONSTANT: POWER_UP_UNINITIALIZED STRING "FALSE"
-- Retrieval info: CONSTANT: WIDTHAD_A NUMERIC "13"
-- Retrieval info: CONSTANT: WIDTH_A NUMERIC "16"
-- Retrieval info: CONSTANT: WIDTH_BYTEENA_A NUMERIC "1"
-- Retrieval info: USED_PORT: address 0 0 13 0 INPUT NODEFVAL "address[12..0]"
-- Retrieval info: USED_PORT: clken 0 0 0 0 INPUT VCC "clken"
-- Retrieval info: USED_PORT: clock 0 0 0 0 INPUT VCC "clock"
-- Retrieval info: USED_PORT: data 0 0 16 0 INPUT NODEFVAL "data[15..0]"
-- Retrieval info: USED_PORT: q 0 0 16 0 OUTPUT NODEFVAL "q[15..0]"
-- Retrieval info: USED_PORT: wren 0 0 0 0 INPUT NODEFVAL "wren"
-- Retrieval info: CONNECT: @address_a 0 0 13 0 address 0 0 13 0
-- Retrieval info: CONNECT: @clock0 0 0 0 0 clock 0 0 0 0
-- Retrieval info: CONNECT: @clocken0 0 0 0 0 clken 0 0 0 0
-- Retrieval info: CONNECT: @data_a 0 0 16 0 data 0 0 16 0
-- Retrieval info: CONNECT: @wren_a 0 0 0 0 wren 0 0 0 0
-- Retrieval info: CONNECT: q 0 0 16 0 @q_a 0 0 16 0
-- Retrieval info: GEN_FILE: TYPE_NORMAL test.vhd TRUE
-- Retrieval info: GEN_FILE: TYPE_NORMAL test.inc FALSE
-- Retrieval info: GEN_FILE: TYPE_NORMAL test.cmp TRUE
-- Retrieval info: GEN_FILE: TYPE_NORMAL test.bsf FALSE
-- Retrieval info: GEN_FILE: TYPE_NORMAL test_inst.vhd FALSE
-- Retrieval info: LIB_FILE: altera_mf
