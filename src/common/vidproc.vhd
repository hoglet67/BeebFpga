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
-- BBC Micro "VIDPROC" Video ULA
--
-- Synchronous implementation for FPGA
--
-- (C) 2011 Mike Stirling
--
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vidproc is
    generic (
        IncludeVideoNuLA : boolean := false;
        RGB_WIDTH        : integer := 1
        );
    port (
        CLOCK       :   in  std_logic;
        CPUCLKEN    :   in  std_logic;

        -- Clock enable qualifies display cycles (interleaved with CPU cycles)
        CLKEN       :   in  std_logic;
        PIXCLK      :   in  std_logic;
        nRESET      :   in  std_logic;

        -- Clock enable output to CRTC
        CLKEN_CRTC  :   out std_logic;

        -- Bus interface
        ENABLE      :   in  std_logic;
        A           :   in  std_logic_vector(1 downto 0);
        -- CPU data bus (for register writes)
        DI_CPU      :   in  std_logic_vector(7 downto 0);
        -- Display RAM data bus (for display data fetch)
        DI_RAM      :   in  std_logic_vector(7 downto 0);

        -- Control interface
        nINVERT     :   in  std_logic;
        DISEN       :   in  std_logic;
        CURSOR      :   in  std_logic;

        -- Video in (teletext mode)
        R_IN        :   in  std_logic;
        G_IN        :   in  std_logic;
        B_IN        :   in  std_logic;

        -- Video out
        R           :   out std_logic_vector(RGB_WIDTH - 1 downto 0);
        G           :   out std_logic_vector(RGB_WIDTH - 1 downto 0);
        B           :   out std_logic_vector(RGB_WIDTH - 1 downto 0)
        );
end entity;

architecture rtl of vidproc is
-- Write-only registers
    signal r0_cursor0       :   std_logic;
    signal r0_cursor1       :   std_logic;
    signal r0_cursor2       :   std_logic;
    signal r0_crtc_2mhz     :   std_logic;
    signal r0_pixel_rate    :   std_logic_vector(1 downto 0);
    signal r0_teletext      :   std_logic;
    signal r0_flash         :   std_logic;

    type palette_t is array(0 to 15) of std_logic_vector(3 downto 0);
    signal palette          :   palette_t;

-- Pixel shift register
    signal di               :   std_logic_vector(7 downto 0);
    signal shiftreg         :   std_logic_vector(7 downto 0);
-- Delayed display enable
    signal delayed_disen    :   std_logic;
    signal delayed_disen2   :   std_logic;

-- Internal clock enable generation
    signal clken_pixel      :   std_logic;
    signal clken_load       :   std_logic;
    signal clken_fetch      :   std_logic;
    signal clken_counter    :   unsigned(3 downto 0);
    signal pixen_prescale   :   unsigned(1 downto 0);
    signal pixen_counter    :   unsigned(3 downto 0);

-- Cursor generation - can span up to 32 pixels
-- Segments 0 and 1 are 8 pixels wide
-- Segment 2 is 16 pixels wide
    signal cursor_invert    :   std_logic;
    signal cursor_active    :   std_logic;
    signal cursor_counter   :   unsigned(1 downto 0);

    signal RR               :   std_logic;
    signal GG               :   std_logic;
    signal BB               :   std_logic;

-- Pass physical colour to VideoNuLA
    signal phys_col                   : std_logic_vector(3 downto 0);

-- Delay line for physical colour to support horirontal scroll offset
    signal phys_col_delay_reg         : std_logic_vector(27 downto 0);
    signal phys_col_delay_mux         : std_logic_vector(31 downto 0);
    signal phys_col_delay_out         : std_logic_vector(3 downto 0);

-- Additional VideoNuLA registers
    signal nula_palette_mode          : std_logic;
    signal nula_hor_scroll_offset     : std_logic_vector(2 downto 0);
    signal nula_left_banking_size     : std_logic_vector(3 downto 0);
    signal nula_disable_a1            : std_logic;
    signal nula_enable_attr_mode      : std_logic;
    signal nula_enable_text_attr_mode : std_logic;
    signal nula_flashing_flags        : std_logic_vector(7 downto 0);
    signal nula_write_index           : std_logic;
    signal nula_data_last             : std_logic_vector(7 downto 0);
    signal nula_RGB                   : std_logic_vector(11 downto 0);

-- Additional VideoNuLA palette
    type nula_palette_t is array(0 to 15) of std_logic_vector(11 downto 0);
    signal nula_palette               : nula_palette_t;

-- Additional VideoNuLA signals
    signal nula_nreset                 : std_logic := '0';

begin

    -- Original VideoULA Registers

    -- Synchronous register access, enabled on every clock
    process(CLOCK,nRESET)
    begin
        if nRESET = '0' then
            r0_cursor0 <= '0';
            r0_cursor1 <= '0';
            r0_cursor2 <= '0';
            r0_crtc_2mhz <= '0';
            r0_pixel_rate <= "00";
            r0_teletext <= '0';
            r0_flash <= '0';

            for colour in 0 to 15 loop
                palette(colour) <= (others => '0');
            end loop;
        elsif rising_edge(CLOCK) then
            if CPUCLKEN = '1' then
                if ENABLE = '1' and (A(1) = '0' or not IncludeVideoNuLA or (IncludeVideoNuLA and nula_disable_a1 = '1')) then
                    if A(0) = '0' then
                        -- Access control register
                        r0_cursor0 <= DI_CPU(7);
                        r0_cursor1 <= DI_CPU(6);
                        r0_cursor2 <= DI_CPU(5);
                        r0_crtc_2mhz <= DI_CPU(4);
                        r0_pixel_rate <= DI_CPU(3 downto 2);
                        r0_teletext <= DI_CPU(1);
                        r0_flash <= DI_CPU(0);
                    else
                        -- Access palette register
                        palette(to_integer(unsigned(DI_CPU(7 downto 4)))) <= DI_CPU(3 downto 0);
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- Additional VideoNuLA registers
    videoNula_registers: if IncludeVideoNuLA generate
    begin

        -- Synchronous register access, enabled on every clock
        process(CLOCK, nRESET)
        begin

            if nRESET = '0' then

                nula_nreset <= '0';

            elsif rising_edge(CLOCK) then

                if CPUCLKEN = '1' then

                    -- If the nula_nreset register is '0', sSynchronously reset
                    -- everything, then set nula_nreset to '1' to acknowledge.
                    -- This allow the reset logic to be in one place, but
                    -- triggered by three things: power up, nRESET and &FE22=&4x

                    if nula_nreset = '0' then
                        nula_palette_mode          <= '0';
                        nula_hor_scroll_offset     <= (others => '0');
                        nula_left_banking_size     <= (others => '0');
                        nula_disable_a1            <= '0';
                        nula_enable_attr_mode      <= '0';
                        nula_enable_text_attr_mode <= '0';
                        nula_flashing_flags        <= (others => '1');
                        nula_write_index           <= '0';
                        nula_palette( 0)           <= x"000";
                        nula_palette( 1)           <= x"F00";
                        nula_palette( 2)           <= x"0F0";
                        nula_palette( 3)           <= x"FF0";
                        nula_palette( 4)           <= x"00F";
                        nula_palette( 5)           <= x"F0F";
                        nula_palette( 6)           <= x"0FF";
                        nula_palette( 7)           <= x"FFF";
                        nula_palette( 8)           <= x"000";
                        nula_palette( 9)           <= x"F00";
                        nula_palette(10)           <= x"0F0";
                        nula_palette(11)           <= x"FF0";
                        nula_palette(12)           <= x"00F";
                        nula_palette(13)           <= x"F0F";
                        nula_palette(14)           <= x"0FF";
                        nula_palette(15)           <= x"FFF";
                        nula_nreset                <= '1';
                    end if;

                    if ENABLE = '1' and A(1) = '1' and nula_disable_a1 = '0' then
                        if A(0) = '0' then
                            -- &FE22 - Auxiliary Control Register
                            case DI_CPU(7 downto 4) is
                                when x"1" =>
                                    nula_palette_mode          <= DI_CPU(0);
                                when x"2" =>
                                    nula_hor_scroll_offset     <= DI_CPU(2 downto 0);
                                when x"3" =>
                                    nula_left_banking_size     <= DI_CPU(3 downto 0);
                                when x"4" =>
                                    nula_nreset                <= '0';
                                when x"5" =>
                                    nula_disable_a1            <= '1';
                                when x"6" =>
                                    nula_enable_attr_mode      <= DI_CPU(0);
                                when x"7" =>
                                    nula_enable_text_attr_mode <= DI_CPU(0);
                                when x"8" =>
                                    -- bits 7..4 control colours 8..11 respectively
                                    nula_flashing_flags(7 downto 4) <= DI_CPU(3 downto 0);
                                when x"9" =>
                                    -- bits 3..0 control colours 12..15 respectively
                                    nula_flashing_flags(3 downto 0) <= DI_CPU(3 downto 0);
                                when others =>
                            end case;
                        else
                            -- &FE23 - Auxiliary Palette Register
                            if nula_write_index = '0' then
                                nula_data_last <= DI_CPU;
                            else
                                nula_palette(to_integer(unsigned(nula_data_last(7 downto 4)))) <= nula_data_last(3 downto 0) & DI_CPU;
                                -- if writing to colours 8..15, clear the flash
                                -- flags to supress flashing
                                if nula_data_last(7) = '1' then
                                    nula_flashing_flags(to_integer(unsigned(nula_data_last(6 downto 4) xor "111"))) <= '0';
                                end if;
                            end if;
                            nula_write_index <= not nula_write_index;
                        end if;
                    end if;
                end if;
            end if;
        end process;
    end generate;

    -- The CRT controller is always enabled in the 15th cycle, so that the result
    -- is ready for latching into the shift register in cycle 0.  If 2 MHz mode is
    -- selected then the CRTC is also enabled in the 7th cycle
    CLKEN_CRTC <= CLKEN and
                  clken_counter(0) and clken_counter(1) and clken_counter(2) and
                  (clken_counter(3) or r0_crtc_2mhz);

    -- The result is fetched from the CRTC in cycle 0 and also cycle 8 if 2 MHz
    -- mode is selected.  This is used for reloading the shift register as well as
    -- counting cursor pixels
    clken_fetch <= CLKEN and not (clken_counter(0) or clken_counter(1) or clken_counter(2) or
                                  (clken_counter(3) and not r0_crtc_2mhz));


    process(CLOCK,nRESET)
    begin
        if nRESET = '0' then
            clken_counter <= (others => '0');
        elsif rising_edge(CLOCK) then
            if CLKEN = '1' then
                -- Increment internal cycle counter during each video clock
                clken_counter <= clken_counter + 1;
                if clken_fetch = '1' then
                    di <= DI_RAM;
                end if;
            end if;
        end if;
    end process;


    -- =========================================================
    -- PIXCLK is the main clock below this point
    -- =========================================================


    -- Pixel clock enables
    process(PIXCLK,nRESET)
    begin
        if nRESET = '0' then

            pixen_counter <= (others => '0');
            pixen_prescale <= (others => '0');

        elsif rising_edge(PIXCLK) then

            clken_pixel <= '0';
            clken_load <= '0';


            if pixen_prescale = 1 then
                pixen_prescale <= pixen_prescale + 2;
            else
                pixen_prescale <= pixen_prescale + 1;
            end if;

            if pixen_prescale = 3 then
                case r0_pixel_rate is
                    when "00" =>
                        clken_pixel <= not (pixen_counter(0) or pixen_counter(1) or pixen_counter(2));
                    when "01" =>
                        clken_pixel <= not (pixen_counter(0) or pixen_counter(1));
                    when "10" =>
                        clken_pixel <= not pixen_counter(0);
                    when "11" =>
                        clken_pixel <= '1';
                    when others =>
                end case;
                if pixen_counter = 0 or (r0_crtc_2mhz = '1' and pixen_counter = 8) then
                    clken_load <= '1';
                end if;
                pixen_counter <= pixen_counter + 1;
            end if;
        end if;
    end process;


    -- Shift register control
    process(PIXCLK,nRESET)
    begin
        if nRESET = '0' then
            shiftreg <= (others => '0');
        elsif rising_edge(PIXCLK) then
            if clken_pixel = '1' then
                if clken_load = '1' then
                    -- Fetch next byte from RAM into shift register.  This always occurs in
                    -- cycle 0, and also in cycle 8 if the CRTC is clocked at double rate.
                    shiftreg <= di;
                else
                    -- Clock shift register and input '1' at LSB
                    shiftreg <= shiftreg(6 downto 0) & "1";
                end if;
            end if;
        end if;
    end process;

    -- Cursor generation
    cursor_invert <= cursor_active and
                     ((r0_cursor0 and not (cursor_counter(0) or cursor_counter(1))) or
                      (r0_cursor1 and cursor_counter(0) and not cursor_counter(1)) or
                      (r0_cursor2 and cursor_counter(1)));

    process(PIXCLK,nRESET)
    begin
        if nRESET = '0' then
            cursor_active <= '0';
            cursor_counter <= (others => '0');
        elsif rising_edge(PIXCLK) then
            if clken_pixel = '1' then
                if clken_load = '1' then
                    if CURSOR = '1' or cursor_active = '1' then
                        -- Latch cursor
                        cursor_active <= '1';

                        -- Reset on counter wrap
                        if cursor_counter = "11" then
                            cursor_active <= '0';
                        end if;

                        -- Increment counter
                        if cursor_active = '0' then
                            -- Reset
                            cursor_counter <= (others => '0');
                        else
                            -- Increment
                            cursor_counter <= cursor_counter + 1;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- Pixel generation
    -- The new shift register contents are loaded during
    -- cycle 0 (and 8) but will not be read here until the next cycle.
    -- By running this process on every single video tick instead of at
    -- the pixel rate we ensure that the resulting delay is minimal and
    -- constant (running this at the pixel rate would cause
    -- the display to move slightly depending on which mode was selected).
    process(PIXCLK,nRESET)
        variable palette_a : std_logic_vector(3 downto 0);
        variable dot_val : std_logic_vector(3 downto 0);
        variable red_val : std_logic;
        variable green_val : std_logic;
        variable blue_val : std_logic;
        variable do_flash : std_logic;
    begin
        if nRESET = '0' then
            RR <= '0';
            GG <= '0';
            BB <= '0';
            delayed_disen <= '0';
        elsif rising_edge(PIXCLK) then
            if clken_pixel = '1' then
                -- Look up dot value in the palette.  Bits are as follows:
                -- bit 3 - FLASH
                -- bit 2 - Not BLUE
                -- bit 1 - Not GREEN
                -- bit 0 - Not RED
                palette_a := shiftreg(7) & shiftreg(5) & shiftreg(3) & shiftreg(1);
                dot_val := palette(to_integer(unsigned(palette_a)));


                -- Apply flash inversion if required
                do_flash := r0_flash;
                if IncludeVideoNuLA then
                    if nula_flashing_flags(to_integer(unsigned(dot_val(2 downto 0)))) = '0' then
                        do_flash := '0';
                    end if;
                end if;
                red_val := (dot_val(3) and do_flash) xor not dot_val(0);
                green_val := (dot_val(3) and do_flash) xor not dot_val(1);
                blue_val := (dot_val(3) and do_flash) xor not dot_val(2);

                -- To output
                -- FIXME: INVERT option
                RR <= (red_val and delayed_disen) xor cursor_invert;
                GG <= (green_val and delayed_disen) xor cursor_invert;
                BB <= (blue_val and delayed_disen) xor cursor_invert;

                -- Display enable signal delayed by one clock
                delayed_disen <= DISEN;

                -- Output physical colour, to be used by VideoNuLA
                if nula_palette_mode = '1' then
                    phys_col <= palette_a;
                else
                    phys_col <= dot_val(3) & blue_val & green_val & red_val;
                end if;
            end if;
        end if;
    end process;

    VideoNula_included: if IncludeVideoNuLA generate
    begin

        -- Infer a large mux to select the appropriate hor scroll delay tap
        phys_col_delay_mux <= phys_col_delay_reg & phys_col;
        phys_col_delay_out <= phys_col_delay_mux(to_integer(unsigned(nula_hor_scroll_offset)) * 4 + 3 downto to_integer(unsigned(nula_hor_scroll_offset)) * 4);

        process (PIXCLK)
            variable invert : std_logic_vector(3 downto 0);
        begin
           if rising_edge(PIXCLK) then
               if clken_pixel = '1' then
                   -- Shift pixels in from right (so bits 3..0 are the most recent)
                   phys_col_delay_reg <= phys_col_delay_reg(23 downto 0) & phys_col;
                   delayed_disen2 <= delayed_disen;
                   invert := (others => cursor_invert);
                   if delayed_disen2 = '1' then
                       nula_RGB <= nula_palette(to_integer(unsigned(phys_col_delay_out xor invert)));
                   else
                       nula_RGB <= x"000";
                   end if;

               end if;
           end if;
        end process;

        R <= nula_RGB(11 downto 8) when r0_teletext = '0' else
             (others => R_IN xor cursor_invert);

        G <= nula_RGB(7 downto 4) when r0_teletext = '0' else
             (others => G_IN xor cursor_invert);

        B <= nula_RGB(3 downto 0) when r0_teletext = '0' else
             (others => B_IN xor cursor_invert);

    end generate;

    VideoNula_not_included: if not IncludeVideoNuLA generate
    begin
        R <= (others => RR) when r0_teletext = '0' else (others => R_IN xor cursor_invert);
        G <= (others => GG) when r0_teletext = '0' else (others => G_IN xor cursor_invert);
        B <= (others => BB) when r0_teletext = '0' else (others => B_IN xor cursor_invert);
    end generate;


end architecture;
