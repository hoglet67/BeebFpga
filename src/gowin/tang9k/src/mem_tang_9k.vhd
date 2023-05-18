library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use std.textio.all;

-- Generic top-level entity for Altera DE1 board
entity mem_tang_9k is
port(
	CLK_48			: in	std_logic;
	ext_A           : in 	std_logic_vector (18 downto 0);
	ext_Din         : in 	std_logic_vector (7 downto 0);
	ext_Dout        : out 	std_logic_vector (7 downto 0);
	ext_nCS         : in 	std_logic;
	ext_nWE         : in 	std_logic;
	ext_nOE         : in 	std_logic
);
end mem_tang_9k;

architecture rtl of mem_tang_9k is

	type mem_mos_t is array(0 to 16383) of std_logic_vector(7 downto 0);

	impure function MEM_INIT_FILE(file_name:STRING) return mem_mos_t is
	FILE infile : text is in file_name;
	variable arr : mem_mos_t := (others => (others => '0'));
	variable inl : line;
	variable count : integer;
	begin
		count := 0;
		while not(endfile(infile)) and count < 16384 loop
			readline(infile, inl);
			read(inl, arr(count));
			count := count + 1;
		end loop;

		return arr;
	end function;

	signal r_mem_rom : mem_mos_t := MEM_INIT_FILE("../../../roms/bbcb/os12.bit");

	type mem_ram_t is array(0 to 16383) of std_logic_vector(7 downto 0);

	signal r_mem_ram : mem_ram_t;

begin

	p_ram_rd:process(CLK_48)
	begin
		if rising_edge(CLK_48) then
			if ext_A(18) = '0' then
				ext_Dout <= r_mem_rom(to_integer(unsigned(ext_A(13 downto 0))));
			else
				ext_Dout <= r_mem_ram(to_integer(unsigned(ext_A(13 downto 0))));
			end if;
		end if;
	end process;
	
	p_wr:process(CLK_48)
	begin
		if rising_edge(CLK_48) then
			if ext_nCS = '0' and ext_nWE = '0' then
				if ext_A(18) = '1' then
					r_mem_ram(to_integer(unsigned(ext_A(13 downto 0)))) <= ext_Din;
				end if;
			end if;
		end if;

	end process;


end rtl;


