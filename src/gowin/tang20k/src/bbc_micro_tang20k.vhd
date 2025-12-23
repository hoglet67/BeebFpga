-- BBC Master / BBC B for the Tang Nano 20K
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

-- This is generated dynamically using tclPre
library work;
use work.version_config_pack.all;

entity bbc_micro_tang20k is
    generic (
        IncludeHDMI            : boolean := true;
        IncludeSRGB            : boolean := G_CONFIG_VGA;
        IncludeVGA             : boolean := G_CONFIG_VGA;
        IncludeMaster          : boolean := G_CONFIG_MASTER; -- if both included, the CPU is the AlanD 65C02
        IncludeBeeb            : boolean := G_CONFIG_BEEB;   -- and Config(7) can toggle between the ROM images
        IncludeAMXMouse        : boolean := true;
        IncludeSPISD           : boolean := true;
        IncludeSID             : boolean := true;
        IncludeMusic5000       : boolean := true;
        IncludeMusic5000Filter : boolean := true; -- Music 5000 Low Pass IIR Filter
        IncludeMixerResampler  : boolean := true;
        IncludeICEDebugger     : boolean := G_CONFIG_DEBUGGER;
        IncludeVideoNuLA       : boolean := true;
        IncludeTrace           : boolean := true;
        IncludeBootStrap       : boolean := true;
        IncludeMonitor         : boolean := false; -- So we see the normal status LEDs
        IncludeCoPro6502       : boolean := true;
        IncludeCoProExt        : boolean := not G_CONFIG_VGA;
        IncludeSoftLEDs        : boolean := true;  -- Add 1 MHz bus registers for the 6 on-board LEDs and the WS2812
        IncludeSoftVolume      : boolean := true;  -- Add 1MHz register for the volume
        IncludeI2SAudio        : boolean := true;
        IncludeSPDIFAudio      : boolean := true;
        IncludeVGADAC          : boolean := G_CONFIG_VGA;
        IncludeAnalogJS        : boolean := false;
        IncludeSerial          : boolean := true;

        MinVolume              : integer := 0;  -- -60dB
        DefaultVolumeSpeaker   : integer := 12; -- -24dB
        DefaultVolumeLine      : integer := 16; -- -12dB
        MaxVolume              : integer := 20; --   0dB

        PRJ_ROOT               : string  := "../../../..";
        MOS_NAME               : string  := "/roms/bbcb/os12_basic.bit";
        SIM                    : boolean := false
        );
    port (
        sys_clk         : in    std_logic;     -- 135MHz clock from SI5351 CLK2 (pin 13)

        audio_clk       : in    std_logic;     -- 24.576MHz audio clock from the SI5351 CLK1 (pin 11)

        btn1            : in    std_logic;     -- Powerup reset
        btn2            : in    std_logic;     -- Config modifier
        reconfig_n      : out   std_logic;
        led             : out   std_logic_vector (5 downto 0);
        ws2812_din      : out   std_logic;
        key_conf        : in    std_logic;

        -- Keyboard / Mouse
        ps2_clk         : inout std_logic;
        ps2_data        : inout std_logic;
        ps2_mouse_clk   : inout std_logic;
        ps2_mouse_data  : inout std_logic;

        -- Joystick
        js_clk          : out   std_logic;     -- this is actually just phi2 to save a pin
        js_load_n       : out   std_logic;
        js_data         : in    std_logic;

        -- SD Card
        tf_miso         : in    std_logic;
        tf_cs           : out   std_logic;
        tf_sclk         : out   std_logic;
        tf_mosi         : out   std_logic;

        -- USB UART
        uart_rx         : in    std_logic;
        uart_tx         : out   std_logic;

        -- HDMI
        tmds_clk_p      : out   std_logic;
        tmds_clk_n      : out   std_logic;
        tmds_d_p        : out   std_logic_vector(2 downto 0);
        tmds_d_n        : out   std_logic_vector(2 downto 0);

        -- VGA
        vga_r           : inout std_logic;
        vga_r_n         : inout std_logic;
        vga_g           : inout std_logic;
        vga_g_n         : inout std_logic;
        vga_b           : inout std_logic;
        vga_b_n         : inout std_logic;
        vga_hs          : inout std_logic;
        vga_vs          : inout std_logic;

        -- I2S Audio
        i2s_mclk        : out   std_logic;
        i2s_bclk        : out   std_logic;
        i2s_lrclk       : out   std_logic;
        i2s_din         : out   std_logic;
        pa_en           : inout std_logic;

        -- 1-bit DAC Audio
        audiol          : inout std_logic; -- inout at this can also be configures as I2C_SCL (IncludeAnalogJS)
        audior          : inout std_logic; -- inout at this can also be configures as I2C_SDA (IncludeAnalogJS)

        -- SPDIF Audio
        audio_spdif     : out   std_logic;

        -- Magic ports for SDRAM to be inferred
        O_sdram_clk     : out   std_logic;
        O_sdram_cke     : out   std_logic;
        O_sdram_cs_n    : out   std_logic;
        O_sdram_cas_n   : out   std_logic;
        O_sdram_ras_n   : out   std_logic;
        O_sdram_wen_n   : out   std_logic;
        IO_sdram_dq     : inout std_logic_vector(31 downto 0);
        O_sdram_addr    : out   std_logic_vector(10 downto 0);
        O_sdram_ba      : out   std_logic_vector(1 downto 0);
        O_sdram_dqm     : out   std_logic_vector(3 downto 0);

        -- SPI Flash (for ROM data)
        flash_cs        : out   std_logic;     -- Active low FLASH chip select
        flash_si        : out   std_logic;     -- Serial output to FLASH chip SI pin
        flash_ck        : out   std_logic;     -- FLASH clock
        flash_so        : in    std_logic      -- Serial input from FLASH chip SO pin
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

    component DCS
        generic (
            DCS_MODE : string := "RISING"
        );
        port (
            CLK0     : in  std_logic;
            CLK1     : in  std_logic;
            CLK2     : in  std_logic;
            CLK3     : in  std_logic;
            CLKSEL   : in  std_logic_vector(3 downto 0);
            SELFORCE : in  std_logic;
            CLKOUT   : out std_logic
        );
    end component;

    component OSER10
        generic (
            GSREN : string := "false";
            LSREN : string := "true"
        );
        port (
            Q : out std_logic;
            D0 : in std_logic;
            D1 : in std_logic;
            D2 : in std_logic;
            D3 : in std_logic;
            D4 : in std_logic;
            D5 : in std_logic;
            D6 : in std_logic;
            D7 : in std_logic;
            D8 : in std_logic;
            D9 : in std_logic;
            FCLK : in std_logic;
            PCLK : in std_logic;
            RESET : in std_logic
        );
    end component;

    component ELVDS_OBUF
        port (
            I : in std_logic;
            O : out std_logic;
            OB : out std_logic
        );
    end component;

    component ws2812
        port (
            clk : in std_logic;
            color : in std_logic_vector(23 downto 0);
            data : out std_logic
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
            return 19; --DB: > 10ms for SPI to start up?
        end if;
    end function;

    --------------------------------------------------------
    -- Version ROM
    --------------------------------------------------------

    type version_rom_type is array(0 to 31) of unsigned(7 downto 0);

    function init_version_rom return version_rom_type is
        variable tmp : version_rom_type;
        variable nibble : unsigned(3 downto 0);
        variable i : integer;
    begin
        -- Git version
        for i in 0 to 7 loop
            nibble := unsigned(G_CONFIG_VERSION(i * 4 + 3 downto i * 4));
            if nibble < 10 then
                tmp(7 - i) := to_unsigned(character'pos('0'), 8) + nibble;
            else
                tmp(7 - i) := to_unsigned(character'pos('A'), 8) + nibble - 10;
            end if;
        end loop;
        -- Git dirty flag
        i := 8;
        if G_CONFIG_DIRTY then
            tmp(i) := to_unsigned(character'pos('?'), 8);
            i := i + 1;
        end if;
        tmp(i) := to_unsigned(character'pos(' '), 8);
        -- VGA vs PiTube
        if G_CONFIG_VGA then
            tmp(i+1) := to_unsigned(character'pos('V'), 8);
            tmp(i+2) := to_unsigned(character'pos('G'), 8);
            tmp(i+3) := to_unsigned(character'pos('A'), 8);
            i := i + 4;
        else
            tmp(i+1) := to_unsigned(character'pos('P'), 8);
            tmp(i+2) := to_unsigned(character'pos('i'), 8);
            tmp(i+3) := to_unsigned(character'pos('T'), 8);
            tmp(i+4) := to_unsigned(character'pos('u'), 8);
            tmp(i+5) := to_unsigned(character'pos('b'), 8);
            tmp(i+6) := to_unsigned(character'pos('e'), 8);
            i := i + 7;
        end if;
        tmp(i) := to_unsigned(character'pos(' '), 8);
        -- NoDebugger vs Debugger
        if not G_CONFIG_DEBUGGER then
            tmp(i+1) := to_unsigned(character'pos('N'), 8);
            tmp(i+2) := to_unsigned(character'pos('o'), 8);
            i := i + 2;
        end if;
        tmp(i+1) := to_unsigned(character'pos('D'), 8);
        tmp(i+2) := to_unsigned(character'pos('e'), 8);
        tmp(i+3) := to_unsigned(character'pos('b'), 8);
        tmp(i+4) := to_unsigned(character'pos('u'), 8);
        tmp(i+5) := to_unsigned(character'pos('g'), 8);
        tmp(i+6) := to_unsigned(character'pos('g'), 8);
        tmp(i+7) := to_unsigned(character'pos('e'), 8);
        tmp(i+8) := to_unsigned(character'pos('r'), 8);
        tmp(i+9) := x"0D";
        i := i + 10;
        while (i < 32) loop
            tmp(i) := x"00";
            i := i + 1;
        end loop;
        return tmp;
    end function;

    signal version_rom : version_rom_type := init_version_rom;
    signal version_rom_byte : std_logic_vector(7 downto 0);

    --------------------------------------------------------
    -- Signals
    --------------------------------------------------------

    signal clock_24        : std_logic;
    signal clock_27        : std_logic;
    signal clock_48        : std_logic;
    signal clock_96        : std_logic;
    signal clock_96_p      : std_logic;
    signal clock_135       : std_logic;
    signal spdif_clk       : std_logic; -- 6.144MHz SPDIF clock
    signal mem_ready       : std_logic;

    -- Audio
    signal dac_l_in        : std_logic_vector(9 downto 0);
    signal dac_r_in        : std_logic_vector(9 downto 0);
    signal audio_src       : std_logic := '1'; -- 0 = Legacy, 1 = Mixer
    signal audio_l         : std_logic_vector(19 downto 0);
    signal audio_r         : std_logic_vector(19 downto 0);
    signal volume          : unsigned(4 downto 0) := to_unsigned(0, 5);
    signal default_volume  : unsigned(4 downto 0) := to_unsigned(0, 5);
    signal m5k_filter_en   : std_logic := '1';

    -- output used to load sample into SPDIF (spdif clock domain)
    signal spdif_load      : std_logic;

    signal config          : std_logic_vector(9 downto 0);
    signal config_key      : std_logic;

    signal joystick1       : std_logic_vector(4 downto 0) := (others => '1');
    signal joystick2       : std_logic_vector(4 downto 0) := (others => '1');
    signal adc_ch0         : std_logic_vector(11 downto 0) := (others => '0');
    signal adc_ch1         : std_logic_vector(11 downto 0) := (others => '0');
    signal adc_ch2         : std_logic_vector(11 downto 0) := (others => '0');
    signal adc_ch3         : std_logic_vector(11 downto 0) := (others => '0');
    signal jumper          : std_logic_vector(7 downto 0) := (others => '0');

    signal config_reset_n  : std_logic := '0';
    signal powerup_reset_n : std_logic := '0';
    signal hard_reset_n    : std_logic;
    signal reset_counter   : std_logic_vector(RESETBITS downto 0);
    signal trigger_reset   : std_logic := '0';

    signal ext_A_stb       : std_logic;
    signal ext_A           : std_logic_vector (18 downto 0);
    signal ext_Din         : std_logic_vector (7 downto 0);
    signal ext_Dout        : std_logic_vector (7 downto 0);
    signal ext_nCS         : std_logic;
    signal ext_nWE         : std_logic;
    signal ext_nWE_long    : std_logic;
    signal ext_nOE         : std_logic;

    signal keyb_dip        : std_logic_vector(7 downto 0);
    signal m128_mode       : std_logic := '0';
    signal copro_mode      : std_logic := '0';
    signal copro_ext       : std_logic := '0';
    signal uart_debugger   : std_logic := '0';
    signal vga_mode        : std_logic := '0';

    signal caps_led        : std_logic;
    signal shift_led       : std_logic;
    signal clip_led        : std_logic;

    -- Analog video
    signal rgb_red         : std_logic_vector(3 downto 0);
    signal rgb_green       : std_logic_vector(3 downto 0);
    signal rgb_blue        : std_logic_vector(3 downto 0);
    signal rgb_csync       : std_logic;
    signal vga_red         : std_logic_vector(3 downto 0);
    signal vga_green       : std_logic_vector(3 downto 0);
    signal vga_blue        : std_logic_vector(3 downto 0);
    signal vga_hsync       : std_logic;
    signal vga_vsync       : std_logic;
    signal dac_red         : std_logic_vector(3 downto 0);
    signal dac_green       : std_logic_vector(3 downto 0);
    signal dac_blue        : std_logic_vector(3 downto 0);
    signal dac_hsync       : std_logic;
    signal dac_vsync       : std_logic;

    -- HDMI
    signal hdmi_aspect     : std_logic_vector(1 downto 0) := "11";
    signal hdmi_audio_en   : std_logic := '1';
    signal vid_debug       : std_logic;
    signal tmds_r          : std_logic_vector(9 downto 0);
    signal tmds_g          : std_logic_vector(9 downto 0);
    signal tmds_b          : std_logic_vector(9 downto 0);

    -- External tube
    signal ext_tube_r_nw   : std_logic;
    signal ext_tube_nrst   : std_logic;
    signal ext_tube_ntube  : std_logic;
    signal ext_tube_phi2   : std_logic;
    signal ext_tube_a      : std_logic_vector(6 downto 0);
    signal ext_tube_di     : std_logic_vector(7 downto 0);
    signal ext_tube_do     : std_logic_vector(7 downto 0);
    signal ext_tube_ctrl   : std_logic_vector(5 downto 0); -- signals that use the LED output

    -- CPU tracing
    signal trace_data      :   std_logic_vector(7 downto 0);
    signal trace_r_nw      :   std_logic;
    signal trace_sync      :   std_logic;
    signal trace_rstn      :   std_logic;
    signal trace_phi2      :   std_logic;

    -- Mem Controller Monior LEDs
    signal monitor_leds    :   std_logic_vector(5 downto 0);

    -- 1MHz Bus
    signal ext_1mhz_clk    : std_logic; -- the system clock
    signal ext_1mhz_clken  : std_logic; -- a 1MHz strobe, valid for one system clock cycle
    signal ext_1mhz_nrst   : std_logic;
    signal ext_1mhz_pgfc_n : std_logic;
    signal ext_1mhz_pgfd_n : std_logic;
    signal ext_1mhz_r_nw   : std_logic;
    signal ext_1mhz_addr   : std_logic_vector(7 downto 0);
    signal ext_1mhz_di     : std_logic_vector(7 downto 0);
    signal ext_1mhz_do     : std_logic_vector(7 downto 0);

    -- Multiboot
    signal reconfig        : std_logic;
    signal pa_en_dout      : std_logic;

    -- LEDs
    signal multiboot_leds  : std_logic_vector(5 downto 0);
    signal normal_leds     : std_logic_vector(5 downto 0);
    signal soft_leds       : std_logic_vector(7 downto 0) := (others => '0');
    signal ws2812_r        : std_logic_vector(7 downto 0) := (others => '0');
    signal ws2812_g        : std_logic_vector(7 downto 0) := (others => '0');
    signal ws2812_b        : std_logic_vector(7 downto 0) := (others => '0');
    signal ws2812_data     : std_logic;

    -- UART
    signal avr_rx          : std_logic;
    signal avr_tx          : std_logic;
    signal serial_rx       : std_logic;
    signal serial_tx       : std_logic;

    -- Test
    signal test            : std_logic_vector(7 downto 0);

begin

    --------------------------------------------------------
    -- BBC Micro Core
    --------------------------------------------------------

    bbc_micro : entity work.bbc_micro_core
        generic map (
            IncludeAMXMouse        => IncludeAMXMouse,
            IncludeSPISD           => IncludeSPISD,
            IncludeSID             => IncludeSID,
            IncludeMusic5000       => IncludeMusic5000,
            IncludeMusic5000Filter => IncludeMusic5000Filter,
            IncludeMusic5000SPDIF  => false,
            IncludeMixerResampler  => IncludeMixerResampler,
            IncludeICEDebugger     => IncludeICEDebugger,
            IncludeCoPro6502       => IncludeCoPro6502,
            IncludeCoProSPI        => false,
            IncludeCoProExt        => true, -- we need phi2 all the time
            IncludeVideoNuLA       => IncludeVideoNuLA,
            IncludeTrace           => IncludeTrace,
            IncludeSRGB            => IncludeSRGB,
            IncludeVGA             => IncludeVGA,
            IncludeHDMI            => IncludeHDMI,
            IncludeAnalogJS        => IncludeAnalogJS,
            IncludeSerial          => IncludeSerial,
            UseOrigKeyboard        => false,
            UseT65Core             => not IncludeMaster,
            UseAlanDCore           => IncludeMaster
        )
        port map (
            clock_27        => clock_27,
            clock_48        => clock_48,
            clock_avr       => clock_24,
            hard_reset_n    => hard_reset_n,
            powerup_reset_n => powerup_reset_n,
            ps2_kbd_clk     => ps2_clk,
            ps2_kbd_data    => ps2_data,
            ps2_mse_clk     => ps2_mouse_clk,
            ps2_mse_data    => ps2_mouse_data,

            -- SRGB Video
            rgb_red         => rgb_red,
            rgb_green       => rgb_green,
            rgb_blue        => rgb_blue,
            rgb_csync       => rgb_csync,

            -- VGA Video
            vga_red         => vga_red,
            vga_green       => vga_green,
            vga_blue        => vga_blue,
            vga_hsync       => vga_hsync,
            vga_vsync       => vga_vsync,

            audio_l         => open,               -- 16 bit legacy audio
            audio_r         => open,
            audio_src       => audio_src,
            volume          => to_unsigned(VOLUME_FN(to_integer(volume)), 10),
            hd_audio_l      => audio_l,            -- 20 bit HD audio
            hd_audio_r      => audio_r,
            psg_audio       => open,
            psg_strobe      => open,
            sid_audio       => open,
            sid_strobe      => open,
            m5k_filter_en   => m5k_filter_en,
            m5k_audio_l     => open,
            m5k_audio_r     => open,
            m5k_strobe      => open,
            m5k_spdif       => open,
            ext_nOE         => ext_nOE,
            ext_nWE         => ext_nWE,
            ext_nWE_long    => ext_nWE_long,
            ext_nCS         => ext_nCS,
            ext_A           => ext_A,
            ext_A_stb       => ext_A_stb,
            ext_Dout        => ext_Dout,
            ext_Din         => ext_Din,
            SDMISO          => tf_miso,
            SDSS            => tf_cs,
            SDCLK           => tf_sclk,
            SDMOSI          => tf_mosi,
            caps_led        => caps_led,
            shift_led       => shift_led,
            keyb_dip        => keyb_dip,
            ext_keyb_led1   => open,
            ext_keyb_led2   => open,
            ext_keyb_led3   => open,
            ext_keyb_1mhz   => open,
            ext_keyb_en_n   => open,
            ext_keyb_pa     => open,
            ext_keyb_rst_n  => '1',
            ext_keyb_ca2    => '0',
            ext_keyb_pa7    => '0',
            config_key      => config_key,
            config          => config,
            joystick1       => joystick1,
            joystick2       => joystick2,
            adc_ch0         => adc_ch0,
            adc_ch1         => adc_ch1,
            adc_ch2         => adc_ch2,
            adc_ch3         => adc_ch3,
            fire1_n         => joystick1(4),
            fire2_n         => joystick2(4),
            avr_reset       => not hard_reset_n,
            avr_RxD         => avr_rx,
            avr_TxD         => avr_tx,
            serial_RxD      => serial_rx,
            serial_TxD      => serial_tx,
            cpu_addr        => open,
            m128_mode       => m128_mode,
            copro_mode      => copro_mode,
            copro_ext       => copro_ext,
            p_spi_ssel      => '0',
            p_spi_sck       => '0',
            p_spi_mosi      => '0',
            p_spi_miso      => open,
            p_irq_b         => open,
            p_nmi_b         => open,
            p_rst_b         => open,
            ext_tube_r_nw   => ext_tube_r_nw,
            ext_tube_nrst   => ext_tube_nrst,
            ext_tube_ntube  => ext_tube_ntube,
            ext_tube_phi2   => ext_tube_phi2,
            ext_tube_a      => ext_tube_a,
            ext_tube_di     => ext_tube_di,
            ext_tube_do     => ext_tube_do,
            ext_1mhz_clken  => ext_1mhz_clken, -- a 1MHz strobe, valid for one system clock cycle
            ext_1mhz_nrst   => ext_1mhz_nrst,
            ext_1mhz_pgfc_n => ext_1mhz_pgfc_n,
            ext_1mhz_pgfd_n => ext_1mhz_pgfd_n,
            ext_1mhz_r_nw   => ext_1mhz_r_nw,
            ext_1mhz_addr   => ext_1mhz_addr,
            ext_1mhz_di     => ext_1mhz_di,
            ext_1mhz_do     => ext_1mhz_do,
            ext_1mhz_irq_n  => open,
            ext_1mhz_nmi_n  => open,
            hdmi_aspect     => hdmi_aspect,
            hdmi_audio_en   => hdmi_audio_en,
            vid_debug       => vid_debug,
            tmds_r          => tmds_r,
            tmds_g          => tmds_g,
            tmds_b          => tmds_b,
            trace_data      => trace_data,
            trace_r_nw      => trace_r_nw,
            trace_sync      => trace_sync,
            trace_rstn      => trace_rstn,
            trace_phi2      => trace_phi2,
            test            => test
        );

    keyb_dip       <= "00000000";
    vid_debug      <= '0';

    --------------------------------------------------------
    -- Clock Generation
    --------------------------------------------------------

    -- 48 MHz master clock from 135MHz input clock
    -- plus intermediate 96MHz clock for scan doubler

    pll1 : rPLL
        generic map (
            FCLKIN => "135",
            DEVICE => "GW2AR-18C",
            IDIV_SEL => 44,
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

    clock_135 <= sys_clk;

    clkdiv5 : CLKDIV
        generic map (
            DIV_MODE => "5",            -- Divide by 5
            GSREN => "false"
        )
        port map (
            RESETN => '1',
            HCLKIN => clock_135,
            CLKOUT => clock_27,         -- 27MHz HDMI Pixel Clock
            CALIB  => '1'
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

    clkdiv_spdif : CLKDIV
        generic map (
            DIV_MODE => "4",            -- Divide by 4
            GSREN => "false"
        )
        port map (
            RESETN => '1',
            HCLKIN => audio_clk,        -- 24.576MHz audio clock
            CLKOUT => spdif_clk,        --  6.144MHz spdif clock
            CALIB  => '1'
        );

    --------------------------------------------------------
    -- Button 1: Power Up Reset
    --------------------------------------------------------

    -- Generate a reliable power up reset on powerup, if bt1n is
    -- pressed or if trigger_reset is asserted.

    reset_gen : process(clock_48)
    begin
        if rising_edge(clock_48) then
            if btn1 = '1' or trigger_reset = '1' then
                reset_counter <= (others => '0');
            elsif (reset_counter(reset_counter'high) = '0') then
                reset_counter <= reset_counter + 1;
            end if;
            powerup_reset_n <= reset_counter(reset_counter'high);
            hard_reset_n <= not (not powerup_reset_n or not mem_ready);
            -- Config reset forces a read of the config jumpers
            -- Note, don't do this on trigger reset, as this comes
            -- from a config key press, which you would then loose!
            if btn1 = '1' then
                config_reset_n <= '0';
            elsif reset_counter(reset_counter'high) = '1' then
                config_reset_n <= '1';
            end if;
        end if;
    end process;

    --------------------------------------------------------
    -- Multiboot Reconfig
    --------------------------------------------------------

    inst_multiboot : entity work.multiboot
        generic map (
            CORE_ID => G_CORE_ID
            )
        port map (
            clock           => clock_48,
            powerup_reset_n => powerup_reset_n,
            btn1            => btn1,
            btn2            => btn2,
            btn3            => key_conf,
            jumper          => jumper(5 downto 0),
            led             => multiboot_leds,
            pa_en_dout      => pa_en_dout,
            reconfig        => reconfig
            );

    pa_en      <= '0' when pa_en_dout = '0' else 'Z';
    reconfig_n <= '0' when reconfig = '1' else 'Z';

    --------------------------------------------------------
    -- Button 2: Config modifier
    --------------------------------------------------------

    config_key <= btn2;

    --------------------------------------------------------
    -- Config keys F1..F10
    --
    -- These can be activated with one of the following modifiers
    --    Ctrl-LeftAlt
    --    Right-Alt
    --    Btn2
    --    Boot button or KeyConfig jumper
    --
    -- The config options are
    --     Config F1 = Volume down (clamped at MinVolume)
    --     Config F2 = Volume up   (clamped at MaxVolume)
    --     Config F3 = Volume default
    --     Config F4 = M5K Filter (On/Off)
    --     Config F5 = Audio Source (Mixer/Legacy)
    --     Config F6 = HDMI Aspect Ratio (Auto/DVI/16:9/4:3) [**]
    --     Config F7 = Co Pro (Off/Int/Ext)                  [**]
    --     Config F8 = Machine (Beeb/Master)                 [**]
    --     Config F9 = Reserved for serial
    --     Config F10 = Spare
    --
    -- The default for [**] are set by the external config jumpers
    --
    --------------------------------------------------------

    config_gen : process(clock_48)
    begin
        if rising_edge(clock_48) then
            -- The default is for a config key to not trigger a power up reset
            trigger_reset <= '0';

            -- Config(1) is volume down
            if config(1) = '1' and volume > MinVolume then
                volume <= volume - 1;
            end if;

            -- Config (2) is volume up
            if config(2) = '1' and volume < MaxVolume then
                volume <= volume + 1;
            end if;

            -- Config (3) is volume default
            if config(3) = '1' then
                volume <= default_volume;
            end if;

            if IncludeSoftVolume and ext_1mhz_pgfc_n = '0' and ext_1mhz_r_nw = '0' and ext_1mhz_addr = x"54" then
                if ext_1mhz_di > MaxVolume then
                    volume <= to_unsigned(MaxVolume, volume'length);
                elsif ext_1mhz_di < MinVolume then
                    volume <= to_unsigned(MinVolume, volume'length);
                else
                    volume <= unsigned(ext_1mhz_di(volume'length - 1 downto 0));
                end if;
            end if;

            -- Config(4) is M5K Filter on/pff
            if config(4) = '1' then
                m5k_filter_en <= not m5k_filter_en;
            end if;

            -- Config(5) is Audio Source (Mixer/Legacy)
            if config(5) = '1' then
                audio_src <= not audio_src;
            end if;

            -- Config(6) is the HDMI aspect ratio
            if config(6) then
                case hdmi_aspect is
                    when "00" =>
                        hdmi_aspect   <= "01";
                        hdmi_audio_en <=  '1';
                    when "01" =>
                        hdmi_aspect   <= "10";
                        hdmi_audio_en <=  '1';
                    when "10" =>
                        hdmi_aspect   <= "11";
                        hdmi_audio_en <=  '1';
                    when "11" =>
                        hdmi_aspect   <= "00";
                        hdmi_audio_en <=  '0';
                end case;
            end if;

            -- Config(7) is the Co Pro setting
            if config(7) then
                -- Beeb: Cycle Off/Interal/External (if included)
                if copro_mode = '0' then
                    -- Internal
                    copro_mode <= '1';
                    copro_ext <= '0';
                elsif copro_ext = '0' and IncludeCoProExt then
                    -- External
                    copro_mode <= '1';
                    copro_ext <= '1';
                else
                    -- Off
                    copro_mode <= '0';
                    copro_ext <= '0';
                end if;
                -- Trigger a power up reset
                trigger_reset <= '1';
            end if;

            -- Config(8) cycles between Beeb and Master mode if both are included
            if IncludeMaster and IncludeBeeb then
                if Config(8) = '1' then
                    m128_mode     <= not m128_mode;
                    trigger_reset <= '1';
                end if;
            end if;

            -- Config(9) switches the USB uart between the Beeb Serial Port and the ICE debugger
            if IncludeICEDebugger and IncludeSerial then
                if Config(9) = '1' then
                    uart_debugger <= not uart_debugger;
                end if;
            end if;

            -- Config(0) switches between VGA Mode and sRGB mode
            if IncludeVGA and IncludeSRGB then
                if Config(0) = '1' then
                    vga_mode <= not vga_mode;
                end if;
            end if;

            -- Config reset happens just once when the core is first configured
            if config_reset_n = '0' then
                if IncludeMaster and IncludeBeeb then
                    m128_mode <= not jumper(0); -- 0 (on) = Master; 1 (off) = Beeb;
                elsif IncludeMaster then
                    m128_mode <= '1';
                else
                    m128_mode <= '0';
                end if;
                -- Note: External PiTube and the VGADAC are mutually
                -- exclusive, so jumper(3) can be overloaded
                copro_mode    <= not jumper(2); -- 0 (on) = Co Pro Enabled;  1 (off) = Co Pro disabled
                if IncludeVGADAC then
                    copro_ext <= '0';
                    vga_mode  <= not jumper(3); -- 0 (on) = VGA Mode; 1 (off) = SRGB Mode
                else
                    copro_ext <= not jumper(3); -- 0 (on) = External Co Pro; 1 (off) = Internal Co Pro
                    vga_mode  <= '0';
                end if;
                hdmi_aspect   <= "11";      -- default is now auto aspect ratio
                hdmi_audio_en <= jumper(4); -- both jumper fitted (0) triggers DVI mode
                if IncludeICEDebugger and IncludeSerial then
                    uart_debugger <= jumper(5); -- 0 (on) = Serial; 1 (off) = Debugger
                elsif IncludeICEDebugger then
                    uart_debugger <= '1';
                else
                    uart_debugger <= '0';
                end if;
                -- Determine line vs speaker by reading the pa_en jumper
                if pa_en = '0' then
                    default_volume <= to_unsigned(DefaultVolumeLine, 5);
                    volume         <= to_unsigned(DefaultVolumeLine, 5);
                else
                    default_volume <= to_unsigned(DefaultVolumeSpeaker, 5);
                    volume         <= to_unsigned(DefaultVolumeSpeaker, 5);
                end if;
            end if;

        end if;
    end process;


    --------------------------------------------------------
    -- SPDIF
    --------------------------------------------------------

    -- Note: this block assumes a fixed 48KHz sample rate derived
    -- from an external spdif_clk of 6.144MHz, which must be
    -- locked to the main system clock. This constraint is
    -- satisfied by virtue of the way we configure the MS5351A
    -- clock generator.
    --
    -- When legacy audio is selected this is not ideal!
    -- PSG = 125KHz, SID = 1MHz, M5K = 48.487KHz.
    --
    -- It might in this case to switch the SPDIF output to the M5K.

    gen_spdif_audio : if IncludeSPDIFAudio generate
        signal spdif_in        : std_logic_vector(19 downto 0);
        signal channelA        : std_logic;
        signal div64           : unsigned(5 downto 0) := (others => '0');
    begin

        spdif_in <= audio_l when channelA = '1' else audio_r;

        process(spdif_clk)
        begin
            if rising_edge(spdif_clk) then
                div64 <= div64 + 1;
                if div64 = 0 then
                    spdif_load <= '1';
                else
                    spdif_load <= '0';
                end if;
            end if;
        end process;

        spdif_serialize: entity work.spdif_serializer
            port map (
                clk          => spdif_clk,
                clken        => '1',
                auxAudioBits => (others => '0'),
                sample       => spdif_in,
                load         => spdif_load,
                channelA     => channelA,
                spdifOut     => audio_spdif
                );
    end generate;

    gen_no_spdif_audio : if not IncludeSPDIFAudio generate
        audio_spdif <= '1';
    end generate;

    --------------------------------------------------------
    -- Audio DACs
    --------------------------------------------------------

    pwm : if not IncludeAnalogJS generate

        -- Convert from signed to unsigned
        dac_l_in <= (not audio_l(19)) & audio_l(18 downto 10);
        dac_r_in <= (not audio_r(19)) & audio_r(18 downto 10);

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
    end generate;

    --------------------------------------------------------
    -- HDMI Output
    --------------------------------------------------------

    --  Serialize the three 10-bit TMDS channels to three serialized 1-bit TMDS streams

    hdmi : if (IncludeHDMI) generate
        signal serialized_c : std_logic;
        signal serialized_r : std_logic;
        signal serialized_g : std_logic;
        signal serialized_b : std_logic;
    begin

        ser_b : OSER10
            generic map (
                GSREN => "false",
                LSREN => "true"
            )
            port map(
                PCLK  => clock_27,
                FCLK  => clock_135,
                RESET => '0',
                Q     => serialized_b,
                D0    => tmds_b(0),
                D1    => tmds_b(1),
                D2    => tmds_b(2),
                D3    => tmds_b(3),
                D4    => tmds_b(4),
                D5    => tmds_b(5),
                D6    => tmds_b(6),
                D7    => tmds_b(7),
                D8    => tmds_b(8),
                D9    => tmds_b(9)
            );

        ser_g : OSER10
            generic map (
                GSREN => "false",
                LSREN => "true"
            )
            port map (
                PCLK  => clock_27,
                FCLK  => clock_135,
                RESET => '0',
                Q     => serialized_g,
                D0    => tmds_g(0),
                D1    => tmds_g(1),
                D2    => tmds_g(2),
                D3    => tmds_g(3),
                D4    => tmds_g(4),
                D5    => tmds_g(5),
                D6    => tmds_g(6),
                D7    => tmds_g(7),
                D8    => tmds_g(8),
                D9    => tmds_g(9)
            );

        ser_r : OSER10
            generic map (
                GSREN => "false",
                LSREN => "true"
            )
            port map (
                PCLK  => clock_27,
                FCLK  => clock_135,
                RESET => '0',
                Q     => serialized_r,
                D0    => tmds_r(0),
                D1    => tmds_r(1),
                D2    => tmds_r(2),
                D3    => tmds_r(3),
                D4    => tmds_r(4),
                D5    => tmds_r(5),
                D6    => tmds_r(6),
                D7    => tmds_r(7),
                D8    => tmds_r(8),
                D9    => tmds_r(9)
                );

        ser_c : OSER10
            generic map (
                GSREN => "false",
                LSREN => "true"
            )
            port map (
                PCLK  => clock_27,
                FCLK  => clock_135,
                RESET => '0',
                Q     => serialized_c,
                D0    => '1',
                D1    => '1',
                D2    => '1',
                D3    => '1',
                D4    => '1',
                D5    => '0',
                D6    => '0',
                D7    => '0',
                D8    => '0',
                D9    => '0'
            );

        -- Encode the 1-bit serialized TMDS streams to Low-voltage differential signaling (LVDS) HDMI output pins

        OBUFDS_c : ELVDS_OBUF
            port map (
                I  => serialized_c,
                O  => tmds_clk_p,
                OB => tmds_clk_n
             );

        OBUFDS_b : ELVDS_OBUF
            port map (
                I  => serialized_b,
                O  => tmds_d_p(0),
                OB => tmds_d_n(0)
            );

        OBUFDS_g : ELVDS_OBUF
            port map (
                I  => serialized_g,
                O  => tmds_d_p(1),
                OB => tmds_d_n(1)
            );

        OBUFDS_r : ELVDS_OBUF
            port map (
                I  => serialized_r,
                O  => tmds_d_p(2),
                OB => tmds_d_n(2)
            );

    end generate;

    --------------------------------------------------------
    -- I2S Audio
    --------------------------------------------------------

    -- For the MAX98357A (on the Tang Nano 20K)
    -- and the CS4354 (on the Dock board)

    -- The CS4354 has LRCLK polarity Left=0 Right=1 but the datasheet
    -- is ambiguous as to which of AOUTA/B is Left/Right. On the Tang
    -- Nano 20K PCB I guessed that AOUTA was Left, but this appear to
    -- be wrong. So we swap then here.

    -- This also swaps the polarity for the MAX98357A, but as we'd
    -- like to use this in mono mode (output = L/2 + R/2) then that
    -- shouldn't matter.

    gen_i2s : if IncludeI2SAudio generate
    begin
        i2s : entity work.i2s_simple
            generic map (
                ATTENUATE  => 0,         -- No attenuation, allows use of full dynamic range
                CLOCKSPEED => 6144000,   -- SPDIF Clock
                SAMPLERATE => 48000      -- Output sample rate of new audio resampler
                )
            port map (
                clock      => spdif_clk,
                reset_n    => '1',       -- Avoid a nasty click on powerup_reset_n
                audio_l    => audio_r,   -- Swapped, see comment above
                audio_r    => audio_l,   -- Swapped, see comment above
                i2s_lrclk  => i2s_lrclk,
                i2s_bclk   => i2s_bclk,
                i2s_din    => i2s_din
                );
        i2s_mclk <= audio_clk;
    end generate;

    not_gen_i2s : if not IncludeI2SAudio generate
        i2s_mclk   <= 'Z';
        i2s_lrclk  <= 'Z';
        i2s_bclk   <= 'Z';
        i2s_din    <= 'Z';
    end generate;

    --------------------------------------------------------
    -- SDRAM Memory Controller
    --------------------------------------------------------

    e_mem: entity work.mem_tang_20k
        generic map (
            SIM => SIM,
            IncludeMonitor => IncludeMonitor,
            IncludeBootStrap => IncludeBootStrap,
            IncludeMinimalBeeb => false,
            IncludeMinimalMaster => false,
            PRJ_ROOT => PRJ_ROOT,
            MOS_NAME => MOS_NAME
        )
        port map (
            m128_mode      => m128_mode,
            RST_n          => powerup_reset_n,
            READY          => mem_ready,
            CLK_96         => clock_96,
            CLK_96_p       => clock_96_p,
            CLK_48         => clock_48,
            core_A_stb     => ext_A_stb,
            core_A         => ext_A,
            core_Din       => ext_Din,
            core_Dout      => ext_Dout,
            core_nCS       => ext_nCS,
            core_nWE       => ext_nWE,
            core_nWE_long  => ext_nWE_long,
            core_nOE       => ext_nOE,

            O_sdram_clk    => O_sdram_clk     ,
            O_sdram_cke    => O_sdram_cke     ,
            O_sdram_cs_n   => O_sdram_cs_n    ,
            O_sdram_cas_n  => O_sdram_cas_n   ,
            O_sdram_ras_n  => O_sdram_ras_n   ,
            O_sdram_wen_n  => O_sdram_wen_n   ,
            IO_sdram_dq    => IO_sdram_dq     ,
            O_sdram_addr   => O_sdram_addr    ,
            O_sdram_ba     => O_sdram_ba      ,
            O_sdram_dqm    => O_sdram_dqm     ,

            led            => monitor_leds,

            FLASH_CS       => flash_cs,
            FLASH_SI       => flash_si,
            FLASH_CK       => flash_ck,
            FLASH_SO       => flash_so
        );

    --------------------------------------------------------
    -- 1MHz Bus LEDs
    --------------------------------------------------------

    GenSoftLEDs: if IncludeSoftLEDs generate

        function bit_reverse (a: in std_logic_vector)
            return std_logic_vector is
            variable result: std_logic_vector(a'RANGE);
            alias aa: std_logic_vector(a'REVERSE_RANGE) is a;
        begin
            for i in aa'RANGE loop
                result(i) := aa(i);
            end loop;
            return result;
        end;

    begin

        -- This module is in Verilog and comes from MisteryNano
        inst_ws2812 : entity work.ws2812
            port map (
                clk   => clock_48,
                color => bit_reverse(ws2812_g & ws2812_r & ws2812_b),
                data  => ws2812_data
                );

        process(clock_48)
        begin
            if rising_edge(clock_48) then
                if ext_1mhz_clken = '1' then
                    if ext_1mhz_nrst = '0' then
                        soft_leds <= x"00";
                        ws2812_r  <= x"00";
                        ws2812_g  <= x"00";
                        ws2812_b  <= x"00";
                    elsif ext_1mhz_pgfc_n = '0' and ext_1mhz_r_nw = '0' then
                        case ext_1mhz_addr is
                            when x"50" =>
                                soft_leds <= ext_1mhz_di;
                            when x"51" =>
                                ws2812_r  <= ext_1mhz_di;
                            when x"52" =>
                                ws2812_g  <= ext_1mhz_di;
                            when x"53" =>
                                ws2812_b  <= ext_1mhz_di;
                            when others =>
                                null;
                        end case;
                    end if;
                end if;
            end if;
        end process;
    end generate;

--------------------------------------------------------
-- VGA / SRGB output
--------------------------------------------------------

    -- Note: It's a build error if both IncludeVGADAC and IncludeCoProExt are both set

    -- Mux to select between SRGB and VGA if both are included

    dac_red   <= vga_red   when IncludeVGA  and (vga_mode = '1' or not IncludeSRGB) else
                 rgb_red   when IncludeSRGB and (vga_mode = '0' or not IncludeVGA)  else
                 (others => '0');
    dac_green <= vga_green when IncludeVGA  and (vga_mode = '1' or not IncludeSRGB) else
                 rgb_green when IncludeSRGB and (vga_mode = '0' or not IncludeVGA)  else
                 (others => '0');
    dac_blue  <= vga_blue  when IncludeVGA  and (vga_mode = '1' or not IncludeSRGB) else
                 rgb_blue  when IncludeSRGB and (vga_mode = '0' or not IncludeVGA)  else
                 (others => '0');
    dac_hsync <= vga_hsync when IncludeVGA  and (vga_mode = '1' or not IncludeSRGB) else
                 rgb_csync when IncludeSRGB and (vga_mode = '0' or not IncludeVGA)  else
                 '0';
    dac_vsync <= vga_vsync when IncludeVGA  and (vga_mode = '1' or not IncludeSRGB) else
                 '1'       when IncludeSRGB and (vga_mode = '0' or not IncludeVGA)  else
                 '0';

    -- Note: It's a build error if both IncludeVGADAC and IncludeCoProExt are both set

    vga_1bit_dac : if IncludeVGADAC generate
        signal vga_r_int       : std_logic;
        signal vga_g_int       : std_logic;
        signal vga_b_int       : std_logic;

        signal clk_sample      : std_logic;
        signal clk_dac_px      : std_logic;
        signal clk_dac         : std_logic;
        signal clk_sel         : std_logic_vector(3 downto 0);

        signal fbdsel          : std_logic_vector(5 downto 0);
        signal idsel           : std_logic_vector(5 downto 0);
        signal odsel           : std_logic_vector(5 downto 0);

    begin

        -- Use a dynamic clock switch (DCS) clock mux to select the
        -- appropriate sample clock with minimal latency.

        clk_sel <= "00" & vga_mode & not vga_mode;

        dcs1 : DCS port map (
            CLK0     => clock_48,
            CLK1     => clock_27,
            CLK2     => '0',
            CLK3     => '0',
            CLKSEL   => clk_sel,
            SELFORCE => '1',
            CLKOUT   => clk_sample
            );

        -- Use a PLL to generate the fast DAC clocks and vary the dividers to
        -- get the appropriate frequencies:
        -- 135 / 1 * 3 = 405MHz for VGA
        -- 135 / 3 * 8 = 360MHz for SRGB

        -- IDIV/FBDIV/ODIV values for generics, e.g. from PLL calculator:
        -- 0/2/2 = 405MHz for VGA
        -- 2/7/2 = 360MHz for SRGB

        -- But the values used in the dynamic ports are formatted differently.
        -- IDIV/FBDIV are basically 64 - the actual divider, or 63 - the generic value
        -- ODIV is slighly different
        -- 63/61/63 = 405MHz for VGA
        -- 61/56/63 = 360MHz for SRGB

        idsel   <= "111111" when vga_mode = '1' else "111101";
        fbdsel  <= "111101" when vga_mode = '1' else "111000";
        odsel   <= "111111";

        pll2 : rPLL
            generic map (
                FCLKIN => "135",
                DEVICE => "GW2AR-18C",
                DYN_IDIV_SEL => "true",
                DYN_FBDIV_SEL => "true",
                DYN_ODIV_SEL => "true"
                )
            port map (
                CLKIN    => clock_135,
                CLKOUT   => clk_dac,        -- 405MHz VGA 1-bit DAC clock
                CLKOUTP  => open,
                CLKOUTD  => open,
                CLKOUTD3 => open,
                LOCK     => open,
                RESET    => '0',
                RESET_P  => '0',
                CLKFB    => '0',
                IDSEL    => idsel,
                FBDSEL   => fbdsel,
                ODSEL    => odsel,
                PSDA     => (others => '0'),
                DUTYDA   => (others => '0'),
                FDLY     => (others => '0')
                );

        clkdiv_dac : CLKDIV
            generic map (
                DIV_MODE => "5",
                GSREN => "false"
                )
            port map (
                RESETN => '1',
                HCLKIN => clk_dac,
                CLKOUT => clk_dac_px,
                CALIB  => '1'
                );

        e_vidr:entity work.dac1_oser
            port map (
                rst_i               => not hard_reset_n,
                clk_sample_i        => clk_sample,
                clk_dac_px_i        => clk_dac_px,
                clk_dac_i           => clk_dac,
                sample_i            => unsigned(dac_red),
                bitstream_o         => vga_r_int
                );
        e_vidg:entity work.dac1_oser
            port map (
                rst_i               => not hard_reset_n,
                clk_sample_i        => clk_sample,
                clk_dac_px_i        => clk_dac_px,
                clk_dac_i           => clk_dac,
                sample_i            => unsigned(dac_green),
                bitstream_o         => vga_g_int
                );
        e_vidb:entity work.dac1_oser
            port map (
                rst_i               => not hard_reset_n,
                clk_sample_i        => clk_sample,
                clk_dac_px_i        => clk_dac_px,
                clk_dac_i           => clk_dac,
                sample_i            => unsigned(dac_blue),
                bitstream_o         => vga_b_int
                );

        -- Manually instantiate differential output buffers to avoid
        -- warning about vga_x_n being unused.

        OBUFDS_r : ELVDS_OBUF
            port map (
                I  => vga_r_int,
                O  => vga_r,
                OB => vga_r_n
             );

        OBUFDS_g : ELVDS_OBUF
            port map (
                I  => vga_g_int,
                O  => vga_g,
                OB => vga_g_n
             );

        OBUFDS_b : ELVDS_OBUF
            port map (
                I  => vga_b_int,
                O  => vga_b,
                OB => vga_b_n
             );

        vga_hs <= dac_hsync;
        vga_vs <= dac_vsync;

    end generate;

    not_vga_1bit_dac : if not IncludeVGADAC and not includeCoProExt generate

        -- Manually instantiate differential output buffers to avoid
        -- warning about vga_x_n being unused.

        OBUFDS_r : ELVDS_OBUF
            port map (
                I  => dac_red(dac_red'high),
                O  => vga_r,
                OB => vga_r_n
             );

        OBUFDS_g : ELVDS_OBUF
            port map (
                I  => dac_green(dac_green'high),
                O  => vga_g,
                OB => vga_g_n
             );

        OBUFDS_b : ELVDS_OBUF
            port map (
                I  => dac_blue(dac_blue'high),
                O  => vga_b,
                OB => vga_b_n
                );

        vga_hs <= dac_hsync;
        vga_vs <= dac_vsync;

    end generate;

--------------------------------------------------------
-- External tube connections
--------------------------------------------------------

    -- Note: It's a build error if both IncludeVGADAC and IncludeCoProExt are both set

    GenCoProExt: if IncludeCoProExt generate
    begin
        ext_tube_do  <= vga_g & vga_b_n & vga_vs & vga_hs & vga_r_n & vga_b & vga_g_n & vga_r;

        vga_g   <= ext_tube_di(7) when ext_tube_r_nw = '0' and ext_tube_phi2 = '1' else 'Z';
        vga_b_n <= ext_tube_di(6) when ext_tube_r_nw = '0' and ext_tube_phi2 = '1' else 'Z';
        vga_vs  <= ext_tube_di(5) when ext_tube_r_nw = '0' and ext_tube_phi2 = '1' else 'Z';
        vga_hs  <= ext_tube_di(4) when ext_tube_r_nw = '0' and ext_tube_phi2 = '1' else 'Z';
        vga_r_n <= ext_tube_di(3) when ext_tube_r_nw = '0' and ext_tube_phi2 = '1' else 'Z';
        vga_b   <= ext_tube_di(2) when ext_tube_r_nw = '0' and ext_tube_phi2 = '1' else 'Z';
        vga_g_n <= ext_tube_di(1) when ext_tube_r_nw = '0' and ext_tube_phi2 = '1' else 'Z';
        vga_r   <= ext_tube_di(0) when ext_tube_r_nw = '0' and ext_tube_phi2 = '1' else 'Z';

        ext_tube_ctrl(5) <= ext_tube_nrst;
        ext_tube_ctrl(4) <= ext_tube_a(2);
        ext_tube_ctrl(3) <= ext_tube_a(1);
        ext_tube_ctrl(2) <= ext_tube_ntube;
        ext_tube_ctrl(1) <= ext_tube_r_nw;
        ext_tube_ctrl(0) <= ext_tube_a(0);

    end generate;

    GenCoProNotExt: if not IncludeCoProExt generate
    begin
        ext_tube_do  <= x"FE";
        ext_tube_ctrl <= (others => '1');
    end generate;

--------------------------------------------------------
-- External shift register for joysticks / config links
--------------------------------------------------------

    sr : entity work.shift_register
        port map (
            clock     => clock_48,
            js_clk    => ext_tube_phi2,
            js_data   => js_data,
            js_load_n => js_load_n,
            joystick1 => joystick1,
            joystick2 => joystick2,
            jumper    => jumper
        );

--------------------------------------------------------
-- Analog Joystick via I2C
--------------------------------------------------------

    analog_js : if IncludeAnalogJS generate
        signal inst_address : std_logic_vector(9 downto 0);
        signal inst_data    : std_logic_vector(8 downto 0);
        signal reg_addr     : std_logic_vector(4 downto 0);
        signal reg_data     : std_logic_vector(7 downto 0);
        signal msb          : std_logic_vector(6 downto 0);
        signal reg_write    : std_logic;
        signal i2c_scl      : std_logic;
        signal i2c_sda_i    : std_logic;
        signal i2c_sda_o    : std_logic;
        signal i2c_sda_t    : std_logic;
    begin

        -- I3C2 source and assembler to generate this program is in ../tools
        process(clock_48)
        begin
            if rising_edge(clock_48) then
                case inst_address is
                    when "0000000000" => inst_data <= "110010000"; -- WRITE 0x90 ; Device address + write
                    when "0000000001" => inst_data <= "100000001"; -- WRITE 0x01 ; Select config register
                    when "0000000010" => inst_data <= "111000101"; -- WRITE 0xC5 ; Config MSB (Start conversion Ch0)
                    when "0000000011" => inst_data <= "111100011"; -- WRITE 0xE3 ; Config LSB
                    when "0000000100" => inst_data <= "011111111"; -- STOP       ; End tx
                    when "0000000101" => inst_data <= "011101010"; -- DELAY 1024 ; wait ~2.5ms for conversion
                    when "0000000110" => inst_data <= "110010000"; -- WRITE 0x90 ; Device address + write
                    when "0000000111" => inst_data <= "100000000"; -- WRITE 0x00 ; Select conversion register
                    when "0000001000" => inst_data <= "011111111"; -- STOP
                    when "0000001001" => inst_data <= "110010001"; -- WRITE 0x91 ; Device address + read
                    when "0000001010" => inst_data <= "011000100"; -- READ  4
                    when "0000001011" => inst_data <= "011000000"; -- READ  0
                    when "0000001100" => inst_data <= "011111111"; -- STOP
                    when "0000001101" => inst_data <= "110010000"; -- WRITE 0x90 ; Device address + write
                    when "0000001110" => inst_data <= "100000001"; -- WRITE 0x01 ; Select config register
                    when "0000001111" => inst_data <= "111010101"; -- WRITE 0xD5 ; Config MSB (Start conversion Ch1)
                    when "0000010000" => inst_data <= "111100011"; -- WRITE 0xE3 ; Config LSB
                    when "0000010001" => inst_data <= "011111111"; -- STOP       ; End tx
                    when "0000010010" => inst_data <= "011101010"; -- DELAY 1024 ; wait ~2.5ms for conversion
                    when "0000010011" => inst_data <= "110010000"; -- WRITE 0x90 ; Device address + write
                    when "0000010100" => inst_data <= "100000000"; -- WRITE 0x00 ; Select conversion register
                    when "0000010101" => inst_data <= "011111111"; -- STOP
                    when "0000010110" => inst_data <= "110010001"; -- WRITE 0x91 ; Device address + read
                    when "0000010111" => inst_data <= "011000100"; -- READ  4
                    when "0000011000" => inst_data <= "011000001"; -- READ  1
                    when "0000011001" => inst_data <= "011111111"; -- STOP
                    when "0000011010" => inst_data <= "110010000"; -- WRITE 0x90 ; Device address + write
                    when "0000011011" => inst_data <= "100000001"; -- WRITE 0x01 ; Select config register
                    when "0000011100" => inst_data <= "111100101"; -- WRITE 0xE5 ; Config MSB (Start conversion Ch2)
                    when "0000011101" => inst_data <= "111100011"; -- WRITE 0xE3 ; Config LSB
                    when "0000011110" => inst_data <= "011111111"; -- STOP       ; End tx
                    when "0000011111" => inst_data <= "011101010"; -- DELAY 1024 ; wait ~2.5ms for conversion
                    when "0000100000" => inst_data <= "110010000"; -- WRITE 0x90 ; Device address + write
                    when "0000100001" => inst_data <= "100000000"; -- WRITE 0x00 ; Select conversion register
                    when "0000100010" => inst_data <= "011111111"; -- STOP
                    when "0000100011" => inst_data <= "110010001"; -- WRITE 0x91 ; Device address + read
                    when "0000100100" => inst_data <= "011000100"; -- READ  4
                    when "0000100101" => inst_data <= "011000010"; -- READ  2
                    when "0000100110" => inst_data <= "011111111"; -- STOP
                    when "0000100111" => inst_data <= "110010000"; -- WRITE 0x90 ; Device address + write
                    when "0000101000" => inst_data <= "100000001"; -- WRITE 0x01 ; Select config register
                    when "0000101001" => inst_data <= "111110101"; -- WRITE 0xF5 ; Config MSB (Start conversion Ch3)
                    when "0000101010" => inst_data <= "111100011"; -- WRITE 0xE3 ; Config LSB
                    when "0000101011" => inst_data <= "011111111"; -- STOP       ; End tx
                    when "0000101100" => inst_data <= "011101010"; -- DELAY 1024 ; wait ~2.5ms for conversion
                    when "0000101101" => inst_data <= "110010000"; -- WRITE 0x90 ; Device address + write
                    when "0000101110" => inst_data <= "100000000"; -- WRITE 0x00 ; Select conversion register
                    when "0000101111" => inst_data <= "011111111"; -- STOP
                    when "0000110000" => inst_data <= "110010001"; -- WRITE 0x91 ; Device address + read
                    when "0000110001" => inst_data <= "011000100"; -- READ  4
                    when "0000110010" => inst_data <= "011000011"; -- READ  3
                    when "0000110011" => inst_data <= "011111111"; -- STOP
                    when "0000110100" => inst_data <= "010110000"; -- SET   0    ; Indicate that new, consistent data is available
                    when "0000110101" => inst_data <= "010100000"; -- CLEAR 0
                    when "0000110110" => inst_data <= "000000000"; -- JUMP loop
                    when others => inst_data <= (others =>'0');
                end case;
            end if;
        end process;

        inst_i3c2 : entity work.i3c2
            generic map (
                clk_divide   => x"78" -- 0x78 = 120 to give 400KHz
                )
            port map (
                clk          => clock_48,
                inst_address => inst_address,
                inst_data    => inst_data,
                i2c_scl      => i2c_scl,
                i2c_sda_i    => i2c_sda_i,
                i2c_sda_o    => i2c_sda_o,
                i2c_sda_t    => i2c_sda_t,
                inputs       => (others => '0'),
                outputs      => open,
                reg_addr     => reg_addr,
                reg_data     => reg_data,
                reg_write    => reg_write,
                debug_scl    => open,
                debug_sda    => open,
                error        => open
                );

        process(clock_48)
        begin
            if rising_edge(clock_48) then
                if reg_write = '1' then
                    case reg_addr is
                        when "00000" =>
                            adc_ch0 <= msb & reg_data(7 downto 3);
                        when "00001" =>
                            adc_ch1 <= msb & reg_data(7 downto 3);
                        when "00010" =>
                            adc_ch2 <= msb & reg_data(7 downto 3);
                        when "00011" =>
                            adc_ch3 <= msb & reg_data(7 downto 3);
                        when "00100" =>
                            if reg_data(7) = '0' then
                                msb <= reg_data(6 downto 0);
                            else
                                -- should not see negative values, but clamp at zero anyway
                                msb <= (others => '0');
                            end if;
                        when others =>
                            null;
                    end case;
                end if;
            end if;
        end process;

        audiol    <= i2c_scl;
        audior    <= i2c_sda_o when i2c_sda_t = '0' else 'Z';
        i2c_sda_i <= audior;

    end generate;

    not_analog_js : if not IncludeAnalogJS generate
        adc_ch0 <= (others => '0');
        adc_ch1 <= (others => '0');
        adc_ch2 <= (others => '0');
        adc_ch3 <= (others => '0');
    end generate;

--------------------------------------------------------
-- Outputs/signals whose function depends on the Includes
--------------------------------------------------------

    js_clk <= ext_tube_phi2;

    normal_leds <= (caps_led & shift_led & m5k_filter_en & clip_led & audio_src & hdmi_audio_en) xor "111111";

    led <= ext_tube_ctrl                      when IncludeCoProExt                                  else
           multiboot_leds                     when G_CORE_ID >= 0 and powerup_reset_n = '0'         else
           soft_leds(5 downto 0) xor "111111" when IncludeSoftLEDs and soft_leds(7 downto 6) = "10" else
           test(5 downto 0)      xor "111111" when IncludeSoftLEDs and soft_leds(7 downto 6) = "11" else
           monitor_leds                       when IncludeMonitor                                   else
           normal_leds;

    process(clock_48)
    begin
        if rising_edge(clock_48) then
            if ext_1mhz_addr < 32 then
                version_rom_byte <= std_logic_vector(version_rom(conv_integer(ext_1mhz_addr(4 downto 0))));
            else
                version_rom_byte <= x"00";
            end if;
        end if;
    end process;

    ext_1mhz_do <= soft_leds                  when IncludeSoftLEDs   and ext_1mhz_addr = x"50" and ext_1mhz_pgfc_n = '0' else
                   ws2812_r                   when IncludeSoftLEDs   and ext_1mhz_addr = x"51" and ext_1mhz_pgfc_n = '0' else
                   ws2812_g                   when IncludeSoftLEDs   and ext_1mhz_addr = x"52" and ext_1mhz_pgfc_n = '0' else
                   ws2812_b                   when IncludeSoftLEDs   and ext_1mhz_addr = x"53" and ext_1mhz_pgfc_n = '0' else
             "000" & std_logic_vector(volume) when IncludeSoftVolume and ext_1mhz_addr = x"54" and ext_1mhz_pgfc_n = '0' else
                   version_rom_byte           when                                                 ext_1mhz_pgfd_n = '0' else
                   x"FF";

    ws2812_din <= ws2812_data when IncludeSoftLEDs else '0';

    uart_tx   <= avr_tx  when uart_debugger = '1' else serial_tx;
    serial_rx <= '0'     when uart_debugger = '1' else uart_rx;
    avr_rx    <= uart_rx when uart_debugger = '1' else '1';

end architecture;
