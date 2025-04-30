-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2025 Dominic Beesley https://github.com/dominicbeesley
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
-- -----------------------------------------------------------------------------

----------------------------------------------------------------------------------
-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	27/2/2025
-- Design Name: 
-- Module Name:    	dac1_oser
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		1 bit DAC using an OSER10 and fixed patterns
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created 
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity dac1_oser is
	Generic (
		G_SAMPLE_SIZE		: natural := 10;
		G_SYNC_DEPTH		: natural := 1
	);
   Port (
		rst_i					: in  	std_logic;
		clk_dac_i			: in		std_logic;
		clk_dac_px_i		: in		std_logic;

		sample_i				: in		unsigned(G_SAMPLE_SIZE-1 downto 0);				-- sample in, will be registered in dac domain
		
		bitstream_o			: out		std_logic
	);
end dac1_oser;

architecture rtl of dac1_oser is

	COMPONENT OSER10
		PORT(
			Q:OUT std_logic;
			D0:IN std_logic;
			D1:IN std_logic;
			D2:IN std_logic;
			D3:IN std_logic;
			D4:IN std_logic;
			D5:IN std_logic;
			D6:IN std_logic;
			D7:IN std_logic;
			D8:IN std_logic;
			D9:IN std_logic;
			FCLK:IN std_logic;
			PCLK:IN std_logic;
			RESET:IN std_logic
 		);
	END COMPONENT;

	type	sample_arr	is array(natural range <>) of unsigned(G_SAMPLE_SIZE-1 downto 0);

	signal r_arr_clk_dac : sample_arr(G_SYNC_DEPTH downto 0);

	signal r_pat	: std_logic_vector(9 downto 0);

	signal r_px_ctr : unsigned(1 downto 0);

	function PAT(i:unsigned) return std_logic_vector is
	variable R : std_logic_vector(9 downto 0);
	begin

		case to_integer(i) is		
when 0 => R := "0000000000";
when 1 => R := "0000000000";
when 2 => R := "0000000000";
when 3 => R := "0000000000";
when 4 => R := "0000000000";
when 5 => R := "0000000000";
when 6 => R := "0000000000";
when 7 => R := "0100000000";
when 8 => R := "0000000000";
when 9 => R := "0000010000";
when 10 => R := "0000000000";
when 11 => R := "0100000000";
when 12 => R := "1000000000";
when 13 => R := "1000000000";
when 14 => R := "1000000000";
when 15 => R := "0100000000";
when 16 => R := "1000000100";
when 17 => R := "0000010000";
when 18 => R := "0001000000";
when 19 => R := "0100000010";
when 20 => R := "1000001000";
when 21 => R := "0010000010";
when 22 => R := "0000100000";
when 23 => R := "0100000100";
when 24 => R := "0000010000";
when 25 => R := "1000010000";
when 26 => R := "1000010000";
when 27 => R := "0100001000";
when 28 => R := "0000100010";
when 29 => R := "0001000100";
when 30 => R := "0010001000";
when 31 => R := "0100010001";
when 32 => R := "1001000100";
when 33 => R := "0100010001";
when 34 => R := "0001000100";
when 35 => R := "0100100010";
when 36 => R := "1001001000";
when 37 => R := "1001000100";
when 38 => R := "1000100100";
when 39 => R := "0100100100";
when 40 => R := "1001001001";
when 41 => R := "0010010010";
when 42 => R := "0100100100";
when 43 => R := "0100100100";
when 44 => R := "0010010010";
when 45 => R := "0100101001";
when 46 => R := "0010010010";
when 47 => R := "0101001001";
when 48 => R := "1010010100";
when 49 => R := "1010010010";
when 50 => R := "1001010010";
when 51 => R := "0101001010";
when 52 => R := "0010100101";
when 53 => R := "0100101001";
when 54 => R := "0101001010";
when 55 => R := "0101010010";
when 56 => R := "1010101010";
when 57 => R := "0101010101";
when 58 => R := "0010101010";
when 59 => R := "0101010101";
when 60 => R := "0010101010";
when 61 => R := "1010101010";
when 62 => R := "1010101010";
when 63 => R := "0101010101";
when 64 => R := "1101010101";
when 65 => R := "0101010101";
when 66 => R := "0101010101";
when 67 => R := "0110101010";
when 68 => R := "1101010101";
when 69 => R := "1010101010";
when 70 => R := "1101010101";
when 71 => R := "0110101010";
when 72 => R := "1101011010";
when 73 => R := "1011010110";
when 74 => R := "1010110101";
when 75 => R := "0110101101";
when 76 => R := "1101101011";
when 77 => R := "0101101101";
when 78 => R := "0110101101";
when 79 => R := "0110110101";
when 80 => R := "0101101101";
when 81 => R := "1011010110";
when 82 => R := "1101101101";
when 83 => R := "0110110110";
when 84 => R := "0110110110";
when 85 => R := "1101101101";
when 86 => R := "1011011011";
when 87 => R := "0111011011";
when 88 => R := "1110110111";
when 89 => R := "0110111011";
when 90 => R := "0111011011";
when 91 => R := "0111011011";
when 92 => R := "1110111011";
when 93 => R := "1011101110";
when 94 => R := "1110111011";
when 95 => R := "0111011101";
when 96 => R := "0111011101";
when 97 => R := "1110111011";
when 98 => R := "1101110111";
when 99 => R := "0111101110";
when 100 => R := "1111101111";
when 101 => R := "0111101111";
when 102 => R := "0111101111";
when 103 => R := "0111110111";
when 104 => R := "1111110111";
when 105 => R := "1101111101";
when 106 => R := "1111011111";
when 107 => R := "0111111011";
when 108 => R := "0111111011";
when 109 => R := "1111101111";
when 110 => R := "1110111111";
when 111 => R := "0111111101";
when 112 => R := "1111111111";
when 113 => R := "0111111111";
when 114 => R := "0111111111";
when 115 => R := "0111111111";
when 116 => R := "0111111111";
when 117 => R := "1111101111";
when 118 => R := "1111111111";
when 119 => R := "0111111111";
when 120 => R := "0111111111";
when 121 => R := "1111111111";
when 122 => R := "1111111111";
when 123 => R := "0111111111";
when 124 => R := "0111111111";
when 125 => R := "1111111111";
when 126 => R := "1111111111";
when others => R := "1111111111";
		end case;

		return R;

	end function;

begin

	r_arr_clk_dac(G_SYNC_DEPTH) <= sample_i;


	g_sync:if G_SYNC_DEPTH > 0 generate
		-- register the incoming sample to avoid metastability
		p_sync_sample:process(clk_dac_px_i)
		begin
			if rising_edge(clk_dac_px_i) then
				for I in 1 to G_SYNC_DEPTH loop
					r_arr_clk_dac(I-1) <= r_arr_clk_dac(I);
				end loop;
			end if;
		end process;
	end generate;

	g_reg_pat: process(clk_dac_px_i)
	begin
		if rising_edge(clk_dac_px_i) then
			r_pat <= PAT(r_arr_clk_dac(0) & r_px_ctr);
			r_px_ctr <= r_px_ctr + 1;
		end if;
	end process;

	e_ser10:OSER10
		PORT MAP (
 			Q		=> bitstream_o,
 			D0		=> r_pat(0),
 			D1		=> r_pat(1),
 			D2		=> r_pat(2),
 			D3		=> r_pat(3),
 			D4		=> r_pat(4),
 			D5		=> r_pat(5),
 			D6		=> r_pat(6),
 			D7		=> r_pat(7),
 			D8		=> r_pat(8),
 			D9		=> r_pat(9),
 			FCLK	=> clk_dac_i,
 			PCLK	=> clk_dac_px_i,
 			RESET	=> '0'
 		);

end rtl;

