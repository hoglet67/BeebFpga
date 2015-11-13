-- BBC Master / BBC B for the Altera/Terasic DE1
--
-- Copright (c) 2015 David Banks
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
-- Altera/Terasic DE1 top-level
--
-- (c) 2015 David Banks
-- (C) 2011 Mike Stirling

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- Generic top-level entity for Altera DE1 board
entity bbc_micro_de1 is
port (
    -- Clocks
    CLOCK_24_0  :   in  std_logic;
    CLOCK_24_1  :   in  std_logic;
    CLOCK_27_0  :   in  std_logic;
    CLOCK_27_1  :   in  std_logic;
    CLOCK_50    :   in  std_logic;
    EXT_CLOCK   :   in  std_logic;
    
    -- Switches
    SW          :   in  std_logic_vector(9 downto 0);
    -- Buttons
    KEY         :   in  std_logic_vector(3 downto 0);
    
    -- 7 segment displays
    HEX0        :   out std_logic_vector(6 downto 0);
    HEX1        :   out std_logic_vector(6 downto 0);
    HEX2        :   out std_logic_vector(6 downto 0);
    HEX3        :   out std_logic_vector(6 downto 0);
    -- Red LEDs
    LEDR        :   out std_logic_vector(9 downto 0);
    -- Green LEDs
    LEDG        :   out std_logic_vector(7 downto 0);
    
    -- VGA
    VGA_R       :   out std_logic_vector(3 downto 0);
    VGA_G       :   out std_logic_vector(3 downto 0);
    VGA_B       :   out std_logic_vector(3 downto 0);
    VGA_HS      :   out std_logic;
    VGA_VS      :   out std_logic;
    
    -- Serial
    UART_RXD    :   in  std_logic;
    UART_TXD    :   out std_logic;
    
    -- PS/2 Keyboard
    PS2_CLK     :   inout   std_logic;
    PS2_DAT     :   inout   std_logic;
    
    -- I2C
    I2C_SCLK    :   inout   std_logic;
    I2C_SDAT    :   inout   std_logic;
    
    -- Audio
    AUD_XCK     :   out     std_logic;
    AUD_BCLK    :   out     std_logic;
    AUD_ADCLRCK :   out     std_logic;
    AUD_ADCDAT  :   in      std_logic;
    AUD_DACLRCK :   out     std_logic;
    AUD_DACDAT  :   out     std_logic;
    
    -- SRAM
    SRAM_ADDR   :   out     std_logic_vector(17 downto 0);
    SRAM_DQ     :   inout   std_logic_vector(15 downto 0);
    SRAM_CE_N   :   out     std_logic;
    SRAM_OE_N   :   out     std_logic;
    SRAM_WE_N   :   out     std_logic;
    SRAM_UB_N   :   out     std_logic;
    SRAM_LB_N   :   out     std_logic;
    
    -- SDRAM
    DRAM_ADDR   :   out     std_logic_vector(11 downto 0);
    DRAM_DQ     :   inout   std_logic_vector(15 downto 0);
    DRAM_BA_0   :   in      std_logic;
    DRAM_BA_1   :   in      std_logic;
    DRAM_CAS_N  :   in      std_logic;
    DRAM_CKE    :   in      std_logic;
    DRAM_CLK    :   in      std_logic;
    DRAM_CS_N   :   in      std_logic;
    DRAM_LDQM   :   in      std_logic;
    DRAM_RAS_N  :   in      std_logic;
    DRAM_UDQM   :   in      std_logic;
    DRAM_WE_N   :   in      std_logic;
    
    -- Flash
    FL_ADDR     :   out     std_logic_vector(21 downto 0);
    FL_DQ       :   inout   std_logic_vector(7 downto 0);
    FL_RST_N    :   out     std_logic;
    FL_OE_N     :   out     std_logic;
    FL_WE_N     :   out     std_logic;
    FL_CE_N     :   out     std_logic;
    
    -- SD card (SPI mode)
    SD_nCS      :   out     std_logic;
    SD_MOSI     :   out     std_logic;
    SD_SCLK     :   out     std_logic;
    SD_MISO     :   in      std_logic;
    
    -- GPIO
    GPIO_0      :   inout   std_logic_vector(35 downto 0);
    GPIO_1      :   inout   std_logic_vector(35 downto 0)
    );
end entity;

architecture rtl of bbc_micro_de1 is


-------------
-- Signals
-------------

signal clock_32        : std_logic;
signal audio_l         : std_logic_vector(15 downto 0);
signal audio_r         : std_logic_vector(15 downto 0);
signal hard_reset_n    : std_logic;


signal pll_reset       : std_logic;
signal pll_locked      : std_logic;

signal pcm_inl          :   std_logic_vector(15 downto 0);
signal pcm_inr          :   std_logic_vector(15 downto 0);

signal ext_A            : std_logic_vector (18 downto 0);
signal ext_Din          : std_logic_vector (7 downto 0);
signal ext_Dout         : std_logic_vector (7 downto 0);
signal ext_nCS          : std_logic;
signal ext_nWE          : std_logic;
signal ext_nOE          : std_logic;

begin

--------------------------------------------------------
-- BBC Micro Core
--------------------------------------------------------

bbc_micro : entity work.bbc_micro_core
    generic map (
        UseICEDebugger => false,
        UseT65Core     => false,
        UseAlanDCore   => true
    )
    port map (
        clock_32       => clock_32,
        clock_24       => CLOCK_24_0,
        clock_27       => CLOCK_27_0,
        hard_reset_n   => hard_reset_n,
        ps2_clk        => PS2_CLK,
        ps2_data       => PS2_DAT,
        video_red      => VGA_R,
        video_green    => VGA_G,
        video_blue     => VGA_B,
        video_vsync    => VGA_VS,
        video_hsync    => VGA_HS,
        audio_l        => audio_l,
        audio_r        => audio_r,
        ext_nOE        => ext_nOE,
        ext_nWE        => ext_nWE,
        ext_nCS        => ext_nCS,
        ext_A          => ext_A,
        ext_Dout       => ext_Dout,
        ext_Din        => ext_Din,
        SDMISO         => SD_MISO,
        SDSS           => SD_nCS,
        SDCLK          => SD_SCLK,
        SDMOSI         => SD_MOSI,
        caps_led       => LEDR(0),
        shift_led      => LEDR(1),
        keyb_dip       => SW(7 downto 0),
        vid_mode       => "001" & SW(8),
        joystick1      => (others => '1'),
        joystick2      => (others => '1'),
        avr_RxD        => UART_RXD,
        avr_TxD        => UART_TXD,
        cpu_addr       => open,
        ModeM128       => SW(9)
    );


--------------------------------------------------------
-- Clock Generation
--------------------------------------------------------

    -- 32 MHz master clock from 24MHz input clock
    pll: entity work.pll32 port map (
        pll_reset,
        CLOCK_24_0,
        clock_32,
        pll_locked
    );

--------------------------------------------------------
-- Power Up Reset Generation
--------------------------------------------------------

    -- Asynchronous reset
    -- PLL is reset by external reset switch
    pll_reset <= not KEY(0);

    hard_reset_n <= not (pll_reset or not pll_locked);

--------------------------------------------------------
-- Audio DACs
--------------------------------------------------------

    i2s : entity work.i2s_intf port map (
        CLOCK_24_0,
        hard_reset_n,
        pcm_inl,
        pcm_inr,
        audio_l,
        audio_r,
        AUD_XCK,
        AUD_DACLRCK,
        AUD_BCLK,
        AUD_DACDAT,
        AUD_ADCDAT
        );

    i2c : entity work.i2c_loader 
        generic map (
            log2_divider => 7
        )
        port map (
            clock_32,
            hard_reset_n,
            I2C_SCLK,
            I2C_SDAT,
            LEDR(5), -- IS_DONE
            LEDR(4) -- IS_ERROR
        );
    
--------------------------------------------------------
-- Map external memory bus to SRAM/FLASH
--------------------------------------------------------

    -- 0x00000-0x5FFFF -> FLASH
    -- 0x60000-0x7FFFF -> SRAM

    ext_Dout <= SRAM_DQ(7 downto 0) when ext_a(18 downto 17) = "11" else FL_DQ;
  
    FL_RST_N <= hard_reset_n;
    FL_CE_N <= '0';
    FL_OE_N <= '0';
    FL_WE_N <= '1';
    FL_ADDR <= "000" & ext_a;
        
    -- SRAM bus
    SRAM_UB_N <= '1';
    SRAM_LB_N <= '0';
    SRAM_CE_N <= '0';
    SRAM_OE_N <= ext_nOE;

    -- TODO consider gating with clock, w.g.
    -- SRAM_WE_N <= ext_nWE or nor clock_32;

    SRAM_WE_N <= ext_nWE;
    SRAM_ADDR <= ext_a(17 downto 0);
    SRAM_DQ(15 downto 8) <= (others => 'Z');
    SRAM_DQ(7 downto 0) <= ext_Din when ext_nWE = '0' else (others => 'Z');
    
end architecture;
