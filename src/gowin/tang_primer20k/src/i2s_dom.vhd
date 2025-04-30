-- Simple I2S Interface
--
-- Copright (c) 2025 Dom Beesley - reworked from i2s_simple 
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity i2s_dom is
    port (
        -- Clock/Reset      
        clock      : in  std_logic;         -- should be 32*2* the sample rate
        reset_n    : in  std_logic;         

        -- Parallel Audio In (signed)
        audio_l    : in  std_logic_vector(15 downto 0);
        audio_r    : in  std_logic_vector(15 downto 0);

        -- I2S Audio Out
        i2s_bclk   : out std_logic;         -- half the input clock rate
        i2s_lrclk  : out std_logic;         -- swaps every 16 samples
        i2s_din    : out std_logic;         -- data out from here, in to dac
        pa_en      : out std_logic          -- enable (reset_n) out
    );
end entity;

architecture rtl of i2s_dom is

    signal lr_ring      : std_logic_vector(31 downto 0) := "00000000000000001111111111111111";
    signal shift_reg    : std_logic_vector(31 downto 0) := (others => '0');
    signal shift_bclk   : std_logic := '1';
    signal en           : std_logic := '0';
begin

    pa_en <= en; -- enable amplifier
    i2s_bclk <= shift_bclk;
    i2s_lrclk <= lr_ring(lr_ring'high);
    i2s_din <= shift_reg(shift_reg'high);

    p_sh:process(clock)

    begin
        if reset_n = '0' then
            lr_ring <= "00000000000000001111111111111111";
            en <= '0';
            shift_bclk <= '1';
            shift_reg <= (others => '0');
        elsif rising_edge(clock) then
            
            if shift_bclk = '1' then
                shift_bclk <= '0';
                -- data can change on falling edge of bclk

                if lr_ring(31) = '1' and lr_ring(30) = '0' then
                    shift_reg <= audio_l & audio_r;
                    en <= '1';
                else
                    shift_reg <= shift_reg(shift_reg'high-1 downto 0) & shift_reg(0);
                end if;

                lr_ring <= lr_ring(lr_ring'high-1 downto 0) & lr_ring(lr_ring'high);

            else
                shift_bclk <= '1';
            end if;
        end if;

    end process;




end architecture;
