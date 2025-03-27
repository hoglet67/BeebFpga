-- BBC Master / BBC B for the Tang Primer 20K
--
-- Copright (c) 2025 Dominic Beesley
-- Copright (c) 2025 David Banks
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library work;
use work.board_config_pack.all;
use work.sample_rate_converter_pkg.all;

entity bbc_micro_tang20k is
    generic (
        IncludeMaster      : boolean := false; -- if both included, the CPU is the AlanD 65C02
        IncludeBeeb        : boolean := true; -- and btn1 can toggle between the ROM images

        IncludeAMXMouse    : boolean := false;
        IncludeSPISD       : boolean := true;
        IncludeSID         : boolean := true;
        IncludeMusic5000       : boolean := true;
        IncludeMusic5000Filter : boolean := true; -- Music 5000 Low Pass IIR Filter
        IncludeMusic5000SPDIF  : boolean := true; -- Music 5000 20-bit SPDIF Output
        IncludeMixerResampler  : boolean := false;                      -- TODO: DB: runs out of resources
        IncludeICEDebugger     : boolean := G_CONFIG_DEBUGGER;
        IncludeVideoNuLA   : boolean := true;
        IncludeTrace       : boolean := false;
        IncludeHDMI        : boolean := true;
        IncludeBootStrap   : boolean := true;
        IncludeMonitor     : boolean := true;
        IncludeCoPro6502       : boolean := false;
        IncludeSoftLEDs        : boolean := true;
        IncludeI2SAudio        : boolean := true;

        MinVolume              : integer := 0;  -- -60dB
        DefaultVolume          : integer := 10; -- -30dB
        MaxVolume              : integer := 20; --   0dB

        PRJ_ROOT           : string  := "../../../..";
        --MOS_NAME           : string  := "/roms/bbcb/os12x3.bit";
        MOS_NAME           : string  := "/roms/bbcb/os_tester3x.bit";
        SIM                : boolean := false
        );
    port (
        sys_clk         : in    std_logic;
        btn1_n          : in    std_logic;     -- Toggle Master / Beeb modes
        btn2_n          : in    std_logic;     -- Toggle HDMI / DVI modes
        btn3_n          : in    std_logic;
        led             : out   std_logic_vector (5 downto 0);

        -- Keyboard / Mouse
        ps2_clk         : inout std_logic;
        ps2_data        : inout std_logic;
        ps2_mouse_clk   : inout std_logic;
        ps2_mouse_data  : inout std_logic;

        -- SD Card
        tf_miso         : in    std_logic;
        tf_cs           : out   std_logic;
        tf_sclk         : out   std_logic;
        tf_mosi         : out   std_logic;

        -- USB UART
        uart_rx         : in    std_logic;
        uart_tx         : out   std_logic;


        -- VGA
        vid_r_o         : out   std_logic;
        vid_b_o         : out   std_logic;
        vid_g_o         : out   std_logic;
        vid_cs_o        : out   std_logic;
        vid_chr_o        : out   std_logic;

        -- I2S Audio
        i2s_bclk        : out   std_logic;
        i2s_lrclk       : out   std_logic;
        i2s_din         : out   std_logic;
        pa_en           : out   std_logic;


        -- SPI Flash (for ROM data)
        flash_cs        : out   std_logic;     -- Active low FLASH chip select
        flash_si        : out   std_logic;     -- Serial output to FLASH chip SI pin
        flash_ck        : out   std_logic;     -- FLASH clock
        flash_so        : in    std_logic     -- Serial input from FLASH chip SO pin

        );
end entity;

architecture rtl of bbc_micro_tang20k is



    --------------------------------------------------------
    -- FPGA Primitive Components
    --------------------------------------------------------

    component rPLL
        generic (
            FCLKIN: in string := "100.0";
            DEVICE: in string := "GW1N-4";
            DYN_IDIV_SEL: in string := "false";
            IDIV_SEL: in integer := 0;
            DYN_FBDIV_SEL: in string := "false";
            FBDIV_SEL: in integer := 0;
            DYN_ODIV_SEL: in string := "false";
            ODIV_SEL: in integer := 8;
            PSDA_SEL: in string := "0000";
            DYN_DA_EN: in string := "false";
            DUTYDA_SEL: in string := "1000";
            CLKOUT_FT_DIR: in bit := '1';
            CLKOUTP_FT_DIR: in bit := '1';
            CLKOUT_DLY_STEP: in integer := 0;
            CLKOUTP_DLY_STEP: in integer := 0;
            CLKOUTD3_SRC: in string := "CLKOUT";
            CLKFB_SEL: in string := "internal";
            CLKOUT_BYPASS: in string := "false";
            CLKOUTP_BYPASS: in string := "false";
            CLKOUTD_BYPASS: in string := "false";
            CLKOUTD_SRC: in string := "CLKOUT";
            DYN_SDIV_SEL: in integer := 2
        );
        port (
            CLKOUT: out std_logic;
            LOCK: out std_logic;
            CLKOUTP: out std_logic;
            CLKOUTD: out std_logic;
            CLKOUTD3: out std_logic;
            RESET: in std_logic;
            RESET_P: in std_logic;
            CLKIN: in std_logic;
            CLKFB: in std_logic;
            FBDSEL: in std_logic_vector(5 downto 0);
            IDSEL: in std_logic_vector(5 downto 0);
            ODSEL: in std_logic_vector(5 downto 0);
            PSDA: in std_logic_vector(3 downto 0);
            DUTYDA: in std_logic_vector(3 downto 0);
            FDLY: in std_logic_vector(3 downto 0)
        );
    end component;

    component CLKDIV
        generic (
            DIV_MODE : string := "2";
            GSREN: in string := "false"
        );
        port (
            CLKOUT: out std_logic;
            HCLKIN: in std_logic;
            RESETN: in std_logic;
            CALIB: in std_logic
        );
    end component;

    --------------------------------------------------------
    -- Functions
    --------------------------------------------------------

function VOLUME_FN(log : in natural) return natural is
    begin
        case log is
            when  1 => return    1;
            when  2 => return    2;
            when  3 => return    3;
            when  4 => return    4;
            when  5 => return    6;
            when  6 => return    8;
            when  7 => return   11;
            when  8 => return   16;
            when  9 => return   23;
            when 10 => return   32;
            when 11 => return   46;
            when 12 => return   64;
            when 13 => return   91;
            when 14 => return  128;
            when 15 => return  182;
            when 16 => return  256;
            when 17 => return  363;
            when 18 => return  512;
            when 19 => return  724;
            when 20 => return 1023;
            when others => return 0;
        end case;
    end function;

    function RESETBITS return natural is
    begin
        if SIM then
            return 10;
        else
            return 24; --DB: > 10ms for SPI to start up?
        end if;
    end function;

    --------------------------------------------------------
    -- Signals
    --------------------------------------------------------

    signal clock_24        : std_logic;
    signal clock_48        : std_logic;
    signal clock_96        : std_logic;
    signal clock_96_p      : std_logic;
    signal mem_ready       : std_logic;

    -- Audio
    signal dac_l_in        : std_logic_vector(9 downto 0);
    signal dac_r_in        : std_logic_vector(9 downto 0);
    signal audio_l         : std_logic_vector(15 downto 0);
    signal audio_r         : std_logic_vector(15 downto 0);
    signal audiol          : std_logic;
    signal audior          : std_logic;
    signal volume          : unsigned(4 downto 0) := to_unsigned(DefaultVolume, 5);
    signal audio_l_legacy  : std_logic_vector(15 downto 0);
    signal audio_r_legacy  : std_logic_vector(15 downto 0);
    signal sid_audio       : signed(17 downto 0);
    signal sid_strobe      : std_logic;
    signal psg_audio       : signed(17 downto 0);
    signal psg_strobe      : std_logic;
    signal m5k_filter_en   : std_logic := '1';
    signal m5k_spdif       : std_logic;
    signal m5k_audio_l     : signed(17 downto 0);
    signal m5k_audio_r     : signed(17 downto 0);
    signal m5k_strobe      : std_logic;
    signal mixer_strobe    : std_logic;
    signal i2s_clk         : std_logic := '0';

    signal config_counter  : std_logic_vector(21 downto 0);
    signal config_last     : std_logic;
    signal config          : std_logic_vector(9 downto 0);

    signal powerup_reset_n : std_logic := '0';
    signal hard_reset_n    : std_logic;
    signal reset_counter   : std_logic_vector(RESETBITS downto 0);

    signal ext_A_stb       : std_logic;
    signal ext_A           : std_logic_vector (18 downto 0);
    signal ext_Din         : std_logic_vector (7 downto 0);
    signal ext_Dout        : std_logic_vector (7 downto 0);
    signal ext_nCS         : std_logic;
    signal ext_nWE         : std_logic;
    signal ext_nWE_long    : std_logic;
    signal ext_nOE         : std_logic;

    signal keyb_dip        : std_logic_vector(7 downto 0);
    signal vid_mode        : std_logic_vector(3 downto 0);
    signal m128_mode       : std_logic := '1';
    signal copro_mode      : std_logic := '1';

    signal caps_led        : std_logic;
    signal shift_led       : std_logic;

    signal i_VGA_R         : std_logic_vector(3 downto 0);
    signal i_VGA_G         : std_logic_vector(3 downto 0);
    signal i_VGA_B         : std_logic_vector(3 downto 0);
    signal i_VGA_HS        : std_logic;
    signal i_VGA_VS        : std_logic;
    signal i_VGA_DE        : std_logic;
    signal i_VGA_CLKEN     : std_logic;
    signal i_VGA_MHZ12     : std_logic;

    -- CPU tracing
    signal trace_data      :   std_logic_vector(7 downto 0);
    signal trace_r_nw      :   std_logic;
    signal trace_sync      :   std_logic;
    signal trace_rstn      :   std_logic;
    signal trace_phi2      :   std_logic;

    -- Mem Controller Monior LEDs
    signal monitor_leds    :   std_logic_vector(5 downto 0);

    -- 1 bit DAC

    constant C_VID_SAMPLE_SIZE  : natural := 5;
    constant C_PEDESTAL         : natural := 8;

    signal r0_vid_r         : unsigned(3 downto 0);
    signal r0_vid_g         : unsigned(3 downto 0);
    signal r0_vid_b         : unsigned(3 downto 0);

    signal r_vid_r          : unsigned(C_VID_SAMPLE_SIZE-1 downto 0);
    signal r_vid_g          : unsigned(C_VID_SAMPLE_SIZE-1 downto 0);
    signal r_vid_b          : unsigned(C_VID_SAMPLE_SIZE-1 downto 0);

    signal r2_vid_r         : unsigned(C_VID_SAMPLE_SIZE-1 downto 0);
    signal r2_vid_g         : unsigned(C_VID_SAMPLE_SIZE-1 downto 0);
    signal r2_vid_b         : unsigned(C_VID_SAMPLE_SIZE-1 downto 0);

    signal r_vid_req        : std_logic;
    signal r_vid_ack        : std_logic;

    signal i_clk_dac        : std_logic;

    signal i_chroma_s       : signed(4 downto 0);
    signal r2_vid_chroma    : unsigned(4 downto 0);
    signal i_clk_chroma_x4  : std_logic;

    -- 1MHz Bus
    signal ext_1mhz_clk    : std_logic; -- the system clock
    signal ext_1mhz_clken  : std_logic; -- a 1MHz strobe, valid for one system clock cycle
    signal ext_1mhz_nrst   : std_logic;
    signal ext_1mhz_pgfc_n : std_logic;
    signal ext_1mhz_r_nw   : std_logic;
    signal ext_1mhz_addr   : std_logic_vector(7 downto 0);
    signal ext_1mhz_di     : std_logic_vector(7 downto 0);
    signal ext_1mhz_do     : std_logic_vector(7 downto 0);

    -- LEDs
    signal normal_leds     : std_logic_vector(5 downto 0);

    -- Test
    signal test            : std_logic_vector(7 downto 0);

    -- debug keyboard

    signal dbg_keyboard_state : std_logic_vector(5 downto 0);

begin

    --------------------------------------------------------
    -- BBC Micro Core
    --------------------------------------------------------

    bbc_micro : entity work.bbc_micro_core
        generic map (
            IncludeAMXMouse    => IncludeAMXMouse,
            IncludeSPISD       => IncludeSPISD,
            IncludeSID         => IncludeSID,
            IncludeMusic5000   => IncludeMusic5000,
            IncludeMusic5000Filter => IncludeMusic5000Filter,
            IncludeMusic5000SPDIF  => IncludeMusic5000SPDIF,
            IncludeICEDebugger     => IncludeICEDebugger,
            IncludeCoPro6502       => IncludeCoPro6502,
            IncludeCoProSPI    => false,
            IncludeCoProExt    => false,
            IncludeVideoNuLA   => IncludeVideoNuLA,
            IncludeTrace       => IncludeTrace,
            IncludeHDMI        => IncludeHDMI,
            UseOrigKeyboard    => false,
            UseT65Core         => not IncludeMaster,
            UseAlanDCore       => IncludeMaster
        )
        port map (
            clock_27       => '1',
            clock_32       => '0',                 -- Unused now in the core
            clock_48       => clock_48,
            clock_96       => clock_96,
            clock_avr       => clock_24,
            hard_reset_n   => hard_reset_n,
            powerup_reset_n => powerup_reset_n,
            ps2_kbd_clk    => ps2_clk,
            ps2_kbd_data   => ps2_data,
            ps2_mse_clk    => ps2_mouse_clk,
            ps2_mse_data   => ps2_mouse_data,
            dbg_keyboard_state => dbg_keyboard_state,
            video_red      => i_VGA_R,
            video_green    => i_VGA_G,
            video_blue     => i_VGA_B,
            video_hsync    => i_VGA_hs,
            video_vsync    => i_VGA_vs,
            video_disen    => i_VGA_de,
            video_clken    => i_VGA_CLKEN,
            video_mhz12    => i_VGA_MHZ12,
            audio_l         => audio_l_legacy,
            audio_r         => audio_r_legacy,
            hdmi_audio_ext  => open,
            hdmi_audio_l    => open,
            hdmi_audio_r    => open,
            psg_audio       => psg_audio,
            psg_strobe      => psg_strobe,
            sid_audio       => sid_audio,
            sid_strobe      => sid_strobe,
            m5k_filter_en   => m5k_filter_en,
            m5k_audio_l     => m5k_audio_l,
            m5k_audio_r     => m5k_audio_r,
            m5k_strobe      => m5k_strobe,
            m5k_spdif       => m5k_spdif,
            ext_nOE        => ext_nOE,
            ext_nWE        => ext_nWE,
            ext_nWE_long   => ext_nWE_long,
            ext_nCS        => ext_nCS,
            ext_A          => ext_A,
            ext_A_stb      => ext_A_stb,
            ext_Dout       => ext_Dout,
            ext_Din        => ext_Din,
            SDMISO         => tf_miso,
            SDSS           => tf_cs,
            SDCLK          => tf_sclk,
            SDMOSI         => tf_mosi,
            caps_led       => caps_led,
            shift_led      => shift_led,
            keyb_dip       => keyb_dip,
            ext_keyb_led1  => open,
            ext_keyb_led2  => open,
            ext_keyb_led3  => open,
            ext_keyb_1mhz  => open,
            ext_keyb_en_n  => open,
            ext_keyb_pa    => open,
            ext_keyb_rst_n => '1',
            ext_keyb_ca2   => '0',
            ext_keyb_pa7   => '0',
            config          => config,
            vid_mode       => vid_mode,
            joystick1      => (others => '1'),
            joystick2      => (others => '1'),
            avr_reset      => not hard_reset_n,
            avr_RxD        => uart_rx,
            avr_TxD        => uart_tx,
            cpu_addr       => open,
            m128_mode      => m128_mode,
            copro_mode      => copro_mode,
            p_spi_ssel     => '0',
            p_spi_sck      => '0',
            p_spi_mosi     => '0',
            p_spi_miso     => open,
            p_irq_b        => open,
            p_nmi_b        => open,
            p_rst_b        => open,
            ext_tube_r_nw  => open,
            ext_tube_nrst  => open,
            ext_tube_ntube => open,
            ext_tube_phi2  => open,
            ext_tube_a     => open,
            ext_tube_di    => open,
            ext_tube_do    => (others => '0'),
            ext_1mhz_clken  => ext_1mhz_clken, -- a 1MHz strobe, valid for one system clock cycle
            ext_1mhz_nrst   => ext_1mhz_nrst,
            ext_1mhz_pgfc_n => ext_1mhz_pgfc_n,
            ext_1mhz_pgfd_n => open,
            ext_1mhz_r_nw   => ext_1mhz_r_nw,
            ext_1mhz_addr   => ext_1mhz_addr,
            ext_1mhz_di     => ext_1mhz_di,
            ext_1mhz_do     => ext_1mhz_do,
            ext_1mhz_irq_n  => open,
            ext_1mhz_nmi_n  => open,
            hdmi_aspect    => open,
            hdmi_audio_en  => open,
            vid_debug      => '0',
            tmds_r         => open,
            tmds_g         => open,
            tmds_b         => open,
            hsync_ref      => open,
            trace_data     => trace_data,
            trace_r_nw     => trace_r_nw,
            trace_sync     => trace_sync,
            trace_rstn     => trace_rstn,
            trace_phi2     => trace_phi2,
            test            => test
        );

    vid_mode       <= "0000";-- DB: force 15KHz mode
    keyb_dip       <= "00000011";

    --------------------------------------------------------
    -- Clock Generation
    --------------------------------------------------------

    -- 48 MHz master clock from 27MHz input clock
    -- plus intermediate 96MHz clock for scan doubler

    pll1 : rPLL
        generic map (
            FCLKIN => "27",
            DEVICE => "GW2A-18C",
            IDIV_SEL => 8,
            FBDIV_SEL => 31,
            ODIV_SEL => 8,
            DYN_SDIV_SEL => 2,
            PSDA_SEL => "1000"          -- 180 degree phase shift
        )
        port map (
            CLKIN    => sys_clk,
            CLKOUT   => clock_96,       -- 96MHz clock for SDRAM
            CLKOUTP  => clock_96_p,     -- 96MHz clock for SDRAM, phase shifted 180 degrees
            CLKOUTD  => clock_48,       -- 48MHz main clock
            CLKOUTD3 => open,
            LOCK     => open,
            RESET    => '0',
            RESET_P  => '0',
            CLKFB    => '0',
            FBDSEL   => (others => '0'),
            IDSEL    => (others => '0'),
            ODSEL    => (others => '0'),
            PSDA     => (others => '0'),
            DUTYDA   => (others => '0'),
            FDLY     => (others => '0')
        );


    clkdiv4 : CLKDIV
        generic map (
            DIV_MODE => "4",            -- Divide by 4
            GSREN => "false"
        )
        port map (
            RESETN => powerup_reset_n,
            HCLKIN => clock_96,
            CLKOUT => clock_24,         -- 24MHz AVR Clock
            CALIB  => '1'
        );



    --------------------------------------------------------
    -- Button 1: Power Up Reset and Master/Beeb toggle
    --------------------------------------------------------

    -- Generate a reliable power up reset on powerup, and if bt1n is pressed
    -- Also, if both IncludeMaster and IncludeBeeb then toggle m128mode

    reset_gen : process(clock_48)
    begin
        if rising_edge(clock_48) then
            if (btn1_n = '0') then
                reset_counter <= (others => '0');
            elsif (reset_counter(reset_counter'high) = '0') then
                reset_counter <= reset_counter + 1;
            elsif powerup_reset_n = '0' then
                if IncludeBeeb and IncludeMaster then
                    m128_mode <= not m128_mode;
                    if m128_mode = '1' then
                        copro_mode <= not copro_mode;
                    end if;
                elsif IncludeMaster then
                    m128_mode <= '1';
                    copro_mode <= not copro_mode;
                else
                    m128_mode <= '0';
                    copro_mode <= not copro_mode;
                end if;
            end if;
            powerup_reset_n <= reset_counter(reset_counter'high);
            hard_reset_n <= not (not powerup_reset_n or not mem_ready);
        end if;
    end process;

    --------------------------------------------------------
    -- Button 2: HDMI / DVI mode toggle
    --
    -- The audio options are changed using the Config keys:
    --     Ctrl-Alt F1 = Volume down (clamped at 0)
    --     Ctrl-Alt F2 = Volume up
    --     Ctrl-Alt F3 = Toggle S/PDIF source (Mixer/M5K)
    --     Ctrl-Alt F4 = Toggle M5K Filter (On/Off)
    --
    -- Defaults are currently:
    --     Volume: 63
    --     S/PDIF output from Mixer
    --     M5K filter enabled
    --
    -- Changes to these settings persist when BTN1/BTN2 are
    -- pressed. Is this the right behaviour?
    --
    -- Current volume can be read/written at address &FC54.
    --
    -- TODO: Add config option for MAX98357 Audio On/Off. Need to
    -- check the datasheet for correct order to sequence stuff.
    --
    --------------------------------------------------------

    config_gen : process(clock_48)
    begin
        if rising_edge(clock_48) then
            if powerup_reset_n = '0' then
--                hdmi_audio_en <= '1';
                config_counter <= (others => '0');
            elsif btn2_n = '0' then
                config_counter <= (others => '1');
            elsif config_counter(config_counter'high) = '1' then
                config_counter <= config_counter - 1;
            elsif config_last = '1' then
                -- For now, keep HDMI/DVI mode on BTN2
--                hdmi_audio_en <= not hdmi_audio_en;
            end if;
            config_last <= config_counter(config_counter'high);
            -- If SoftLEDs are included, these move to the 1MHz bus section
            if not IncludeSoftLEDs then
                if config(1) = '1' and volume > MinVolume then
                    volume <= volume - 1;
                end if;
                if config(2) = '1' and volume < MaxVolume then
                    volume <= volume + 1;
                end if;
            end if;
            if config(3) = '1' then
--                m5k_spdif_en <= not m5k_spdif_en;
            end if;
            if config(4) = '1' then
                m5k_filter_en <= not m5k_filter_en;
            end if;
            if config(5) = '1' then
--                hdmi_audio_src <= not hdmi_audio_src;
            end if;
        end if;
    end process;

    --------------------------------------------------------
    -- Audio Mixer
    --------------------------------------------------------

    gen_mixer_resampler : if IncludeMixerResampler generate
        constant NUM_CHANNELS  : integer := 4;
        signal channel_in      : t_sample_array(0 to NUM_CHANNELS - 1);
        signal channel_clken   : std_logic_vector(NUM_CHANNELS - 1 downto 0);
        signal channel_load    : std_logic_vector(NUM_CHANNELS - 1 downto 0);
        signal mixer_l         : signed(19 downto 0);
        signal mixer_r         : signed(19 downto 0);
        signal spdif_in        : std_logic_vector(19 downto 0);
        signal channelA        : std_logic;
        signal div64           : unsigned(5 downto 0) := (others => '0');
--        signal mhz6_clken      : std_logic;
    begin

        -- Order: 3, 2, 1, 0
        channel_clken <= "1111";
        channel_load  <=  m5k_strobe & m5k_strobe & psg_strobe & sid_strobe;

        -- Order: 0, 1, 2, 3
        channel_in    <= ( sid_audio, psg_audio, m5k_audio_l, m5k_audio_r );

        sample_rate_converter_inst : entity work.sample_rate_converter
            generic map (
                NUM_CHANNELS      => NUM_CHANNELS,
                VOLUME_WIDTH      => 10,
                OUTPUT_RATE       => 1000,           -- 48KHz
                OUTPUT_WIDTH      => 20,             -- 20 bits
                OUTPUT_SHIFT      => 14,
                FILTER_NTAPS      => 3840,
                FILTER_L          => (6, 24, 128, 128),
                FILTER_M          => 125,
                FILTER_SHIFT      => 16,
                CHANNEL_TYPE      => (mono, mono, left_channel, right_channel),
                BUFFER_A_WIDTH    => 10,             -- 1K Words
                COEFF_A_WIDTH     => 11,             -- 2K Words
                ACCUMULATOR_WIDTH => 54,
                BUFFER_SIZE       => (704, 192, 64, 64)
                )
            port map (
                clk               => clock_48,
                reset_n           => powerup_reset_n,
                volume            => to_unsigned(VOLUME_FN(to_integer(volume)), 10),
                channel_clken     => channel_clken,
                channel_load      => channel_load,
                channel_in        => channel_in,
                mixer_strobe      => mixer_strobe,
                mixer_l           => mixer_l,
                mixer_r           => mixer_r
                );

        audio_l      <= std_logic_vector(mixer_l(19 downto 4));
        audio_r      <= std_logic_vector(mixer_r(19 downto 4));
--        hdmi_audio_l <= audio_l when hdmi_audio_src = '1' else audio_l_legacy;
--        hdmi_audio_r <= audio_r when hdmi_audio_src = '1' else audio_r_legacy;

    end generate;

    gen_no_resampler: if not IncludeMixerResampler generate

--        audio_spdif  <= m5k_spdif;
        audio_l      <= audio_l_legacy;
        audio_r      <= audio_r_legacy;
--        hdmi_audio_l <= audio_r_legacy;
--        hdmi_audio_r <= audio_r_legacy;

    end generate;

    --------------------------------------------------------
    -- SPDIF
    --------------------------------------------------------

    --------------------------------------------------------
    -- Audio DACs
    --------------------------------------------------------

    -- Convert from signed to unsigned
    dac_l_in <= (not audio_l(15)) & audio_l(14 downto 6);
    dac_r_in <= (not audio_r(15)) & audio_r(14 downto 6);

    dac_l : entity work.pwm_sddac
        generic map (
            msbi_g => 9
        )
        port map (
            clk_i => clock_48,
            reset => '0',
            dac_i => dac_l_in,
            dac_o => audiol
        );

    dac_r : entity work.pwm_sddac
        generic map (
            msbi_g => 9
        )
        port map (
            clk_i => clock_48,
            reset => '0',
            dac_i => dac_r_in,
            dac_o => audior
            );



    --------------------------------------------------------
    -- I2S Audio Using On-Board PT8211 DAC
    --------------------------------------------------------
    gen_i2s : if IncludeI2SAudio generate
    begin


	    --TODO: DB: make a cheap and jittery 3.072M clock
	    --TODO: DB: this will have a lot of jitter on each bit but should be solid on each word - test THD at output
	    p_i2s_clk_gen:process(clock_96)
	    constant div : natural := 8;
	    constant num : natural := 125;
	    variable r_acc : unsigned(7 downto 0) := (others => '0');
	    begin
	        if rising_edge(clock_96) then
	            r_acc := r_acc + div;
	            if r_acc >= num then
	                r_acc := r_acc - num;
	                i2s_clk <= not i2s_clk;
	            end if;
	        end if;
	    end process;

        i2s : entity work.i2s_dom
            port map (
                clock      => i2s_clk,
                reset_n    => powerup_reset_n,
                audio_l    => audio_l,
                audio_r    => audio_r,
                i2s_lrclk  => i2s_lrclk,
                i2s_bclk   => i2s_bclk,
                i2s_din    => i2s_din,
                pa_en      => pa_en
                );
    end generate;

    not_gen_i2s : if not IncludeI2SAudio generate
        i2s_lrclk  <= 'Z';
        i2s_bclk   <= 'Z';
        i2s_din    <= 'Z';
        pa_en      <= '0';
    end generate;

    --------------------------------------------------------
    -- ??? Memory Controller
    --------------------------------------------------------

    e_mem: entity work.mem_tang_20k
        generic map (
            SIM => SIM,
            IncludeMonitor => IncludeMonitor,
            IncludeBootStrap => IncludeBootStrap,
            IncludeMinimalBeeb => true,
            IncludeMinimalMaster => true,
            PRJ_ROOT => PRJ_ROOT,
            MOS_NAME => MOS_NAME
        )
        port map (
            m128_mode      => m128_mode,
            CLK_96         => clock_96,
            CLK_96_P       => clock_96_p,
            RST_n          => powerup_reset_n,
            READY          => mem_ready,
            CLK_48         => clock_48,
            core_A_stb     => ext_A_stb,
            core_A         => ext_A,
            core_Din       => ext_Din,
            core_Dout      => ext_Dout,
            core_nCS       => ext_nCS,
            core_nWE       => ext_nWE,
            core_nWE_long  => ext_nWE_long,
            core_nOE       => ext_nOE,

            led            => monitor_leds,

            FLASH_CS       => flash_cs,
            FLASH_SI       => flash_si,
            FLASH_CK       => flash_ck,
            FLASH_SO       => flash_so
        );

    --------------------------------------------------------
    -- 1MHz Bus LEDs
    --------------------------------------------------------

    normal_leds <= (caps_led & shift_led & m128_mode & m5k_filter_en & "00") xor "111111";

--    GenLEDS: if IncludeSoftLEDs generate
--        signal soft_leds       : std_logic_vector(7 downto 0) := (others => '0');
--        signal ws2812_r        : std_logic_vector(7 downto 0) := (others => '0');
--        signal ws2812_g        : std_logic_vector(7 downto 0) := (others => '0');
--        signal ws2812_b        : std_logic_vector(7 downto 0) := (others => '0');

--        function bit_reverse (a: in std_logic_vector)
--            return std_logic_vector is
--            variable result: std_logic_vector(a'RANGE);
--            alias aa: std_logic_vector(a'REVERSE_RANGE) is a;
--        begin
--            for i in aa'RANGE loop
--                result(i) := aa(i);
--            end loop;
--            return result;
--        end;

--    begin

--        -- This module is in Verilog and comes from MisteryNano
--        inst_ws2812 : entity work.ws2812
--            port map (
--                clk   => clock_48,
--                color => bit_reverse(ws2812_g & ws2812_r & ws2812_b),
--                data  => ws2812_din
--                );
--
--        led <= --soft_leds(5 downto 0) xor "111111" when soft_leds(7 downto 6) = "10" else
--               --test(5 downto 0)      xor "111111" when soft_leds(7 downto 6) = "11" else
--               monitor_leds                       when IncludeMonitor               else
--               normal_leds;
--

        led <= --soft_leds(5 downto 0) xor "111111" when soft_leds(7 downto 6) = "10" else
               --test(5 downto 0)      xor "111111" when soft_leds(7 downto 6) = "11" else
               monitor_leds                       when IncludeMonitor               else
               (dbg_keyboard_state) xor "111111";



        process(clock_48)
        begin
            if rising_edge(clock_48) then
                if ext_1mhz_clken = '1' then
                    if ext_1mhz_nrst = '0' then
--                        soft_leds <= x"00";
--                        ws2812_r  <= x"00";
--                        ws2812_g  <= x"00";
--                        ws2812_b  <= x"00";
                    elsif ext_1mhz_pgfc_n = '0' and ext_1mhz_r_nw = '0' then
                        case ext_1mhz_addr is
--                            when x"50" =>
--                                soft_leds <= ext_1mhz_di;
--                            when x"51" =>
--                                ws2812_r  <= ext_1mhz_di;
--                            when x"52" =>
--                                ws2812_g  <= ext_1mhz_di;
--                            when x"53" =>
--                                ws2812_b  <= ext_1mhz_di;
                            when x"54" =>
                                if ext_1mhz_di > MaxVolume then
                                    volume <= to_unsigned(MaxVolume, volume'length);
                                elsif ext_1mhz_di < MinVolume then
                                    volume <= to_unsigned(MinVolume, volume'length);
                                else
                                    volume <= unsigned(ext_1mhz_di(volume'length - 1 downto 0));
                                end if;
                            when others =>
                                null;
                        end case;
                    end if;
                end if;
                -- Although not related to the 1MHz bus, it's necessary
                -- to implement this here.
                if config(1) = '1' and volume > MinVolume then
                    volume <= volume - 1;
                end if;
                if config(2) = '1' and volume < MaxVolume then
                    volume <= volume + 1;
                end if;
            end if;
        end process;

        ext_1mhz_do <=  
--                         soft_leds when ext_1mhz_addr = x"50" else
--                         ws2812_r when ext_1mhz_addr = x"51" else
--                         ws2812_g when ext_1mhz_addr = x"52" else
--                         ws2812_b when ext_1mhz_addr = x"53" else
 "000" & std_logic_vector(volume) when ext_1mhz_addr = x"54" else
                       x"FF";

--    end generate;

--    NotGenLEDS: if not IncludeSoftLEDs generate
--
--        led <= monitor_leds when IncludeMonitor else normal_leds;
--        ws2812_din <= '0';
--
--    end generate;

    --------------------------------------------------------
    -- 1 bit video
    --------------------------------------------------------
    
    e_pll2: entity work.pll2v
    port map (
        clkout => i_clk_dac,
        clkin => sys_clk
    );


    vid_cs_o <= not (i_VGA_hs xor i_VGA_vs); 

    p_v1:process(clock_48)
        function U(S : in std_logic) return unsigned is
        variable r : unsigned(0 downto 0);
        begin
            r(0) := S;
            return r;
        end function U;
    begin
        if rising_edge(clock_48) then
            --if i_VGA_CLKEN = '1' then

                r0_vid_r <= unsigned(i_VGA_R);
                r0_vid_g <= unsigned(i_VGA_G);
                r0_vid_b <= unsigned(i_VGA_B);

                -- note inverted for analogue circuits
                r_vid_r <= ("0" & r0_vid_r) + to_unsigned(C_PEDESTAL, r_vid_r'length); -- + resize(U(i_rnd_r), r_vid_r'length);                
                r_vid_g <= ("0" & r0_vid_g) + to_unsigned(C_PEDESTAL, r_vid_g'length); -- + resize(U(i_rnd_r), r_vid_r'length);                
                r_vid_b <= ("0" & r0_vid_b) + to_unsigned(C_PEDESTAL, r_vid_b'length); -- + resize(U(i_rnd_r), r_vid_r'length);                


                if r_vid_req = '1' then
                    r_vid_req <= '0';
                else
                    r_vid_req <= '1';
                end if;
            --end if;
        end if;
    end process;

    p_v2:process(i_clk_dac)
    variable v_vr2 : std_logic;
    begin
        if rising_edge(i_clk_dac) then
            if v_vr2 /= r_vid_ack then
                r2_vid_r <= r_vid_r;
                r2_vid_g <= r_vid_g;
                r2_vid_b <= r_vid_b;
                r_vid_ack <= v_vr2;
            end if;
            v_vr2 := r_vid_req;
        end if;
    end process;

    e_vidr:entity work.dac_1bit
    generic map (
        G_SAMPLE_SIZE       => C_VID_SAMPLE_SIZE,
        G_SYNC_DEPTH        => 1,
        G_PWM               => FALSE
    )
    port map (
        rst_i               => not hard_reset_n,
        clk_dac             => i_clk_dac,

        sample              => not r2_vid_r,
        
        bitstream           => vid_r_o
    );

    e_vidg:entity work.dac_1bit
    generic map (
        G_SAMPLE_SIZE       => C_VID_SAMPLE_SIZE,
        G_SYNC_DEPTH        => 1,
        G_PWM               => FALSE
    )
    port map (
        rst_i               => not hard_reset_n,
        clk_dac             => i_clk_dac,

        sample              => not r2_vid_g,
        
        bitstream           => vid_g_o
    );

    e_vidb:entity work.dac_1bit
    generic map (
        G_SAMPLE_SIZE       => C_VID_SAMPLE_SIZE,
        G_SYNC_DEPTH        => 1,
        G_PWM               => FALSE
    )
    port map (
        rst_i               => not hard_reset_n,
        clk_dac             => i_clk_dac,

        sample              => not r2_vid_b,
        
        bitstream           => vid_b_o
    );


    e_chroma_gen:entity work.dossy_chroma
    generic map (
        G_USE_EXT_x4_CLK  => false

        )
    port map (

      clk_i             => clock_48,
      clk_chroma_x4_i   => '1',

      r_i               => unsigned(i_VGA_R),
      g_i               => unsigned(i_VGA_G),
      b_i               => unsigned(i_VGA_B),

      hs_i              => i_VGA_hs,
      vs_i              => i_VGA_vs,

      chroma_o          => i_chroma_s,
      clk_chroma_x4_o   => i_clk_chroma_x4,


      car_ry_o          => open,
      pal_sw_o          => open,
      base_ry_o         => open
   );


    p_chrom_s2u:process(i_clk_chroma_x4)
    begin
        if rising_edge(i_clk_chroma_x4) then
            
            r2_vid_chroma <= to_unsigned(16+to_integer(i_chroma_s), 5);

        end if;

    end process;

    e_chrom:entity work.dac_1bit
    generic map (
        G_SAMPLE_SIZE       => 5,
        G_SYNC_DEPTH        => 1,
        G_PWM               => FALSE
    )
    port map (
        rst_i               => not hard_reset_n,
        clk_dac             => i_clk_dac,

        sample              => r2_vid_chroma,
        
        bitstream           => vid_chr_o
    );

   
end architecture;
