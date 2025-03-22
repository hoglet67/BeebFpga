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

-- Company:          Dossytronics
-- Engineer:         Dominic Beesley
-- 
-- Create Date:      15/03/2029
-- Design Name: 
-- Module Name:      dossy_chroma
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:      experimental NTSC chroma generation
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

entity dossy_chroma is
   generic (
      G_BREEZE          : natural := 40;
      G_BURST           : natural := 100;

      G_INBITS          : natural := 4;

      G_OUTBITS         : natural := 5;

      G_CLOCKSPEED      : natural := 48000000;

      G_USE_EXT_x4_CLK  : boolean := false;
      G_PAL             : boolean := true;
      G_CAR_DIV         : natural := 709379;
      G_CAR_NUM         : natural := 1920000    -- PAL * 4 with 25Hz offset

--      G_PAL     : boolean := true;
--      G_CAR_DIV : natural := 1135;
--      G_CAR_NUM : natural := 3072    -- PAL * 4 without 25Hz offset

--      G_PAL     : boolean := false;
--      G_CAR_DIV : natural := 105;
--      G_CAR_NUM : natural := 352    -- NTSC * 4
   );
   port (

      clk_i             : in  std_logic;
      clk_chroma_x4_i   : in  std_logic;

      r_i               : in  unsigned(G_INBITS-1 downto 0);
      g_i               : in  unsigned(G_INBITS-1 downto 0);
      b_i               : in  unsigned(G_INBITS-1 downto 0);

      hs_i              : in  std_logic;
      vs_i              : in  std_logic;

      chroma_o          : out signed(G_OUTBITS-1 downto 0);
      clk_chroma_x4_o   : out std_logic;

      car_ry_o          : out std_logic;
      pal_sw_o          : out std_logic;
      base_by_o         : out signed(G_OUTBITS-1 downto 0);
      base_ry_o         : out signed(G_OUTBITS-1 downto 0)
      
   );
end dossy_chroma;

architecture rtl of dossy_chroma is



signal r_car_by : std_logic;
signal r_car_ry : std_logic;

signal r_base_by : signed(G_OUTBITS-1 downto 0);
signal r_base_ry : signed(G_OUTBITS-1 downto 0);

signal r_mod_by : signed(G_OUTBITS-1 downto 0);
signal r_mod_ry : signed(G_OUTBITS-1 downto 0);


signal r_burst  : std_logic;

signal r_pal_swich : std_logic := '0';

signal i_clk_chroma_x4 : std_logic;

begin

   car_ry_o <= r_car_ry;
   pal_sw_o <= r_pal_swich;
   base_by_o <= r_base_by;
   base_ry_o <= r_base_ry;
   clk_chroma_x4_o <= i_clk_chroma_x4;

   p_ident:process(clk_i)
   variable vlast : std_logic;
   begin
      if rising_edge(clk_i) then
         if hs_i = '1' and vlast = '0' then
            if G_PAL then
               r_pal_swich <= not r_pal_swich;
            end if;
         end if;
         vlast := hs_i;
      end if;
   end process;


   g_int_x4_clk:if not G_USE_EXT_x4_CLK generate

      p_car_gen:process(clk_i)
      constant div : natural := G_CAR_DIV;
      constant num : natural := G_CAR_NUM;
      variable r_acc : unsigned(numbits(num) downto 0) := (others => '0');
      begin
         if rising_edge(clk_i) then
            r_acc := r_acc + div;
            if r_acc >= num then
               r_acc := r_acc - num;
               i_clk_chroma_x4 <= '1';
            else
               i_clk_chroma_x4 <= '0';
            end if;
         end if;
      end process;
   end generate;

   g_ext_x4_clk:if G_USE_EXT_x4_CLK generate
      i_clk_chroma_x4 <= clk_chroma_x4_i;
   end generate;


   p_quad_gen:process(i_clk_chroma_x4)
   variable vsr_by : std_logic_vector(3 downto 0) := "1100";
   variable vsr_ry : std_logic_vector(3 downto 0) := "1001";
   begin
      if rising_edge(i_clk_chroma_x4) then
         r_car_by <= vsr_by(0);
         r_car_ry <= vsr_ry(0) xor r_pal_swich;
         vsr_by := vsr_by(2 downto 0) & vsr_by(3);
         vsr_ry := vsr_ry(2 downto 0) & vsr_ry(3);
      end if;
   end process;


   p_gate:process(clk_i)
   variable v_ctr : unsigned(numbits(G_BURST+G_BREEZE+5) downto 0);
   begin 

      if rising_edge(clk_i) then

         if v_ctr > G_BREEZE and v_ctr <= G_BREEZE + G_BURST then
            r_burst <= '1';
         else
            r_burst <= '0';
         end if;

         if hs_i = '1' then
            v_ctr := (others => '0');
         else
            if v_ctr(v_ctr'high) = '0' then
               v_ctr := v_ctr + 1;
            end if;
         end if;
      end if;
   end process;

      
   p_by_mag:process(clk_i)
   begin
      if rising_edge(clk_i) then
         if r_burst = '1' then
            if G_PAL then
               r_base_by <= to_signed(-2, r_base_by'length);
            else
               r_base_by <= to_signed(-6, r_base_by'length);
            end if;
         else
            r_base_by <= to_signed(to_integer(
               shift_right(
                  (to_signed(to_integer(r_i), 10 + G_INBITS+1) * (-37))
               +  (to_signed(to_integer(g_i), 10 + G_INBITS+1) * (-73))
               +  (to_signed(to_integer(b_i), 10 + G_INBITS+1) * (111))
               , 8)),
               r_base_by'length
               );
         end if;
      end if;
   end process;

   p_ry_mag:process(clk_i)
   begin
      if rising_edge(clk_i) then
         if r_burst = '1' then
            if G_PAL then
               r_base_ry <= to_signed(2, r_base_ry'length);
            else
               r_base_ry <= to_signed(0, r_base_ry'length);
            end if;
         else
            r_base_ry <= to_signed(to_integer(
               shift_right(
                  (to_signed(to_integer(r_i), 10 + G_INBITS+1) * (157))
               +  (to_signed(to_integer(g_i), 10 + G_INBITS+1) * (-132))
               +  (to_signed(to_integer(b_i), 10 + G_INBITS+1) * (-25))
               , 8)),
               r_base_ry'length
               );
         end if;
      end if;
   end process;

   p_mod_ry:process(i_clk_chroma_x4)
   begin
      if rising_edge(i_clk_chroma_x4) then
         if r_car_ry = '1' then
            r_mod_ry <= r_base_ry;
         else
            r_mod_ry <= -r_base_ry;
         end if;
      end if;
   end process;

   p_mod_by:process(i_clk_chroma_x4)
   begin
      if rising_edge(i_clk_chroma_x4) then
         if r_car_by = '1' then
            r_mod_by <= r_base_by;
         else
            r_mod_by <= -r_base_by;
         end if;
      end if;
   end process;

   p_sum:process(i_clk_chroma_x4)
   begin
      if rising_edge(i_clk_chroma_x4) then
         chroma_o <= r_mod_by + r_mod_ry;
      end if;
   end process;

end rtl;