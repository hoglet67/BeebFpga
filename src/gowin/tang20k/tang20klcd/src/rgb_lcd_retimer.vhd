-- BBC Master / BBC B for the Tang Nano 20K
--
-- Copright (c) 2025 Dominic Beesley
-- Copright (c) 2025 David Banks
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
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use work.common.all;

entity rgb_lcd_retimer is
    generic (
        G_PX_IN_WIDTH    : natural := 4;
        G_PX_OUT_WIDTH   : natural := 6
    );
    port(
        clock_48        : in std_logic;

        video_r         : in std_logic_vector(G_PX_IN_WIDTH-1 downto 0);
        video_g         : in std_logic_vector(G_PX_IN_WIDTH-1 downto 0);
        video_b         : in std_logic_vector(G_PX_IN_WIDTH-1 downto 0);
        video_hs        : in std_logic;
        video_vs        : in std_logic;
        video_de        : in std_logic;
        video_pclken    : in std_logic;

        lcd_hs          : out std_logic;
        lcd_vs          : out std_logic;
        lcd_de          : out std_logic;
        lcd_bl          : out std_logic;
        lcd_dclk        : out std_logic;

        lcd_r           : out std_logic_vector(G_PX_OUT_WIDTH-1 downto 0);
        lcd_g           : out std_logic_vector(G_PX_OUT_WIDTH-1 downto 0);
        lcd_b           : out std_logic_vector(G_PX_OUT_WIDTH-1 downto 0)
    );
end entity;

architecture rtl of rgb_lcd_retimer is

    constant LCD_FIFO_LEN  : natural := 12;

    type t_pix_arr is array (natural range <>) of std_logic_vector(G_PX_IN_WIDTH-1 downto 0);

    signal sr_fifo_lcd_r        :  t_pix_arr(0 to LCD_FIFO_LEN-1);
    signal sr_fifo_lcd_g        :  t_pix_arr(0 to LCD_FIFO_LEN-1);
    signal sr_fifo_lcd_b        :  t_pix_arr(0 to LCD_FIFO_LEN-1);
    signal sr_fifo_lcd_de       :  std_logic_vector(0 to LCD_FIFO_LEN-1);

    -- return left-justified portion of v
    function RESIZEU(
        v : unsigned;
        SIZE : natural
        ) return unsigned is
    variable res : unsigned(SIZE-1 downto 0);
    begin
        if SIZE <= v'length then
            res := v(v'high downto v'high-SIZE+1);
        else
            -- left most bits
            for I in SIZE-1 downto SIZE-v'length loop
                res(I) := v(v'low + I - SIZE + v'length);
            end loop;
            -- repeat last bit
            for I in SIZE-v'length-1 downto 0 loop
                res(I) := v(v'low);
            end loop;
        end if;
        return res;
    end function;


    function SUM4(
        signal sr           : in t_pix_arr
    ) return std_logic_vector is
    variable acc : unsigned(G_PX_IN_WIDTH+2-1 downto 0);
    begin
        
        acc := (others => '0');
        for I in LCD_FIFO_LEN-4 to LCD_FIFO_LEN-1 loop
            acc := acc + unsigned(sr(I));
        end loop;

        return  std_logic_vector(RESIZEU(acc, G_PX_OUT_WIDTH));

    end function;

    signal ctr_bl : unsigned(10 downto 0);

    constant MAXPIXELSPERLIN : natural := 2048;
    constant MAXLINES : natural := 1024;

    constant PIXELS_H : natural := 480;
    constant PIXELS_V : natural := 272;
    constant H_FUDGE  : natural := 2;

    -- horizontal blanking regs
    signal r_h_ctr : unsigned(numbits(MAXPIXELSPERLIN)-1 downto 0) := (others => '0');
    signal r_h_min_de : unsigned(numbits(MAXPIXELSPERLIN)-1 downto 0) := (others => '1');
    signal r_h_de_offset : unsigned(numbits(MAXPIXELSPERLIN)-1 downto 0) := (others => '1');
    signal r_v_ctr : unsigned(numbits(MAXLINES)-1 downto 0);
    signal r_v_min_de : unsigned(numbits(MAXLINES)-1 downto 0);
    signal r_v_de_offset : unsigned(numbits(MAXLINES)-1 downto 0);
    signal r_v_de_offset2 : unsigned(numbits(MAXLINES)-1 downto 0);

    signal r_vs_clken : std_logic;
    signal r_hs_clken : std_logic;
    signal r_had_de_line : std_logic := '0';
    signal r_had_de_field : std_logic := '0';
    signal r_output_clken : std_logic;

begin

    -- LCD backlight PWM 
    p_bl:process(clock_48)
    begin
        if rising_edge(clock_48) then
            ctr_bl <= ctr_bl - 1;
        end if;
    end process;

    lcd_bl <= ctr_bl(ctr_bl'high) and ctr_bl(ctr_bl'high-1) ; -- 25% duty

    -- pixels in from core's 12/16MHz pixel clock
    -- stuff into a fifo that is running at 48MHz and 
    -- grab back out at the LCD's preferred rate 
    p_lcd_pix:process(clock_48)
    begin
        if rising_edge(clock_48) then

            for i in LCD_FIFO_LEN-1 downto 1 loop
                sr_fifo_lcd_r(I) <= sr_fifo_lcd_r(I - 1);
                sr_fifo_lcd_g(I) <= sr_fifo_lcd_g(I - 1);
                sr_fifo_lcd_b(I) <= sr_fifo_lcd_b(I - 1);
                sr_fifo_lcd_de(I) <= sr_fifo_lcd_de(I - 1);
            end loop;

            if video_pclken = '1' then

                sr_fifo_lcd_r(0) <= video_r;
                sr_fifo_lcd_g(0) <= video_g;
                sr_fifo_lcd_b(0) <= video_b;
                sr_fifo_lcd_de(0) <= video_DE;

                lcd_hs <= not video_hs;
                lcd_vs <= not video_vs;

            end if;           
        end if;
    end process;


    -- HS: once per line pulse - 1 output pixel wide
    -- VS: once per 50hz field - 1 output pixel wide
    p_hs:process(clock_48, r_output_clken)
    -- gate out spurious, we don't care so much where but how often, don't
    variable v_prev_hsync : unsigned(3 downto 0); 
    variable v_prev_vsync : unsigned(3 downto 0); 
    begin
        if rising_edge(clock_48) and r_output_clken = '1' then
            r_hs_clken <= '0';
            r_vs_clken <= '0';
            if video_hs = '1' then
                if to_integer(v_prev_hsync) = 0 then
                    r_hs_clken <= '1';
                    -- look for field
                    if video_vs = '1' then
                        if to_integer(v_prev_vsync) = 0 then
                            r_vs_clken <= '1';
                        end if;
                        v_prev_vsync := (others => '1');
                    else
                        if to_integer(v_prev_vsync) > 0 then
                            v_prev_vsync := v_prev_vsync - 1;
                        end if;
                    end if;
                end if;
                v_prev_hsync := (others => '1');
            else
                if to_integer(v_prev_hsync) > 0 then
                    v_prev_hsync := v_prev_hsync - 1;
                end if;
            end if;
        end if;
    end process;

    
    p_measure_offset:process(clock_48, r_output_clken)
    variable v_DE : std_logic;
    variable v_reset_h_ctr : boolean;
    begin
        if rising_edge(clock_48) and r_output_clken = '1' then

            v_DE := or_reduce(sr_fifo_lcd_de(LCD_FIFO_LEN-4 to LCD_FIFO_LEN-1));

            v_reset_h_ctr := false;

            if r_vs_clken = '1' then
                -- end of frame calc new de offset
                if r_had_de_field = '1' then
                    r_h_de_offset <= r_h_min_de + H_FUDGE;
                    r_v_de_offset <= r_v_min_de;
                    r_v_de_offset2 <= r_v_de_offset;
                end if;
                r_had_de_field <= '0';
                r_h_min_de <= (others => '1');
                v_reset_h_ctr := true;
                r_had_de_line <= '0';
                r_v_ctr <= (others => '0');
            elsif r_hs_clken = '1' then
                v_reset_h_ctr := true;
                r_had_de_line <= '0';
                r_v_ctr <= r_v_ctr + 1;
            elsif r_had_de_line = '0' then
                if v_DE = '1' then
                    if r_h_min_de > r_h_ctr then
                        r_h_min_de <= r_h_ctr;
                    end if;
                    r_had_de_line <= '1';
                    if r_had_de_field = '0' then
                        r_had_de_field <= '1';
                        r_v_min_de <= r_v_ctr;
                    end if;
                end if;
            end if;
            if v_reset_h_ctr then
                r_h_ctr <= (others => '0');
            else
                r_h_ctr <= r_h_ctr + 1;
            end if;
        end if;
    end process;

    
    -- form the output clock signal for the lcd and align with our pixel output
    p_lcd_pixck:process(clock_48)
    variable v_lcd_ck : std_logic_vector(3 downto 0) := "1100";
    begin
        if rising_edge(clock_48) then            
            r_output_clken <= '0';
            if v_lcd_ck = "1100" then
                r_output_clken <= '1';
            end if;
            lcd_dclk <= v_lcd_ck(0);
            v_lcd_ck := v_lcd_ck(0) & v_lcd_ck(v_lcd_ck'high downto 1);
        end if;
    end process;

    -- this process reforms the pixels from a 16 or 12 MHz rate to a fixed rate 
    -- of 12 MHz. If 16->12MHZ then simple 3:4 pixel resampling will occur 
    p_outout:process(clock_48)
    begin
        if rising_edge(clock_48) and r_output_clken = '1' then
            lcd_r <= SUM4(sr_fifo_lcd_r);
            lcd_g <= SUM4(sr_fifo_lcd_g);
            lcd_b <= SUM4(sr_fifo_lcd_b);


--            if r_h_ctr >= r_h_de_offset + 64 and r_h_ctr < r_h_de_offset + 416 then
--                lcd_g(G_PX_OUT_WIDTH-2) <= '1';
--            end if;
--
--            if r_v_ctr >= r_v_de_offset + 8 and r_v_ctr < r_v_de_offset + 264 then
--                lcd_b(G_PX_OUT_WIDTH-2) <= '1';
--            end if;
--            if or_reduce(sr_fifo_lcd_de(LCD_FIFO_LEN-4 to LCD_FIFO_LEN-1)) = '1' then 
--                lcd_de <= '1';
--            else
--                lcd_de <= '0';
--            end if;

            if (r_h_ctr >= r_h_de_offset and r_h_ctr < r_h_de_offset + PIXELS_H) and
               (r_v_ctr >= r_v_de_offset2 and r_v_ctr < r_v_de_offset2 + PIXELS_V) then
               lcd_de <= '1';
            else
               lcd_de <= '0';
            end if;

        end if;
    end process;




end architecture rtl;

