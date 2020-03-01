-- BBC Master / BBC B for the Papilio Duo
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
-- Papilio Duo top-level
--
-- (c) 2015 David Banks
-- (C) 2011 Mike Stirling

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

-- Generic top-level entity for Papilio Duo board
entity bbc_micro_duo is
    generic (
        IncludeAMXMouse    : boolean := false;
        IncludeSID         : boolean := false;
        IncludeMusic5000   : boolean := false;
        IncludeICEDebugger : boolean := true;
        IncludeCoPro6502   : boolean := false;  -- The co pro options are mutually exclusive
        IncludeCoProExt    : boolean := false; -- (i.e. select just one)
        IncludeVideoNuLA   : boolean := true
    );
    port (
        clk_32M00      : in    std_logic;
        ps2_kbd_clk    : in    std_logic;
        ps2_kbd_data   : in    std_logic;
        ps2_mse_clk    : inout std_logic;
        ps2_mse_data   : inout std_logic;
        ERST           : in    std_logic;
        red            : out   std_logic_vector (3 downto 0);
        green          : out   std_logic_vector (3 downto 0);
        blue           : out   std_logic_vector (3 downto 0);
        vsync          : out   std_logic;
        hsync          : out   std_logic;
        audioL         : out   std_logic;
        audioR         : out   std_logic;
        SRAM_nOE       : out   std_logic;
        SRAM_nWE       : out   std_logic;
        SRAM_nCS       : out   std_logic;
        SRAM_A         : out   std_logic_vector (20 downto 0);
        SRAM_D         : inout std_logic_vector (7 downto 0);
        SDMISO         : in    std_logic;
        SDSS           : out   std_logic;
        SDCLK          : out   std_logic;
        SDMOSI         : out   std_logic;
        LED1           : out   std_logic;
        LED2           : out   std_logic;
        ARDUINO_RESET  : out   std_logic;
        SW1            : in    std_logic;
        FLASH_CS       : out   std_logic;                     -- Active low FLASH chip select
        FLASH_SI       : out   std_logic;                     -- Serial output to FLASH chip SI pin
        FLASH_CK       : out   std_logic;                     -- FLASH clock
        FLASH_SO       : in    std_logic;                     -- Serial input from FLASH chip SO pin
        avr_RxD        : in    std_logic;
        avr_TxD        : out   std_logic;
        -- DIP(1..0) = Video Mode:
        --             (00) SCART RGB mode (15.625KHz)
        --             (01) Mode 0-6: RGBtoVGA SD, Mode 7: RGBtoVGA SD
        --             (10) Mode 0-7: Mist SD,     Mode 7: Mist SD
        --             (11) Mode 0-7: Mist SD,     Mode 7: SAA5050 VGA Mode
        -- DIP(2) = Machine:
        --             (0) BBC Model B
        --             (1) BBC Master
        -- DIP(3) = Co Pro:
        --             (0) Off
        --             (1) On
        DIP            : in    std_logic_vector(3 downto 0);
        JOYSTICK1      : in    std_logic_vector(4 downto 0);
        JOYSTICK2      : in    std_logic_vector(4 downto 0)
    );
end entity;

architecture rtl of bbc_micro_duo is

-------------
-- Signals
-------------

    signal clk0            : std_logic;
    signal clk1            : std_logic;
    signal clk2            : std_logic;
    signal clk3            : std_logic;
    signal clkfb           : std_logic;
    signal clkfb_buf       : std_logic;
    signal fx_clk_27       : std_logic;
    signal fx_clk_32       : std_logic;

    signal clock_27        : std_logic;
    signal clock_32        : std_logic;
    signal clock_48        : std_logic;
    signal clock_96        : std_logic;
    signal clock_avr       : std_logic;

    attribute S : string;
--  attribute S of clock_avr : signal is "yes";
    attribute S of clock_27  : signal is "yes";
    attribute S of clock_32  : signal is "yes";
    attribute S of clock_96  : signal is "yes";

    signal dac_l_in        : std_logic_vector(9 downto 0);
    signal dac_r_in        : std_logic_vector(9 downto 0);
    signal audio_l         : std_logic_vector(15 downto 0);
    signal audio_r         : std_logic_vector(15 downto 0);
    signal audio           : std_logic;
    signal powerup_reset_n : std_logic;
    signal hard_reset_n    : std_logic;
    signal reset_counter   : std_logic_vector(9 downto 0);
    signal RAM_A           : std_logic_vector(18 downto 0);
    signal RAM_Din         : std_logic_vector(7 downto 0);
    signal RAM_Dout        : std_logic_vector(7 downto 0);
    signal RAM_nWE         : std_logic;
    signal RAM_nOE         : std_logic;
    signal RAM_nCS         : std_logic;
    signal keyb_dip        : std_logic_vector(7 downto 0);
    signal vid_mode        : std_logic_vector(3 downto 0);
    signal m128_mode       : std_logic;
    signal m128_mode_1     : std_logic;
    signal m128_mode_2     : std_logic;
    signal copro_mode      : std_logic;
    signal caps_led        : std_logic;
    signal shift_led       : std_logic;

-----------------------------------------------
-- Bootstrap ROM Image from SPI FLASH into SRAM
-----------------------------------------------

    -- start address of user data in FLASH as obtained from bitmerge.py
    -- this is safely beyond the end of the bitstream
    constant user_address_beeb    : std_logic_vector(23 downto 0) := x"060000";
    constant user_address_master  : std_logic_vector(23 downto 0) := x"0A0000";
    signal   user_address         : std_logic_vector(23 downto 0);

    -- lenth of user data in FLASH = 256KB (16x 16K ROM) images
    constant user_length   : std_logic_vector(23 downto 0) := x"040000";

    -- high when FLASH is being copied to SRAM, can be used by user as active high reset
    signal bootstrap_busy  : std_logic;

begin

--------------------------------------------------------
-- BBC Micro Core
--------------------------------------------------------

    copro_mode <= DIP(3);
    keyb_dip       <= "00000000";
    m128_mode      <= DIP(2);
    vid_mode       <= "00" & DIP(1 downto 0);
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
        UseT65Core         => false,
        UseAlanDCore       => true
    )
    port map (
        clock_27       => clock_27,
        clock_32       => clock_32,
        clock_48       => clock_48,
        clock_96       => clock_96,
        clock_avr      => clock_avr,
        hard_reset_n   => hard_reset_n,
        ps2_kbd_clk    => ps2_kbd_clk,
        ps2_kbd_data   => ps2_kbd_data,
        ps2_mse_clk    => ps2_mse_clk,
        ps2_mse_data   => ps2_mse_data,
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
        SDMISO         => SDMISO,
        SDSS           => SDSS,
        SDCLK          => SDCLK,
        SDMOSI         => SDMOSI,
        caps_led       => caps_led,
        shift_led      => shift_led,
        keyb_dip       => keyb_dip,
        vid_mode       => vid_mode,
        joystick1      => JOYSTICK1,
        joystick2      => JOYSTICK2,
        avr_reset      => not hard_reset_n,
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
    LED1 <= caps_led;
    LED2 <= shift_led;

--------------------------------------------------------
-- Clock Generation
--------------------------------------------------------


    inst_PLL : PLL_BASE
        generic map (
            BANDWIDTH            => "OPTIMIZED",
            CLK_FEEDBACK         => "CLKFBOUT",
            COMPENSATION         => "SYSTEM_SYNCHRONOUS",
            DIVCLK_DIVIDE        => 1,
            CLKFBOUT_MULT        => 15,
            CLKFBOUT_PHASE       => 0.000,
            CLKOUT0_DIVIDE       => 5,         -- 32 * (15/5) = 96MHz
            CLKOUT0_PHASE        => 0.000,
            CLKOUT0_DUTY_CYCLE   => 0.500,
            CLKOUT1_DIVIDE       => 10,        -- 32 * (15/10) = 48MHz
            CLKOUT1_PHASE        => 0.000,
            CLKOUT1_DUTY_CYCLE   => 0.500,
            CLKOUT2_DIVIDE       => 15,        -- 32 * (15/15) = 32MHz
            CLKOUT2_PHASE        => 0.000,
            CLKOUT2_DUTY_CYCLE   => 0.500,
            CLKOUT3_DIVIDE       => 20,        -- 32 * (15/20) = 24MHz
            CLKOUT3_PHASE        => 0.000,
            CLKOUT3_DUTY_CYCLE   => 0.500,
            CLKIN_PERIOD         => 31.25,
            REF_JITTER           => 0.010
            )
        port map (
            -- Output clocks
            CLKFBOUT            => clkfb,
            CLKOUT0             => clk0,
            CLKOUT1             => clk1,
            CLKOUT2             => clk2,
            CLKOUT3             => clk3,
            RST                 => '0',
            -- Input clock control
            CLKFBIN             => clkfb_buf,
            CLKIN               => clk_32M00
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

    -- 27MHz for the alternative scan doubler

    inst_DCM : DCM
        generic map (
            CLKFX_MULTIPLY    => 27,
            CLKFX_DIVIDE      => 32,
            CLK_FEEDBACK      => "1X"
            )
        port map (
            CLKIN             => clk_32M00,
            CLKFB             => fx_clk_32,
            RST               => '0',
            DSSEN             => '0',
            PSINCDEC          => '0',
            PSEN              => '0',
            PSCLK             => '0',
            CLK2X             => fx_clk_32,
            CLKFX             => fx_clk_27
            );

    inst_clk27_buf : BUFG
    port map (
        I => fx_clk_27,
        O => clock_27
        );

--------------------------------------------------------
-- Power Up Reset Generation
--------------------------------------------------------

    -- Generate a reliable power up reset, as ERST on the Papilio doesn't do this
    -- Also, perform a power up reset if the master/beeb mode switch is changed
    reset_gen : process(clock_48)
    begin
        if rising_edge(clock_48) then
            m128_mode_1 <= m128_mode;
            m128_mode_2 <= m128_mode_1;
            if (m128_mode_1 /= m128_mode_2) then
                reset_counter <= (others => '0');
            elsif (reset_counter(reset_counter'high) = '0') then
                reset_counter <= reset_counter + 1;
            end if;
            powerup_reset_n <= not ERST and reset_counter(reset_counter'high);
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
        clk_i => clock_48,
        reset => '0',
        dac_i => dac_l_in,
        dac_o => audioL
    );

    dac_r : entity work.pwm_sddac
    generic map (
        msbi_g => 9
    )
    port map (
        clk_i => clock_48,
        reset => '0',
        dac_i => dac_r_in,
        dac_o => audioR
    );

--------------------------------------------------------
-- Papilio Duo Misc
--------------------------------------------------------

    -- Follow convention for keeping Arduino reset
    ARDUINO_RESET <= SW1;

--------------------------------------------------------
-- BOOTSTRAP SPI FLASH to SRAM
--------------------------------------------------------

    user_address <= user_address_master when m128_mode = '1' else user_address_beeb;

    inst_bootstrap: entity work.bootstrap
    generic map (
        user_length     => user_length
    )
    port map(
        clock           => clock_48,
        powerup_reset_n => powerup_reset_n,
        bootstrap_busy  => bootstrap_busy,
        user_address    => user_address,
        RAM_nOE         => RAM_nOE,
        RAM_nWE         => RAM_nWE,
        RAM_nCS         => RAM_nCS,
        RAM_A           => RAM_A,
        RAM_Din         => RAM_Din,
        RAM_Dout        => RAM_Dout,
        SRAM_nOE        => SRAM_nOE,
        SRAM_nWE        => SRAM_nWE,
        SRAM_nCS        => SRAM_nCS,
        SRAM_A          => SRAM_A,
        SRAM_D          => SRAM_D,
        FLASH_CS        => FLASH_CS,
        FLASH_SI        => FLASH_SI,
        FLASH_CK        => FLASH_CK,
        FLASH_SO        => FLASH_SO
    );

end architecture;
