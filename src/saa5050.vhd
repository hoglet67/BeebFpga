-- BBC Micro for Altera DE1
--
-- Copyright (c) 2011 Mike Stirling
--
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- * Redistributions of source code must retain the above copyright notice,
--   this list of conditions and the following disclaimer.
--
-- * Redistributions in synthesized form must reproduce the above copyright
--   notice, this list of conditions and the following disclaimer in the
--   documentation and/or other materials provided with the distribution.
--
-- * Neither the name of the author nor the names of other contributors may
--   be used to endorse or promote products derived from this software without
--   specific prior written agreement from the author.
--
-- * License is granted for non-commercial use only.  A fee may not be charged
--   for redistributions as source code or in synthesized/hardware form without 
--   specific prior written agreement from the author.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--
-- SAA5050 teletext generator
--
-- Synchronous implementation for FPGA.  Certain TV-specific functions are
-- not implemented.  e.g.
--
-- No /SI pin - 'TEXT' mode is permanently enabled
-- No remote control features (/DATA, DLIM)
-- No large character support
-- No support for box overlay (BLAN, PO, DE)
-- No character rounding, although this may be added
--
-- FIXME: Hold graphics not supported - this needs to be added
--
-- (C) 2011 Mike Stirling
--
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity saa5050 is
port (
	CLOCK		:	in	std_logic;	
	-- 6 MHz dot clock enable
	CLKEN		:	in	std_logic;
	-- Async reset
	nRESET		:	in	std_logic;
	
	-- Character data input (in the bus clock domain)
	DI_CLOCK	:	in	std_logic;
	DI_CLKEN	:	in	std_logic;
	DI			:	in	std_logic_vector(6 downto 0);
	
	-- Timing inputs
	-- General line reset (not used)
	GLR			:	in	std_logic; -- /HSYNC
	-- Data entry window - high during VSYNC.
	-- Resets ROM row counter and drives 'flash' signal
	DEW			:	in	std_logic; -- VSYNC
	-- Character rounding select - high during even field
	CRS			:	in	std_logic; -- FIELD
	-- Load output shift register enable - high during active video
	LOSE		:	in	std_logic; -- DE
	
	-- Video out
	R			:	out	std_logic;
	G			:	out	std_logic;
	B			:	out	std_logic;
	Y			:	out	std_logic
	);
end entity;

architecture rtl of saa5050 is

component saa5050_rom IS
	PORT
	(
		address		: IN STD_LOGIC_VECTOR (11 DOWNTO 0);
		clock		: IN STD_LOGIC ;
		q		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
	);
end component;

-- Register inputs in the bus clock domain
signal di_r			:	std_logic_vector(6 downto 0);
signal dew_r		:	std_logic;
signal lose_r		:	std_logic;
-- Data input registered in the pixel clock domain
signal code			:	std_logic_vector(6 downto 0);
signal line_addr	:	unsigned(3 downto 0);
signal rom_address	:	std_logic_vector(11 downto 0);
signal rom_data		:	std_logic_vector(7 downto 0);

-- Delayed display enable derived from LOSE by delaying for one character
signal disp_enable	:	std_logic;
-- Latched timing signals for detection of falling edges
signal dew_latch	:	std_logic;
signal lose_latch	:	std_logic;
signal disp_enable_latch	:	std_logic;

-- Row and column addressing is handled externally.  We just need to
-- keep track of which of the 10 lines we are on within the character...
signal line_counter	:	unsigned(3 downto 0);
-- ... and which of the 6 pixels we are on within each line
signal pixel_counter :	unsigned(2 downto 0);
-- We also need to count frames to implement the flash feature.
-- The datasheet says this is 0.75 Hz with a 3:1 on/off ratio, so it
-- is probably a /64 counter, which gives us 0.78 Hz
signal flash_counter :	unsigned(5 downto 0);
-- Output shift register
signal shift_reg	:	std_logic_vector(5 downto 0);

-- Flash mask
signal flash		:	std_logic;

-- Current display state
-- Foreground colour (B2, G1, R0)
signal fg			:	std_logic_vector(2 downto 0);
-- Background colour (B2, G1, R0)
signal bg			:	std_logic_vector(2 downto 0);
signal conceal		:	std_logic;
signal gfx			:	std_logic;
signal gfx_sep		:	std_logic;
signal gfx_hold		:	std_logic;
signal is_flash		:	std_logic;
signal double_high	:	std_logic;
-- Set in first row of double height
signal double_high1	:	std_logic;
-- Set in second row of double height
signal double_high2	:	std_logic;

begin
	char_rom: saa5050_rom port map (
		rom_address,
		CLOCK,
		rom_data
		);
		
	-- Generate flash signal for 3:1 ratio
	flash <= flash_counter(5) and flash_counter(4);
		
	-- Sync inputs
	process(DI_CLOCK,nRESET)
	begin
		if nRESET = '0' then
			di_r <= (others => '0');
			dew_r <= '0';
			lose_r <= '0';
		elsif rising_edge(DI_CLOCK) and DI_CLKEN = '1' then
			di_r <= DI;
			dew_r <= DEW;
			lose_r <= LOSE;
		end if;
	end process;
	
	-- Register data into pixel clock domain
	process(CLOCK,nRESET)
	begin
		if nRESET = '0' then
			code <= (others => '0');
		elsif rising_edge(CLOCK) and CLKEN = '1' then
			code <= di_r;
		end if;
	end process;
	
	-- Generate character rom address in pixel clock domain
	-- This is done combinatorially since all the inputs are already
	-- registered and the address is re-registered by the ROM
	line_addr <= line_counter				 when double_high = '0' else
			("0" & line_counter(3 downto 1)) when double_high2 = '0' else
			("0" & line_counter(3 downto 1)) + 5;
	rom_address <= (others => '0') when (double_high = '0' and double_high2 = '1') else
			gfx & code & std_logic_vector(line_addr);
	
	-- Character row and pixel counters
	process(CLOCK,nRESET)
	begin	
		if nRESET = '0' then
			dew_latch <= '0';
			lose_latch <= '0';
			disp_enable <= '0';
			disp_enable_latch <= '0';
			double_high1 <= '0';
			double_high2 <= '0';
			line_counter <= (others => '0');
			pixel_counter <= (others => '0');
			flash_counter <= (others => '0');
		elsif rising_edge(CLOCK) and CLKEN = '1' then
			-- Register syncs for edge detection
			dew_latch <= dew_r;
			lose_latch <= lose_r;
			disp_enable_latch <= disp_enable;
			
			-- When first entering double-height mode start on top row
			if double_high = '1' and double_high1 = '0' and double_high2 = '0' then
				double_high1 <= '1';
			end if;
			
			-- Count pixels between 0 and 5
			if pixel_counter = 5 then
				-- Start of next character and delayed display enable
				pixel_counter <= (others => '0');
				disp_enable <= lose_latch;
			else
				pixel_counter <= pixel_counter + 1;
			end if;
			
			-- Rising edge of LOSE is the start of the active line
			if lose_r = '1' and lose_latch = '0' then
				-- Reset pixel counter - small offset to make the output
				-- line up with the cursor from the video ULA
				pixel_counter <= "011";
			end if;
						
			-- Count frames on end of VSYNC (falling edge of DEW)
			if dew_r = '0' and dew_latch = '1' then
				flash_counter <= flash_counter + 1;
			end if;
			
			if dew_r = '1' then
				-- Reset line counter and double height state during VSYNC
				line_counter <= (others => '0');
				double_high1 <= '0';
				double_high2 <= '0';
			else
				-- Count lines on end of active video (falling edge of disp_enable)
				if disp_enable = '0' and disp_enable_latch = '1' then
					if line_counter = 9 then
						line_counter <= (others => '0');
						
						-- Keep track of which row we are on for double-height
						-- The double_high flag can be cleared before the end of a row, but if
						-- double height characters are used anywhere on a row then the double_high1
						-- flag will be set and remain set until the next row.  This is used
						-- to determine that the bottom half of the characters should be shown if
						-- double_high is set once again on the row below.
						double_high1 <= '0';
						double_high2 <= double_high1;
					else
						line_counter <= line_counter + 1;
					end if;
				end if;
			end if;
		end if;
	end process;
	
	-- Shift register
	process(CLOCK,nRESET)
	begin
		if nRESET = '0' then
			shift_reg <= (others => '0');
		elsif rising_edge(CLOCK) and CLKEN = '1' then
			if disp_enable = '1' and pixel_counter = 0 then
				-- Load the shift register with the ROM bit pattern
				-- at the start of each character while disp_enable is asserted.
				shift_reg <= rom_data(5 downto 0);
				
				-- If bit 7 of the ROM data is set then this is a graphics
				-- character and separated/hold graphics modes apply.
				-- We don't just assume this to be the case if gfx=1 because
				-- these modes don't apply to caps even in graphics mode
				if rom_data(7) = '1' then
					-- Apply a mask for separated graphics mode
					if gfx_sep = '1' then
						shift_reg(5) <= '0';
						shift_reg(2) <= '0';
						if line_counter = 2 or line_counter = 6 or line_counter = 9 then
							shift_reg <= (others => '0');
						end if;
					end if;
				end if;
			else
				-- Pump the shift register
				shift_reg <= shift_reg(4 downto 0) & "0";
			end if;
		end if;
	end process;
	
	-- Control character handling
	process(CLOCK,nRESET)
	begin	
		if nRESET = '0' then
			fg <= (others => '1');
			bg <= (others => '0');
			conceal <= '0';
			gfx <= '0';
			gfx_sep <= '0';
			gfx_hold <= '0';
			is_flash <= '0';
			double_high <= '0';
		elsif rising_edge(CLOCK) and CLKEN = '1' then			
			if disp_enable = '0' then
				-- Reset to start of line defaults
				fg <= (others => '1');
				bg <= (others => '0');
				conceal <= '0';
				gfx <= '0';
				gfx_sep <= '0';
				gfx_hold <= '0';
				is_flash <= '0';
				double_high <= '0';
			elsif pixel_counter = 0 then
				-- Latch new control codes at the start of each character
				if code(6 downto 5) = "00" then
					if code(3) = '0' then
						-- Colour and graphics setting clears conceal mode
						conceal <= '0';
						
						-- Select graphics or alpha mode
						gfx <= code(4);
						
						-- 0 would be black but is not allowed so has no effect,
						-- otherwise set the colour
						if code(2 downto 0) /= "000" then
							fg <= code(2 downto 0);
						end if;
					else
						case code(4 downto 0) is
						-- FLASH
						when "01000" => is_flash <= '1';
						-- STEADY
						when "01001" => is_flash <= '0';
						-- NORMAL HEIGHT
						when "01100" => double_high <= '0';
						-- DOUBLE HEIGHT
						when "01101" => double_high <= '1';
						-- CONCEAL
						when "11000" => conceal <= '1';
						-- CONTIGUOUS GFX
						when "11001" => gfx_sep <= '0';
						-- SEPARATED GFX
						when "11010" => gfx_sep <= '1';
						-- BLACK BACKGROUND
						when "11100" => bg <= (others => '0');
						-- NEW BACKGROUND
						when "11101" => bg <= fg;
						-- HOLD GFX
						when "11110" => gfx_hold <= '1';
						-- RELEASE GFX
						when "11111" => gfx_hold <= '0';
						
						when others => null;
						end case;
					end if;
				end if;
			end if;
		end if;
	end process;
	
	-- Output
	process(CLOCK,nRESET)
	variable pixel : std_logic;
	begin	
		pixel := shift_reg(5) and not ((flash and is_flash) or conceal);
		
		if nRESET = '0' then
			R <= '0';
			G <= '0';
			B <= '0';
		elsif rising_edge(CLOCK) and CLKEN = '1' then
			-- Generate mono output
			Y <= pixel;
			
			-- Generate colour output
			if pixel = '1' then
				R <= fg(0);
				G <= fg(1);
				B <= fg(2);
			else
				R <= bg(0);
				G <= bg(1);
				B <= bg(2);
			end if;
		end if;
	end process;
end architecture;
