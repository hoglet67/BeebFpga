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
--
--
--
-- (C) 2011 Mike Stirling
--
-- Updated to run at 12MHz rather than 6MHz
-- Character rounding added
-- Implemented Graphics Hold
-- Lots of fixes to correctly implement Set-At and Set-After control codes
--
-- (C) 2015 David Banks

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity saa5050 is
generic (
    IncludeTTxtROM : boolean := TRUE -- false if the SAA5050 character ROM needs loading
    );
port (
    CLOCK       :   in  std_logic;
    -- 6 MHz dot clock enable
    CLKEN       :   in  std_logic;
    -- Async reset
    nRESET      :   in  std_logic;

    -- Character data input (in the bus clock domain)
    DI_CLOCK    :   in  std_logic;
    DI_CLKEN    :   in  std_logic;
    DI          :   in  std_logic_vector(6 downto 0);

    -- Timing inputs
    -- General line reset (not used)
    GLR         :   in  std_logic; -- /HSYNC
    -- Data entry window - high during VSYNC.
    -- Resets ROM row counter and drives 'flash' signal
    DEW         :   in  std_logic; -- VSYNC
    -- Character rounding select - high during even field
    CRS         :   in  std_logic; -- FIELD
    -- Load output shift register enable - high during active video
    LOSE        :   in  std_logic; -- DE

    -- Video out
    R           :   out std_logic;
    G           :   out std_logic;
    B           :   out std_logic;
    Y           :   out std_logic;
    PIXDE       :   out std_logic;

    -- Simultaneous odd/even lines for feeding into a line doubler
    R_even      :   out std_logic;
    G_even      :   out std_logic;
    B_even      :   out std_logic;
    R_odd       :   out std_logic;
    G_odd       :   out std_logic;
    B_odd       :   out std_logic;

    -- SAA5050 character ROM loading
    char_rom_we   : in std_logic := '0';
    char_rom_addr : in std_logic_vector(10 downto 0) := (others => '0');
    char_rom_data : in std_logic_vector(7 downto 0) := (others => '0')
    );
end entity;

architecture rtl of saa5050 is

-- Register inputs in the bus clock domain
signal di_tmp       :   std_logic_vector(6 downto 0);
signal di_r         :   std_logic_vector(6 downto 0);
signal dew_r        :   std_logic;
signal lose_r       :   std_logic;

-- Data input registered in the pixel clock domain
signal code          :   std_logic_vector(6 downto 0);
signal line_addr     :   unsigned(3 downto 0);
signal rom_char      :   std_logic_vector(6 downto 0);
signal rom_addr      :   std_logic_vector(10 downto 0);
signal rom_addr_this :   std_logic_vector(10 downto 0);
signal rom_addr_prev :   std_logic_vector(10 downto 0);
signal rom_addr_next :   std_logic_vector(10 downto 0);
signal row_data      :   std_logic_vector(7 downto 0);
signal ref_data_even :   std_logic_vector(7 downto 0);
signal ref_data_odd :   std_logic_vector(7 downto 0);

-- Delayed display enable derived from LOSE by delaying for one and two characters
signal disp_enable  :   std_logic;
-- Latched timing signals for detection of falling edges
signal dew_latch    :   std_logic;
signal lose_latch   :   std_logic;
signal disp_enable_latch    :   std_logic;

-- Row and column addressing is handled externally.  We just need to
-- keep track of which of the 10 lines we are on within the character...
signal line_counter :   unsigned(3 downto 0);
-- ... and which of the 12 pixels we are on within each line
signal pixel_counter :  unsigned(3 downto 0);
-- We also need to count frames to implement the flash feature.
-- The datasheet says this is 0.75 Hz with a 3:1 on/off ratio, so it
-- is probably a /64 counter, which gives us 0.78 Hz
signal flash_counter :  unsigned(5 downto 0);

-- Output shift register
signal shift_reg_even :   std_logic_vector(11 downto 0);
signal shift_reg_odd  :   std_logic_vector(11 downto 0);
signal shift_reg_de   :   std_logic_vector(11 downto 0);

-- Flash mask
signal flash        :   std_logic;

-- Current display state
-- Foreground colour (B2, G1, R0)
signal fg           :   std_logic_vector(2 downto 0);
-- Background colour (B2, G1, R0)
signal bg           :   std_logic_vector(2 downto 0);
signal conceal      :   std_logic;
signal gfx          :   std_logic;
signal gfx_sep      :   std_logic;
signal gfx_hold     :   std_logic;
signal is_flash     :   std_logic;
signal double_high  :   std_logic;

-- One-shot versions of certain control signals to support "Set-After" semantics
signal fg_next          : std_logic_vector(2 downto 0);
signal alpha_next       : std_logic;
signal gfx_next         : std_logic;
signal gfx_release_next : std_logic;
signal is_flash_next    : std_logic;
signal double_high_next : std_logic;
signal unconceal_next   : std_logic;

-- Once char delayed versions of all of the signals seen by the ROM/Shift Register/Output Stage
-- This is to compensate for the one char delay through the control state machine
signal code_r       :   std_logic_vector(6 downto 0);
signal disp_enable_r:   std_logic;
signal fg_r         :   std_logic_vector(2 downto 0);
signal bg_r         :   std_logic_vector(2 downto 0);
signal conceal_r    :   std_logic;
signal is_flash_r   :   std_logic;

-- Last graphics character, for use by graphics hold
signal last_gfx_sep     : std_logic;
signal last_gfx         : std_logic_vector(6 downto 0);
signal hold_active      : std_logic;

-- Set in first row of double height
signal double_high1 :   std_logic;
-- Set in second row of double height
signal double_high2 :   std_logic;

begin

    -- Generate flash signal for 3:1 ratio
    flash <= flash_counter(5) and flash_counter(4);

    -- Sync inputs
    process(DI_CLOCK,nRESET)
    begin
        if nRESET = '0' then
            di_tmp <= (others => '0');
            di_r <= (others => '0');
            dew_r <= '0';
            lose_r <= '0';
        elsif rising_edge(DI_CLOCK) then
            if DI_CLKEN = '1' then
                di_tmp <= DI;
                di_r <= di_tmp;
                dew_r <= DEW;
                lose_r <= LOSE;
            end if;
        end if;
    end process;

    -- Register data into pixel clock domain
    process(CLOCK,nRESET)
    begin
        if nRESET = '0' then
            code          <= (others => '0');
            code_r        <= (others => '0');
            disp_enable_r <= '0';
            fg_r          <= (others => '0');
            bg_r          <= (others => '0');
            conceal_r     <= '0';
            is_flash_r    <= '0';
        elsif rising_edge(CLOCK) then
            if CLKEN = '1' then
                code <= di_r;
                if pixel_counter = 0 then
                    code_r        <= code;
                    disp_enable_r <= disp_enable;
                    fg_r          <= fg;
                    bg_r          <= bg;
                    conceal_r     <= conceal;
                    is_flash_r    <= is_flash;
                end if;
            end if;
        end if;
    end process;

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
        elsif rising_edge(CLOCK) then
            if CLKEN = '1' then
                -- Register syncs for edge detection
                dew_latch <= dew_r;
                lose_latch <= lose_r;
                disp_enable_latch <= disp_enable;

                -- When first entering double-height mode start on top row
                if double_high = '1' and double_high1 = '0' and double_high2 = '0' then
                    double_high1 <= '1';
                end if;

                -- Count pixels between 0 and 11
                if pixel_counter = 11 then
                    -- Start of next character and delayed display enable
                    pixel_counter <= (others => '0');
                    disp_enable <= lose_r;
                else
                    pixel_counter <= pixel_counter + 1;
                end if;

                -- Rising edge of LOSE is the start of the active line
                if lose_r = '1' and lose_latch = '0' then
                    -- Reset pixel counter - small offset to make the output
                    -- line up with the cursor from the video ULA
                    pixel_counter <= "0110";
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
        end if;
    end process;



    -- Control character handling
    process(CLOCK,nRESET)
    begin
        if nRESET = '0' then
            -- Current Attributes
            fg               <= (others => '1');
            bg               <= (others => '0');
            conceal          <= '0';
            gfx              <= '0';
            gfx_sep          <= '0';
            gfx_hold         <= '0';
            is_flash         <= '0';
            double_high      <= '0';
            -- One-shot versions to support "Set-After" semantics
            fg_next          <= (others => '0');
            gfx_next         <= '0';
            alpha_next       <= '0';
            gfx_release_next <= '0';
            is_flash_next    <= '0';
            double_high_next <= '0';
            unconceal_next   <= '0';
            -- Last graphics character
            last_gfx         <= (others => '0');
            last_gfx_sep     <= '0';
        elsif rising_edge(CLOCK) then
            if CLKEN = '1' then
                -- Reset to start of line defaults
                if disp_enable = '0' then
                    -- Current Attributes
                    fg               <= (others => '1');
                    bg               <= (others => '0');
                    conceal          <= '0';
                    gfx              <= '0';
                    gfx_sep          <= '0';
                    gfx_hold         <= '0';
                    is_flash         <= '0';
                    double_high      <= '0';
                    -- One-shot versions to support "Set-After" semantics
                    fg_next          <= (others => '0');
                    gfx_next         <= '0';
                    alpha_next       <= '0';
                    gfx_release_next <= '0';
                    is_flash_next    <= '0';
                    double_high_next <= '0';
                    unconceal_next   <= '0';
                    -- Last graphics character
                    last_gfx         <= (others => '0');
                    last_gfx_sep     <= '0';
                elsif pixel_counter = 0 then
                    -- One-shot versions to support "Set-After" semantics
                    fg_next          <= (others => '0');
                    gfx_next         <= '0';
                    alpha_next       <= '0';
                    gfx_release_next <= '0';
                    is_flash_next    <= '0';
                    double_high_next <= '0';
                    unconceal_next   <= '0';
                    if code(5) = '1' then
                        -- Latch the last graphic character (inc seperation), to support graphics hold
                        last_gfx <= code;
                        last_gfx_sep <= gfx_sep;
                    elsif code(6 downto 5) = "00" and gfx_hold = '0' and code(4 downto 0) /= "11110" then
                        -- SAA5050 hold bug: control codes outside of hold clear the held character (apart from 11110=HOLD)
                        last_gfx <= (others => '0');
                    end if;

                    -- Set After codes (from the previous char) are handled first, because in some
                    -- cases they can be over-ridden by Set At codes. For example:
                    -- Flash (Set After) followed by Steady (Set At) => Steady wins
                    -- Double (Set After) followed by Normal (Set At) => Normal wins
                    -- Delay the "Set After" control code effect until the next character
                    if fg_next /= "000" then
                        fg <= fg_next;
                    end if;
                    if gfx_next = '1' then
                        gfx <= '1';
                    end if;
                    if alpha_next = '1' then
                        gfx <= '0';
                        last_gfx <= (others => '0');
                    end if;
                    if is_flash_next = '1' then
                        is_flash <= '1';
                    end if;
                    if double_high_next = '1' then
                        double_high <= '1';
                    end if;
                    if gfx_release_next = '1' then
                        gfx_hold <= '0';
                    end if;

                    -- Note, conflicts can arise as setting/clearing happen in different cycles
                    -- e.g. 03 (Alpha Yellow) 18 (Conceal) should leave us in a conceal state
                    if conceal = '1' and unconceal_next = '1' then
                        conceal <= '0';
                    end if;

                    -- Latch new control codes at the start of each character
                    if code(6 downto 5) = "00" then
                        if code(3) = '0' then
                            -- 0 would be black but is not allowed so has no effect
                            if code(2 downto 0) /= "000" then
                                -- Colour and graphics setting clears conceal mode - Set After
                                unconceal_next <= '1';
                                -- Select the foreground colout - Set After
                                fg_next <= code(2 downto 0);
                                -- Select graphics or alpha mode - Set After
                                if code(4) = '1' then
                                    gfx_next <= '1';
                                else
                                    alpha_next <= '1';
                                end if;
                            end if;
                        else
                            case code(4 downto 0) is
                            -- FLASH - Set After
                            when "01000" =>
                                is_flash_next <= '1';
                            -- STEADY - Set At
                            when "01001" =>
                                is_flash <= '0';
                            -- NORMAL HEIGHT - Set At
                            when "01100" =>
                                double_high <= '0';
                                -- Graphics hold character is cleared by a *change* of height
                                if (double_high = '1') then
                                    last_gfx <= (others => '0');
                                end if;
                            -- DOUBLE HEIGHT - Set After
                            when "01101" =>
                                double_high_next <= '1';
                                -- Graphics hold character is cleared by a *change* of height
                                if (double_high = '0') then
                                    last_gfx <= (others => '0');
                                end if;
                            -- CONCEAL - Set At
                            when "11000" =>
                                conceal <= '1';
                            -- CONTIGUOUS GFX - Set At
                            when "11001" =>
                                gfx_sep <= '0';
                            -- SEPARATED GFX - Set At
                            when "11010" =>
                                gfx_sep <= '1';
                            -- BLACK BACKGROUND - Set At
                            when "11100" =>
                                bg <= (others => '0');
                            -- NEW BACKGROUND - Set At
                            when "11101" =>
                                -- if there is a pending foreground change, then use it
                                if fg_next /= "000" then
                                    bg <= fg_next;
                                else
                                    bg <= fg;
                                end if;
                            -- HOLD GFX - Set At
                            when "11110" =>
                                gfx_hold <= '1';
                            -- RELEASE GFX - Set After
                            when "11111" =>
                                gfx_release_next <= '1';
                            when others => null;
                            end case;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Character ROM
    --------------------------------------------------------------------

    -- Generate character rom address in pixel clock domain
    -- This is done combinatorially since all the inputs are already
    -- registered and the address is re-registered by the ROM
    line_addr <= line_counter                when double_high = '0' else
            ("0" & line_counter(3 downto 1)) when double_high2 = '0' else
            ("0" & line_counter(3 downto 1)) + 5;

    hold_active <= '1' when gfx_hold = '1' and code_r(6 downto 5) = "00" else '0';

    rom_char <= (others => '0') when (double_high = '0' and double_high2 = '1') else
                last_gfx when hold_active = '1'                                 else
                code_r;

    rom_addr_this <= rom_char & std_logic_vector(line_addr);

    rom_addr_prev <= rom_char & std_logic_vector(line_addr - 1);

    rom_addr_next <= rom_char & std_logic_vector(line_addr + 1);

    rom_addr <= char_rom_addr when char_rom_we = '1' and not IncludeTTxtROM else
                rom_addr_prev when pixel_counter = 9  else
                rom_addr_next when pixel_counter = 10 else
                rom_addr_this;

    -- If IncludeTTxtROM is true then we include the "ROM" version that is
    -- initialized with the mode 7 character set data
    -- (this is generally used for Xilinx builds)
    char_rom_block: if IncludeTTxtROM generate
    char_rom : entity work.saa5050_rom port map (
        clock    => CLOCK,
        clken    => CLKEN,
        addressA => rom_addr,
        QA       => row_data
        );
    end generate;

    -- If IncludeTTxtROM is false then we include the "RAM" version that is
    -- uninitialized, and needs loading during the core boostrap phase
    -- (this is generally used for Altera builds)
    char_ram_block: if not IncludeTTxtROM generate
        char_ram : entity work.saa5050_rom_uninitialized port map (
            clock    => CLOCK,
            clken    => CLKEN,
            wea      => char_rom_we,
            addressA => rom_addr,
            dina     => char_rom_data,
            QA       => row_data
            );
    end generate;

    -- Latch reference rows for character rounding...

    -- SAA5050 datasheet: For small characters rounding is always
    -- referenced in the same direction (i.e. row before in even
    -- fields and row after in odd fields as determined by the CRS
    -- signal). For double height characters rounding is always
    -- referenced alternately up and down changing every line using an
    -- internally generated signal. (The CRS signal is '0' for the odd
    -- field and '1' for the even field of an interlaced TV picture).

    process(CLOCK)
    begin
        if rising_edge(CLOCK) then
            if CLKEN = '1' then
                if double_high = '0' then
                    -- normal height, reference is based on even vs odd row
                    if pixel_counter = 10 then
                        ref_data_even <= row_data; -- above
                    end if;
                    if pixel_counter = 11 then
                        ref_data_odd  <= row_data; -- below
                    end if;
                else
                    -- double height, reference is based on the LSB of the line counter
                    if pixel_counter = 10 then
                        if line_counter(0) = '0' then
                            ref_data_odd  <= row_data; -- above
                            ref_data_even <= row_data; -- above
                        end if;
                    end if;
                    if pixel_counter = 11 then
                        if line_counter(0) = '1' then
                            ref_data_odd  <= row_data; -- below
                            ref_data_even <= row_data; -- below
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Shift register
    --------------------------------------------------------------------
    process(CLOCK,nRESET)
        variable row      : std_logic_vector(11 downto 0);
        variable ref_even : std_logic_vector(11 downto 0);
        variable ref_odd  : std_logic_vector(11 downto 0);
    begin
        if nRESET = '0' then
            shift_reg_even <= (others => '0');
            shift_reg_odd <= (others => '0');
            shift_reg_de <= (others => '0');
        elsif rising_edge(CLOCK) then
            if CLKEN = '1' then
                if disp_enable_r = '1' and pixel_counter = 0 then

                    if gfx = '1' and rom_char(5) = '1' then
                        if line_addr < 3 then
                            row := (11 downto 6 => rom_char(0), 5 downto 0 => rom_char(1));
                        elsif line_addr < 7 then
                            row := (11 downto 6 => rom_char(2), 5 downto 0 => rom_char(3));
                        else
                            row := (11 downto 6 => rom_char(4), 5 downto 0 => rom_char(6));
                        end if;
                        -- Apply a mask for separated graphics mode
                        if (hold_active = '0' and gfx_sep = '1') or (hold_active = '1' and last_gfx_sep = '1') then
                            row(10) := '0';
                            row(11) := '0';
                            row(4) := '0';
                            row(5) := '0';
                            if line_addr = 2 or line_addr = 6 or line_addr = 9 then
                                row := (others => '0');
                            end if;
                        end if;
                        shift_reg_even <= row;
                        shift_reg_odd  <= row;
                    else
                        -- Character rounding

                        -- a is the current row of pixels, doubled up
                        row := row_data(5) & row_data(5) &
                               row_data(4) & row_data(4) &
                               row_data(3) & row_data(3) &
                               row_data(2) & row_data(2) &
                               row_data(1) & row_data(1) &
                               row_data(0) & row_data(0);

                        -- ref even is normally the above row of pixels, doubled up
                        ref_even := ref_data_even(5) & ref_data_even(5) &
                                    ref_data_even(4) & ref_data_even(4) &
                                    ref_data_even(3) & ref_data_even(3) &
                                    ref_data_even(2) & ref_data_even(2) &
                                    ref_data_even(1) & ref_data_even(1) &
                                    ref_data_even(0) & ref_data_even(0);

                        -- ref odd is the normally the below row of pixels, doubled up
                        ref_odd  := ref_data_odd(5) & ref_data_odd(5) &
                                    ref_data_odd(4) & ref_data_odd(4) &
                                    ref_data_odd(3) & ref_data_odd(3) &
                                    ref_data_odd(2) & ref_data_odd(2) &
                                    ref_data_odd(1) & ref_data_odd(1) &
                                    ref_data_odd(0) & ref_data_odd(0);

                        -- Perform character rounding on even (upper) row
                        shift_reg_even <= row or
                                          (('0' & row(11 downto 1)) and ref_even and not('0' & ref_even(11 downto 1))) or
                                          ((row(10 downto 0) & '0') and ref_even and not(ref_even(10 downto 0) & '0'));

                        -- Perform character rounding on odd (lower) row
                        shift_reg_odd  <= row or
                                          (('0' & row(11 downto 1)) and ref_odd and not('0' & ref_odd(11 downto 1))) or
                                          ((row(10 downto 0) & '0') and ref_odd and not(ref_odd(10 downto 0) & '0'));

                    end if;

                    -- Load the shift register with the ROM bit pattern
                    -- at the start of each character while disp_enable is asserted.

                    shift_reg_de <= (others => '1');

                else
                    -- Pump the shift register
                    shift_reg_even <= shift_reg_even(10 downto 0) & "0";
                    shift_reg_odd  <= shift_reg_odd(10 downto 0)  & "0";
                    shift_reg_de   <= shift_reg_de(10 downto 0)   & "0";
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Output Pixel Colouring
    --------------------------------------------------------------------
    process(CLOCK,nRESET)
        variable pixel_even : std_logic;
        variable pixel_odd  : std_logic;
        variable pixel      : std_logic;
    begin
        if rising_edge(CLOCK) then
            if CLKEN = '1' then
                pixel_even := shift_reg_even(11) and not ((flash and is_flash_r) or conceal_r);
                pixel_odd  := shift_reg_odd(11)  and not ((flash and is_flash_r) or conceal_r);

                if CRS = '1' then
                    pixel := pixel_even;
                else
                    pixel := pixel_odd;
                end if;

                -- Generate mono output
                Y <= pixel;

                -- Generate colour output
                if pixel = '1' then
                    R <= fg_r(0);
                    G <= fg_r(1);
                    B <= fg_r(2);
                else
                    R <= bg_r(0);
                    G <= bg_r(1);
                    B <= bg_r(2);
                end if;

                if pixel_even = '1' then
                    R_even <= fg_r(0);
                    G_even <= fg_r(1);
                    B_even <= fg_r(2);
                else
                    R_even <= bg_r(0);
                    G_even <= bg_r(1);
                    B_even <= bg_r(2);
                end if;

                if pixel_odd = '1' then
                    R_odd <= fg_r(0);
                    G_odd <= fg_r(1);
                    B_odd <= fg_r(2);
                else
                    R_odd <= bg_r(0);
                    G_odd <= bg_r(1);
                    B_odd <= bg_r(2);
                end if;

                PIXDE <= shift_reg_de(11);
            end if;
        end if;
    end process;

end architecture;
