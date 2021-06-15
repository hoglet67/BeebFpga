-- BBC Master / BBC B for the Pynq Z2
--
-- Copright (c) 2021 David Banks
--
-- Based on previous work by Mike Stirling
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
-- Pynq Z2 top-level
--
-- (c) 2021 David Banks
-- (C) 2011 Mike Stirling

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
library UNISIM;
use UNISIM.Vcomponents.all;

-- Generic top-level entity for Pynq Z2 board
entity bbc_micro_pynqz2 is
    generic (
        IncludeAMXMouse    : boolean := false;
        IncludeSID         : boolean := true;
        IncludeMusic5000   : boolean := true;
        IncludeICEDebugger : boolean := true;
        IncludeCoPro6502   : boolean := true;
        IncludeCoProExt    : boolean := true;
        IncludeVideoNuLA   : boolean := true;
        IncludeMaster      : boolean := true
    );
    port (
        -- PMOD B
        clock              : in    std_logic;
        btn_reset          : in    std_logic;
        ps2_clk_io         : inout std_logic;
        ps2_data_io        : inout std_logic;
        sd_cs_n_o          : out   std_logic;
        sd_miso_i          : in    std_logic;
        sd_mosi_o          : out   std_logic;
        sd_sclk_o          : out   std_logic;

        -- LEDs
        led                : out   std_logic_vector(3 downto 0);

        -- Switches
        sw                 : in    std_logic_vector(1 downto 0);

        -- HDMI
        hdmi_n             : out   std_logic_vector(3 downto 0);
        hdmi_p             : out   std_logic_vector(3 downto 0);
        hdmi_scl           : inout std_logic;
        hdmi_sda           : inout std_logic;
        hdmi_cec           : inout std_logic;
        hdmi_hpdn          : in    std_logic;

        -- ICE Debugger
        avr_RxD            : in    std_logic;
        avr_TxD            : out   std_logic;

        -- PiTubeDirect connects to the Raspberry Pi Connector
        accel_io           : inout std_logic_vector(27 downto 0);

        -- External Keyboard connects to the Arduino Connector
        ext_keyb_led1      : out   std_logic;
        ext_keyb_led2      : out   std_logic;
        ext_keyb_led3      : out   std_logic;
        ext_keyb_1mhz      : out   std_logic;
        ext_keyb_en_n      : out   std_logic;
        ext_keyb_pa        : out   std_logic_vector(6 downto 0);
        ext_keyb_rst_n     : in    std_logic;
        ext_keyb_ca2       : in    std_logic;
        ext_keyb_pa7       : in    std_logic
        );
end entity;

architecture rtl of bbc_micro_pynqz2 is

-------------
-- Signals
-------------

    signal clk0            : std_logic;
    signal clk1            : std_logic;
    signal clk2            : std_logic;
    signal clk3            : std_logic;
    signal clk4            : std_logic;
    signal clkfb           : std_logic;
    signal clkfb_buf       : std_logic;
    signal clk100          : std_logic;

    signal hclk0            : std_logic;
    signal hclk1            : std_logic;
    signal hclk2            : std_logic;
    signal hclkfb           : std_logic;
    signal hclkfb_buf       : std_logic;

--  signal fx_clk_27       : std_logic;

    signal clock_16        : std_logic; -- for ICAP (flashreboot) only
    signal clock_27        : std_logic;
    signal clock_32        : std_logic;
    signal clock_48        : std_logic;
    signal clock_96        : std_logic;
    signal clock_135       : std_logic;
    signal clock_135_n     : std_logic;
    signal clock_avr       : std_logic;

    attribute S : string;
    attribute S of clock_avr : signal is "yes";
    attribute S of clock_27  : signal is "yes";
    attribute S of clock_32  : signal is "yes";
    attribute S of clock_96  : signal is "yes";

    signal audio_l         : std_logic_vector(15 downto 0);
    signal audio_r         : std_logic_vector(15 downto 0);
    signal powerup_reset_n : std_logic;
    signal hard_reset_n    : std_logic;
    signal hard_reset      : std_logic;
    signal reset_counter   : std_logic_vector(9 downto 0);
    signal RAM_A           : std_logic_vector(18 downto 0);
    signal RAM_Din         : std_logic_vector(7 downto 0);
    signal RAM_Dout        : std_logic_vector(7 downto 0);
    signal RAM_nWE         : std_logic;
    signal RAM_nOE         : std_logic;
    signal RAM_nCS         : std_logic;
    signal RAM_CS          : std_logic;
    signal RAM_WE          : std_logic;
    signal keyb_dip        : std_logic_vector(7 downto 0) := x"00";
    signal vid_mode        : std_logic_vector(3 downto 0) := "0001";
    signal vid_debug       : std_logic;
    signal m128_mode       : std_logic;
    signal copro_mode      : std_logic;
    signal aspect_wide     : std_logic;
    signal hdmi_aspect     : std_logic_vector(1 downto 0);
    signal hdmi_aspect_169 : std_logic;
    signal red             : std_logic_vector(3 downto 0);
    signal green           : std_logic_vector(3 downto 0);
    signal blue            : std_logic_vector(3 downto 0);
    signal hdmi_red        : std_logic_vector(3 downto 0);
    signal hdmi_green      : std_logic_vector(3 downto 0);
    signal hdmi_blue       : std_logic_vector(3 downto 0);
    signal hdmi_hsync      : std_logic;
    signal hdmi_vsync      : std_logic;
    signal hdmi_blank      : std_logic;
    signal hdmi_audio_en   : std_logic;
    signal hsync           : std_logic;
    signal vsync           : std_logic;
    signal hsync1          : std_logic;
    signal vsync1          : std_logic;
    signal hcnt            : std_logic_vector(9 downto 0);
    signal vcnt            : std_logic_vector(9 downto 0);
    signal ext_tube_r_nw   : std_logic;
    signal ext_tube_nrst   : std_logic;
    signal ext_tube_ntube  : std_logic;
    signal ext_tube_phi2   : std_logic;
    signal ext_tube_a      : std_logic_vector(6 downto 0);
    signal ext_tube_di     : std_logic_vector(7 downto 0);
    signal ext_tube_do     : std_logic_vector(7 downto 0);

    signal tdms_r          : std_logic_vector(9 downto 0);
    signal tdms_g          : std_logic_vector(9 downto 0);
    signal tdms_b          : std_logic_vector(9 downto 0);

    signal config          : std_logic_vector(9 downto 0);

    signal caps_led        : std_logic;
    signal shift_led       : std_logic;

begin

--------------------------------------------------------
-- BBC Micro Core
--------------------------------------------------------

    -- Format of Video
    -- Bit 1,0 select the video format
    --   00 - 15.625KHz SRGB
    --   01 - 31.250KHz VGA using the RGB2VGA Scan Doubler
    --   10 - 31.250KHz VGA using the Mist Scan Doubler
    --   11 - 31.250KHz VGA using the Mist Scan Doubler (Modes 0..6) and SAA5050 VGA (Mode 7)
    -- Bit 2 inverts hsync
    -- Bit 3 inverts vsync

    bbc_micro : entity work.bbc_micro_core
    generic map (
        IncludeAMXMouse    => IncludeAMXMouse,
        IncludeSID         => IncludeSID,
        IncludeMusic5000   => IncludeMusic5000,
        IncludeICEDebugger => IncludeICEDebugger,
        IncludeCoPro6502   => IncludeCoPro6502,
        IncludeCoProSPI    => false,
        IncludeCoProExt    => IncludeCoProExt,
        IncludeVideoNuLA   => IncludeVideoNuLA,
        UseOrigKeyboard    => false,
        UseT65Core         => not IncludeMaster,  -- select the 6502 for the Beeb
        UseAlanDCore       => IncludeMaster,      -- select the 65C02 for the Master
        OverrideCMOS       => false
        )
    port map (
        clock_27       => clock_27,
        clock_32       => clock_32,
        clock_48       => clock_48,
        clock_96       => clock_96,
        clock_avr      => clock_avr,
        hard_reset_n   => hard_reset_n,
        ps2_kbd_clk    => ps2_clk_io,
        ps2_kbd_data   => ps2_data_io,
        ps2_mse_clk    => open,
        ps2_mse_data   => open,
        ps2_swap       => '0',
        video_red      => red,
        video_green    => green,
        video_blue     => blue,
        video_vsync    => vsync,
        video_hsync    => hsync,
        audio_l        => audio_l,
        audio_r        => audio_r,
        ext_nOE        => RAM_nOE,
        ext_nWE        => RAM_nWE,
        ext_nCS        => RAM_nCS,
        ext_A          => RAM_A,
        ext_Dout       => RAM_Dout,
        ext_Din        => RAM_Din,
        SDMISO         => sd_miso_i,
        SDSS           => sd_cs_n_o,
        SDCLK          => sd_sclk_o,
        SDMOSI         => sd_mosi_o,
        caps_led       => caps_led,
        shift_led      => shift_led,
        keyb_dip       => keyb_dip,
        vid_mode       => vid_mode,
        aspect_wide    => aspect_wide,
        joystick1      => "11111",
        joystick2      => "11111",
        avr_reset      => hard_reset,
        avr_RxD        => avr_RxD,
        avr_TxD        => avr_TxD,
        cpu_addr       => open,
        m128_mode      => m128_mode,
        copro_mode     => copro_mode,
        p_spi_ssel     => '0',
        p_spi_sck      => '0',
        p_spi_mosi     => '0',
        p_spi_miso     => open,
        p_irq_b        => open,
        p_nmi_b        => open,
        p_rst_b        => open,
        ext_tube_r_nw  => ext_tube_r_nw,
        ext_tube_nrst  => ext_tube_nrst,
        ext_tube_ntube => ext_tube_ntube,
        ext_tube_phi2  => ext_tube_phi2,
        ext_tube_a     => ext_tube_a,
        ext_tube_di    => ext_tube_di,
        ext_tube_do    => ext_tube_do,
        test           => open,

        -- original keyboard
        ext_keyb_led1  => ext_keyb_led1,
        ext_keyb_led2  => ext_keyb_led2,
        ext_keyb_led3  => ext_keyb_led3,
        ext_keyb_1mhz  => ext_keyb_1mhz,
        ext_keyb_en_n  => ext_keyb_en_n,
        ext_keyb_pa    => ext_keyb_pa,
        ext_keyb_rst_n => ext_keyb_rst_n,
        ext_keyb_ca2   => ext_keyb_ca2,
        ext_keyb_pa7   => ext_keyb_pa7,

        -- config
        config        => config

    );

--------------------------------------------------------
-- Clock Generation
--------------------------------------------------------


    -- 100MHz to 96/48/32 MHz

    inst_PLL1 : PLL_BASE
        generic map (
            BANDWIDTH            => "OPTIMIZED",
            CLK_FEEDBACK         => "CLKFBOUT",
            COMPENSATION         => "DCM2PLL",
            DIVCLK_DIVIDE        => 1,
            CLKFBOUT_MULT        => 32,        -- PLL 864MHz
            CLKFBOUT_PHASE       => 0.000,
            CLKOUT0_DIVIDE       => 9,         -- 864 / 9 = 96MHz
            CLKOUT0_PHASE        => 0.000,
            CLKOUT0_DUTY_CYCLE   => 0.500,
            CLKOUT1_DIVIDE       => 18,        -- 864 / 18 = 48MHz
            CLKOUT1_PHASE        => 0.000,
            CLKOUT1_DUTY_CYCLE   => 0.500,
            CLKOUT2_DIVIDE       => 27,        -- 864 / 27 = 32MHz
            CLKOUT2_PHASE        => 0.000,
            CLKOUT2_DUTY_CYCLE   => 0.500,
            CLKOUT3_DIVIDE       => 36,        -- 864 / 36 = 24MHz
            CLKOUT3_PHASE        => 0.000,
            CLKOUT3_DUTY_CYCLE   => 0.500,
            CLKOUT4_DIVIDE       => 54,        -- 864 / 54 = 16MHz
            CLKOUT4_PHASE        => 0.000,
            CLKOUT4_DUTY_CYCLE   => 0.500,
            CLKIN_PERIOD         => 37.037,
            REF_JITTER           => 0.010
            )
        port map (
            -- Output clocks
            CLKFBOUT            => clkfb,
            CLKOUT0             => clk0,
            CLKOUT1             => clk1,
            CLKOUT2             => clk2,
            CLKOUT3             => clk3,
            CLKOUT4             => clk4,
            RST                 => '0',
            -- Input clock control
            CLKFBIN             => clkfb_buf,
            CLKIN               => clock
            );

    inst_clkfb_buf : BUFG
        port map (
            I => clkfb,
            O => clkfb_buf
            );

    inst_clk0_buf : BUFG
        port map (
            I => clk0,
            O => clock_96
            );

    inst_clk1_buf : BUFG
        port map (
            I => clk1,
            O => clock_48
            );

    inst_clk2_buf : BUFG
        port map (
            I => clk2,
            O => clock_32
            );

    inst_clk3_buf : BUFG
        port map (
            I => clk3,
            O => clock_avr
            );

    inst_clk4_buf : BUFG
        port map (
            I => clk4,
            O => clock_16
            );

    -- 27MHz for HDMI (and the alternative scan doubler)

    inst_PLL2 : PLL_BASE
        generic map (
            BANDWIDTH            => "OPTIMIZED",
            CLK_FEEDBACK         => "CLKFBOUT",
            COMPENSATION         => "DCM2PLL",
            DIVCLK_DIVIDE        => 1,
            CLKFBOUT_MULT        => 25,        -- PLL 675 MHz
            CLKFBOUT_PHASE       => 0.000,
            CLKOUT0_DIVIDE       => 25,        -- 675 / 25 = 27MHz
            CLKOUT0_PHASE        => 0.000,
            CLKOUT0_DUTY_CYCLE   => 0.500,
            CLKOUT1_DIVIDE       => 5,         -- 675 / 5 = 135MHz
            CLKOUT1_PHASE        => 0.000,
            CLKOUT1_DUTY_CYCLE   => 0.500,
            CLKOUT2_DIVIDE       => 5,         -- 675 / 5 = 135MHz (inverted)
            CLKOUT2_PHASE        => 180.000,
            CLKOUT2_DUTY_CYCLE   => 0.500,
            CLKIN_PERIOD         => 37.037,
            REF_JITTER           => 0.010
            )
        port map (
            -- Output clocks
            CLKFBOUT            => hclkfb,
            CLKOUT0             => hclk0,
            CLKOUT1             => hclk1,
            CLKOUT2             => hclk2,
            RST                 => '0',
            -- Input clock control
            CLKFBIN             => hclkfb_buf,
            CLKIN               => clock
            );


    inst_hclkfb_buf : BUFG
        port map (
            I => hclkfb,
            O => hclkfb_buf
            );

    inst_hclk0_buf : BUFG
        port map (
            I => hclk0,
            O => clock_27
            );

    inst_hclk1_buf : BUFG
        port map (
            I => hclk1,
            O => clock_135
            );

    inst_hclk2_buf : BUFG
        port map (
            I => hclk2,
            O => clock_135_n
            );

--------------------------------------------------------
-- Power Up Reset Generation
--------------------------------------------------------

    m128_mode <= '1' when IncludeMaster else '0';

    -- Generate a reliable power up reset and handle configuration mode
    reset_gen : process(clock_48)
    begin
        if rising_edge(clock_48) then
            if btn_reset = '1' then
                reset_counter <= (others => '0');
            elsif reset_counter(reset_counter'high) = '0' then
                reset_counter <= reset_counter + 1;
            end if;
            powerup_reset_n <= reset_counter(reset_counter'high);
            -- Configuration toggles
            -- Yellow 5 - HDMI audio/data on/off
            -- Yellow 6 - HDMI aspect: auto
            -- Yellow 7 - HDMI aspect: 4:3
            -- Yellow 8 - HDMI aspect: 16:9
            -- Yellow 9 - Int Co Pro on/off
            -- Yellow 0 - Video debug on/off
            if powerup_reset_n = '0' then
                hdmi_audio_en <= '1';
                hdmi_aspect <= "00";
                copro_mode <= sw(0);
                vid_debug <= sw(1);
            else
                if config(5) = '1' then
                    hdmi_audio_en <= not hdmi_audio_en;
                end if;
                if config(6) = '1' then
                    hdmi_aspect <= "00";
                end if;
                if config(7) = '1' then
                    hdmi_aspect <= "01";
                end if;
                if config(8) = '1' then
                    hdmi_aspect <= "10";
                end if;
                if config(9) = '1' then
                    copro_mode <= not copro_mode;
                end if;
                if config(0) = '1' then
                    vid_debug <= not vid_debug;
                end if;
            end if;
        end if;
    end process;

    hard_reset_n <= powerup_reset_n;
    hard_reset   <= not hard_reset_n;

--------------------------------------------------------
-- SRAM INTERFACE
--------------------------------------------------------

    RAM_CS <= not RAM_nCS;
    RAM_WE <= not RAM_nWE;

    sram : entity work.generic_ram
    generic map (
        ADDR_BITS => 19,
        DATA_BITS => 8
    )
    port map (
        clk  => clock_48,
        ena  => RAM_CS,
        wea  => RAM_WE,
        addr => RAM_A,
        din  => RAM_Din,
        dout => RAM_Dout
    );

--------------------------------------------------------
-- External tube connections
--------------------------------------------------------

    GenCoProExt: if IncludeCoProExt generate
    begin
        ext_tube_do  <= accel_io(25 downto 22) & accel_io(11 downto 8);
        accel_io(0)  <= 'Z';
        accel_io(1)  <= 'Z';
        accel_io(2)  <= ext_tube_a(1);
        accel_io(3)  <= ext_tube_a(2);
        accel_io(4)  <= ext_tube_nrst;
        accel_io(5)  <= 'Z'; -- reserved for ext_tube_a(3);
        accel_io(6)  <= 'Z';
        accel_io(7)  <= ext_tube_phi2;
        accel_io(11 downto 8) <= ext_tube_di(3 downto 0) when ext_tube_r_nw = '0' and ext_tube_phi2 = '1' else (others => 'Z');
        accel_io(12) <= 'Z';
        accel_io(13) <= 'Z';
        accel_io(14) <= 'Z'; -- Serial Tx
        accel_io(15) <= '1'; -- Serial Rx
        accel_io(16) <= 'Z';
        accel_io(17) <= ext_tube_ntube;
        accel_io(18) <= ext_tube_r_nw;
        accel_io(19) <= 'Z';
        accel_io(20) <= 'Z';
        accel_io(21) <= 'Z';
        accel_io(25 downto 22) <= ext_tube_di(7 downto 4) when ext_tube_r_nw = '0' and ext_tube_phi2 = '1' else (others => 'Z');
        accel_io(26) <= 'Z';
        accel_io(27) <= ext_tube_a(0);
    end generate;

    GenCoProNotExt: if not IncludeCoProExt generate
    begin
        ext_tube_do  <= x"FE";
        accel_io     <= (others => 'Z');
    end generate;

--------------------------------------------------------
-- HDMI
--------------------------------------------------------

    -- Recreate the video sync/blank signals that match standard HDTV 720x576p
    --
    -- Modeline "720x576 @ 50hz"  27    720   732   796   864   576   581   586   625
    --
    -- Hcnt is set to 0 on the trailing edge of hsync from the Beeb core
    -- so the H constants below need to be offset by 864-796=68
    --
    -- Vcnt is set to 0 on the trailing edge of vsync from the Beeb core
    -- so the V constants below need to be offset by 625-586=39
    --
    -- This only works because the Beeb core is generating 32us lines
    --
    -- The hdmidataencode module inserts a two 32 pixel data packets after the
    -- first edge of hsync. The hsync pluse + back porch needs to be at least
    -- this width. There are also min requirements on the size of control
    -- islands of 12 pixels.

    process(clock_27)
        variable voffset : integer;
        variable vsize   : integer;
    begin
        if rising_edge(clock_27) then
            hsync1 <= hsync;
            if hsync1 = '0' and hsync = '1' then
                hcnt <= (others => '0');
                vsync1 <= vsync;
                if vsync1 = '0' and vsync = '1' then
                    vcnt <= (others => '0');
                else
                    vcnt <= vcnt + 1;
                end if;
            else
                hcnt <= hcnt + 1;
            end if;
            if hdmi_audio_en = '1' then
                voffset := 39;
                vsize   := 576;
            else
                voffset := 55;
                vsize   := 540;
            end if;
            if hcnt < 68 or hcnt >= 68 + 720 or vcnt < voffset or vcnt >= voffset + vsize then
                hdmi_blank <= '1';
                hdmi_red   <= (others => '0');
                hdmi_green <= (others => '0');
                hdmi_blue  <= (others => '0');
            else
                hdmi_blank <= '0';
                hdmi_red   <= red;
                if vid_debug = '1' and (hcnt = 68 or hcnt = 68 + 719 or vcnt = voffset or vcnt = voffset + vsize - 1) then
                    hdmi_green <= (others => '1');
                else
                    hdmi_green <= green;
                end if;
                hdmi_blue  <= blue;
            end if;
            if hcnt >= 732 + 68 then -- 800
                hdmi_hsync <= '0';
                if vcnt >= 581 + 39 then -- 620
                    hdmi_vsync <= '0';
                else
                    hdmi_vsync <= '1';
                end if;
            else
                hdmi_hsync <= '1';
            end if;
        end if;
    end process;

    hdmi_aspect_169 <= '0' when hdmi_aspect = "01" else -- always 4:3
                       '1' when hdmi_aspect = "10" else -- always 16:9
                       aspect_wide;                     -- 4:3 in modes 0-6;
                                                        -- 16:9 i mode 7

    inst_hdmi: entity work.hdmi
    generic map (
      FREQ => 27000000,  -- pixel clock frequency
      FS   => 48000,     -- audio sample rate - should be 32000, 44100 or 48000
      CTS  => 27000,     -- CTS = Freq(pixclk) * N / (128 * Fs)
      N    => 6144       -- N = 128 * Fs /1000,  128 * Fs /1500 <= N <= 128 * Fs /300
      --FS   => 32000,   -- audio sample rate - should be 32000, 44100 or 48000
      --CTS  => 27000,   -- CTS = Freq(pixclk) * N / (128 * Fs)
      --N    => 4096     -- N = 128 * Fs /1000,  128 * Fs /1500 <= N <= 128 * Fs /300
    )
    port map (
      -- clocks
      I_CLK_PIXEL      => clock_27,
      -- components
      I_R              => hdmi_red   & "0000",
      I_G              => hdmi_green & "0000",
      I_B              => hdmi_blue  & "0000",
      I_BLANK          => hdmi_blank,
      I_HSYNC          => hdmi_hsync,
      I_VSYNC          => hdmi_vsync,
      I_ASPECT_169     => hdmi_aspect_169,
      -- PCM audio
      I_AUDIO_ENABLE   => hdmi_audio_en,
      I_AUDIO_PCM_L    => audio_l,
      I_AUDIO_PCM_R    => audio_r,
      -- TMDS parallel pixel synchronous outputs (serialize LSB first)
      O_RED            => tdms_r,
      O_GREEN          => tdms_g,
      O_BLUE           => tdms_b
      );

    inst_hdmi_out_xilinx: entity work.hdmi_out_xilinx
    port map (
        clock_pixel_i  => clock_27,    -- (x1)
        clock_tdms_i   => clock_135,   -- (x5)
        clock_tdms_n_i => clock_135_n, -- (x5)
        red_i          => tdms_r,
        green_i        => tdms_g,
        blue_i         => tdms_b,
        tmds_out_p     => hdmi_p,
        tmds_out_n     => hdmi_n
   );

--------------------------------------------------------
-- Miscellaneous outputs
--------------------------------------------------------

    led(0) <= btn_reset;
    led(1) <= caps_led;
    led(2) <= shift_led;
    led(3) <= copro_mode;

    hdmi_scl <= 'Z';
    hdmi_sda <= 'Z';
    hdmi_cec <= 'Z';

end architecture;
