-- BBC Master / BBC B for the Spectrum Next
--
-- Copright (c) 2020 David Banks
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
-- Spectrum Next top-level
--
-- (c) 2017 David Banks
-- (C) 2011 Mike Stirling

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
library UNISIM;
use UNISIM.Vcomponents.all;

-- Generic top-level entity for Spectrum Next board
entity bbc_micro_spec_next is
    generic (
        IncludeAMXMouse    : boolean := false;
        IncludeSID         : boolean := false;
        IncludeMusic5000   : boolean := false;
        IncludeICEDebugger : boolean := false;
        IncludeCoPro6502   : boolean := false;
        IncludeCoProExt    : boolean := false;
        IncludeVideoNuLA   : boolean := false;
        IncludeBootstrap   : boolean := true;
        IncludeMaster      : boolean := true
    );
    port (
        accel_io              : inout std_logic_vector(27 downto 0);
        audioext_l_o          : out   std_logic;
        audioext_r_o          : out   std_logic;
        audioint_o            : out   std_logic;
        btn_divmmc_n_i        : in    std_logic;
        btn_multiface_n_i     : in    std_logic;
        btn_reset_n_i         : in    std_logic;
        bus_addr_o            : out   std_logic_vector(15 downto 0);
        bus_busack_n_o        : out   std_logic;
        bus_busreq_n_i        : in    std_logic;
        bus_clk35_o           : out   std_logic;
        bus_data_io           : inout std_logic_vector(7 downto 0);
        bus_halt_n_o          : out   std_logic;
        bus_int_n_io          : out   std_logic;
        bus_iorq_n_o          : out   std_logic;
        bus_iorqula_n_i       : in    std_logic;
        bus_m1_n_o            : out   std_logic;
        bus_mreq_n_o          : out   std_logic;
        bus_nmi_n_i           : in    std_logic;
        bus_ramcs_i           : in    std_logic;
        bus_rd_n_o            : out   std_logic;
        bus_rfsh_n_o          : out   std_logic;
        bus_romcs_i           : in    std_logic;
        bus_rst_n_io          : inout std_logic;
        bus_wait_n_i          : in    std_logic;
        bus_wr_n_o            : out   std_logic;
        clock_50_i            : in    std_logic;
        csync_o               : out   std_logic;
        ear_port_i            : in    std_logic;
        esp_gpio0_io          : inout std_logic;
        esp_gpio2_io          : inout std_logic;
        esp_rx_i              : in    std_logic;
        esp_tx_o              : out   std_logic;
        flash_cs_n_o          : out   std_logic;
        flash_hold_o          : out   std_logic;
        flash_miso_i          : in    std_logic;
        flash_mosi_o          : out   std_logic;
        flash_sclk_o          : out   std_logic;
        flash_wp_o            : out   std_logic;
        hdmi_n_o              : out   std_logic_vector(3 downto 0);
        hdmi_p_o              : out   std_logic_vector(3 downto 0);
        hsync_o               : out   std_logic;
        i2c_scl_io            : inout std_logic;
        i2c_sda_io            : inout std_logic;
        joyp1_i               : in    std_logic;
        joyp2_i               : in    std_logic;
        joyp3_i               : in    std_logic;
        joyp4_i               : in    std_logic;
        joyp6_i               : in    std_logic;
        joyp7_o               : out   std_logic;
        joyp9_i               : in    std_logic;
        joysel_o              : out   std_logic;
        keyb_col_i            : in    std_logic_vector(6 downto 0);
        keyb_row_o            : out   std_logic_vector(7 downto 0);
        mic_port_o            : out   std_logic;
        ps2_clk_io            : inout std_logic;
        ps2_data_io           : inout std_logic;
        ps2_pin2_io           : inout std_logic;
        ps2_pin6_io           : inout std_logic;
        ram_addr_o            : out   std_logic_vector(18 downto 0);
        ram_ce_n_o            : out   std_logic_vector(3 downto 0);
        ram_data_io           : inout std_logic_vector(15 downto 0);
        ram_oe_n_o            : out   std_logic;
        ram_we_n_o            : out   std_logic;
        rgb_b_o               : out   std_logic_vector(2 downto 0);
        rgb_g_o               : out   std_logic_vector(2 downto 0);
        rgb_r_o               : out   std_logic_vector(2 downto 0);
        sd_cs1_n_o            : out   std_logic;
        sd_cs0_n_o            : out   std_logic;
        sd_miso_i             : in    std_logic;
        sd_mosi_o             : out   std_logic;
        sd_sclk_o             : out   std_logic;
        vsync_o               : out   std_logic;
        extras_io             : inout std_logic
    );
end entity;

architecture rtl of bbc_micro_spec_next is

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

    signal dac_l_in        : std_logic_vector(9 downto 0);
    signal dac_r_in        : std_logic_vector(9 downto 0);
    signal audio_l         : std_logic_vector(15 downto 0);
    signal audio_r         : std_logic_vector(15 downto 0);
    signal powerup_reset_n : std_logic;
    signal hard_reset_n    : std_logic;
    signal reset_counter   : std_logic_vector(9 downto 0);
    signal ram_addr        : std_logic_vector(20 downto 0);
    signal RAM_A           : std_logic_vector(18 downto 0);
    signal RAM_Din         : std_logic_vector(7 downto 0);
    signal RAM_Dout        : std_logic_vector(7 downto 0);
    signal RAM_nWE         : std_logic;
    signal RAM_nOE         : std_logic;
    signal RAM_nCS         : std_logic;
    signal keyb_dip        : std_logic_vector(7 downto 0);
    signal vid_mode        : std_logic_vector(3 downto 0) := "0011";
    signal reconfig_ctr    : std_logic_vector(23 downto 0);
    signal reconfig        : std_logic := '0';
    signal m128_mode       : std_logic;
    signal copro_mode      : std_logic := '0';
    signal ttxt_mode       : std_logic;
    signal hdmi_aspect     : std_logic_vector(1 downto 0) := "00";
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
    signal hdmi_audio_en   : std_logic := '1';
    signal hsync           : std_logic;
    signal vsync           : std_logic;
    signal hsync1          : std_logic;
    signal vsync1          : std_logic;
    signal hcnt            : std_logic_vector(9 downto 0);
    signal vcnt            : std_logic_vector(9 downto 0);
    signal joystick1       : std_logic_vector(4 downto 0);
    signal joystick2       : std_logic_vector(4 downto 0);
    signal ext_tube_r_nw   : std_logic;
    signal ext_tube_nrst   : std_logic;
    signal ext_tube_ntube  : std_logic;
    signal ext_tube_phi2   : std_logic;
    signal ext_tube_a      : std_logic_vector(6 downto 0);
    signal ext_tube_di     : std_logic_vector(7 downto 0);
    signal ext_tube_do     : std_logic_vector(7 downto 0);
    signal ROM_D           : std_logic_vector(7 downto 0);

    signal ext_keyb_1mhz   : std_logic;
    signal ext_keyb_en_n   : std_logic;
    signal ext_keyb_pa     : std_logic_vector(6 downto 0);
    signal ext_keyb_rst_n  : std_logic;
    signal ext_keyb_ca2    : std_logic;
    signal ext_keyb_pa7    : std_logic;

    signal tdms_r          : std_logic_vector(9 downto 0);
    signal tdms_g          : std_logic_vector(9 downto 0);
    signal tdms_b          : std_logic_vector(9 downto 0);

-----------------------------------------------
-- Bootstrap ROM Image from SPI FLASH into SRAM
-----------------------------------------------

    -- TODO: When we can span two slots....
    --
    --
    -- Spec Next FLASH is Winbond 25Q128JVSQ (16MB)
    --  Slot 0: AB Core        (0x000000-0x07FFFF)
    --  Slot 1: Spec Next Core (0x080000-0x0FFFFF)
    --  Slot 2: Beeb Core      (0x100000-0x17FFFF)
    --  Slot 3: Beeb ROMS      (0x180000-0x1FFFFF)

    -- For now, we have seperate Beeb and Master build, each with just 4 ROMs
    -- as that's all that will fit at the end of a 512KB Slot

    -- start address of user data in FLASH as obtained from bitmerge.py
    -- this is just beyond the end of the bitstream
    constant user_address_beeb    : std_logic_vector(23 downto 0) := x"170000";
    constant user_address_master  : std_logic_vector(23 downto 0) := x"170000";
    signal   user_address         : std_logic_vector(23 downto 0);

    -- lenth of user data in FLASH = 64KB (4x 16K ROM) images
    constant user_length : std_logic_vector(23 downto 0) := x"010000";

    -- ROM Map
    --
    -- FLASH   Beeb            Master
    -- 0 ->    4 MOS 1.20      3 MMFS
    -- 1 ->    8 MMFS          4 MOS 3.20
    -- 2 ->    E Ram Master    C Basic II
    -- 3 ->    F Basic II      F Terminal

    constant user_rom_map_beeb    : std_logic_vector(63 downto 0) := x"000000000000FE84";
    constant user_rom_map_master  : std_logic_vector(63 downto 0) := x"000000000000FC43";
    signal   user_rom_map         : std_logic_vector(63 downto 0);

    -- high when FLASH is being copied to SRAM, can be used by user as active high reset
    signal bootstrap_busy  : std_logic;

    -- Config buttons
    signal yellow_config             : std_logic_vector(9 downto 0);
    signal green_config              : std_logic_vector(9 downto 0);

begin

--------------------------------------------------------
-- BBC Micro Core
--------------------------------------------------------

    -- As per the Beeb keyboard DIP switches
    keyb_dip       <= "00000000";

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
        UseOrigKeyboard    => true,
        UseT65Core         => not IncludeMaster,  -- select the 6502 for the Beeb
        UseAlanDCore       => IncludeMaster       -- select the 65C02 for the Master
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
        ps2_mse_clk    => ps2_pin6_io,
        ps2_mse_data   => ps2_pin2_io,
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
        SDSS           => sd_cs0_n_o,
        SDCLK          => sd_sclk_o,
        SDMOSI         => sd_mosi_o,
        caps_led       => open,
        shift_led      => open,
        keyb_dip       => keyb_dip,
        vid_mode       => vid_mode,
        ttxt_mode      => ttxt_mode,
        joystick1      => joystick1,
        joystick2      => joystick2,
        avr_reset      => not hard_reset_n,
        avr_RxD        => esp_rx_i,
        avr_TxD        => esp_tx_o,
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
        ext_keyb_led1  => open,
        ext_keyb_led2  => open,
        ext_keyb_led3  => open,
        ext_keyb_1mhz  => ext_keyb_1mhz,
        ext_keyb_en_n  => ext_keyb_en_n,
        ext_keyb_pa    => ext_keyb_pa,
        ext_keyb_rst_n => ext_keyb_rst_n,
        ext_keyb_ca2   => ext_keyb_ca2,
        ext_keyb_pa7   => ext_keyb_pa7
    );

    -- Joystick 1
    --   Bit 0 - Up (active low)
    --   Bit 1 - Down (active low)
    --   Bit 2 - Left (active low)
    --   Bit 3 - Right (active low)
    --   Bit 4 - Fire (active low)
    joystick1 <= joyp6_i & joyp4_i & joyp3_i & joyp2_i & joyp1_i;

    -- Joystick 2
    --   Unused
    joystick2 <= "11111";

    -- VGA RGB outputs
    rgb_r_o <= red(3 downto 1);
    rgb_g_o <= green(3 downto 1);
    rgb_b_o <= blue(3 downto 1);
    hsync_o <= hsync;
    vsync_o <= vsync;

--------------------------------------------------------
-- Clock Generation
--------------------------------------------------------

    -- 50MHz to 100MHz

    inst_DCM1 : DCM
        generic map (
            CLK_FEEDBACK         => "2X"
            )
        port map (
            CLKIN                => clock_50_i,
            CLKFB                => clk100,
            RST                  => '0',
            DSSEN                => '0',
            PSINCDEC             => '0',
            PSEN                 => '0',
            PSCLK                => '0',
            CLK2X                => clk100
            );


    -- 100MHz to 96/48/32 MHz

    inst_PLL1 : PLL_BASE
        generic map (
            BANDWIDTH            => "OPTIMIZED",
            CLK_FEEDBACK         => "CLKFBOUT",
            COMPENSATION         => "DCM2PLL",
            DIVCLK_DIVIDE        => 5,
            CLKFBOUT_MULT        => 24,
            CLKFBOUT_PHASE       => 0.000,
            CLKOUT0_DIVIDE       => 5,         -- 100 * (24/5/5) = 96MHz
            CLKOUT0_PHASE        => 0.000,
            CLKOUT0_DUTY_CYCLE   => 0.500,
            CLKOUT1_DIVIDE       => 10,        -- 100 * (24/5/10) = 48MHz
            CLKOUT1_PHASE        => 0.000,
            CLKOUT1_DUTY_CYCLE   => 0.500,
            CLKOUT2_DIVIDE       => 15,        -- 100 * (24/5/15) = 32MHz
            CLKOUT2_PHASE        => 0.000,
            CLKOUT2_DUTY_CYCLE   => 0.500,
            CLKOUT3_DIVIDE       => 20,        -- 100 * (24/5/20) = 24MHz
            CLKOUT3_PHASE        => 0.000,
            CLKOUT3_DUTY_CYCLE   => 0.500,
            CLKOUT4_DIVIDE       => 30,        -- 100 * (24/5/30) = 16MHz
            CLKOUT4_PHASE        => 0.000,
            CLKOUT4_DUTY_CYCLE   => 0.500,
            CLKIN_PERIOD         => 10.000,
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
            CLKIN               => clk100
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
            DIVCLK_DIVIDE        => 2,
            CLKFBOUT_MULT        => 27,
            CLKFBOUT_PHASE       => 0.000,
            CLKOUT0_DIVIDE       => 25,       -- 50 * (27/2/25) = 27MHz
            CLKOUT0_PHASE        => 0.000,
            CLKOUT0_DUTY_CYCLE   => 0.500,
            CLKOUT1_DIVIDE       => 5,        -- 50 * (27/2/5) = 135MHz
            CLKOUT1_PHASE        => 0.000,
            CLKOUT1_DUTY_CYCLE   => 0.500,
            CLKOUT2_DIVIDE       => 5,        -- 50 * (27/2/5) = 135MHz (inverted)
            CLKOUT2_PHASE        => 180.000,
            CLKOUT2_DUTY_CYCLE   => 0.500,
            CLKIN_PERIOD         => 20.000,
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
            CLKIN               => clock_50_i
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


--    inst_DCM2 : DCM
--        generic map (
--            CLKFX_MULTIPLY    => 27,
--            CLKFX_DIVIDE      => 25,
--            CLKIN_DIVIDE_BY_2 => TRUE,
--            CLK_FEEDBACK      => "NONE"
--            )
--        port map (
--            CLKIN             => clock_50_i,
--            CLKFB             => '0',
--            RST               => '0',
--            DSSEN             => '0',
--            PSINCDEC          => '0',
--            PSEN              => '0',
--            PSCLK             => '0',
--            CLKFX             => fx_clk_27
--            );
--
--    inst_clk27_buf : BUFG
--    port map (
--        I => fx_clk_27,
--        O => clock_27
--        );

--------------------------------------------------------
-- Power Up Reset Generation
--------------------------------------------------------

    m128_mode <= '1' when IncludeMaster else '0';

    -- Generate a reliable power up reset
    -- Also, perform a power up reset if the master/beeb mode switch is changed
    reset_gen : process(clock_48)
    begin
        if rising_edge(clock_48) then
            if reset_counter(reset_counter'high) = '0' then
                reset_counter <= reset_counter + 1;
            end if;
            powerup_reset_n <= btn_reset_n_i and reset_counter(reset_counter'high);
        end if;
    end process;

    -- extend the version seen by the core to hold the 6502 reset during bootstrap
    hard_reset_n <= powerup_reset_n and not bootstrap_busy;

--------------------------------------------------------
-- Configuration toggles
--------------------------------------------------------

    config: process(clock_48)
    begin
        if rising_edge(clock_48) then

            -- Yellow 1-8 Changes Video Modes and HDMI Audio

            if yellow_config(1) = '1' then
                vid_mode      <= "0000";
            elsif yellow_config(2) = '1' then
                vid_mode      <= "0001";
            elsif yellow_config(3) = '1' then
                vid_mode      <= "0010";
            elsif yellow_config(4) = '1' then
                vid_mode      <= "0011";
            elsif yellow_config(5) = '1' then
                hdmi_audio_en <= not hdmi_audio_en;
            elsif yellow_config(6) = '1' then
                hdmi_aspect <= "00";
            elsif yellow_config(7) = '1' then
                hdmi_aspect <= "01";
            elsif yellow_config(8) = '1' then
                hdmi_aspect <= "10";
            end if;

            -- Green 1-2 Manages the internal 65C02 Co Processor
            if green_config(1) = '1' then
                copro_mode <= '1';
            elsif green_config(2) = '1' then
                copro_mode <= '0';
            end if;

        end if;
    end process;

--------------------------------------------------------
-- Dynamic Reconfiguration
--------------------------------------------------------

    reconfig_gen : process(clock_16)
    begin
        if rising_edge(clock_16) then
            if btn_reset_n_i = '0' then
                reconfig_ctr <= reconfig_ctr + 1;
            else
                reconfig_ctr <= (others => '0');
            end if;
            if reconfig_ctr = 16000000 then
                reconfig <= '1';
            end if;
        end if;
    end process;

    flash_reboot_inst : entity work.flashboot
    port map (
        reset_i    => '0',
        clock_i    => clock_16,
        start_i    => reconfig,
        spiaddr_i  => x"6B" & "00001" & "0000000000000000000"
        );

--------------------------------------------------------
-- Membrane Keyboard
--------------------------------------------------------

    kbd_spec_next_inst : entity work.kbd_spec_next
    port map (
        -- Clock
        clock             => clock_48,
        reset_n           => hard_reset_n,

        -- Specnext Keboard matrix
        keyb_col_i        => keyb_col_i,
        keyb_row_o        => keyb_row_o,

        -- Specnext Buttons
        btn_divmmc_n_i    => btn_divmmc_n_i,    -- Green  / divmmc    / Drive
        btn_multiface_n_i => btn_multiface_n_i, -- Yellow / multiface / NMI

        -- Debounced configuration outputs
        -- (pulse high for 1 clock cycle when depressed)
        green_config      => green_config,      -- Green  / divmmc    / Drive
        yellow_config     => yellow_config,     -- Yellow / multiface / NMI

        -- Beeb Keyboard
        keyb_1mhz         => ext_keyb_1mhz,
        keyb_en_n         => ext_keyb_en_n,
        keyb_pa           => ext_keyb_pa,
        keyb_rst_n        => ext_keyb_rst_n,
        keyb_ca2          => ext_keyb_ca2,
        keyb_pa7          => ext_keyb_pa7
        );

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
        dac_o => audioext_l_o
    );

    dac_r : entity work.pwm_sddac
    generic map (
        msbi_g => 9
    )
    port map (
        clk_i => clock_48,
        reset => '0',
        dac_i => dac_r_in,
        dac_o => audioext_r_o
    );

--------------------------------------------------------
-- BOOTSTRAP SPI FLASH to SRAM
--------------------------------------------------------

    GenBootstrap: if IncludeBootstrap generate

        user_address <= user_address_master when m128_mode = '1' else user_address_beeb;

        user_rom_map <= user_rom_map_master when m128_mode = '1' else user_rom_map_beeb;

        inst_bootstrap: entity work.bootstrap
            generic map (
                user_length     => user_length
                )
            port map(
                clock           => clock_48,
                powerup_reset_n => powerup_reset_n,
                bootstrap_busy  => bootstrap_busy,
                user_address    => user_address,
                user_rom_map    => user_rom_map,
                RAM_nOE         => RAM_nOE,
                RAM_nWE         => RAM_nWE,
                RAM_nCS         => RAM_nCS,
                RAM_A           => RAM_A,
                RAM_Din         => RAM_Din,
                RAM_Dout        => RAM_Dout,
                SRAM_nOE        => ram_oe_n_o,
                SRAM_nWE        => ram_we_n_o,
                SRAM_nCS        => ram_ce_n_o(1),
                SRAM_A          => ram_addr,
                SRAM_D          => ram_data_io(15 downto 8),
                FLASH_CS        => flash_cs_n_o,
                FLASH_SI        => flash_mosi_o,
                FLASH_CK        => flash_sclk_o,
                FLASH_SO        => flash_miso_i
                );

        ram_addr_o <= ram_addr(18 downto 0);

    end generate;

    NotGenBootstrap: if not IncludeBootstrap generate

        bootstrap_busy          <= '0';
        ram_oe_n_o              <= RAM_nOE;
        ram_we_n_o              <= RAM_nWE;
        ram_ce_n_o(1)           <= RAM_nCS;
        ram_addr_o              <= RAM_A(18 downto 0);
        ram_data_io(15 downto 8)<= RAM_Din when RAM_nWE = '0' else (others => 'Z');

        RAM_Dout                <= ROM_D when RAM_A(18) = '0' else ram_data_io(15 downto 8);

        flash_cs_n_o            <= '1';
        flash_mosi_o            <= '1';
        flash_sclk_o            <= '1';

        -- Minimal Model B ROM set with OS 1.20, Basic II and MMFS
        inst_rom: entity work.minimal_modelb_rom_set
            port map (
                clk => clock_48,
                addr => RAM_A(17 downto 0),
                data => ROM_D
                );

    end generate;

    ram_data_io(7 downto 0) <= "ZZZZZZZZ";
    ram_ce_n_o(0) <= '1';
    ram_ce_n_o(2) <= '1';
    ram_ce_n_o(3) <= '1';

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
    -- The hdmidataencode module inserts a 32 pixel data packet after each of hsync,
    -- so the hsync pulse needs to be at least this width.

    process(clock_27)
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
            if hcnt < 68 or hcnt >= 68 + 720 or vcnt < 39 or vcnt >= 39 + 576 then
                hdmi_blank <= '1';
                hdmi_red   <= (others => '0');
                hdmi_green <= (others => '0');
                hdmi_blue  <= (others => '0');
            else
                hdmi_blank <= '0';
                hdmi_red   <= red;
                if hcnt = 68 or hcnt = 68 + 719 or vcnt = 39 or vcnt = 39 + 575 then
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
                       ttxt_mode;                       -- 4:3 in modes 0-6;
                                                        -- 16:9 i mode 7

    inst_hdmi: entity work.hdmi
    generic map (
      FREQ => 27000000,  -- pixel clock frequency
      --FS   => 48000,   -- audio sample rate - should be 32000, 44100 or 48000
      --CTS  => 27000,   -- CTS = Freq(pixclk) * N / (128 * Fs)
      --N    => 6144     -- N = 128 * Fs /1000,  128 * Fs /1500 <= N <= 128 * Fs /300
      FS   => 32000,     -- audio sample rate - should be 32000, 44100 or 48000
      CTS  => 27000,     -- CTS = Freq(pixclk) * N / (128 * Fs)
      N    => 4096       -- N = 128 * Fs /1000,  128 * Fs /1500 <= N <= 128 * Fs /300
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
        tmds_out_p     => hdmi_p_o,
        tmds_out_n     => hdmi_n_o
   );

--------------------------------------------------------
-- Unused outputs
--------------------------------------------------------

    -- Interal audio (speaker, not fitted)
    audioint_o     <= '0';

    -- Spectrum Next Bus
    -- (all these signals have PULLUP set in the .ucf file)
    bus_addr_o     <= (others => 'Z');
    bus_busack_n_o <= 'Z';
    bus_clk35_o    <= 'Z';
    bus_data_io    <= (others => 'Z');
    bus_halt_n_o   <= 'Z';
    bus_iorq_n_o   <= 'Z';
    bus_m1_n_o     <= 'Z';
    bus_mreq_n_o   <= 'Z';
    bus_rd_n_o     <= 'Z';
    bus_rfsh_n_o   <= 'Z';
    bus_rst_n_io   <= 'Z';
    bus_wr_n_o     <= 'Z';
    bus_int_n_io   <= 'Z';

    -- TODO: add support for sRGB output
    csync_o        <= '1';

    -- ESP 8266 module
    esp_gpio0_io   <= 'Z';
    esp_gpio2_io   <= 'Z';

    -- Addtional flash pins; used at IO2 and IO3 in Quad SPI Mode
    flash_hold_o   <= '1';
    flash_wp_o     <= '0';

    i2c_scl_io <= 'Z';
    i2c_sda_io <= 'Z';

    -- Pin 7 on the joystick connecter. TODO: is '1' correct?
    joyp7_o    <= '1';

    -- Controls a mux to select between two joystick ports
    joysel_o   <= '0';

    -- Mic Port (output, as it connects to the mic input on cassette deck)
    mic_port_o <= '0';

    -- CS2 is for internal SD socket
    sd_cs1_n_o <= '1';

    -- Extra unused pin
    extras_io <= 'Z';

end architecture;
