-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2020 Dominic Beesley https://github.com/dominicbeesley
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
-- Create Date:    	3/7/2018 
-- Design Name: 
-- Module Name:    	dac_1bit
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		1 bit DAC
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

entity dac_1bit is
	Generic (
		G_SAMPLE_SIZE		: natural := 10;
		G_SYNC_DEPTH		: natural := 1;
		G_PWM					: boolean := false
	);
   Port (
		rst_i					: in  	std_logic;
		clk_dac				: in		std_logic;

		sample				: in		unsigned(G_SAMPLE_SIZE-1 downto 0);				-- sample in, will be registered in dac domain
		
		bitstream			: out		std_logic
	);
end dac_1bit;

architecture dac_1bit_arc of dac_1bit is
	type	sample_arr	is array(natural range <>) of unsigned(G_SAMPLE_SIZE-1 downto 0);

	signal r_arr_clk_dac : sample_arr(G_SYNC_DEPTH downto 0);
begin

	r_arr_clk_dac(G_SYNC_DEPTH) <= sample;

	g_sync:if G_SYNC_DEPTH > 0 generate
		-- register the incoming sample to avoid metastability
		p_sync_sample:process(clk_dac)
		begin
			if rising_edge(clk_dac) then
				for I in 1 to G_SYNC_DEPTH loop
					r_arr_clk_dac(I-1) <= r_arr_clk_dac(I);
				end loop;
			end if;
		end process;
	end generate;

GG_PWM:IF G_PWM GENERATE
	p_pwm: process(clk_dac, rst_i)
	variable ctr:unsigned(G_SAMPLE_SIZE-1 downto 0);
	begin
		if rst_i = '1' then
			ctr := ('1', others => '0');			-- max neg value
			bitstream <= '0';											
		elsif rising_edge(clk_dac) then
			if (ctr >= r_arr_clk_dac(0)) then
				bitstream <= '0';
			else
				bitstream <= '1';
			end if;
			ctr := ctr + 1;
		end if;
	end process;
END GENERATE;
GG_SIG:IF not G_PWM GENERATE

   process (clk_dac)
   variable samu:unsigned(G_SAMPLE_SIZE downto 0); -- 1 larger than sample?
   variable sum:unsigned(G_SAMPLE_SIZE downto 0);
   begin		
		if rising_edge(clk_dac) then
		   samu := unsigned('0' &  r_arr_clk_dac(0));
			bitstream <= sum(G_SAMPLE_SIZE);
			-- signed to unsigned expand to 9 bits
         sum := unsigned('0' & sum(G_SAMPLE_SIZE-1 downto 0)) + samu(G_SAMPLE_SIZE-1 downto 0);
		end if; 
   end process;


END GENERATE;

end dac_1bit_arc;

--architecture Behavioral of dac_1bit is
--	 signal samu: unsigned(10 downto 0);
--    signal sum : unsigned(10 downto 0);
--begin
--
--   process (clk, sum, sample)
--   begin
--	
--		
--		if rising_edge(clk) then
--		   samu <= unsigned(to_signed(512, 11) + sample);
--			bitstream <= sum(10);
--			-- signed to unsigned expand to 9 bits
--         sum <= unsigned("0" & sum(9 downto 0)) + unsigned("0" & samu(9 downto 0));
--		end if; 
--   end process;
--
--end Behavioral;