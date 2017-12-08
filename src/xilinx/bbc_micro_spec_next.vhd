-- BBC Master / BBC B for the Spectrum Next
--
-- Copright (c) 2017 David Banks
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
        bus_int_n_i           : in    std_logic;
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
        keyb_col_i            : in    std_logic_vector(4 downto 0);
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
        sd_cs2_n_o            : out   std_logic;
        sd_cs_n_o             : out   std_logic;
        sd_miso_i             : in    std_logic;
        sd_mosi_o             : out   std_logic;
        sd_sclk_o             : out   std_logic;
        vsync_o               : out   std_logic
    );
end entity;

architecture rtl of bbc_micro_spec_next is

-------------
-- Signals
-------------

    signal fx_clk_24       : std_logic;
    signal fx_clk_32       : std_logic;
    signal clock_24        : std_logic;
    signal clock_27        : std_logic;
    signal clock_32        : std_logic;
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
    signal vid_mode        : std_logic_vector(3 downto 0);
    signal m128_counter    : std_logic_vector(24 downto 0);
    signal m128_mode       : std_logic := '0';
    signal m128_mode_1     : std_logic;
    signal m128_mode_2     : std_logic;
    signal copro_mode      : std_logic;
    signal red             : std_logic_vector(3 downto 0);
    signal green           : std_logic_vector(3 downto 0);
    signal blue            : std_logic_vector(3 downto 0);
    signal joystick1       : std_logic_vector(4 downto 0);
    signal joystick2       : std_logic_vector(4 downto 0);

-----------------------------------------------
-- Bootstrap ROM Image from SPI FLASH into SRAM
-----------------------------------------------

    -- start address of user data in FLASH as obtained from bitmerge.py
    -- this is safely beyond the end of the bitstream
    constant user_address_beeb    : std_logic_vector(23 downto 0) := x"080000";
    constant user_address_master  : std_logic_vector(23 downto 0) := x"0C0000";
    signal   user_address         : std_logic_vector(23 downto 0);

    -- lenth of user data in FLASH = 256KB (16x 16K ROM) images
    constant user_length   : std_logic_vector(23 downto 0) := x"040000";

    -- high when FLASH is being copied to SRAM, can be used by user as active high reset
    signal bootstrap_busy  : std_logic;

begin

--------------------------------------------------------
-- BBC Micro Core
--------------------------------------------------------

	 -- TODO, make this optional
    copro_mode     <= '1';

	 -- As per the Beeb keyboard DIP switches
    keyb_dip       <= "00000000";

	 -- Bit 3 inverts vsync
	 -- Bit 2 inverts hsync
	 -- Bit 1 selects between Mist (0) and RGBtoVGA (1) scan doublers
	 -- Bit 0 selecte between sRGB (0) and VGA (1)
    vid_mode       <= "0001";

    bbc_micro : entity work.bbc_micro_core
    generic map (
        IncludeAMXMouse    => false,
        IncludeSID         => true,
        IncludeMusic5000   => true,
        IncludeICEDebugger => true,
        IncludeCoPro6502   => true,
        IncludeCoProSPI    => false,
        UseOrigKeyboard    => false,
        UseT65Core         => false,
        UseAlanDCore       => true
    )
    port map (
        clock_32       => clock_32,
        clock_24       => clock_24,
        clock_27       => clock_27,
        hard_reset_n   => hard_reset_n,
        ps2_kbd_clk    => ps2_clk_io,
        ps2_kbd_data   => ps2_data_io,
        ps2_mse_clk    => ps2_pin6_io,
        ps2_mse_data   => ps2_pin2_io,
        video_red      => red,
        video_green    => green,
        video_blue     => blue,
        video_vsync    => vsync_o,
        video_hsync    => hsync_o,
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
        caps_led       => open,
        shift_led      => open,
        keyb_dip       => keyb_dip,
        vid_mode       => vid_mode,
        joystick1      => joystick1,
        joystick2      => joystick2,
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
        test           => open,
        -- original keyboard not yet supported on the Duo
        ext_keyb_led1  => open,
        ext_keyb_led2  => open,
        ext_keyb_led3  => open,
        ext_keyb_1mhz  => open,
        ext_keyb_en_n  => open,
        ext_keyb_pa    => open,
        ext_keyb_rst_n => '1',
        ext_keyb_ca2   => '1',
        ext_keyb_pa7   => '1'
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

--------------------------------------------------------
-- Clock Generation
--------------------------------------------------------

    -- TODO: the 24MHz clock needs to be phase locked to the 32MHz clock
    -- Not clear the below arrangement will accomplish this
    -- If MODE 7 is unstable, this is the first place to look!

    DCM1 : DCM
    generic map (
        CLKFX_MULTIPLY  => 16,
        CLKFX_DIVIDE    => 25,
        CLK_FEEDBACK    => "NONE"
        )
    port map (
        CLKIN           => clock_50_i,
        CLKFB           => '0',
        RST             => '0',
        DSSEN           => '0',
        PSINCDEC        => '0',
        PSEN            => '0',
        PSCLK           => '0',
        CLKFX           => fx_clk_32
        );

    BUFG1 : BUFG
    port map (
        I => fx_clk_32,
        O => clock_32
        );

    DCM2 : DCM
    generic map (
        CLKFX_MULTIPLY  => 12,
        CLKFX_DIVIDE    => 25,
        CLK_FEEDBACK    => "NONE"
        )
    port map (
        CLKIN           => clock_50_i,
        CLKFB           => '0',
        RST             => '0',
        DSSEN           => '0',
        PSINCDEC        => '0',
        PSEN            => '0',
        PSCLK           => '0',
        CLKFX           => fx_clk_24
        );

    BUFG2 : BUFG
    port map (
        I => fx_clk_24,
        O => clock_24
        );

    clock_27 <= '0';

--------------------------------------------------------
-- Power Up Reset Generation
--------------------------------------------------------

    m128_gen : process(clock_32)
    begin
        if rising_edge(clock_32) then
            if btn_multiface_n_i = '0' then
                m128_counter <= m128_counter + 1;
            else
                m128_counter <= (others => '0');
            end if;
            if m128_counter = 32000000 then -- 1s
                m128_mode <= not m128_mode;
            end if;
        end if;
    end process;

    -- Generate a reliable power up reset
    -- Also, perform a power up reset if the master/beeb mode switch is changed
    reset_gen : process(clock_32)
    begin
        if rising_edge(clock_32) then
            m128_mode_1 <= m128_mode;
            m128_mode_2 <= m128_mode_1;
            if (m128_mode_1 /= m128_mode_2) then
                reset_counter <= (others => '0');
            elsif (reset_counter(reset_counter'high) = '0') then
                reset_counter <= reset_counter + 1;
            end if;
            powerup_reset_n <= btn_reset_n_i and reset_counter(reset_counter'high);
        end if;
    end process;

   -- extend the version seen by the core to hold the 6502 reset during bootstrap
   hard_reset_n <= powerup_reset_n and not bootstrap_busy;

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
        clk_i => clock_32,
        reset => '0',
        dac_i => dac_l_in,
        dac_o => audioext_l_o
    );

    dac_r : entity work.pwm_sddac
    generic map (
        msbi_g => 9
    )
    port map (
        clk_i => clock_32,
        reset => '0',
        dac_i => dac_r_in,
        dac_o => audioext_r_o
    );

--------------------------------------------------------
-- BOOTSTRAP SPI FLASH to SRAM
--------------------------------------------------------

    user_address <= user_address_master when m128_mode = '1' else user_address_beeb;

    inst_bootstrap: entity work.bootstrap
    generic map (
        user_length     => user_length
    )
    port map(
        clock           => clock_32,
        powerup_reset_n => powerup_reset_n,
        bootstrap_busy  => bootstrap_busy,
        user_address    => user_address,
        RAM_nOE         => RAM_nOE,
        RAM_nWE         => RAM_nWE,
        RAM_nCS         => RAM_nCS,
        RAM_A           => RAM_A,
        RAM_Din         => RAM_Din,
        RAM_Dout        => RAM_Dout,
        SRAM_nOE        => ram_oe_n_o,
        SRAM_nWE        => ram_we_n_o,
        SRAM_nCS        => ram_ce_n_o(0),
        SRAM_A          => ram_addr,
        SRAM_D          => ram_data_io(7 downto 0),
        FLASH_CS        => flash_cs_n_o,
        FLASH_SI        => flash_mosi_o,
        FLASH_CK        => flash_sclk_o,
        FLASH_SO        => flash_miso_i
        );

	 ram_addr_o <= ram_addr(18 downto 0);
    ram_data_io(15 downto 8) <= "ZZZZZZZZ";
    ram_ce_n_o(1) <= '0';
    ram_ce_n_o(2) <= '0';
    ram_ce_n_o(3) <= '0';
    ram_data_io(15 downto 8) <= "ZZZZZZZZ";

--------------------------------------------------------
-- Unused outputs
--------------------------------------------------------

    -- Pi Connector
    accel_io       <= "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZ";

    -- TODO: what is this?
    audioint_o     <= '1';

    -- Spectrum Next Bus
    bus_addr_o     <= x"0000";
    bus_busack_n_o <= '1';
    bus_clk35_o    <= '1';
    bus_data_io    <= "ZZZZZZZZ";
    bus_halt_n_o   <= '1';
    bus_iorq_n_o   <= '1';
    bus_m1_n_o     <= '1';
    bus_mreq_n_o   <= '1';
    bus_rd_n_o     <= '1';
    bus_rfsh_n_o   <= '1';
    bus_rst_n_io   <= 'Z';
    bus_wr_n_o     <= '1';

    -- TODO: add support for sRGB output
    csync_o        <= '1';

    -- ESP 8266 module
    esp_gpio0_io   <= 'Z';
    esp_gpio2_io   <= 'Z';

    -- Unused Flash inputs
    flash_hold_o   <= '1'; -- low pauses serial communications with flash
    flash_wp_o     <= '1'; -- disable write protection

    -- TODO: add support for HDMI output
    OBUFDS_c0  : OBUFDS port map ( O  => hdmi_p_o(0), OB => hdmi_n_o(0), I => '1');
    OBUFDS_c1  : OBUFDS port map ( O  => hdmi_p_o(1), OB => hdmi_n_o(1), I => '1');
    OBUFDS_c2  : OBUFDS port map ( O  => hdmi_p_o(2), OB => hdmi_n_o(2), I => '1');
    OBUFDS_clk : OBUFDS port map ( O  => hdmi_p_o(3), OB => hdmi_n_o(3), I => '1');

    i2c_scl_io <= 'Z';
    i2c_sda_io <= 'Z';

	 -- TODO: what are these?
    joyp7_o    <= '1';
    joysel_o   <= '1';

    keyb_row_o <= x"FF";

	 -- TODO: what is this?
    mic_port_o <= '1';

	 -- TODO: are we using the correct CS?
    sd_cs2_n_o <= '1';

end architecture;
