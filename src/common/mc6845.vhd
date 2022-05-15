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
-- MC6845 CRTC
--
-- Synchronous implementation for FPGA
--
-- (C) 2011 Mike Stirling
--
-- Corrected cursor flash rate
-- Fixed incorrect positioning of cursor when over left most character
-- Fixed timing of VSYNC
-- Fixed interlaced timing (add an extra line)
-- Implemented r05_v_total_adj
-- Implemented delay parts of r08_interlace (see Hitacht HD6845SP datasheet)
--
-- (C) 2015 David Banks
--
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mc6845 is
port (
    CLOCK       :   in  std_logic;
    CLKEN       :   in  std_logic;
    CLKEN_CPU   :   in  std_logic;
    CLKEN_ADR   :   in  std_logic;
    nRESET      :   in  std_logic;

    -- Bus interface
    ENABLE      :   in  std_logic;
    R_nW        :   in  std_logic;
    RS          :   in  std_logic;
    DI          :   in  std_logic_vector(7 downto 0);
    DO          :   out std_logic_vector(7 downto 0);

    -- Display interface
    VSYNC       :   out std_logic;
    HSYNC       :   out std_logic;
    DE          :   out std_logic;
    CURSOR      :   out std_logic;
    LPSTB       :   in  std_logic;

    VGA         :   in  std_logic;

    -- Memory interface
    MA          :   out std_logic_vector(13 downto 0);
    RA          :   out std_logic_vector(4 downto 0);
    test        :   out std_logic_vector(3 downto 0)
    );
end entity;

architecture rtl of mc6845 is

-- Host-accessible registers
signal addr_reg         :   std_logic_vector(4 downto 0);   -- Currently addressed register
-- These are write-only
signal r00_h_total      :   unsigned(7 downto 0);   -- Horizontal total, chars
signal r01_h_displayed  :   unsigned(7 downto 0);   -- Horizontal active, chars
signal r02_h_sync_pos   :   unsigned(7 downto 0);   -- Horizontal sync position, chars
signal r03_v_sync_width :   unsigned(3 downto 0);   -- Vertical sync width, scan lines (0=16 lines)
signal r03_h_sync_width :   unsigned(3 downto 0);   -- Horizontal sync width, chars (0=no sync)
signal r04_v_total      :   unsigned(6 downto 0);   -- Vertical total, character rows
signal r05_v_total_adj  :   unsigned(4 downto 0);   -- Vertical offset, scan lines
signal r06_v_displayed  :   unsigned(6 downto 0);   -- Vertical active, character rows
signal r07_v_sync_pos   :   unsigned(6 downto 0);   -- Vertical sync position, character rows
signal r08_interlace    :   std_logic_vector(7 downto 0);
signal r09_max_scan_line_addr       :   unsigned(4 downto 0);
signal r10_cursor_mode  :   std_logic_vector(1 downto 0);
signal r10_cursor_start :   unsigned(4 downto 0);   -- Cursor start, scan lines
signal r11_cursor_end   :   unsigned(4 downto 0);   -- Cursor end, scan lines
signal r12_start_addr_h :   unsigned(5 downto 0);
signal r13_start_addr_l :   unsigned(7 downto 0);
-- These are read/write
signal r14_cursor_h     :   unsigned(5 downto 0);
signal r15_cursor_l     :   unsigned(7 downto 0);
-- These are read-only
signal r16_light_pen_h  :   unsigned(5 downto 0);
signal r17_light_pen_l  :   unsigned(7 downto 0);


-- Timing generation
-- Horizontal counter counts position on line
signal h_counter        :   unsigned(7 downto 0);
-- HSYNC counter counts duration of sync pulse
signal h_sync_counter   :   unsigned(3 downto 0);
-- Row counter counts current character row
signal row_counter      :   unsigned(6 downto 0);
signal row_counter_next :   unsigned(6 downto 0);
-- Line counter counts current line within each character row
signal line_counter     :   unsigned(4 downto 0);
-- Vertical adjust counter counts lines within the vertical adjust period
signal vadjust_counter  :   unsigned(4 downto 0);
-- VSYNC counter counts duration of sync pulse
signal v_sync_counter   :   unsigned(3 downto 0);
-- Field counter counts number of complete fields for cursor flash
signal field_counter    :   unsigned(4 downto 0);

-- Internal signals
signal h_display        :   std_logic;
signal hs               :   std_logic;
signal v_display        :   std_logic;
signal vs               :   std_logic;
signal vs_hit           :   std_logic;
signal vs_hit_last      :   std_logic;
signal vs_even          :   std_logic;
signal vs_odd           :   std_logic;
signal odd_field        :   std_logic; -- indicates the current field is an odd field, updated on counter wrap
signal ma_i             :   unsigned(13 downto 0);
signal cursor_i         :   std_logic;
signal lpstb_i          :   std_logic;
signal de0              :   std_logic;
signal de1              :   std_logic;
signal de2              :   std_logic;
signal cursor0          :   std_logic;
signal cursor1          :   std_logic;
signal cursor2          :   std_logic;
signal interlaced_video :   std_logic;
signal max_scan_line    :   unsigned(4 downto 0);
signal adj_scan_line    :   unsigned(4 downto 0);

signal in_adj           :   std_logic;
signal sof1             :   std_logic;
signal sof2             :   std_logic;
signal eom_latched      :   std_logic;
signal eof_latched      :   std_logic;
signal first_scanline   :   std_logic;
signal extra_scanline   :   std_logic;

begin
    HSYNC <= hs; -- External HSYNC driven directly from internal signal
    VSYNC <= vs; -- External VSYNC driven directly from internal signal

    de0 <= '1' when h_display = '1' and v_display = '1' and r08_interlace(5 downto 4) /= "11" else '0';

    DE <= de0 when r08_interlace(5 downto 4) = "00" else
          de1 when r08_interlace(5 downto 4) = "01" else
          de2 when r08_interlace(5 downto 4) = "10" else
          '0';

    -- Cursor output generated combinatorially from the internal signal in
    -- accordance with the currently selected cursor mode
    cursor0 <= '0'                              when h_display = '0' or v_display = '0' else
                cursor_i                        when r10_cursor_mode = "00" else
                '0'                             when r10_cursor_mode = "01" else
                (cursor_i and field_counter(3)) when r10_cursor_mode = "10" else
                (cursor_i and field_counter(4));

    CURSOR <=   cursor0 when r08_interlace(7 downto 6) = "00" else
                cursor1 when r08_interlace(7 downto 6) = "01" else
                cursor2 when r08_interlace(7 downto 6) = "10" else
                '0';

    -- Synchronous register access.  Enabled on every clock.
    process(CLOCK,nRESET)
    begin
        if nRESET = '0' then
           -- Reset registers to defaults
            addr_reg <= (others => '0');
            r00_h_total <= (others => '0');
            r01_h_displayed <= (others => '0');
            r02_h_sync_pos <= (others => '0');
            r03_v_sync_width <= (others => '0');
            r03_h_sync_width <= (others => '0');
            r04_v_total <= (others => '0');
            r05_v_total_adj <= (others => '0');
            r06_v_displayed <= (others => '0');
            r07_v_sync_pos <= (others => '0');
            r08_interlace <= (others => '0');
            r09_max_scan_line_addr <= (others => '0');
            r10_cursor_mode <= (others => '0');
            r10_cursor_start <= (others => '0');
            r11_cursor_end <= (others => '0');
            r12_start_addr_h <= (others => '0');
            r13_start_addr_l <= (others => '0');
            r14_cursor_h <= (others => '0');
            r15_cursor_l <= (others => '0');

            DO <= (others => '0');
        elsif rising_edge(CLOCK) then
            if ENABLE = '1' then
                if R_nW = '1' then
                    -- Read
                    case addr_reg is
                    when "01100" =>
                        DO <= "00" & std_logic_vector(r12_start_addr_h);
                    when "01101" =>
                        DO <= std_logic_vector(r13_start_addr_l);
                    when "01110" =>
                        DO <= "00" & std_logic_vector(r14_cursor_h);
                    when "01111" =>
                        DO <= std_logic_vector(r15_cursor_l);
                    when "10000" =>
                        DO <= "00" & std_logic_vector(r16_light_pen_h);
                    when "10001" =>
                        DO <= std_logic_vector(r17_light_pen_l);
                    when others =>
                        DO <= (others => '0');
                    end case;
                elsif CLKEN_CPU = '1' then
                    -- Write
                    if RS = '0' then
                        addr_reg <= DI(4 downto 0);
                    else
                        case addr_reg is
                        when "00000" =>
                            r00_h_total <= unsigned(DI);
                        when "00001" =>
                            r01_h_displayed <= unsigned(DI);
                        when "00010" =>
                            r02_h_sync_pos <= unsigned(DI);
                        when "00011" =>
                            r03_v_sync_width <= unsigned(DI(7 downto 4));
                            r03_h_sync_width <= unsigned(DI(3 downto 0));
                        when "00100" =>
                            r04_v_total <= unsigned(DI(6 downto 0));
                        when "00101" =>
                            r05_v_total_adj <= unsigned(DI(4 downto 0));
                        when "00110" =>
                            r06_v_displayed <= unsigned(DI(6 downto 0));
                        when "00111" =>
                            r07_v_sync_pos <= unsigned(DI(6 downto 0));
                        when "01000" =>
                            r08_interlace <= DI(7 downto 0);
                        when "01001" =>
                            r09_max_scan_line_addr <= unsigned(DI(4 downto 0));
                        when "01010" =>
                            r10_cursor_mode <= DI(6 downto 5);
                            r10_cursor_start <= unsigned(DI(4 downto 0));
                        when "01011" =>
                            r11_cursor_end <= unsigned(DI(4 downto 0));
                        when "01100" =>
                            r12_start_addr_h <= unsigned(DI(5 downto 0));
                        when "01101" =>
                            r13_start_addr_l <= unsigned(DI(7 downto 0));
                        when "01110" =>
                            r14_cursor_h <= unsigned(DI(5 downto 0));
                        when "01111" =>
                            r15_cursor_l <= unsigned(DI(7 downto 0));
                        when others =>
                            null;
                        end case;
                    end if;
                end if;
            end if;
        end if;
    end process; -- registers

    -- TODO: Review the below two expressions, as the VGA mode criteria should really be the same

    -- Normally the max scan line is r09_max_scan_line_addr, with two exceptions
    -- In VGA mode we add one so the mode 7 18 becomes 19 (giving 20 rows per character)
    -- In interlace sync + video mode we mask off the LSB

    max_scan_line <= r09_max_scan_line_addr + 1               when VGA = '1'                        else
                     r09_max_scan_line_addr(4 downto 1) & '0' when r08_interlace(1 downto 0) = "11" else
                     r09_max_scan_line_addr;

    -- Normally the adjust scan line is r05_v_total_adj, with one exception
    -- In VGA Mode we add two so the Mode7 value of 2 becomes 4 (giving 31 * 20 + 4 = 624 lines)
    adj_scan_line <= r05_v_total_adj + 2 when r08_interlace(1 downto 0) = "11" and VGA = '1'  else
                     r05_v_total_adj;


    -- Horizontal, vertical and address counters
    process(CLOCK,nRESET)
    variable ma_row_start : unsigned(13 downto 0);
    variable ma_row_next  : unsigned(13 downto 0);
    begin
        if nRESET = '0' then
            -- H
            h_counter <= (others => '0');
            h_display <= '0';

            -- V
            line_counter <= (others => '0');
            vadjust_counter <= (others => '0');
            row_counter <= (others => '0');
            v_display <= '0';

            -- Fields (cursor flash)
            field_counter <= (others => '0');

            -- Addressing
            ma_row_start := (others => '0');
            ma_row_next  := (others => '0');
            ma_i <= (others => '0');

            -- End of frame logic
            sof1 <= '0';
            sof2 <= '0';
            in_adj <= '0';
            eom_latched <= '0';
            eof_latched <= '0';
            first_scanline <= '0';
            extra_scanline <= '0';

        elsif rising_edge(CLOCK) then
            if CLKEN = '1' then

                if h_counter = r01_h_displayed then
                    ma_row_next := ma_i;
                end if;

                -- H Display Enable logic (lags by one clock cycle)
                if h_counter = r01_h_displayed or h_counter = r00_h_total then
                    h_display <= '0';
                elsif h_counter = 0 then
                    h_display <= '1';
                end if;

                -- V Display Enable logic (lags by one clock cycle)
                --
                -- JSBEEB contains this comment concerning R6 hit:
                --    The Hitachi 6845 will notice this equality at any character,
                --    including in the middle of a scanline.
                if row_counter = r06_v_displayed and first_scanline = '0' and v_display = '1' then
                    -- Drop v_display
                    v_display <= '0';
                    -- Surprisingly, the odd/even flag and field counter are updated based on R6
                    -- i.e. Both cursor blink and interlace cease if R6 > R4.
                    -- https://github.com/mattgodbolt/jsbeeb/blob/main/video.js#L641
                    -- Increment field counter
                    field_counter <= field_counter + 1;
                end if;

                -- Horizontal counter increments on each clock, wrapping at h_total
                if h_counter = r00_h_total then
                    -- h_total reached
                    h_counter <= (others => '0');

                    -- In vertical adjust, start incrementing the vadjust counter,
                    -- everything else is the same

                    if in_adj = '1' then
                        vadjust_counter <= vadjust_counter + 1;
                    end if;

                    first_scanline <= '0';

                    if eof_latched = '1' and (r08_interlace(0) = '0' or field_counter(0) = '0' or extra_scanline = '1') then

                        line_counter <= (others => '0');
                        vadjust_counter <= (others => '0');

                        -- Address is loaded from start address register at the top of
                        -- each field and the row counter is reset
                        ma_row_start := r12_start_addr_h & r13_start_addr_l;
                        ma_row_next  := r12_start_addr_h & r13_start_addr_l;
                        row_counter <= (others => '0');
                        v_display <= '1';

                        -- Reset the in extra time flag
                        in_adj <= '0';
                        eom_latched <= '0';
                        eof_latched <= '0';
                        first_scanline <= '1';

                        -- Latch odd field so it's stable for the whole field
                        odd_field <= field_counter(0);

                    elsif line_counter = max_scan_line then
                        -- Scan line counter increments, wrapping at max_scan_line_addr
                        -- Next character row
                        line_counter <= (others => '0');
                        -- On all other character rows within the field the row start address is
                        -- increased by h_displayed and the row counter is incremented
                        ma_row_start := ma_row_next;
                        row_counter <= row_counter + 1;
                    else
                        -- Next scan line.  Count in twos in interlaced sync+video mode
                        if r08_interlace(1 downto 0) = "11" and VGA = '0' then
                            line_counter <= line_counter + 2;
                            line_counter(0) <= '0'; -- Force to even
                        else
                            line_counter <= line_counter + 1;
                        end if;

                    end if;

                    --  extra_scanline records that an extra scanline was added to the field
                    if eof_latched = '1' and r08_interlace(0) = '1' and field_counter(0) = '1' and extra_scanline = '0' then
                        extra_scanline <= '1';
                    else
                        extra_scanline <= '0';
                    end if;

                    -- Memory address preset to row start at the beginning of each
                    -- scan line
                    ma_i <= ma_row_start;
                else
                    -- Increment horizontal counter
                    h_counter <= h_counter + 1;
                    -- Increment memory address
                    ma_i <= ma_i + 1;
                end if;

                -- Two clocks after the start of frame, detect the end of frae
                -- (i.e. on last scanline including the vertical adjust, which
                -- may be zero)
                if sof2 = '1' then
                    if eom_latched = '1' then
                        if vadjust_counter = adj_scan_line then
                            eof_latched <= '1';
                        else
                            in_adj <= '1';
                        end if;
                    end if;
                end if;

                -- One clock after the start of frame, detect the end of main
                -- (i.e. on last scanline in last row)
                if sof1 = '1' then
                    if line_counter = max_scan_line and row_counter = r04_v_total then
                        eom_latched <= '1';
                    end if;
                end if;

                -- Maintain start of frame state
                -- (sof1 is usually when C0=1 and sof2 is usually when C0=2)
                sof2 <= sof1;
                if h_counter = 0 then
                    sof1 <= '1';
                else
                    sof1 <= '0';
                end if;

            end if;
        end if;
    end process;

    -- H Sync Generation
    --
    -- Note: r03_h_sync_width should have the following effect:
    --       0 => no hsync
    --       1 => hsync lasting 1 character
    --       2 => vsync lasting 2 characters
    --       ...
    --       15 => hsync lasting 15 characters
    --
    -- Changing R2 during HSYNC does not retrigger HSYNC
    -- Changing R3 during HSYNC does extend (or overflow) HSYNC
    -- multiple HSYNCs can happen on a line, but there will be a gap between them
    -- R3=0 => no HSYNC

    process(CLOCK,nRESET)
    begin
        if nRESET = '0' then
            hs <= '0';
            h_sync_counter <= (others => '0');
        elsif rising_edge(CLOCK) then
            if CLKEN = '1' then
                if hs = '0' then
                    if h_counter = r02_h_sync_pos - 1 and r03_h_sync_width /= 0 then
                        hs <= '1';
                    end if;
                    h_sync_counter <= x"1";
                else
                    if h_sync_counter = r03_h_sync_width then
                        hs <= '0';
                    end if;
                    h_sync_counter <= h_sync_counter + 1;
                end if;
            end if;
        end if;
    end process;

    -- V Sync Generation
    --
    -- Note: r03_v_sync_width should have the following effect:
    --       0 => vsync lasting 16 lines
    --       1 => vsync lasting 1 line
    --       2 => vsync lasting 2 lines
    --       ...
    --       15 => vsync lasting 15 lines
    --
    -- Note: Measurements on a real beeb confirm:
    --       even vsync is aligned with the start of the active display
    --       odd vsync is delayed by exactly half a scan line
    --
    -- triggered immediately when C4=R7 (irrespective of h_counter)
    -- possible to generate several VSYNCs in a frame
    -- can only generate one VSYNC per row
    -- vsync counter increments on C0=0
    -- on vsync, vdisplay => 0
    -- R3=0 => 16 lines
    -- ??? what happens if R3 changes during vsync

    row_counter_next <= (others => '0') when h_counter = r00_h_total and eof_latched = '1' and (r08_interlace(0) = '0' or field_counter(0) = '0' or extra_scanline = '1') else
                        row_counter + 1 when h_counter = r00_h_total and line_counter = max_scan_line else
                        row_counter;

    vs_hit <= '1' when row_counter_next = r07_v_sync_pos else '0';

    -- Generate an even vsync that is aligned to h_counter = 0
    process(CLOCK,nRESET)
    begin
        if nRESET = '0' then
            vs_even <= '0';
            v_sync_counter <= (others => '0');
        elsif rising_edge(CLOCK) then
            if CLKEN = '1' then
                if vs_hit = '1' and vs_hit_last = '0' then
                    vs_even <= '1';
                    v_sync_counter <= x"1";
                elsif h_counter = r00_h_total then
                    if  v_sync_counter = r03_v_sync_width then
                        vs_even <= '0';
                    end if;
                    v_sync_counter <= v_sync_counter + 1;
                end if;
                vs_hit_last <= vs_hit;
            end if;
        end if;
    end process;

    -- Generate an odd vsync that is delayed by half a line
    process(CLOCK)
    begin
        if rising_edge(CLOCK) then
            if CLKEN = '1' then
                if h_counter = ("0" & r00_h_total(7 downto 1)) then
                    vs_odd <= vs_even;
                end if;
            end if;
        end if;
    end process;

    -- Select between vs_odd and vs_even based on interlace state
    vs <= vs_odd when r08_interlace(0) = '1' and VGA = '0' and odd_field = '0' else vs_even;

    -- Address generation
    process(CLOCK,nRESET)
    begin
        if nRESET = '0' then
            RA <= (others => '0');
            MA <= (others => '0');
        elsif rising_edge(CLOCK) then
            if CLKEN_ADR = '1' then
                -- On the Read 6845 you don't see glitches on RA0 when writing r08
                -- so mimic this by latching the relevant r08 state once per line.
                -- This is probably done differently on the real hardware. I suspect
                -- the replacement of line_counter(0) with odd_field is done
                -- upstream as part of the line counter logic, and then when comparing
                -- to the max scanline, the LSB is masked off. I had a got at implementing
                -- this, but it got messy.
                if h_counter = r00_h_total then
                    if r08_interlace(1 downto 0) = "11" and VGA = '0' then
                        interlaced_video <= '1';
                    else
                        interlaced_video <= '0';
                    end if;
                end if;
                -- Character row address is just the scan line counter delayed by
                -- one clock to line up with the syncs.
                if interlaced_video = '1' then
                    RA(0) <= odd_field;
                else
                    RA(0) <= line_counter(0) xor VGA;
                end if;
                RA(4 downto 1) <= std_logic_vector(line_counter(4 downto 1));
                -- Internal memory address delayed by one cycle as well
                MA <= std_logic_vector(ma_i);
            end if;
        end if;
    end process;

    -- Cursor control
    process(CLOCK,nRESET)
    variable cursor_line : std_logic;
    begin
        -- Internal cursor enable signal delayed by 1 clock to line up
        -- with address outputs
        if nRESET = '0' then
            cursor_i <= '0';
            cursor_line := '0';
        elsif rising_edge(CLOCK) then
            if CLKEN = '1' then
                if ma_i = r14_cursor_h & r15_cursor_l then
                    if line_counter = 0 then
                        -- Suppress wrap around if last line is > max scan line
                        cursor_line := '0';
                    end if;
                    if line_counter = r10_cursor_start and r10_cursor_start <= r11_cursor_end then
                        -- First cursor scanline
                        cursor_line := '1';
                    end if;

                    -- Cursor output is asserted within the current cursor character
                    -- on the selected lines only
                    cursor_i <= cursor_line;

                    if line_counter = r11_cursor_end then
                        -- Last cursor scanline
                        cursor_line := '0';
                    end if;
                else
                    -- Cursor is off in all character positions apart from the
                    -- selected one
                    cursor_i <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Light pen capture
    process(CLOCK,nRESET)
    begin
        if nRESET = '0' then
            lpstb_i <= '0';
            r16_light_pen_h <= (others => '0');
            r17_light_pen_l <= (others => '0');
        elsif rising_edge(CLOCK) then
            if CLKEN = '1' then
                -- Register light-pen strobe input
                lpstb_i <= LPSTB;

                if LPSTB = '1' and lpstb_i = '0' then
                    -- Capture address on rising edge
                    r16_light_pen_h <= ma_i(13 downto 8);
                    r17_light_pen_l <= ma_i(7 downto 0);
                end if;
            end if;
        end if;
    end process;

    -- Delayed CURSOR and DE (selected by R08)
    process(CLOCK,nRESET)
    begin
        if rising_edge(CLOCK) then
            if CLKEN = '1' then
                de1     <= de0;
                de2     <= de1;
                cursor1 <= cursor0;
                cursor2 <= cursor1;
            end if;
        end if;
    end process;

    test(0) <= '1' when CLKEN_CPU = '1' and ENABLE = '1' and R_nW = '0' else '0';
    test(1) <= '1' when                     ENABLE = '1' and R_nW = '0' else '0';
    test(2) <= '1' when CLKEN_CPU = '1' and ENABLE = '1' and R_nW = '0' and addr_reg = "00000" else '0';
    test(3) <= '1' when                     ENABLE = '1' and R_nW = '0' and addr_reg = "00000" else '0';

end architecture;
