-- BBC Master / BBC B for the Tang Nano 25K
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

entity bbc_micro_tang25k is
    generic (
        IncludeMaster          : boolean := true; -- if both included, the CPU is the AlanD 65C02
        IncludeBeeb            : boolean := true; -- and btn1 can toggle between the ROM images

        IncludeAMXMouse        : boolean := false;
        IncludeSPISD           : boolean := true;
        IncludeSID             : boolean := true;
        IncludeMusic5000       : boolean := true;
        IncludeMusic5000Filter : boolean := true; -- Music 5000 Low Pass IIR Filter
        IncludeMusic5000SPDIF  : boolean := false; -- Music 5000 20-bit SPDIF Output
        IncludeMixerResampler  : boolean := true;
        IncludeICEDebugger     : boolean := G_CONFIG_DEBUGGER;
        IncludeVideoNuLA       : boolean := true;
        IncludeTrace           : boolean := true;
        IncludeHDMI            : boolean := true;
        IncludeBootStrap       : boolean := true;
        IncludeMonitor         : boolean := false; -- So we see the normal status LEDs
        IncludeCoPro6502       : boolean := true;
        IncludeSoftLEDs        : boolean := true;
        IncludeI2SAudio        : boolean := true;

        MinVolume              : integer := 0;  -- -60dB
        DefaultVolume          : integer := 10; -- -30dB
        MaxVolume              : integer := 20; --   0dB

        PRJ_ROOT               : string  := "../../../..";
        MOS_NAME               : string  := "/roms/bbcb/os12_basic.bit";
        SIM                    : boolean := false
        );
    port (
        brd_clk_50      : in    std_logic;     -- 50MHz clock from the oscillator (pin 4)

        btn1            : in    std_logic;     -- Toggle Master / Beeb modes
        btn2            : in    std_logic;     -- Toggle HDMI / DVI modes

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
        tf_uk_dat1      : inout std_logic;
        tf_uk_dat2      : inout std_logic;

        -- USB UART
        uart_rx         : in    std_logic;
        uart_tx         : out   std_logic;

        -- HDMI
        tmds_clk_p      : out   std_logic;
        tmds_clk_n      : out   std_logic;
        tmds_d_p        : out   std_logic_vector(2 downto 0);
        tmds_d_n        : out   std_logic_vector(2 downto 0);

        -- VGA
        vga_r           : out   std_logic;
        vga_b           : out   std_logic;
        vga_g           : out   std_logic;
        vga_hs          : out   std_logic;
        vga_vs          : out   std_logic;

        -- sdram interface
        sdram_clk_o     :  out   std_logic;
        sdram_DQ_io     :  inout std_logic_vector(15 downto 0);
        sdram_A_o       :  out   std_logic_vector(12 downto 0); 
        sdram_BS_o      :  out   std_logic_vector(1 downto 0); 
        --sdram_CKE_o   :  out   std_logic;
        sdram_nCS_o     :  out   std_logic;
        sdram_nRAS_o    :  out   std_logic;
        sdram_nCAS_o    :  out   std_logic;
        sdram_nWE_o     :  out   std_logic;
        sdram_DQM_o     :  out   std_logic_vector(1 downto 0);

        -- SPI Flash (for ROM data)
        flash_cs        : out   std_logic;     -- Active low FLASH chip select
        flash_si        : out   std_logic;     -- Serial output to FLASH chip SI pin
        flash_ck        : out   std_logic;     -- FLASH clock
        flash_so        : in    std_logic;     -- Serial input from FLASH chip SO pin
        flash_uk_wp     : inout std_logic;
        flash_uk_hold   : inout std_logic;

        brd_led_o       : out std_logic_vector(1 downto 0)
        );
end entity;

architecture rtl of bbc_micro_tang25k is

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
            DIV_MODE : string := "2"
        );
        port (
            CLKOUT: out std_logic;
            HCLKIN: in std_logic;
            RESETN: in std_logic;
            CALIB: in std_logic
        );
    end component;

    component OSER10
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
    signal clock_27        : std_logic;
    signal clock_48        : std_logic;
    signal clock_96        : std_logic;
    signal clock_96_p      : std_logic;
    signal clock_135       : std_logic;
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
    signal mixer_spdif     : std_logic;

    ---test output toggled by the mixer_strobe (system clock domain)
    -- for comparison with spdif_load
    signal toggle          : std_logic := '0';


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


    -- HDMI
    signal hdmi_aspect     : std_logic_vector(1 downto 0);
    signal hdmi_audio_en   : std_logic := '1';
    signal hdmi_audio_src  : std_logic := '1'; -- Sample Rate Convert HDMI Audio
    signal hdmi_audio_l    : std_logic_vector(15 downto 0);
    signal hdmi_audio_r    : std_logic_vector(15 downto 0);
    signal vid_debug       : std_logic;
    signal tmds_r          : std_logic_vector(9 downto 0);
    signal tmds_g          : std_logic_vector(9 downto 0);
    signal tmds_b          : std_logic_vector(9 downto 0);

    -- CPU tracing
    signal trace_data      :   std_logic_vector(7 downto 0);
    signal trace_r_nw      :   std_logic;
    signal trace_sync      :   std_logic;
    signal trace_rstn      :   std_logic;
    signal trace_phi2      :   std_logic;

    -- Mem Controller Monior LEDs
    signal monitor_leds    :   std_logic_vector(5 downto 0);

    -- HDMI PLL synchronization
    signal hsync_ref       : std_logic;
    signal hsync_del       : std_logic_vector(4 downto 0) := (others => '0');
    signal clkdiv_reset_n  : std_logic := '0';
    signal pll1_lock       : std_logic;
    signal pll2_lock       : std_logic;

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

begin
    -- unused pins --
    tf_uk_dat1 <= 'Z';
    tf_uk_dat2 <= 'Z';

    flash_uk_wp <= '0';
    flash_uk_hold <= '1';

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
            IncludeMusic5000SPDIF  => IncludeMusic5000SPDIF,
            IncludeICEDebugger     => IncludeICEDebugger,
            IncludeCoPro6502       => IncludeCoPro6502,
            IncludeCoProSPI        => false,
            IncludeCoProExt        => false,
            IncludeVideoNuLA       => IncludeVideoNuLA,
            IncludeTrace           => IncludeTrace,
            IncludeHDMI            => IncludeHDMI,
            UseOrigKeyboard        => false,
            UseT65Core             => not IncludeMaster,
            UseAlanDCore           => IncludeMaster
        )
        port map (
            clock_27        => clock_27,
            clock_32        => '0',                 -- Unused now in the core
            clock_48        => clock_48,
            clock_96        => clock_96,
            clock_avr       => clock_24,
            hard_reset_n    => hard_reset_n,
            powerup_reset_n => powerup_reset_n,
            ps2_kbd_clk     => ps2_clk,
            ps2_kbd_data    => ps2_data,
            ps2_mse_clk     => ps2_mouse_clk,
            ps2_mse_data    => ps2_mouse_data,
            video_red       => i_VGA_R,
            video_green     => i_VGA_G,
            video_blue      => i_VGA_B,
            video_hsync     => vga_hs,
            video_vsync     => vga_vs,
            audio_l         => audio_l_legacy,
            audio_r         => audio_r_legacy,
            hdmi_audio_ext  => '1',
            hdmi_audio_l    => hdmi_audio_l,
            hdmi_audio_r    => hdmi_audio_r,
            psg_audio       => psg_audio,
            psg_strobe      => psg_strobe,
            sid_audio       => sid_audio,
            sid_strobe      => sid_strobe,
            m5k_filter_en   => m5k_filter_en,
            m5k_audio_l     => m5k_audio_l,
            m5k_audio_r     => m5k_audio_r,
            m5k_strobe      => m5k_strobe,
            m5k_spdif       => m5k_spdif,
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
            config          => config,
            vid_mode        => vid_mode,
            joystick1       => (others => '1'),
            joystick2       => (others => '1'),
            avr_reset       => not hard_reset_n,
            avr_RxD         => uart_rx,
            avr_TxD         => uart_tx,
            cpu_addr        => open,
            m128_mode       => m128_mode,
            copro_mode      => copro_mode,
            p_spi_ssel      => '0',
            p_spi_sck       => '0',
            p_spi_mosi      => '0',
            p_spi_miso      => open,
            p_irq_b         => open,
            p_nmi_b         => open,
            p_rst_b         => open,
            ext_tube_r_nw   => open,
            ext_tube_nrst   => open,
            ext_tube_ntube  => open,
            ext_tube_phi2   => open,
            ext_tube_a      => open,
            ext_tube_di     => open,
            ext_tube_do     => (others => '0'),
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
            hdmi_aspect     => hdmi_aspect,
            hdmi_audio_en   => hdmi_audio_en,
            vid_debug       => vid_debug,
            tmds_r          => tmds_r,
            tmds_g          => tmds_g,
            tmds_b          => tmds_b,
            hsync_ref       => hsync_ref,
            trace_data      => trace_data,
            trace_r_nw      => trace_r_nw,
            trace_sync      => trace_sync,
            trace_rstn      => trace_rstn,
            trace_phi2      => trace_phi2,
            test            => test
        );

    vid_mode       <= "0001" when IncludeHDMI else "0000";
    keyb_dip       <= "00000000";
    hdmi_aspect    <= "00";
    vid_debug      <= '0';

    --------------------------------------------------------
    -- Clock Generation
    --------------------------------------------------------


    -- pll_27_135 generates the 27/135 clock for HDMI and video
    -- the 27MHz clock is also used to generate 48/96/96p
    e_pll_27_135: entity work.pll_27_135
    port map (
        lock        => pll1_lock,
        clkout0     => clock_27,            -- pixel clock
        clkout1     => clock_135,           -- hdmi serial clock
        clkin       => brd_clk_50
    );

    -- generate 48, 96, 96p for main system clock and sdram
    e_pll_48_96: entity work.pll_48_96
    port map (
        lock        => pll2_lock,
        clkout0     => clock_48,            -- core clock
        clkout1     => clock_96,            -- sdram controller clock
        clkout2     => clock_96_p,          -- sdram memory chips clock, phase shifted 
        clkout3     => clock_24,
        clkin       => clock_27
    );
    


    clkdiv4 : CLKDIV
        generic map (
            DIV_MODE => "4"            -- Divide by 4
        )
        port map (
            RESETN => powerup_reset_n,
            HCLKIN => clock_96,
            CLKOUT => clock_24,         -- 24MHz AVR Clock
            CALIB  => '1'
        );

    process(clock_135)
    begin
        if rising_edge(clock_135) then
            -- Synchronise the core hsync signal and delay it a bit
            hsync_del <= hsync_ref & hsync_del(hsync_del'left downto 1);
            -- Release clkdiv reset shortly after the first falling edge of hsync_ref
            if pll1_lock = '1' and pll2_lock = '1' and hsync_del(1) = '0' and hsync_del(0) = '1' then
                clkdiv_reset_n <= '1';
            end if;
        end if;
    end process;

    --------------------------------------------------------
    -- Button 1: Power Up Reset and Master/Beeb toggle
    --------------------------------------------------------

    -- Generate a reliable power up reset on powerup, and if bt1n is pressed
    -- Also, if both IncludeMaster and IncludeBeeb then toggle m128mode

    reset_gen : process(clock_48)
    begin
        if rising_edge(clock_48) then
            if (btn1 = '1') then
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
                config_counter <= (others => '0');
            elsif btn2 = '1' then
                config_counter <= (others => '1');
            elsif config_counter(config_counter'high) = '1' then
                config_counter <= config_counter - 1;
            elsif config_last = '1' then
                -- For now, keep HDMI/DVI mode on BTN2
                hdmi_audio_en <= not hdmi_audio_en;
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
            --    m5k_spdif_en <= not m5k_spdif_en;
            end if;
            if config(4) = '1' then
                m5k_filter_en <= not m5k_filter_en;
            end if;
            if config(5) = '1' then
                hdmi_audio_src <= not hdmi_audio_src;
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
        hdmi_audio_l <= audio_l when hdmi_audio_src = '1' else audio_l_legacy;
        hdmi_audio_r <= audio_r when hdmi_audio_src = '1' else audio_r_legacy;

    end generate;

    gen_no_resampler: if not IncludeMixerResampler generate

        audio_l      <= audio_l_legacy;
        audio_r      <= audio_r_legacy;
        hdmi_audio_l <= audio_r_legacy;
        hdmi_audio_r <= audio_r_legacy;

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
    -- SDRAM Memory Controller
    --------------------------------------------------------

    e_mem: entity work.mem_tang_25k
        generic map (
            SIM => SIM,
            IncludeMonitor => IncludeMonitor,
            IncludeBootStrap => IncludeBootStrap,
            IncludeMinimalBeeb => true,
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

            -- sdram interface
            sdram_clk_o    => sdram_clk_o,
            sdram_DQ_io    => sdram_DQ_io,
            sdram_A_o      => sdram_A_o,
            sdram_BS_o     => sdram_BS_o,
            sdram_CKE_o    => open,             -- TODO: check why I did this
            sdram_nCS_o    => sdram_nCS_o,
            sdram_nRAS_o   => sdram_nRAS_o,
            sdram_nCAS_o   => sdram_nCAS_o,
            sdram_nWE_o    => sdram_nWE_o,
            sdram_DQM_o    => sdram_DQM_o,

            led            => monitor_leds,

            FLASH_CS       => flash_cs,
            FLASH_SI       => flash_si,
            FLASH_CK       => flash_ck,
            FLASH_SO       => flash_so
        );

        --TODO: DB: I've just munged this to do volume control not LEDS
    --------------------------------------------------------
    -- 1MHz Bus LEDs
    --------------------------------------------------------

--    normal_leds <= (caps_led & shift_led & m5k_spdif_en & m5k_filter_en & hdmi_audio_src & hdmi_audio_en) xor "111111";

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
--        led <= soft_leds(5 downto 0) xor "111111" when soft_leds(7 downto 6) = "10" else
--               test(5 downto 0)      xor "111111" when soft_leds(7 downto 6) = "11" else
--               monitor_leds                       when IncludeMonitor               else
--               normal_leds;
--
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
    -- Output Assignments
    --------------------------------------------------------

    vga_r <= i_VGA_R(i_VGA_R'high);
    vga_g <= i_VGA_G(i_VGA_G'high);
    vga_b <= i_VGA_B(i_VGA_B'high);

   

end architecture;
