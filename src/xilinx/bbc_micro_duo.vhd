-- BBC Master / BBC B for the Papilio Duo
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
-- Papilio Duo top-level
--
-- (c) 2015 David Banks
-- (C) 2011 Mike Stirling

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- Generic top-level entity for Papilio Duo board
entity bbc_micro_duo is
     port (clk_32M00      : in    std_logic;
           ps2_clk        : in    std_logic;
           ps2_data       : in    std_logic;
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
           DIP            : in    std_logic_vector(3 downto 0);
           JOYSTICK1      : in    std_logic_vector(4 downto 0);
           JOYSTICK2      : in    std_logic_vector(4 downto 0)
    );
end entity;

architecture rtl of bbc_micro_duo is

-------------
-- Signals
-------------

signal clock_24        : std_logic;
signal clock_27        : std_logic;
signal clock_32        : std_logic;
signal audio_l         : std_logic_vector(15 downto 0);
signal audio_r         : std_logic_vector(15 downto 0);
signal audio           : std_logic;
signal powerup_reset_n : std_logic;
signal hard_reset_n    : std_logic;
signal reset_counter   : std_logic_vector (9 downto 0);


-----------------------------------------------
-- Bootstrap ROM Image from SPI FLASH into SRAM
-----------------------------------------------

-- start address of user data in FLASH as obtained from bitmerge.py
-- this is safely beyond the end of the bitstream
constant user_address   : std_logic_vector(23 downto 0) := x"060000";

-- user_length = 384KB (24x 16K ROM) images
constant user_length    : std_logic_vector(23 downto 0) := x"060000";

--
-- bootstrap signals
--
signal bootstrap_busy   : std_logic;     -- high when FLASH is being copied to SRAM, can be used by user as active high reset
signal flash_init       : std_logic;     -- when low places FLASH driver in init state
signal flash_Done       : std_logic;     -- FLASH init finished when high
signal flash_data       : std_logic_vector(7 downto 0);

-- bootstrap control of SRAM, these signals connect to SRAM when boostrap_busy = '1'
signal bs_A             : std_logic_vector(18 downto 0);
signal bs_Din           : std_logic_vector(7 downto 0);
signal bs_nCS           : std_logic;
signal bs_nWE           : std_logic;
signal bs_nOE           : std_logic;

-- user control of SRAM, these signals connect to SRAM when boostrap_busy = '0'
signal RAM_A            : std_logic_vector (18 downto 0);
signal RAM_Din          : std_logic_vector (7 downto 0);
signal RAM_Dout         : std_logic_vector (7 downto 0);
signal RAM_nCS          : std_logic;
signal RAM_nWE          : std_logic;
signal RAM_nOE          : std_logic;

-- for bootstrap state machine
type    BS_STATE_TYPE is (
            INIT, START_READ_FLASH, READ_FLASH, FLASH0, FLASH1, FLASH2, FLASH3, FLASH4, FLASH5, FLASH6, FLASH7,
            WAIT0, WAIT1, WAIT2, WAIT3, WAIT4, WAIT5, WAIT6, WAIT7, WAIT8, WAIT9, WAIT10, WAIT11
        );

signal bs_state, bs_state_next : BS_STATE_TYPE := INIT;

begin

--------------------------------------------------------
-- BBC Micro Core
--------------------------------------------------------

bbc_micro : entity work.bbc_micro_core
    generic map (
        UseICEDebugger => true,
        UseT65Core     => false,
        UseAlanDCore   => true
    )
    port map (
        clock_32       => clock_32,
        clock_24       => clock_24,
        clock_27       => clock_27,
        hard_reset_n   => hard_reset_n,
        ps2_clk        => ps2_clk,
        ps2_data       => ps2_data,
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
        caps_led       => LED1,
        shift_led      => LED2,
        keyb_dip       => (others => '0'),
        vid_mode       => "00" & DIP(1 downto 0),
        joystick1      => JOYSTICK1,
        joystick2      => JOYSTICK2,
        avr_RxD        => avr_RxD,
        avr_TxD        => avr_TxD,
        cpu_addr       => open,
        ModeM128       => DIP(2)
    );

--------------------------------------------------------
-- Clock Generation
--------------------------------------------------------

    inst_dcm1: entity work.dcm1 port map(
        CLKIN_IN  => clk_32M00,
        CLK0_OUT  => clock_32,
        CLKFX_OUT => clock_24
    );

    inst_dcm2: entity work.dcm2 port map (
        CLKIN_IN  => clk_32M00,
        CLKFX_OUT => clock_27
    );

--------------------------------------------------------
-- Power Up Reset Generation
--------------------------------------------------------

    -- Generate a reliable power up reset, as ERST on the Papilio doesn't do this
    reset_gen : process(clock_32)
    begin
        if rising_edge(clock_32) then
            if (reset_counter(reset_counter'high) = '0') then
                reset_counter <= reset_counter + 1;
            end if;
            powerup_reset_n <= not ERST and reset_counter(reset_counter'high);
        end if;
    end process;

   -- extens the version seen by the core to hold the 6502 reset during bootstrap
   hard_reset_n <= powerup_reset_n and not bootstrap_busy;

--------------------------------------------------------
-- Audio DACs
--------------------------------------------------------

    dac_l : entity work.pwm_sddac port map(
        clk_i => clock_32,
        reset => '0',
        dac_i => audio_l(15 downto 8),
        dac_o => audioL
    );

    dac_r : entity work.pwm_sddac port map(
        clk_i => clock_32,
        reset => '0',
        dac_i => audio_r(15 downto 8),
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

    -- SRAM muxer, allows access to physical SRAM by either bootstrap or user
    SRAM_D              <= bs_Din when bootstrap_busy = '1' and bs_nWE = '0' else RAM_Din when bootstrap_busy = '0' and RAM_nWE = '0' else (others => 'Z');
    SRAM_A(18 downto 0) <= bs_A   when bootstrap_busy = '1' else RAM_A;
    SRAM_A(19)          <= '0';
    SRAM_A(20)          <= '0';
    SRAM_nCS            <= bs_nCS when bootstrap_busy = '1' else RAM_nCS;
    SRAM_nOE            <= bs_nOE when bootstrap_busy = '1' else RAM_nOE;

    -- The RAM write is carefully gated to provide adequate data setup/hold time
    -- Note: the Papilio Duo RAM is fast (10ns), here the WE pulse will be 16.25ns
    -- Be wary of this if porting to another board!!!

    SRAM_nWE        <= bs_nWE  when bootstrap_busy = '1' else (RAM_nWE or not clock_32);
    RAM_Dout        <= SRAM_D; -- anyone can read SRAM_D without contention but his provides some logical separation

    -- bootstrap state machine
    state_bootstrap : process(clock_32, powerup_reset_n, bs_state_next)
        begin
            bs_state <= bs_state_next;                            -- advance bootstrap state machine
            if powerup_reset_n = '0' then                         -- external reset pin
                bs_state_next <= INIT;                            -- move state machine to INIT state
            elsif rising_edge(clock_32) then
                case bs_state is
                    when INIT =>
                        bootstrap_busy <= '1';                    -- indicate bootstrap in progress (holds user in reset)
                        flash_init <= '0';                        -- signal FLASH to begin init
                        bs_A   <= (others => '1');                -- SRAM address all ones (becomes zero on first increment)
                        bs_nCS <= '0';                            -- SRAM always selected during bootstrap
                        bs_nOE <= '1';                            -- SRAM output disabled during bootstrap
                        bs_nWE <= '1';                            -- SRAM write enable inactive default state
                        bs_state_next <= START_READ_FLASH;
                    when START_READ_FLASH =>
                        flash_init <= '1';                        -- allow FLASH to exit init state
                        if flash_Done = '0' then                  -- wait for FLASH init to begin
                            bs_state_next <= READ_FLASH;
                        end if;
                    when READ_FLASH =>
                        if flash_Done = '1' then                  -- wait for FLASH init to complete
                            bs_state_next <= WAIT0;
                        end if;
                    when WAIT0 =>                                 -- wait for the first FLASH byte to be available
                        bs_state_next <= WAIT1;
                    when WAIT1 =>
                        bs_state_next <= WAIT2;
                    when WAIT2 =>
                        bs_state_next <= WAIT3;
                    when WAIT3 =>
                        bs_state_next <= WAIT4;
                    when WAIT4 =>
                        bs_state_next <= WAIT5;
                    when WAIT5 =>
                        bs_state_next <= WAIT6;
                    when WAIT6 =>
                        bs_state_next <= WAIT7;
                    when WAIT7 =>
                        bs_state_next <= WAIT8;
                    when WAIT8 =>
                        bs_state_next <= FLASH0;
                    when WAIT9 =>
                        bs_state_next <= WAIT10;
                    when WAIT10 =>
                        bs_state_next <= WAIT11;
                    when WAIT11 =>
                        bs_state_next <= FLASH0;
                    -- every 8 clock cycles (32M/8 = 2Mhz) we have a new byte from FLASH
                    -- use this ample time to write it to SRAM, we just have to toggle nWE
                    when FLASH0 =>
                        bs_A <= bs_A + 1;                         -- increment SRAM address
                        bs_state_next <= FLASH1;                  -- idle
                    when FLASH1 =>
                        bs_Din( 7 downto 0) <= flash_data;       -- place byte on SRAM data bus
                        bs_state_next <= FLASH2;                  -- idle
                    when FLASH2 =>
                        bs_nWE <= '0';                            -- SRAM write enable
                        bs_state_next <= FLASH3;
                    when FLASH3 =>
                        bs_state_next <= FLASH4;                  -- idle
                    when FLASH4 =>
                        bs_state_next <= FLASH5;                  -- idle
                    when FLASH5 =>
                        bs_state_next <= FLASH6;                  -- idle
                    when FLASH6 =>
                        bs_nWE <= '1';                            -- SRAM write disable
                        bs_state_next <= FLASH7;
                    when FLASH7 =>
                        if "000" & bs_A = user_length then        -- when we've reached end address
                            bootstrap_busy <= '0';                -- indicate bootsrap is done
                            flash_init <= '0';                    -- place FLASH in init state
                            bs_state_next <= FLASH7;              -- remain in this state until reset
                        else
                            bs_state_next <= FLASH0;              -- else loop back
                        end if;
                    when others =>                                -- catch all, never reached
                        bs_state_next <= INIT;
                end case;
            end if;
        end process;

    -- FLASH chip SPI driver
    u_flash : entity work.spi_flash port map (
        U_FLASH_CK => FLASH_CK,
        U_FLASH_CS => FLASH_CS,
        U_FLASH_SI => FLASH_SI,
        U_FLASH_SO => FLASH_SO,
        flash_addr => user_address,
        flash_data => flash_data,
        flash_init => flash_init,
        flash_Done => flash_Done,
        flash_clk  => clock_32
    );


end architecture;
