-- BBC Master / BBC B for the Tang Nano 9K
--
-- Copright (c) 2023 Dominic Beesley
--
-- Based on previous work by Mike Stirling and Dave Banks
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
-- (c) 2021 David Banks
-- (C) 2011 Mike Stirling

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- Generic top-level entity for Altera DE1 board
entity bbc_micro_tang9k is
generic (
        IncludeAMXMouse    : boolean := false;
        IncludeSID         : boolean := false;
        IncludeMusic5000   : boolean := false;
        IncludeICEDebugger : boolean := false;
        IncludeCoPro6502   : boolean := false;  -- The three co pro options
        IncludeCoProSPI    : boolean := false; -- are currently mutually exclusive
        IncludeCoProExt    : boolean := false; -- (i.e. select just one)
        IncludeVideoNuLA   : boolean := false;
        UseOrigKeyboard    : boolean := false;
        UseT65Core         : boolean := true;
        UseAlanDCore       : boolean := false;
        PRJ_ROOT           : string := "../../..";
        MOS_NAME           : string := "/roms/bbcb/os12_basic.bit";
        SIM                : boolean := false
);
port (
        clock_27        : in    std_logic;
        btn1_n          : in    std_logic;
        btn2_n          : in    std_logic;
        ps2_clk         : inout std_logic;
        ps2_data        : inout std_logic;
        ps2_mouse_clk   : inout std_logic;
        ps2_mouse_data  : inout std_logic;
        audiol          : out   std_logic;
        audior          : out   std_logic;
        tf_miso         : in    std_logic;
        tf_cs           : out   std_logic;
        tf_sclk         : out   std_logic;
        tf_mosi         : out   std_logic;
        uart_rx         : in    std_logic;
        uart_tx         : out   std_logic;
        led             : out   std_logic_vector (5 downto 0);
---        tmds_clk_p      : out   std_logic;
---        tmds_clk_n      : out   std_logic;
---        tmds_d_p        : out   std_logic_vector(2 downto 0);
---        tmds_d_n        : out   std_logic_vector(2 downto 0);

        vga_r : out std_logic;
        vga_b : out std_logic;
        vga_g : out std_logic;
        vga_hs: out std_logic;
        vga_vs: out std_logic;

         -- Magic ports for PSRAM to be inferred
         O_psram_ck     : out    std_logic_vector(1 downto 0);
         O_psram_ck_n   : out    std_logic_vector(1 downto 0);
         IO_psram_rwds  : inout  std_logic_vector(1 downto 0);
         IO_psram_dq    : inout  std_logic_vector(15 downto 0);
         O_psram_reset_n: out    std_logic_vector(1 downto 0);
         O_psram_cs_n   : out    std_logic_vector(1 downto 0)
    );
end entity;

architecture rtl of bbc_micro_tang9k is

function RESETBITS return natural is
begin
    if SIM then
        return 10;
    else
        return 15;
    end if;
end function;

-------------
-- Signals
-------------

signal clock_32        : std_logic;
signal clock_48        : std_logic;
signal clock_96        : std_logic;
signal clock_96_p      : std_logic;
signal mem_ready       : std_logic;
signal audio_l         : std_logic_vector(15 downto 0);
signal audio_r         : std_logic_vector(15 downto 0);
signal powerup_reset_n : std_logic;
signal hard_reset_n    : std_logic;
signal reset_counter   : std_logic_vector(RESETBITS downto 0);

signal pll_reset       : std_logic;
signal pll_locked      : std_logic;

signal pcm_inl         : std_logic_vector(15 downto 0);
signal pcm_inr         : std_logic_vector(15 downto 0);

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
signal m128_mode       : std_logic;
signal m128_mode_1     : std_logic;
signal m128_mode_2     : std_logic;
signal copro_mode      : std_logic;

signal p_spi_ssel      : std_logic;
signal p_spi_sck       : std_logic;
signal p_spi_mosi      : std_logic;
signal p_spi_miso      : std_logic;
signal p_irq_b         : std_logic;
signal p_nmi_b         : std_logic;
signal p_rst_b         : std_logic;

signal caps_led        : std_logic;
signal shift_led       : std_logic;
signal is_done         : std_logic;
signal is_error        : std_logic;

signal cpu_addr        : std_logic_vector (15 downto 0);

signal test            : std_logic_vector (7 downto 0);

signal ext_keyb_led1   : std_logic;
signal ext_keyb_led2   : std_logic;
signal ext_keyb_led3   : std_logic;
signal ext_keyb_1mhz   : std_logic;
signal ext_keyb_en_n   : std_logic;
signal ext_keyb_pa     : std_logic_vector(6 downto 0);
signal ext_keyb_rst_n  : std_logic;
signal ext_keyb_ca2    : std_logic;
signal ext_keyb_pa7    : std_logic;

signal ext_tube_r_nw   : std_logic;
signal ext_tube_nrst   : std_logic;
signal ext_tube_ntube  : std_logic;
signal ext_tube_phi2   : std_logic;
signal ext_tube_a      : std_logic_vector(6 downto 0);
signal ext_tube_di     : std_logic_vector(7 downto 0);
signal ext_tube_do     : std_logic_vector(7 downto 0);

signal i_VGA_R          : std_logic_vector(3 downto 0);
signal i_VGA_G          : std_logic_vector(3 downto 0);
signal i_VGA_B          : std_logic_vector(3 downto 0);

-- A registered version to allow slow flash to be used
signal ext_A_r         : std_logic_vector (18 downto 0);

function hex_to_seven_seg(hex: std_logic_vector(3 downto 0))
        return std_logic_vector
    is begin
        case hex is
            --                   abcdefg
            when x"0" => return "0111111";
            when x"1" => return "0000110";
            when x"2" => return "1011011";
            when x"3" => return "1001111";
            when x"4" => return "1100110";
            when x"5" => return "1101101";
            when x"6" => return "1111101";
            when x"7" => return "0000111";
            when x"8" => return "1111111";
            when x"9" => return "1101111";
            when x"a" => return "1110111";
            when x"b" => return "1111100";
            when x"c" => return "0111001";
            when x"d" => return "1011110";
            when x"e" => return "1111001";
            when x"f" => return "1110001";
            when others => return "0000000";
        end case;
    end;

begin


vga_r <= i_VGA_R(i_VGA_R'high);
vga_g <= i_VGA_G(i_VGA_G'high);
vga_b <= i_VGA_B(i_VGA_B'high);

--------------------------------------------------------
-- BBC Micro Core
--------------------------------------------------------

    bbc_micro : entity work.bbc_micro_core
        generic map (
            IncludeAMXMouse    => IncludeAMXMouse,
            IncludeSID         => IncludeSID,
            IncludeMusic5000   => IncludeMusic5000,
            IncludeICEDebugger => IncludeICEDebugger,
            IncludeCoPro6502   => IncludeCoPro6502,
            IncludeCoProSPI    => IncludeCoProSPI,
            IncludeCoProExt    => IncludeCoProExt,
            IncludeVideoNuLA   => IncludeVideoNuLA,
            UseOrigKeyboard    => UseOrigKeyboard,
            UseT65Core         => UseT65Core,
            UseAlanDCore       => UseAlanDCore
            )
        port map (
            clock_27       => clock_27,
            clock_32       => clock_32,
            clock_48       => clock_48,
            clock_96       => clock_96,
            clock_avr      => '0',                 -- DB: no AVR yet
            hard_reset_n   => hard_reset_n,
            ps2_kbd_clk    => ps2_clk,
            ps2_kbd_data   => ps2_data,
            ps2_mse_clk    => ps2_mouse_clk,
            ps2_mse_data   => ps2_mouse_data,
            video_red      => i_VGA_R,
            video_green    => i_VGA_G,
            video_blue     => i_VGA_B,
            video_hsync    => vga_hs,
            video_vsync    => vga_vs,
            audio_l        => audio_l,
            audio_r        => audio_r,
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
            ext_keyb_led1  => ext_keyb_led1,
            ext_keyb_led2  => ext_keyb_led2,
            ext_keyb_led3  => ext_keyb_led3,
            ext_keyb_1mhz  => ext_keyb_1mhz,
            ext_keyb_en_n  => ext_keyb_en_n,
            ext_keyb_pa    => ext_keyb_pa,
            ext_keyb_rst_n => ext_keyb_rst_n,
            ext_keyb_ca2   => ext_keyb_ca2,
            ext_keyb_pa7   => ext_keyb_pa7,
            vid_mode       => vid_mode,
            joystick1      => (others => '1'),
            joystick2      => (others => '1'),
            avr_reset      => not hard_reset_n,
            avr_RxD        => uart_rx,
            avr_TxD        => uart_tx,
            cpu_addr       => cpu_addr,
            m128_mode      => m128_mode,
            copro_mode     => copro_mode,
            p_spi_ssel     => p_spi_ssel,
            p_spi_sck      => p_spi_sck,
            p_spi_mosi     => p_spi_mosi,
            p_spi_miso     => p_spi_miso,
            p_irq_b        => p_irq_b,
            p_nmi_b        => p_nmi_b,
            p_rst_b        => p_rst_b,
            ext_tube_r_nw  => ext_tube_r_nw,
            ext_tube_nrst  => ext_tube_nrst,
            ext_tube_ntube => ext_tube_ntube,
            ext_tube_phi2  => ext_tube_phi2,
            ext_tube_a     => ext_tube_a,
            ext_tube_di    => ext_tube_di,
            ext_tube_do    => ext_tube_do,
            test           => test
        );


    m128_mode      <= '0';       --DB: Model B
    vid_mode       <= "0000";    --DB: 15kHz for now
    copro_mode     <= '0';       --DB: ?
    keyb_dip       <= "00000000";--DB: ?;

--------------------------------------------------------
-- Clock Generation
--------------------------------------------------------

    -- 48 MHz master clock from 27MHz input clock
    -- plus intermediate 96MHz clock for scan doubler
    pll2: entity work.Gowin_rPLL
    port map (
        clkout => clock_96,
        clkoutp => clock_96_p,
        lock => pll_locked,
        clkoutd => clock_48,
        clkoutd3 => clock_32,
        reset => pll_reset,
        clkin => clock_27
    );

--------------------------------------------------------
-- Power Up Reset Generation
--------------------------------------------------------

    -- PLL is reset by external reset switch
    pll_reset <= not btn1_n;     --DB: no keyboard yet...

    -- Generate a reliable power up reset
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
            powerup_reset_n <= reset_counter(reset_counter'high);
        end if;
    end process;

    hard_reset_n <= not (pll_reset or not pll_locked or not powerup_reset_n or not mem_ready);

---- DB: TODO: Get PWM/SigDelta from Blitter --- --------------------------------------------------------
---- DB: TODO: Get PWM/SigDelta from Blitter --- -- Audio DACs
---- DB: TODO: Get PWM/SigDelta from Blitter --- --------------------------------------------------------
---- DB: TODO: Get PWM/SigDelta from Blitter --- 
---- DB: TODO: Get PWM/SigDelta from Blitter ---     i2s : entity work.i2s_intf
---- DB: TODO: Get PWM/SigDelta from Blitter ---         port map (
---- DB: TODO: Get PWM/SigDelta from Blitter ---             CLK         => clock_48,
---- DB: TODO: Get PWM/SigDelta from Blitter ---             nRESET      => hard_reset_n,
---- DB: TODO: Get PWM/SigDelta from Blitter ---             PCM_INL     => pcm_inl,
---- DB: TODO: Get PWM/SigDelta from Blitter ---             PCM_INR     => pcm_inr,
---- DB: TODO: Get PWM/SigDelta from Blitter ---             PCM_OUTL    => audio_l,
---- DB: TODO: Get PWM/SigDelta from Blitter ---             PCM_OUTR    => audio_r,
---- DB: TODO: Get PWM/SigDelta from Blitter ---             I2S_MCLK    => AUD_XCK,
---- DB: TODO: Get PWM/SigDelta from Blitter ---             I2S_LRCLK   => AUD_DACLRCK,
---- DB: TODO: Get PWM/SigDelta from Blitter ---             I2S_BCLK    => AUD_BCLK,
---- DB: TODO: Get PWM/SigDelta from Blitter ---             I2S_DOUT    => AUD_DACDAT,
---- DB: TODO: Get PWM/SigDelta from Blitter ---             I2S_DIN     => AUD_ADCDAT
---- DB: TODO: Get PWM/SigDelta from Blitter ---             );
---- DB: TODO: Get PWM/SigDelta from Blitter --- 
---- DB: TODO: Get PWM/SigDelta from Blitter ---     -- This is to avoid a possible conflict if the codec is in master mode
---- DB: TODO: Get PWM/SigDelta from Blitter ---     AUD_ADCLRCK <= 'Z';
---- DB: TODO: Get PWM/SigDelta from Blitter --- 
---- DB: TODO: Get PWM/SigDelta from Blitter ---     i2c : entity work.i2c_loader
---- DB: TODO: Get PWM/SigDelta from Blitter ---         generic map (
---- DB: TODO: Get PWM/SigDelta from Blitter ---             log2_divider => 7
---- DB: TODO: Get PWM/SigDelta from Blitter ---             )
---- DB: TODO: Get PWM/SigDelta from Blitter ---         port map (
---- DB: TODO: Get PWM/SigDelta from Blitter ---             CLK         => clock_48,
---- DB: TODO: Get PWM/SigDelta from Blitter ---             nRESET      => hard_reset_n,
---- DB: TODO: Get PWM/SigDelta from Blitter ---             I2C_SCL     => I2C_SCLK,
---- DB: TODO: Get PWM/SigDelta from Blitter ---             I2C_SDA     => I2C_SDAT,
---- DB: TODO: Get PWM/SigDelta from Blitter ---             IS_DONE     => is_done,
---- DB: TODO: Get PWM/SigDelta from Blitter ---             IS_ERROR    => is_error
---- DB: TODO: Get PWM/SigDelta from Blitter ---             );
---- DB: TODO: Get PWM/SigDelta from Blitter ---     LEDR(4) <= is_error;
---- DB: TODO: Get PWM/SigDelta from Blitter ---     LEDR(5) <= not is_done;

--- DB: -----------------------------------------------------------
--- DB: ----- Map external memory bus to SRAM/FLASH
--- DB: -----------------------------------------------------------
--- DB: ---
--- DB: ---    -- Hold the ext_A for multiple clock cycles to allow slow FLASH to be used
--- DB: ---    -- This is necessary because currently FLASH and SRAM accesses are
--- DB: ---    -- interleaved every cycle.
--- DB: ---    process(clock_48)
--- DB: ---    begin
--- DB: ---        if rising_edge(clock_48) then
--- DB: ---            if ext_A(18) = '0' then
--- DB: ---                ext_A_r <= ext_A;
--- DB: ---            end if;
--- DB: ---        end if;
--- DB: ---    end process;
--- DB: ---
--- DB: ---    -- 0x00000-0x3FFFF -> FLASH
--- DB: ---    -- 0x40000-0x7FFFF -> SRAM
--- DB: ---    ext_Dout <= SRAM_DQ(7 downto 0) when ext_A(18) = '1' else FL_DQ;
--- DB: ---
--- DB: ---    FL_RST_N <= hard_reset_n;
--- DB: ---    FL_CE_N <= '0';
--- DB: ---    FL_OE_N <= '0';
--- DB: ---    FL_WE_N <= '1';
--- DB: ---    -- Flash address change every at most every 16 cycles (2MHz)
--- DB: ---    -- Use the latched version to maximise access time
--- DB: ---    FL_ADDR <= "000" & m128_mode & ext_A_r(17 downto 0);
--- DB: ---
--- DB: ---    -- SRAM bus
--- DB: ---    SRAM_UB_N <= '1';
--- DB: ---    SRAM_LB_N <= '0';
--- DB: ---    SRAM_CE_N <= '0';
--- DB: ---    SRAM_OE_N <= ext_nOE;
--- DB: ---
--- DB: ---    -- Gate the WE with clock to provide more address/data hold time
--- DB: ---    SRAM_WE_N <= ext_nWE or not clock_48;
--- DB: ---
--- DB: ---    SRAM_ADDR <= ext_A(17 downto 0);
--- DB: ---    SRAM_DQ(15 downto 8) <= (others => 'Z');
--- DB: ---    SRAM_DQ(7 downto 0) <= ext_Din when ext_nWE = '0' else (others => 'Z');
--- DB: ---
--- DB: ---    -- HEX Displays (active low)
--- DB: ---    HEX3 <= hex_to_seven_seg(cpu_addr(15 downto 12)) xor "1111111";
--- DB: ---    HEX2 <= hex_to_seven_seg(cpu_addr(11 downto  8)) xor "1111111";
--- DB: ---    HEX1 <= hex_to_seven_seg(cpu_addr( 7 downto  4)) xor "1111111";
--- DB: ---    HEX0 <= hex_to_seven_seg(cpu_addr( 3 downto  0)) xor "1111111";
--- DB: ---
--- DB: ---    -- Unused LEDs (active high)
--- DB: ---    LEDG <= (others => '0');
--- DB: ---    LEDR(0) <= caps_led;
--- DB: ---    LEDR(1) <= shift_led;
--- DB: ---    LEDR(3 downto 2) <= (others => '0');
--- DB: ---    LEDR(9 downto 6) <= (others => '0');

--- DB ---    -- GPIO_1 is the Co Processor connection
--- DB ---
--- DB ---    GenCoProSPI: if IncludeCoProSPI generate
--- DB ---    begin
--- DB ---        -- Co Pro SPI
--- DB ---        p_spi_ssel <= GPIO_1(0);
--- DB ---        p_spi_sck  <= GPIO_1(1);
--- DB ---        p_spi_mosi <= GPIO_1(2);
--- DB ---        GPIO_1(3)  <= p_spi_miso;
--- DB ---        GPIO_1(4)  <= p_irq_b;
--- DB ---        GPIO_1(5)  <= p_nmi_b;
--- DB ---        GPIO_1(6)  <= p_rst_b;
--- DB ---
--- DB ---        -- Debug outputs for SPI interface
--- DB ---        GPIO_1(28) <= p_spi_ssel;
--- DB ---        GPIO_1(29) <= p_spi_sck;
--- DB ---        GPIO_1(30) <= p_spi_mosi;
--- DB ---        GPIO_1(31) <= p_spi_miso;
--- DB ---        GPIO_1(32) <= p_irq_b;
--- DB ---        GPIO_1(33) <= p_nmi_b;
--- DB ---        GPIO_1(34) <= p_rst_b;
--- DB ---        GPIO_1(35) <= '0';
--- DB ---
--- DB ---        -- Debug outputs for test signals
--- DB ---        GPIO_1(27 downto 20) <= test;
--- DB ---
--- DB ---        -- Unused outputs
--- DB ---        GPIO_1( 2 downto 0)  <= (others => 'Z');
--- DB ---        GPIO_1(17 downto 7)  <= (others => 'Z');
--- DB ---    end generate;
--- DB ---
--- DB ---    GenCoProNotSPI: if not IncludeCoProSPI generate
--- DB ---    begin
--- DB ---        p_spi_ssel <= '1';
--- DB ---        p_spi_sck  <= '1';
--- DB ---        p_spi_mosi <= '1';
--- DB ---    end generate;
--- DB ---
--- DB ---    GenCoProExt: if IncludeCoProExt generate
--- DB ---    begin
--- DB ---        -- Tube signals, in a somewhat arbitrary order
--- DB ---        ext_tube_do          <= GPIO_1(15 downto 8);
--- DB ---        GPIO_1(0)            <= ext_tube_phi2;
--- DB ---        GPIO_1(1)            <= ext_tube_r_nw;
--- DB ---        GPIO_1(2)            <= ext_tube_ntube;
--- DB ---        GPIO_1(3)            <= ext_tube_nrst;
--- DB ---        GPIO_1(7 downto 4)   <= ext_tube_a(3 downto 0);
--- DB ---        GPIO_1(15 downto 8)  <= ext_tube_di when ext_tube_r_nw = '0' else (others => 'Z');
--- DB ---
--- DB ---        -- Debug outputs for test signals
--- DB ---        GPIO_1(27 downto 20) <= test;
--- DB ---
--- DB ---        -- Unused outputs
--- DB ---        GPIO_1(35 downto 28) <= (others => 'Z');
--- DB ---        GPIO_1(17 downto 16) <= (others => 'Z');
--- DB ---    end generate;
--- DB ---
--- DB ---    GenCoProNotExt: if not IncludeCoProExt generate
--- DB ---    begin
--- DB ---        ext_tube_do  <= x"FE";
--- DB ---    end generate;

--- DB ---    -- External Keyboard connected to GPIO0
--- DB ---    -- GND                                -- pin 1
--- DB ---    ext_keyb_rst_n  <= GPIO_0(34);        -- pin 2
--- DB ---    GPIO_0(32)      <= ext_keyb_1mhz;     -- pin 3
--- DB ---    GPIO_0(30)      <= ext_keyb_en_n;     -- pin 4
--- DB ---    GPIO_0(28)      <= ext_keyb_pa(4);    -- pin 5
--- DB ---    GPIO_0(26)      <= ext_keyb_pa(5);    -- pin 6
--- DB ---    GPIO_0(24)      <= ext_keyb_pa(6);    -- pin 7
--- DB ---    GPIO_0(22)      <= ext_keyb_pa(0);    -- pin 8
--- DB ---    GPIO_0(20)      <= ext_keyb_pa(1);    -- pin 9
--- DB ---    GPIO_0(18)      <= ext_keyb_pa(2);    -- pin 10
--- DB ---    GPIO_0(16)      <= ext_keyb_pa(3);    -- pin 11
--- DB ---    ext_keyb_pa7    <= GPIO_0(14);        -- pin 12
--- DB ---    GPIO_0(12)      <= ext_keyb_led3;     -- pin 13
--- DB ---    ext_keyb_ca2    <= GPIO_0(10);        -- pin 14
--- DB ---    -- VCC                                -- pin 15
--- DB ---    GPIO_0(8)      <= ext_keyb_led1;      -- pin 16
--- DB ---    GPIO_0(6)      <= ext_keyb_led2;      -- pin 17
--- DB ---
--- DB ---    -- Unused outputs
--- DB ---    DRAM_ADDR            <= (others => 'Z');
--- DB ---    DRAM_DQ              <= (others => 'Z');
--- DB ---    GPIO_0(35 downto 33) <= (others => 'Z');
--- DB ---    GPIO_0(31 downto 15) <= (others => 'Z');
--- DB ---    GPIO_0(13 downto 0)  <= (others => 'Z');

   
e_mem: entity work.mem_tang_9k
generic map (
    PRJ_ROOT => PRJ_ROOT,
    MOS_NAME => MOS_NAME
)
port map (
   CLK_96         => clock_96,
   CLK_96_P       => clock_96_p,
   RST_n          => powerup_reset_n,
   READY          => mem_ready,
   CLK_48         => clock_48,
   ext_A_stb      => ext_A_stb,
   ext_A          => ext_A,
   ext_Din        => ext_Din,
   ext_Dout       => ext_Dout,
   ext_nCS        => ext_nCS,
   ext_nWE        => ext_nWE_long,
   ext_nOE        => ext_nOE,

   O_psram_ck     => O_psram_ck,
   IO_psram_rwds  => IO_psram_rwds,
   IO_psram_dq    => IO_psram_dq,
   O_psram_cs_n   => O_psram_cs_n,
   O_psram_reset_n=> O_psram_reset_n

);

end architecture;
