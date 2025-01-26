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

-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	16/04/2019
-- Design Name: 
-- Module Name:    	common.vhd
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		blitter utility package
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


package common is
  function ceil_log2(i : natural) return natural;
  function floor_log2(i : natural) return natural;
  -- numbits is the number of bits required to hold w as a *number of options*
  function numbits(w : natural) return natural;
  function b2s(b:boolean) return std_logic;
end package;

library ieee;
use ieee.math_real.all;

package body common is
	function ceil_log2(i : natural) return natural is
	begin
   		return integer(ceil(log2(real(i))));  -- Example using real calculation
 	end function;

	function floor_log2(i : natural) return natural is
	begin
		return integer(floor(log2(real(i))));  -- Example using real calculation
	end function;

	-- number of bits required to hold a number
 	function numbits(w : natural) return natural is
	begin
		assert w > 0 report "width must be > 0" severity error;
		if w = 1 then
			return 1;
		else
			return ceil_log2(w);
		end if;
	end function;

	function b2s(b:boolean) return std_logic is
	begin
		if b then
			return '1';
		else
			return '0';
		end if;
	end function;

end package body;