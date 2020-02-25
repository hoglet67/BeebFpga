-- BBC Micro Core, designed to be platform independant
--
-- Copyright (c) 2015 David Banks
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
-- BBC Micro Core, designed to be platform independant
--
-- (c) 2015 David Banks
-- (C) 2011 Mike Stirling
--
-- Master 128 TODO List
-- ACC_IFJ - direct FC00-FDFF to cartridge port
-- ACC_ITU - internal / external tube
-- INTON/INTOFF registers
-- refactor NVRAM (146818 off System VIA Port A)

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity bbc_micro_core is
    generic (
        IncludeAMXMouse    : boolean := false;
        IncludeSID         : boolean := false;
        IncludeMusic5000   : boolean := false;
        IncludeICEDebugger : boolean := false;
        IncludeCoPro6502   : boolean := false; -- The three co pro options
        IncludeCoProSPI    : boolean := false; -- are currently mutually exclusive
        IncludeCoProExt    : boolean := false; -- (i.e. select just one)
        IncludeVideoNuLA   : boolean := false;
        UseOrigKeyboard    : boolean := false;
        UseT65Core         : boolean := false;
        UseAlanDCore       : boolean := true
    );
    port (
        -- Clocks
        clock_32       : in    std_logic;
        clock_24       : in    std_logic;
        clock_27       : in    std_logic;
        clock_48       : in    std_logic;

        -- Hard reset (active low)
        hard_reset_n   : in    std_logic;

        -- Keyboard
        ps2_kbd_clk    : in    std_logic;
        ps2_kbd_data   : in    std_logic;

        -- Mouse
        ps2_mse_clk    : inout std_logic;
        ps2_mse_data   : inout std_logic;

        -- Video
        video_red      : out   std_logic_vector (3 downto 0);
        video_green    : out   std_logic_vector (3 downto 0);
        video_blue     : out   std_logic_vector (3 downto 0);
        video_vsync    : out   std_logic;
        video_hsync    : out   std_logic;

        -- Audio
        audio_l        : out   std_logic_vector (15 downto 0);
        audio_r        : out   std_logic_vector (15 downto 0);

        -- External memory (e.g. SRAM and/or FLASH)
        -- 512KB logical address space
        ext_nOE        : out   std_logic;
        ext_nWE        : out   std_logic;
        ext_nCS        : out   std_logic;
        ext_A          : out   std_logic_vector (18 downto 0);
        ext_Dout       : in    std_logic_vector (7 downto 0);
        ext_Din        : out   std_logic_vector (7 downto 0);

        -- SD Card
        SDMISO         : in    std_logic;
        SDSS           : out   std_logic;
        SDCLK          : out   std_logic;
        SDMOSI         : out   std_logic;

        -- KeyBoard LEDs (active high)
        caps_led       : out   std_logic;
        shift_led      : out   std_logic;

        -- Keyboard DIP switches
        keyb_dip       : in    std_logic_vector(7 downto 0);

        -- Original Keyboard
        ext_keyb_led1  : out   std_logic;
        ext_keyb_led2  : out   std_logic;
        ext_keyb_led3  : out   std_logic;
        ext_keyb_1mhz  : out   std_logic;
        ext_keyb_en_n  : out   std_logic;
        ext_keyb_pa    : out   std_logic_vector(6 downto 0);
        ext_keyb_rst_n : in    std_logic;
        ext_keyb_ca2   : in    std_logic;
        ext_keyb_pa7   : in    std_logic;

        -- Format of Video
        -- Bit 0 selects 15.625KHz SRGB (0) or 31.5KHz VGA (1)
        -- Bit 1 selects Mist (0) or RGB2VGA (1) scan doubler is used for VGA
        -- Bit 2 inverts hsync
        -- Bit 3 inverts vsync
        vid_mode       : in    std_logic_vector(3 downto 0);

        -- Main Joystick and Secondary Joystick
        -- Bit 0 - Up (active low)
        -- Bit 1 - Down (active low)
        -- Bit 2 - Left (active low)
        -- Bit 3 - Right (active low)
        -- Bit 4 - Fire (active low)
        joystick1      : in    std_logic_vector(4 downto 0);
        joystick2      : in    std_logic_vector(4 downto 0);

        -- ICE T65 Deubgger 57600 baud serial
        avr_RxD        : in    std_logic;
        avr_TxD        : out   std_logic;

        -- Current CPU address, e.g. to drive a hex display
        cpu_addr       : out   std_logic_vector(15 downto 0);

        -- Master Mode
        m128_mode      : in    std_logic;

        -- Co Pro 6502 Mode
        copro_mode     : in    std_logic;

        -- Co Pro SPI - slave interface
        p_spi_ssel     : in    std_logic;
        p_spi_sck      : in    std_logic;
        p_spi_mosi     : in    std_logic;
        p_spi_miso     : out   std_logic;

        -- Co Pro SPI - interrupts/control
        p_irq_b        : out   std_logic;
        p_nmi_b        : out   std_logic;
        p_rst_b        : out   std_logic;

        -- External tube outputs, for connecting to PiTubeDirect
        ext_tube_r_nw  : out   std_logic;
        ext_tube_nrst  : out   std_logic;
        ext_tube_ntube : out   std_logic;
        ext_tube_phi2  : out   std_logic;
        ext_tube_a     : out   std_logic_vector(6 downto 0);
        ext_tube_di    : out   std_logic_vector(7 downto 0);
        ext_tube_do    : in    std_logic_vector(7 downto 0) := x"FE";

        -- Test outputs
        test           : out   std_logic_vector(7 downto 0)

    );
end entity;

architecture rtl of bbc_micro_core is

-- Use 4-bit RGB when VideoNuLA is included, other 1-bit RGB
function calc_rgb_width(includeVideoNuLA : boolean) return integer is
begin
    if includeVideoNuLA then
        return 4;
    else
        return 1;
    end if;
end function;

constant RGB_WIDTH : integer := calc_rgb_width(IncludeVideoNuLA);

-------------
-- Signals
-------------

signal reset        :   std_logic;
signal reset_n      :   std_logic;
signal clock_avr    :   std_logic;

-- Clock enable counter
-- CPU and video cycles are interleaved.  The CPU runs at 2 MHz (every 16th
-- cycle) and the video subsystem is enabled on every odd cycle.
signal clken_counter    :   unsigned(4 downto 0);
signal cpu_cycle        :   std_logic; -- Qualifies all 2 MHz cycles
signal cpu_cycle_mask   :   std_logic_vector(1 downto 0); -- Set to mask CPU cycles until 1 MHz cycle is complete
signal cpu_clken        :   std_logic; -- 2 MHz cycles in which the CPU is enabled
signal cpu_clken1       :   std_logic; -- delayed one cycle for BusMonitor

-- IO cycles are out of phase with the CPU
signal vid_clken        :   std_logic; -- 16 MHz video cycles
signal mhz12_clken      :   std_logic; -- 12 MHz used by SAA 5050
signal mhz6_clken       :   std_logic; -- 6 MHz used by Music 5000
signal mhz4_clken       :   std_logic; -- Used by 6522
signal mhz2_clken       :   std_logic; -- Used for latching CPU address for clock stretch
signal mhz1_clken       :   std_logic; -- 1 MHz bus and associated peripherals, 6522 phase 2

-- SAA5050 needs a 12 MHz clock enable relative to a 24 MHz clock
signal ttxt_clken_counter   :   unsigned(2 downto 0);

-- CPU signals
signal cpu_mode         :   std_logic_vector(1 downto 0);
signal cpu_ready        :   std_logic;
signal cpu_abort_n      :   std_logic;
signal cpu_irq_n        :   std_logic;
signal cpu_nmi_n        :   std_logic;
signal cpu_so_n         :   std_logic;
signal cpu_r_nw         :   std_logic;
signal cpu_nr_w         :   std_logic;
signal cpu_sync         :   std_logic;
signal cpu_ef           :   std_logic;
signal cpu_mf           :   std_logic;
signal cpu_xf           :   std_logic;
signal cpu_ml_n         :   std_logic;
signal cpu_vp_n         :   std_logic;
signal cpu_vda          :   std_logic;
signal cpu_vpa          :   std_logic;
signal cpu_a            :   std_logic_vector(23 downto 0);
signal cpu_di           :   std_logic_vector(7 downto 0);
signal cpu_do           :   std_logic_vector(7 downto 0);
signal cpu_addr_us      :   unsigned (15 downto 0);
signal cpu_dout_us      :   unsigned (7 downto 0);

-- CRTC signals
signal crtc_clken       :   std_logic;
signal crtc_do          :   std_logic_vector(7 downto 0);
signal crtc_vsync       :   std_logic;
signal crtc_vsync_n     :   std_logic;
signal crtc_hsync       :   std_logic;
signal crtc_hsync_n     :   std_logic;
signal crtc_de          :   std_logic;
signal crtc_cursor      :   std_logic;
constant crtc_lpstb     :   std_logic := '0';
signal crtc_ma          :   std_logic_vector(13 downto 0);
signal crtc_ra          :   std_logic_vector(4 downto 0);

-- Decoded display address after address translation for hardware
-- scrolling
signal display_a        :   std_logic_vector(14 downto 0);

-- "VIDPROC" signals
signal vidproc_invert_n :   std_logic;
signal vidproc_disen    :   std_logic;
signal r_in             :   std_logic;
signal g_in             :   std_logic;
signal b_in             :   std_logic;
signal r_out            :   std_logic_vector(RGB_WIDTH - 1 downto 0);
signal g_out            :   std_logic_vector(RGB_WIDTH - 1 downto 0);
signal b_out            :   std_logic_vector(RGB_WIDTH - 1 downto 0);

-- Scandoubler signals (Mist)
signal rgbi_in          :   std_logic_vector(RGB_WIDTH * 3 downto 0);
signal vga0_r           :   std_logic_vector(RGB_WIDTH - 1 downto 0);
signal vga0_g           :   std_logic_vector(RGB_WIDTH - 1 downto 0);
signal vga0_b           :   std_logic_vector(RGB_WIDTH - 1 downto 0);
signal vga0_hs          :   std_logic;
signal vga0_vs          :   std_logic;
signal vga0_mode        :   std_logic;
-- Scandoubler signals (RGB2VGA)
signal vga1_r           :   std_logic_vector(RGB_WIDTH - 1 downto 0);
signal vga1_g           :   std_logic_vector(RGB_WIDTH - 1 downto 0);
signal vga1_b           :   std_logic_vector(RGB_WIDTH - 1 downto 0);
signal vga1_hs          :   std_logic;
signal vga1_vs          :   std_logic;
signal vga1_mode        :   std_logic;
signal rgbi_out         :   std_logic_vector(RGB_WIDTH * 3 downto 0);
signal vsync_int        :   std_logic;
signal hsync_int        :   std_logic;

signal final_r          :   std_logic_vector(RGB_WIDTH - 1 downto 0);
signal final_g          :   std_logic_vector(RGB_WIDTH - 1 downto 0);
signal final_b          :   std_logic_vector(RGB_WIDTH - 1 downto 0);

-- SAA5050 signals
signal ttxt_glr         :   std_logic;
signal ttxt_dew         :   std_logic;
signal ttxt_crs         :   std_logic;
signal ttxt_lose        :   std_logic;
signal ttxt_r           :   std_logic;
signal ttxt_g           :   std_logic;
signal ttxt_b           :   std_logic;
signal ttxt_y           :   std_logic;

-- System VIA signals
signal sys_via_do       :   std_logic_vector(7 downto 0);
signal sys_via_do_oe_n  :   std_logic;
signal sys_via_irq_n    :   std_logic;
signal sys_via_ca1_in   :   std_logic := '0';
signal sys_via_ca2_in   :   std_logic := '0';
signal sys_via_ca2_out  :   std_logic;
signal sys_via_ca2_oe_n :   std_logic;
signal sys_via_pa_in    :   std_logic_vector(7 downto 0);
signal sys_via_pa_out   :   std_logic_vector(7 downto 0);
signal sys_via_pa_oe_n  :   std_logic_vector(7 downto 0);
signal sys_via_cb1_in   :   std_logic := '0';
signal sys_via_cb1_out  :   std_logic;
signal sys_via_cb1_oe_n :   std_logic;
signal sys_via_cb2_in   :   std_logic := '0';
signal sys_via_cb2_out  :   std_logic;
signal sys_via_cb2_oe_n :   std_logic;
signal sys_via_pb_in    :   std_logic_vector(7 downto 0);
signal sys_via_pb_out   :   std_logic_vector(7 downto 0);
signal sys_via_pb_oe_n  :   std_logic_vector(7 downto 0);
signal sys_via_do_r     :   std_logic_vector (7 downto 0);

-- User VIA signals
signal user_via_do      :   std_logic_vector(7 downto 0);
signal user_via_do_oe_n :   std_logic;
signal user_via_irq_n   :   std_logic;
signal user_via_ca1_in  :   std_logic := '0';
constant user_via_ca2_in  :   std_logic := '0';
signal user_via_ca2_out :   std_logic;
signal user_via_ca2_oe_n    :   std_logic;
signal user_via_pa_in   :   std_logic_vector(7 downto 0);
signal user_via_pa_out  :   std_logic_vector(7 downto 0);
signal user_via_pa_oe_n :   std_logic_vector(7 downto 0);
signal user_via_cb1_in  :   std_logic := '0';
signal user_via_cb1_out :   std_logic;
signal user_via_cb1_oe_n    :   std_logic;
signal user_via_cb2_in  :   std_logic := '0';
signal user_via_cb2_out :   std_logic;
signal user_via_cb2_oe_n    :   std_logic;
signal user_via_pb_in   :   std_logic_vector(7 downto 0);
signal user_via_pb_out  :   std_logic_vector(7 downto 0);
signal user_via_pb_oe_n :   std_logic_vector(7 downto 0);
signal user_via_do_r    :   std_logic_vector (7 downto 0);

-- Mouse VIA signals
signal mouse_via_do      :   std_logic_vector(7 downto 0);
signal mouse_via_do_oe_n :   std_logic;
signal mouse_via_irq_n   :   std_logic;
signal mouse_via_ca1_in  :   std_logic := '0';
constant mouse_via_ca2_in  :   std_logic := '0';
signal mouse_via_ca2_out :   std_logic;
signal mouse_via_ca2_oe_n    :   std_logic;
signal mouse_via_pa_in   :   std_logic_vector(7 downto 0);
signal mouse_via_pa_out  :   std_logic_vector(7 downto 0);
signal mouse_via_pa_oe_n :   std_logic_vector(7 downto 0);
signal mouse_via_cb1_in  :   std_logic := '0';
signal mouse_via_cb1_out :   std_logic;
signal mouse_via_cb1_oe_n    :   std_logic;
signal mouse_via_cb2_in  :   std_logic := '0';
signal mouse_via_cb2_out :   std_logic;
signal mouse_via_cb2_oe_n    :   std_logic;
signal mouse_via_pb_in   :   std_logic_vector(7 downto 0);
signal mouse_via_pb_out  :   std_logic_vector(7 downto 0);
signal mouse_via_pb_oe_n :   std_logic_vector(7 downto 0);
signal mouse_via_do_r    :   std_logic_vector(7 downto 0);
signal mouse_read        :   std_logic;
signal mouse_err         :   std_logic;
signal mouse_rx_data     :   std_logic_vector(7 downto 0);
signal mouse_write       :   std_logic;
signal mouse_tx_data     :   std_logic_vector(7 downto 0);

-- IC32 latch on System VIA
signal ic32             :   std_logic_vector(7 downto 0);
signal sound_enable_n   :   std_logic;
--signal speech_read_n    :   std_logic;
--signal speech_write_n   :   std_logic;
signal keyb_enable_n    :   std_logic;
signal disp_addr_offs   :   std_logic_vector(1 downto 0);

-- Keyboard
signal keyb_column      :   std_logic_vector(3 downto 0);
signal keyb_row         :   std_logic_vector(2 downto 0);
signal keyb_out         :   std_logic;
signal keyb_int         :   std_logic;
signal keyb_break       :   std_logic;

-- Sound generator
signal sound_ready      :   std_logic;
signal sound_di         :   std_logic_vector(7 downto 0);
signal sound_ao         :   std_logic_vector(7 downto 0);

-- Optional SID
signal sid_ao           :   std_logic_vector(17 downto 0);
signal sid_do           :   std_logic_vector(7 downto 0);
signal sid_enable       :   std_logic;

-- Optional Music5000
signal music5000_ao_l   :   std_logic_vector(15 downto 0);
signal music5000_ao_r   :   std_logic_vector(15 downto 0);
signal music5000_do     :   std_logic_vector(7 downto 0);

-- Optional Tube
signal tube_do          :   std_logic_vector(7 downto 0);
signal tube_clken       :   std_logic;
signal tube_clken1      :   std_logic := '0';
signal tube_ram_wr      :   std_logic;
signal tube_ram_addr    :   std_logic_vector(15 downto 0);
signal tube_ram_data_in :   std_logic_vector(7 downto 0);
signal ext_tube_clk     :   std_logic;

-- Memory enables
signal ram_enable       :   std_logic;      -- 0x0000
signal rom_enable       :   std_logic;      -- 0x8000 (BASIC/sideways ROMs)
signal mos_enable       :   std_logic;      -- 0xC000

-- IO region enables
signal io_fred          :   std_logic;      -- 0xFC00 (1 MHz bus)
signal io_fred_n        :   std_logic;      -- 0xFC00 (1 MHz bus)
signal io_jim           :   std_logic;      -- 0xFD00 (1 MHz bus)
signal io_jim_n         :   std_logic;      -- 0xFD00 (1 MHz bus)
signal io_sheila        :   std_logic;      -- 0xFE00 (System peripherals)
signal io_sheila_n      :   std_logic;      -- 0xFE00 (System peripherals)

-- SHIELA
signal crtc_enable      :   std_logic;      -- 0xFE00-FE07
signal acia_enable      :   std_logic;      -- 0xFE08-FE0F
signal serproc_enable   :   std_logic;      -- 0xFE10-FE1F
signal vidproc_enable   :   std_logic;      -- 0xFE20-FE2F
signal romsel_enable    :   std_logic;      -- 0xFE30-FE3F
signal sys_via_enable   :   std_logic;      -- 0xFE40-FE5F
signal user_via_enable  :   std_logic;      -- 0xFE60-FE7F, or FE80-FE9F
signal mouse_via_enable :   std_logic;      -- 0xFE60-FE7F
--signal adlc_enable      :   std_logic;      -- 0xFEA0-FEBF (Econet)
signal tube_enable      :   std_logic;      -- 0xFEE0-FEFF

signal adc_enable       :   std_logic;      -- 0xFEC0-FEDF
signal adc_eoc_n        :   std_logic;
signal adc_do           :   std_logic_vector(7 downto 0);
signal adc_ch0          :   std_logic_vector(11 downto 0);
signal adc_ch1          :   std_logic_vector(11 downto 0);
signal adc_ch2          :   std_logic_vector(11 downto 0);
signal adc_ch3          :   std_logic_vector(11 downto 0);

-- ROM select latch
signal romsel           :   std_logic_vector(7 downto 0);

signal mhz1_enable      :   std_logic;      -- Set for access to any 1 MHz peripheral

signal sdclk_int : std_logic;

-- Master Real Time Clock / CMOS RAM
signal rtc_adi         : std_logic_vector(7 downto 0);
signal rtc_do          : std_logic_vector(7 downto 0);
signal rtc_ce          : std_logic;
signal rtc_r_nw        : std_logic;
signal rtc_as          : std_logic;
signal rtc_ds          : std_logic;

-- 0xFE34 Access Control
signal acccon          : std_logic_vector(7 downto 0);
signal acc_irr         : std_logic;
signal acc_tst         : std_logic;
signal acc_ifj         : std_logic;
signal acc_itu         : std_logic;
signal acc_y           : std_logic;
signal acc_x           : std_logic;
signal acc_e           : std_logic;
signal acc_d           : std_logic;

signal acccon_enable   : std_logic;     -- 0xFE34-0xFE37
signal intoff_enable   : std_logic;     -- 0xFE38-0xFE3B
signal inton_enable    : std_logic;     -- 0xFE3C-0xFE3F

signal vdu_op          : std_logic;     -- last opcode was 0xC000-0xDFFF

begin

    -------------------------
    -- COMPONENT INSTANCES
    -------------------------

    GenDebug: if IncludeICEDebugger generate

        core : entity work.MOS6502CpuMonCore
            generic map (
                UseT65Core   => UseT65Core,
                UseAlanDCore => UseAlanDCore
                )
            port map (
                clock_avr    => clock_avr,
                busmon_clk   => clock_32,
                busmon_clken => cpu_clken1,
                cpu_clk      => clock_32,
                cpu_clken    => cpu_clken,
                IRQ_n        => cpu_irq_n,
                NMI_n        => cpu_nmi_n,
                Sync         => cpu_sync,
                Addr         => cpu_a(15 downto 0),
                R_W_n        => cpu_r_nw,
                Din          => cpu_di,
                Dout         => cpu_do,
                SO_n         => cpu_so_n,
                Res_n        => reset_n,
                Rdy          => cpu_ready,
                trig         => "00",
                avr_RxD      => avr_RxD,
                avr_TxD      => avr_TxD,
                sw_reset_cpu => '0',
                sw_reset_avr => not hard_reset_n,
                led_bkpt     => open,
                led_trig0    => open,
                led_trig1    => open,
                tmosi        => open,
                tdin         => open,
                tcclk        => open
                );

        process(clock_32)
        begin
            if rising_edge(clock_32) then
                clock_avr <= not clock_avr;
                cpu_clken1 <= cpu_clken;
            end if;
        end process;

    end generate;

    GenT65Core: if UseT65Core and not IncludeICEDebugger generate
        core : entity work.T65
        port map (
            cpu_mode,
            reset_n,
            cpu_clken,
            clock_32,
            cpu_ready,
            cpu_abort_n,
            cpu_irq_n,
            cpu_nmi_n,
            cpu_so_n,
            cpu_r_nw,
            cpu_sync,
            cpu_ef,
            cpu_mf,
            cpu_xf,
            cpu_ml_n,
            cpu_vp_n,
            cpu_vda,
            cpu_vpa,
            cpu_a,
            cpu_di,
            cpu_do
        );
        avr_TxD <= avr_RxD;
    end generate;

    GenAlanDCore: if UseAlanDCore and not IncludeICEDebugger generate
        core : entity work.r65c02
        port map (
            reset    => reset_n,
            clk      => clock_32,
            enable   => cpu_clken,
            nmi_n    => cpu_nmi_n,
            irq_n    => cpu_irq_n,
            di       => unsigned(cpu_di),
            do       => cpu_dout_us,
            addr     => cpu_addr_us,
            nwe      => cpu_r_nw,
            sync     => cpu_sync,
            sync_irq => open,
            Regs     => open
        );
        cpu_do <= std_logic_vector(cpu_dout_us);
        cpu_a(15 downto 0) <= std_logic_vector(cpu_addr_us);
        cpu_a(23 downto 16) <= (others => '0');
        avr_TxD <= avr_RxD;
    end generate;

    crtc : entity work.mc6845 port map (
        clock_32,
        crtc_clken,
        hard_reset_n,
        crtc_enable,
        cpu_r_nw,
        cpu_a(0),
        cpu_do,
        crtc_do,
        crtc_vsync,
        crtc_hsync,
        crtc_de,
        crtc_cursor,
        crtc_lpstb,
        crtc_ma,
        crtc_ra );

    vidproc_nula: if IncludeVideoNuLA generate
    begin
        videoula : entity work.vidproc
            port map (
                CLOCK       => clock_32,
                CPUCLKEN    => cpu_clken,
                CLKEN       => vid_clken,
                PIXCLK      => clock_48,
                nRESET      => hard_reset_n,
                CLKEN_CRTC  => crtc_clken,
                ENABLE      => vidproc_enable,
                A           => cpu_a(1 downto 0),
                DI_CPU      => cpu_do,
                DI_RAM      => ext_Dout,
                nINVERT     => vidproc_invert_n,
                DISEN       => vidproc_disen,
                CURSOR      => crtc_cursor,
                R_IN        => r_in,
                G_IN        => g_in,
                B_IN        => b_in,
                R           => r_out,
                G           => g_out,
                B           => b_out
                );
    end generate;

    vidproc_orig: if not IncludeVideoNuLA generate
    begin
        videoula_orig : entity work.vidproc_orig
            port map (
                CLOCK       => clock_32,
                CLKEN       => vid_clken,
                nRESET      => hard_reset_n,
                CLKEN_CRTC  => crtc_clken,
                ENABLE      => vidproc_enable,
                A0          => cpu_a(0),
                DI_CPU      => cpu_do,
                DI_RAM      => ext_Dout,
                nINVERT     => vidproc_invert_n,
                DISEN       => vidproc_disen,
                CURSOR      => crtc_cursor,
                R_IN        => r_in,
                G_IN        => g_in,
                B_IN        => b_in,
                R           => r_out,
                G           => g_out,
                B           => b_out
                );
    end generate;

    teletext : entity work.saa5050 port map (
        clock_48, -- This runs at 12 MHz, which we can't derive from the 32 MHz clock
        mhz12_clken,
        hard_reset_n,
        clock_32, -- Data input is synchronised from the bus clock domain
        vid_clken,
        ext_Dout(6 downto 0),
        ttxt_glr,
        ttxt_dew,
        ttxt_crs,
        ttxt_lose,
        ttxt_r, ttxt_g, ttxt_b, ttxt_y
        );

    -- System VIA
    system_via : entity work.m6522 port map (
        cpu_a(3 downto 0),
        cpu_do,
        sys_via_do,
        sys_via_do_oe_n,
        cpu_r_nw,
        sys_via_enable,
        '0', -- nCS2
        sys_via_irq_n,
        sys_via_ca1_in,
        sys_via_ca2_in,
        sys_via_ca2_out,
        sys_via_ca2_oe_n,
        sys_via_pa_in,
        sys_via_pa_out,
        sys_via_pa_oe_n,
        sys_via_cb1_in,
        sys_via_cb1_out,
        sys_via_cb1_oe_n,
        sys_via_cb2_in,
        sys_via_cb2_out,
        sys_via_cb2_oe_n,
        sys_via_pb_in,
        sys_via_pb_out,
        sys_via_pb_oe_n,
        mhz1_clken,
        hard_reset_n, -- System VIA is reset by power on reset only
        mhz4_clken,
        clock_32
        );

    -- User VIA
    user_via : entity work.m6522 port map (
        cpu_a(3 downto 0),
        cpu_do,
        user_via_do,
        user_via_do_oe_n,
        cpu_r_nw,
        user_via_enable,
        '0', -- nCS2
        user_via_irq_n,
        user_via_ca1_in,
        user_via_ca2_in,
        user_via_ca2_out,
        user_via_ca2_oe_n,
        user_via_pa_in,
        user_via_pa_out,
        user_via_pa_oe_n,
        user_via_cb1_in,
        user_via_cb1_out,
        user_via_cb1_oe_n,
        user_via_cb2_in,
        user_via_cb2_out,
        user_via_cb2_oe_n,
        user_via_pb_in,
        user_via_pb_out,
        user_via_pb_oe_n,
        mhz1_clken,
        hard_reset_n,
        mhz4_clken,
        clock_32
        );

    -- Second VIA
    -- If this is included, it becomes the via at FE60 and the user via (above)
    -- is re-addressed to FE80
    GenMouse: if IncludeAMXMouse generate
        mouse_via : entity work.m6522 port map (
            cpu_a(3 downto 0),
            cpu_do,
            mouse_via_do,
            mouse_via_do_oe_n,
            cpu_r_nw,
            mouse_via_enable,
            '0', -- nCS2
            mouse_via_irq_n,
            mouse_via_ca1_in,
            mouse_via_ca2_in,
            mouse_via_ca2_out,
            mouse_via_ca2_oe_n,
            mouse_via_pa_in,
            mouse_via_pa_out,
            mouse_via_pa_oe_n,
            mouse_via_cb1_in,
            mouse_via_cb1_out,
            mouse_via_cb1_oe_n,
            mouse_via_cb2_in,
            mouse_via_cb2_out,
            mouse_via_cb2_oe_n,
            mouse_via_pb_in,
            mouse_via_pb_out,
            mouse_via_pb_oe_n,
            mhz1_clken,
            hard_reset_n,
            mhz4_clken,
            clock_32
        );
        mouse_ps2interface: entity work.ps2interface
        generic map(
            MainClockSpeed => 32000000
        )
        port map(
           ps2_clk  => ps2_mse_clk,
           ps2_data => ps2_mse_data,
           clk      => clock_32,
           rst      => reset,
           tx_data  => mouse_tx_data,
           write    => mouse_write,
           rx_data  => mouse_rx_data,
           read     => mouse_read,
           busy     => open,
           err      => mouse_err
        );
        -- BBC Micro User Port (Mouse use)
        --  2 - CB1 - X Axis
        --  6 - D0  - X Dir
        --  4 - CB2 - Y Axis
        -- 10 - D2  - Y Dir
        -- 16 - D5  - Left button
        -- 18 - D6  - Middle button
        -- 20 - D7  - Right button
        mouse_controller: entity work.quadrature_controller port map(
           clk      => clock_32,
           rst      => reset,
           read     => mouse_read,
           err      => mouse_err,
           rx_data  => mouse_rx_data,
           write    => mouse_write,
           tx_data  => mouse_tx_data,
           x_a      => mouse_via_cb1_in,
           x_b      => mouse_via_pb_in(0),
           y_a      => mouse_via_cb2_in,
           y_b      => mouse_via_pb_in(2),
           left     => mouse_via_pb_in(5),
           middle   => mouse_via_pb_in(6),
           right    => mouse_via_pb_in(7)
        );
        mouse_via_pa_in <= mouse_via_pa_out;
        mouse_via_pb_in(4) <= '1';
        mouse_via_pb_in(3) <= '1';
        mouse_via_pb_in(1) <= '1';
    end generate;
    GenNotMouse: if not IncludeAMXMouse generate
        mouse_via_do <= x"FE";
        mouse_via_irq_n <= '1';
    end generate;


    -- Original Keyboard
    keyboard_orig: if UseOrigKeyboard generate
        ext_keyb_led3  <= '1';     -- motor LED would be driven off serial ULA
        ext_keyb_led2  <= ic32(7); -- caps LED
        ext_keyb_led1  <= ic32(6); -- shift LED
        ext_keyb_1mhz  <= mhz1_clken;
        ext_keyb_en_n  <= keyb_enable_n;
        ext_keyb_pa    <= keyb_row & keyb_column;
        keyb_out       <= ext_keyb_pa7;
        keyb_int       <= ext_keyb_ca2;
        keyb_break     <= not ext_keyb_rst_n;
    end generate;

    -- PS/2 Keyboard
    keyboard_ps2: if not UseOrigKeyboard generate
        keyb : entity work.keyboard port map (
            clock_32, hard_reset_n, mhz1_clken,
            ps2_kbd_clk, ps2_kbd_data,
            keyb_enable_n,
            keyb_column,
            keyb_row,
            keyb_out,
            keyb_int,
            keyb_break,
            keyb_dip
            );
    end generate;

    -- Analog to Digital Convertor
    adc: entity work.upd7002 port map (
        clk        => clock_32,
        cpu_clken  => cpu_clken,
        mhz1_clken => mhz1_clken,
        cs         => adc_enable,
        reset_n    => reset_n,
        r_nw       => cpu_r_nw,
        addr       => cpu_a(1 downto 0),
        di         => cpu_do,
        do         => adc_do,
        eoc_n      => adc_eoc_n,
        ch0        => adc_ch0,
        ch1        => adc_ch1,
        ch2        => adc_ch2,
        ch3        => adc_ch3
    );

    -- Master Joystick Left/Right (low value = right)
    adc_ch0 <= "111111111111" when joystick1(2) = '0' else -- left
               "000000000000" when joystick1(3) = '0' else -- right
               "100000000000";

    -- Master Joystick Up/Down (low value = down)
    adc_ch1 <= "111111111111" when joystick1(0) = '0' else -- up
               "000000000000" when joystick1(1) = '0' else -- down
               "100000000000";

    -- Secondary Joystick Left/Right (low value = right)
    adc_ch2 <= "111111111111" when joystick2(2) = '0' else -- left
               "000000000000" when joystick2(3) = '0' else -- right
               "100000000000";

    -- Secondary Joystick Up/Down (low value = down)
    adc_ch3 <= "111111111111" when joystick2(0) = '0' else -- up
               "000000000000" when joystick2(1) = '0' else -- down
               "100000000000";


--------------------------------------------------------
-- Optional SID
--------------------------------------------------------

    Optional_SID: if IncludeSID generate

        Inst_sid6581: entity work.sid6581
            port map (
                -- TODO, should update SID with a proper clocken
                clk_1MHz   => mhz1_clken,
                clk32      => clock_32,
                clk_DAC    => '0', -- internal pwm dac not used
                reset      => reset,
                cs         => sid_enable,
                we         => cpu_nr_w,
                addr       => cpu_a(4 downto 0),
                di         => cpu_do,
                do         => sid_do,
                pot_x      => '0',
                pot_y      => '0',
                audio_out  => open,
                audio_data => sid_ao
            );
    end generate;

--------------------------------------------------------
-- Optional Music 5000
--------------------------------------------------------

    Optional_Music5000: if IncludeMusic5000 generate

        Inst_Music5000: entity work.Music5000
            port map (
                clk      => clock_32,
                clken    => mhz1_clken,
                clk6     => mhz6_clken,
                clk6en   => '1',
                rnw      => cpu_r_nw,
                rst_n    => reset_n,
                pgfc_n   => io_fred_n,
                pgfd_n   => io_jim_n,
                a        => cpu_a(7 downto 0),
                din      => cpu_do,
                dout     => music5000_do,
                audio_l  => music5000_ao_l,
                audio_r  => music5000_ao_r
            );

    end generate;


--------------------------------------------------------
-- Optional 6502 Co Processor
--------------------------------------------------------

    GenCoPro6502: if IncludeCoPro6502 generate
        signal tube_cs_b : std_logic;
    begin
        copro1 : entity work.CoPro6502
        port map (
            -- Host
            h_clk       => clock_32,
            h_cs_b      => tube_cs_b,
            h_rdnw      => cpu_r_nw,
            h_addr      => cpu_a(2 downto 0),
            h_data_in   => cpu_do,
            h_data_out  => tube_do,
            h_rst_b     => reset_n,
            h_irq_b     => open,
            -- Parasite
            clk_cpu     => clock_32,
            cpu_clken   => tube_clken1,
            -- External RAM
            ram_addr     => tube_ram_addr,
            ram_data_in  => tube_ram_data_in,
            ram_data_out => ext_Dout,
            ram_wr       => tube_ram_wr,
            -- Test signals for debugging
            test         => open
        );
        process(clock_32)
        begin
            if rising_edge(clock_32) then
                tube_clken1 <= tube_clken;
            end if;
        end process;
        tube_cs_b <= '0' when tube_enable = '1' and cpu_clken = '1' else '1';
    end generate;

--------------------------------------------------------
-- Optional SPI Co Processor
--------------------------------------------------------

    GenCoProSPI: if IncludeCoProSPI generate
        signal tube_cs_b : std_logic;
    begin
        copro2 : entity work.CoProSPI
        port map (
            -- Host
            h_clk       => clock_32,
            h_cs_b      => tube_cs_b,
            h_rdnw      => cpu_r_nw,
            h_addr      => cpu_a(2 downto 0),
            h_data_in   => cpu_do,
            h_data_out  => tube_do,
            h_rst_b     => reset_n,
            h_irq_b     => open,
            -- Parasite
            p_clk       => clock_32,
            -- SPI Slave
            p_spi_ssel  => p_spi_ssel,
            p_spi_sck   => p_spi_sck,
            p_spi_mosi  => p_spi_mosi,
            p_spi_miso  => p_spi_miso,
            -- Interrupts/Control
            p_irq_b     => p_irq_b,
            p_nmi_b     => p_nmi_b,
            p_rst_b     => p_rst_b,
            -- Test signals for debugging
            test        => open
        );
        tube_cs_b <= '0' when tube_enable = '1' and cpu_clken = '1' else '1';
    end generate;

--------------------------------------------------------
-- Optional External Co Processor
--------------------------------------------------------

    GenCoProExt: if IncludeCoProExt generate
    begin
        process(clock_32)
        begin
            if rising_edge(clock_32) then
                ext_tube_phi2 <= clken_counter(3);
                ext_tube_r_nw  <= cpu_r_nw;
                ext_tube_nrst  <= reset_n;
                ext_tube_ntube <= not tube_enable;
                ext_tube_a     <= cpu_a(6 downto 0);
                ext_tube_di    <= cpu_do;
            end if;
        end process;
    end generate;

--------------------------------------------------------
-- SN76489 Sound Generator
--------------------------------------------------------

    sound : entity work.sn76489
        generic map (
            AUDIO_RES => 8
            )
        port  map (
            clk => clock_32,
            clk_en => mhz4_clken,
            reset => reset,
            d => sound_di,
            ready => sound_ready,
            we_n => sound_enable_n,
            ce_n => '0',
            audio_out => sound_ao
            );

--------------------------------------------------------
-- Sound Mixer
--------------------------------------------------------

    -- TODO clean up to avoid using hard coded width constants

--    process(sound_ao, sid_ao, music5000_ao_l, music5000_ao_r)
--        variable l : std_logic_vector(15 downto 0);
--        variable r : std_logic_vector(15 downto 0);
--    begin
--        l := std_logic_vector(sound_ao) & "00000000";
--        r := std_logic_vector(sound_ao) & "00000000";
--        if IncludeSID or IncludeMusic5000 then
--            l := l(15) & l(15 downto 1);
--            r := r(15) & r(15 downto 1);
--            if IncludeSID then
--                l := l + (sid_ao(17) & sid_ao(17 downto 3));
--                r := r + (sid_ao(17) & sid_ao(17 downto 3));
--            end if;
--            if IncludeMusic5000 then
--                l := l + (music5000_ao_l(15) & music5000_ao_l(15 downto 1));
--                r := r + (music5000_ao_r(15) & music5000_ao_r(15 downto 1));
--            end if;
--        end if;
--        audio_l <= l;
--        audio_r <= r;
--    end process;

    -- This version assumes only one source is playing at once
    process(sound_ao, sid_ao, music5000_ao_l, music5000_ao_r)
        variable l : std_logic_vector(15 downto 0);
        variable r : std_logic_vector(15 downto 0);
    begin
          -- SN76489 output is 8-bit unsigned
          -- attenuate by one bit as to try to match level with other sources
        l := std_logic_vector(not sound_ao(7) & not sound_ao(7) & sound_ao(6 downto 0)) & "0000000";
        r := std_logic_vector(not sound_ao(7) & not sound_ao(7) & sound_ao(6 downto 0)) & "0000000";
        if IncludeSID then
                -- SID output is 16-bit unsigned
            l := l + (sid_ao(17 downto 2) - x"8000");
            r := r + (sid_ao(17 downto 2) - x"8000");
        end if;
        if IncludeMusic5000 then
                -- Music 5000 output is 16-bit signed
            l := l + music5000_ao_l;
            r := r + music5000_ao_r;
        end if;
        audio_l <= l;
        audio_r <= r;
    end process;

--------------------------------------------------------
-- Reset generation
--------------------------------------------------------

    -- Keyboard and System VIA and Video are by a power up reset signal
    -- Rest of system is reset by all of the above plus keyboard BREAK key
	 -- Syncronise the reset to cpu_clken. This seems to be needed for reliable
	 -- operation of the Alan D core. I think without this, depending on when
	 -- reset is release, there may be too short a time to read the the first
	 -- byte of the reset vector from slow FLASH (on the Altera DE1).
    sync_reset: process(clock_32)
    begin
        if rising_edge(clock_32) then
            if cpu_clken = '1' then
                reset_n <= hard_reset_n and not keyb_break;
            end if;
        end if;
    end process;

    reset   <= not reset_n;

--------------------------------------------------------
-- Clock enable generation
--------------------------------------------------------

    -- 32 MHz clock split into 32 cycles
    -- CPU is on 0 and 16 (but can be masked by 1 MHz bus accesses)
     -- Co Pro CPU is on 4, 12, 20, 28
    -- Video is on all odd cycles (16 MHz)
    -- 1 MHz cycles are on cycle 31 (1 MHz)

    -- Cycles are used as follows
    --
    --      External    Processor
    --        Mem
    --       Access
    --
    -- 00 - Video      - CPU
    -- 01 -            - Video Processor
    -- 02 - Video
    -- 03 - Co Pro     - Video Processor
    -- 04 - Video      - Co Pro CPU
    -- 05              - Video Processor
    -- 06 - Video
    -- 07              - Video Processor
    -- 08 - Video
    -- 09              - Video Processor
    -- 10 - Video
    -- 11 - Co Pro     - Video Processor
    -- 12 - Video      - Co Pro CPU
    -- 13              - Video Processor
    -- 14 - Video
    -- 15 - CPU        - Video Processor
    -- 16 - Video      - CPU
    -- 17              - Video Processor
    -- 18 - Video
    -- 19 - Co Pro     - Video Processor
    -- 20 - Video      - Co Pro CPU
    -- 21              - Video Processor
    -- 22 - Video
    -- 23              - Video Processor
    -- 24 - Video
    -- 25              - Video Processor
    -- 26 - Video
    -- 27 - Co Pro     - Video Processor
    -- 28 - Video      - Co Pro CPU
    -- 29              - Video Processor
    -- 30 - Video
    -- 31 - CPU        - Video Processor

    vid_clken <= clken_counter(0); -- 1,3,5...
    mhz4_clken <= clken_counter(0) and clken_counter(1) and clken_counter(2); -- 7/15/23/31
    mhz2_clken <= mhz4_clken and clken_counter(3); -- 15/31
    mhz1_clken <= mhz2_clken and clken_counter(4); -- 31
    cpu_cycle <= not (clken_counter(0) or clken_counter(1) or clken_counter(2) or clken_counter(3)); -- 0/16
    cpu_clken <= cpu_cycle and not cpu_cycle_mask(1) and not cpu_cycle_mask(0);

    -- Co Processor memory cycles are interleaved with CPU cycles
    -- tube_clken  = 3/11/19/27 - co-processor external memory access cycle
    -- tube_clken1 = 4/12/20/28 - co-processor clocked
    tube_clken <= clken_counter(0) and clken_counter(1) and not clken_counter(2) when IncludeCoPro6502 else '0';

    clk_counter: process(clock_32)
    begin
        if rising_edge(clock_32) then
            clken_counter <= clken_counter + 1;
        end if;
    end process;

    cycle_stretch: process(clock_32,reset_n,mhz2_clken)
    begin
        if reset_n = '0' then
            cpu_cycle_mask <= "00";
        elsif rising_edge(clock_32) and mhz2_clken = '1' then
            if mhz1_enable = '1' and cpu_cycle_mask = "00" then
                -- Block CPU cycles until 1 MHz cycle has completed
                if mhz1_clken = '0' then
                    cpu_cycle_mask <= "01";
                else
                    cpu_cycle_mask <= "10";
                end if;
            end if;
            if cpu_cycle_mask /= "00" then
                cpu_cycle_mask <= cpu_cycle_mask - 1;
            end if;
        end if;
    end process;

    -- 12 MHz clock enable for SAA5050
    -- 6 MHz clock for Music 5000
    ttxt_clk_gen: process(clock_48)
    begin
        if rising_edge(clock_48) then
            ttxt_clken_counter <= ttxt_clken_counter + 1;
            mhz12_clken <= ttxt_clken_counter(0) and ttxt_clken_counter(1);
            mhz6_clken <= ttxt_clken_counter(0) and ttxt_clken_counter(1) and ttxt_clken_counter(2);
        end if;
    end process;

    -- CPU configuration and fixed signals
    cpu_mode <= "00"; -- 6502
    cpu_ready <= '1';
    cpu_abort_n <= '1';
    cpu_nmi_n <= '1';
    cpu_so_n <= '1';
    cpu_nr_w <= not cpu_r_nw;

    -- Address decoding
    -- 0x0000 = 32 KB SRAM
    -- 0x8000 = 16 KB BASIC/Sideways ROMs
    -- 0xC000 = 16 KB MOS ROM
    --
    -- IO regions are mapped into a hole in the MOS.  There are three regions:
    -- 0xFC00 = FRED
    -- 0xFD00 = JIM
    -- 0xFE00 = SHEILA
    ram_enable <= not cpu_a(15);
    rom_enable <= cpu_a(15) and not cpu_a(14);
    mos_enable <= cpu_a(15) and cpu_a(14) and not (io_fred or io_jim or io_sheila);
    io_fred <= '1' when cpu_a(15 downto 8) = "11111100" else '0';
    io_fred_n <= not io_fred;
    io_jim <= '1' when cpu_a(15 downto 8) = "11111101" else '0';
    io_jim_n <= not io_jim;
    io_sheila <= '1' when cpu_a(15 downto 8) = "11111110" else '0';
    io_sheila_n <= not io_sheila;
    -- The following IO regions are accessed at 1 MHz and hence will stall the
    -- CPU accordingly
    mhz1_enable <= io_fred or io_jim or
        adc_enable or sys_via_enable or user_via_enable or mouse_via_enable or
        serproc_enable or acia_enable or crtc_enable;


    -- FRED address demux
    -- Optional peripherals are mapped to fred and/or Jim
    -- 0xFC20 - 0xFEFF = SID
    process(cpu_a,io_fred)
    begin
        -- All regions normally de-selected
        sid_enable <= '0';
        if io_fred = '1' then
            case cpu_a(7 downto 5) is
                when "001" =>
                    sid_enable <= '1';
                when others =>
                    null;
            end case;
        end if;
    end process;

    -- SHEILA address demux
    -- All the system peripherals are mapped into this page as follows:
    -- 0xFE00 - 0xFE07 = MC6845 CRTC
    -- 0xFE08 - 0xFE0F = MC6850 ACIA (Serial/Tape)
    -- 0xFE10 - 0xFE1F = Serial ULA
    -- 0xFE20 - 0xFE2F = Video ULA
    -- 0xFE30 - 0xFE3F = Paged ROM select latch
    -- 0xFE40 - 0xFE5F = System VIA (6522)
    -- 0xFE60 - 0xFE7F = User VIA (6522)
    -- 0xFE80 - 0xFE9F = 8271 Floppy disc controller
    -- 0xFEA0 - 0xFEBF = 68B54 ADLC for Econet
    -- 0xFEC0 - 0xFEDF = uPD7002 ADC
    -- 0xFEE0 - 0xFEFF = Tube ULA
    process(cpu_a,io_sheila,m128_mode,copro_mode)
    begin
        -- All regions normally de-selected
        crtc_enable <= '0';
        acia_enable <= '0';
        serproc_enable <= '0';
        vidproc_enable <= '0';
        romsel_enable <= '0';
        sys_via_enable <= '0';
        user_via_enable <= '0';
        mouse_via_enable <= '0';
 --     adlc_enable <= '0';
        adc_enable <= '0';
        tube_enable <= '0';
        acccon_enable <= '0';
        intoff_enable <= '0';
        inton_enable  <= '0';
        if io_sheila = '1' then
            case cpu_a(7 downto 5) is
                when "000" =>
                    -- 0xFE00
                    if cpu_a(4) = '0' then
                        if cpu_a(3) = '0' then
                            -- 0xFE00
                            crtc_enable <= '1';
                        else
                            -- 0xFE08
                            acia_enable <= '1';
                        end if;
                    else
                        if cpu_a(3) = '0' then
                            -- 0xFE10
                            serproc_enable <= '1';
                        else
                            -- 0xFE18
                            if m128_mode = '1' then
                                adc_enable <= '1';
                            end if;
                        end if;
                    end if;
                when "001" =>
                    -- 0xFE20
                    if cpu_a(4) = '0' then
                        -- 0xFE20
                        vidproc_enable <= not cpu_r_nw;
                    elsif m128_mode = '1' then
                        case cpu_a(3 downto 2) is
                            -- 0xFE30
                            when "00" => romsel_enable <= '1';
                            -- 0xFE34
                            when "01" => acccon_enable <= '1';
                            -- 0xFE38
                            when "10" => intoff_enable <= '1';
                            -- 0xFE3C
                            when "11" => inton_enable  <= '1';
                            when others => null;
                        end case;
                    else
                        -- 0xFE30
                        romsel_enable <= '1';
                    end if;
                when "010" =>
                    -- 0xFE40
                    sys_via_enable <= '1';
                when "011" =>
                    -- 0xFE60
                    if IncludeAMXMouse then
                        mouse_via_enable <= '1';
                    else
                        user_via_enable <= '1';
                    end if;
                when "100" =>
                      -- 0xFE80
                    if IncludeAMXMouse then
                        user_via_enable <= '1';
                    end if;
--              when "101" => adlc_enable <= '1';       -- 0xFEA0
                when "110" =>
                    -- 0xFEC0
                    if m128_mode = '0' then
                        adc_enable <= '1';
                    end if;
                when "111" =>
                    if copro_mode = '1' and (IncludeCoPro6502 or IncludeCoProSPI or IncludeCoProExt) then
                        tube_enable <= '1';       -- 0xFEE0
                    end if;
                when others =>
                    null;
            end case;
        end if;
    end process;

    -- This is needed as in v003 of the 6522 data out is only valid while I_P2_H is asserted
    -- I_P2_H is driven from mhz1_clken
    data_latch: process(clock_32)
    begin
        if rising_edge(clock_32) then
            if (mhz1_clken = '1') then
                mouse_via_do_r <= mouse_via_do;
                user_via_do_r <= user_via_do;
                sys_via_do_r  <= sys_via_do;
            end if;
        end if;
    end process;

    -- CPU data bus mux and interrupts
    cpu_di <=
        ext_Dout       when ram_enable = '1' or rom_enable = '1' or mos_enable = '1' else
        crtc_do        when crtc_enable = '1' else
        adc_do         when adc_enable = '1' else
        "00000010"     when acia_enable = '1' else
        sys_via_do_r   when sys_via_enable = '1' else
        user_via_do_r  when user_via_enable = '1' else
        mouse_via_do_r when mouse_via_enable = '1' else
        -- Optional peripherals
        sid_do         when sid_enable = '1' and IncludeSid else
        music5000_do   when io_jim = '1' and IncludeMusic5000 else
        tube_do        when tube_enable = '1' and (IncludeCoPro6502 or IncludeCoProSPI) else
        ext_tube_do    when tube_enable = '1' and IncludeCoProExt else
        -- Master 128 additions
        romsel         when romsel_enable = '1' and m128_mode = '1' else
        acccon         when acccon_enable = '1' and m128_mode = '1' else
        "11111110"     when io_sheila = '1' else
        "11111111"     when io_fred = '1' or io_jim = '1' else
        (others => '0'); -- un-decoded locations are pulled down by RP1

    cpu_irq_n <= not ((not sys_via_irq_n) or (not user_via_irq_n) or (not mouse_via_irq_n) or acc_irr) when m128_mode = '1' else
                 not ((not sys_via_irq_n) or (not user_via_irq_n) or (not mouse_via_irq_n));
    -- SRAM bus
    ext_nCS <= '0';

    -- Synchronous outputs to External Memory

    -- ext_A is 18..0 providing a 512KB address space

    -- External Memory Map in 16KB pages
    -- 0x00000-0x3FFFF is ROM
    -- 0x40000-0x7FFFF is RAM

    -- Master Mode (Beeb Mode difference)

    -- 000 00xx xxxx xxxx xxxx = ROM Slot 0
    -- 000 01xx xxxx xxxx xxxx = ROM Slot 1
    -- 000 10xx xxxx xxxx xxxx = ROM Slot 2
    -- 000 11xx xxxx xxxx xxxx = ROM Slot 3
    -- 001 00xx xxxx xxxx xxxx = MOS 3.20 (OS 1.20)
    -- 001 01xx xxxx xxxx xxxx = unused
    -- 001 10xx xxxx xxxx xxxx = unused
    -- 001 11xx xxxx xxxx xxxx = unused
    -- 010 00xx xxxx xxxx xxxx = ROM Slot 8 (8000-B5FF)
    -- 010 01xx xxxx xxxx xxxx = ROM Slot 9
    -- 010 10xx xxxx xxxx xxxx = ROM Slot A
    -- 010 11xx xxxx xxxx xxxx = ROM Slot B
    -- 011 00xx xxxx xxxx xxxx = ROM Slot C
    -- 011 01xx xxxx xxxx xxxx = ROM Slot D
    -- 011 10xx xxxx xxxx xxxx = ROM Slot E
    -- 011 11xx xxxx xxxx xxxx = ROM Slot F

    -- 100 00xx xxxx xxxx xxxx = Co Processor
    -- 100 01xx xxxx xxxx xxxx = Co Processor
    -- 100 10xx xxxx xxxx xxxx = Co Processor
    -- 100 11xx xxxx xxxx xxxx = Co Processor
    -- 101 00xx xxxx xxxx xxxx = RAM Slot 4
    -- 101 01xx xxxx xxxx xxxx = RAM Slot 5
    -- 101 10xx xxxx xxxx xxxx = RAM Slot 6
    -- 101 11xx xxxx xxxx xxxx = RAM Slot 7
    -- 110 00xx xxxx xxxx xxxx = Main memory
    -- 110 01xx xxxx xxxx xxxx = Main memory
    -- 110 1000 xxxx xxxx xxxx = Filing System RAM (4K, at C000-CFFF) (unused in Beeb Mode)
    -- 110 1001 xxxx xxxx xxxx = Filing System RAM (4K, at D000-DFFF) (unused in Beeb Mode)
    -- 110 1010 xxxx xxxx xxxx = Private RAM (4K, at 8000-8FFF)       (unused in Beeb Mode)
    -- 110 1011 xxxx xxxx xxxx = Shadow memory (4K, at 3000-3FFF)     (unused in Beeb Mode)
    -- 110 11xx xxxx xxxx xxxx = Shadow memory (16K, at 4000-7FFF)    (unused in Beeb Mode)
    -- 111 00xx xxxx xxxx xxxx = RAM Slot 8 (B600-BFFF)
    -- 111 01xx xxxx xxxx xxxx = unused
    -- 111 10xx xxxx xxxx xxxx = unused
    -- 111 11xx xxxx xxxx xxxx = unused

    process(clock_32,hard_reset_n)
    begin

        if hard_reset_n = '0' then
            ext_nOE <= '1';
            ext_nWE <= '1';
            ext_Din <= (others => '0');
            ext_A   <= (others => '0');
        elsif rising_edge(clock_32) then
            -- Tri-stating of RAM data has been pushed up a level
            ext_Din  <= cpu_do;
            -- Default to reading RAM
            ext_nWE  <= '1';
            ext_nOE  <= '0';
            -- Register SRAM signals to outputs (clock must be at least 2x CPU clock)
            if vid_clken = '0' then
                -- Fetch data from previous display cycle
                if m128_mode = '1' then
                    -- Master 128
                    ext_A <= "110" & acc_d & display_a;
                else
                    -- Model B
                    ext_A <= "1100" & display_a;
                end if;
            elsif IncludeCoPro6502 and tube_clken = '1' then
                -- The Co Processor has access to the memory system on cycles 3, 11, 19, 27
                ext_Din <= tube_ram_data_in;
                ext_nWE <= not tube_ram_wr;
                ext_nOE <= tube_ram_wr;
                ext_A   <= "100" & tube_ram_addr;
            else
                -- Fetch data from previous CPU cycle
                if rom_enable = '1' then
                    if m128_mode = '1' and cpu_a(15 downto 12) = "1000" and romsel(7) = '1' then
                        -- Master 128, RAM bit maps 8000-8FFF as private RAM
                        ext_A   <= "1101010" & cpu_a(11 downto 0);
                        ext_nWE <= cpu_r_nw;
                        ext_nOE <= not cpu_r_nw;
                    else
                        case romsel(3 downto 2) is
                            when "00" =>
                                -- ROM slots 0,1,2,3 are in ROM
                                ext_A <= "000" & romsel(1 downto 0) & cpu_a(13 downto 0);
                            when "01" =>
                                -- ROM slots 4,5,6,7 are writeable on the Beeb and Master
                                ext_A <= "101" & romsel(1 downto 0) & cpu_a(13 downto 0);
                                ext_nWE <= cpu_r_nw;
                                ext_nOE <= not cpu_r_nw;
                            when others =>
                                if m128_mode = '0' and romsel(3 downto 0) = "1000" and cpu_a(13 downto 8) >= "110110" then
                                    -- ROM slot 8 >= B600 is mapped to RAM for
                                    -- the SWRam version of MMFS in Beeb mode only
                                    ext_A <= "11100" & cpu_a(13 downto 0);
                                    ext_nWE <= cpu_r_nw;
                                    ext_nOE <= not cpu_r_nw;
                                else
                                    -- ROM slots 8,9,A,B,C,D,E,F are in ROM
                                    ext_A <= "01" & romsel(2 downto 0) & cpu_a(13 downto 0);
                                end if;
                        end case;
                    end if;
                elsif mos_enable = '1' then
                    if m128_mode = '1' and cpu_a(15 downto 13) = "110" and acc_y = '1' then
                        -- Master 128, Y bit maps C000-DFFF as filing system RAM
                        ext_A   <= "110100" &  cpu_a(12 downto 0);
                        ext_nWE <= cpu_r_nw;
                        ext_nOE <= not cpu_r_nw;
                    else
                        -- Master OS 3.20 / Model B OS 1.20
                        ext_A <= "00100" & cpu_a(13 downto 0);
                    end if;
                elsif ram_enable = '1' then
                    if m128_mode = '1' and (cpu_a(15 downto 12) = "0011"  or cpu_a(15 downto 14) = "01") and (acc_x = '1' or (acc_e = '1' and vdu_op = '1' and cpu_sync = '0')) then
                        -- Shadow RAM
                        ext_A   <= "1101" & cpu_a(14 downto 0);
                    else
                        -- Main RAM
                        ext_A   <= "1100" & cpu_a(14 downto 0);
                    end if;
                    ext_nWE <= cpu_r_nw;
                    ext_nOE <= not cpu_r_nw;
                end if;
            end if;
        end if;
    end process;

    -- Address translation logic for calculation of display address
    process(crtc_ma,crtc_ra,disp_addr_offs)
    variable aa : unsigned(3 downto 0);
    begin
        if crtc_ma(12) = '0' then
            -- No adjustment
            aa := unsigned(crtc_ma(11 downto 8));
        else
            -- Address adjusted according to screen mode to compensate for
            -- wrap at 0x8000.
            case disp_addr_offs is
            when "00" =>
                -- Mode 3 - restart at 0x4000
                aa := unsigned(crtc_ma(11 downto 8)) + 8;
            when "01" =>
                -- Mode 6 - restart at 0x6000
                aa := unsigned(crtc_ma(11 downto 8)) + 12;
            when "10" =>
                -- Mode 0,1,2 - restart at 0x3000
                aa := unsigned(crtc_ma(11 downto 8)) + 6;
            when "11" =>
                -- Mode 4,5 - restart at 0x5800
                aa := unsigned(crtc_ma(11 downto 8)) + 11;
            when others =>
                null;
            end case;
        end if;

        if crtc_ma(13) = '0' then
            -- HI RES
            display_a <= std_logic_vector(aa(3 downto 0)) & crtc_ma(7 downto 0) & crtc_ra(2 downto 0);
        else
            -- TTX VDU
            display_a <= std_logic(aa(3)) & "1111" & crtc_ma(9 downto 0);
        end if;
    end process;

    -- VIDPROC
    vidproc_invert_n <= '1';
    vidproc_disen <= crtc_de and not crtc_ra(3); -- DISEN is masked off by RA(3) for MODEs 3 and 6
    r_in <= ttxt_r;
    g_in <= ttxt_g;
    b_in <= ttxt_b;

    -- SAA5050
    ttxt_glr <= crtc_hsync_n;
    ttxt_dew <= crtc_vsync;
    ttxt_crs <= not crtc_ra(0);
    ttxt_lose <= crtc_de;

    -- Connections to System VIA
    -- ADC
    sys_via_cb1_in <= adc_eoc_n;
    sys_via_pb_in(5) <= joystick2(4);
    sys_via_pb_in(4) <= joystick1(4);

    -- CRTC
    sys_via_ca1_in <= crtc_vsync;
    sys_via_cb2_in <= crtc_lpstb;
    -- Keyboard
    sys_via_ca2_in <= keyb_int;


    -- TODO more work needed here, but this might be enough
    sys_via_pa_in <= rtc_do when m128_mode = '1' and rtc_ce = '1' and rtc_ds = '1' and rtc_r_nw = '1' else
                     -- Must loop back output pins or keyboard won't work
                     keyb_out & sys_via_pa_out(6 downto 0);

    keyb_column <= sys_via_pa_out(3 downto 0);
    keyb_row <= sys_via_pa_out(6 downto 4);
    -- Sound
    sound_di <= sys_via_pa_out;
    -- Others (idle until missing bits implemented)
    sys_via_pb_in(7 downto 6) <= (others => '1');
    sys_via_pb_in(3 downto 0) <= sys_via_pb_out(3 downto 0);

    -- Connections to User VIA (user port is output on green LEDs)
    user_via_ca1_in <= '1'; -- Pulled up

    -- MMBEEB

    -- SDCLK is driven from either PB1 or CB1 depending on the SR Mode
    sdclk_int     <= user_via_pb_out(1) when user_via_pb_oe_n(1) = '0' else
                     user_via_cb1_out   when user_via_cb1_oe_n = '0' else
                     '1';

    SDCLK           <= sdclk_int;
    user_via_cb1_in <= sdclk_int;

    -- SDMOSI is always driven from PB0
    SDMOSI        <= user_via_pb_out(0) when user_via_pb_oe_n(0) = '0' else
                     '1';

    -- SDMISO is always read from CB2
    user_via_cb2_in <= SDMISO; -- SDI

    -- SDSS is hardwired to 0 (always selected) as there is only one slave attached
    SDSS          <= '0';

    user_via_pa_in <= user_via_pa_out;
    user_via_pb_in <= user_via_pb_out;

    -- ROM select latch
    process(clock_32,reset_n)
    begin
        if reset_n = '0' then
            romsel <= (others => '0');
        elsif rising_edge(clock_32) then
            if romsel_enable = '1' and cpu_r_nw = '0' then
                romsel <= cpu_do;
            end if;
        end if;
    end process;

    -- IC32 latch
    sound_enable_n <= ic32(0);
 -- speech_write_n <= ic32(1);
 -- speech_read_n <= ic32(2);
    keyb_enable_n <= ic32(3);
    disp_addr_offs <= ic32(5 downto 4);

    -- Keyboard LEDs
    caps_led <= not ic32(6);
    shift_led <= not ic32(7);

    process(clock_32,reset_n)
    variable bit_num : integer;
    begin
        if reset_n = '0' then
            ic32 <= (others => '0');
        elsif rising_edge(clock_32) then
            bit_num := to_integer(unsigned(sys_via_pb_out(2 downto 0)));
            ic32(bit_num) <= sys_via_pb_out(3);
        end if;
    end process;

-----------------------------------------------
-- Scan Doubler from the MIST project
-----------------------------------------------

    inst_mist_scandoubler: entity work.mist_scandoubler
    generic map (
        -- WIDTH is width of individual rgb in/out ports
        WIDTH => RGB_WIDTH
    )
    port map (
        clk => clock_32,
        clk_16 => clock_32,
        clk_16_en => vid_clken,
        hs_in => crtc_hsync_n,
        vs_in => crtc_vsync_n,
        r_in => r_out,
        g_in => g_out,
        b_in => b_out,
        hs_out => vga0_hs,
        vs_out => vga0_vs,
        r_out => vga0_r,
        g_out => vga0_g,
        b_out => vga0_b,
        is15k => open
    );
    crtc_hsync_n <= not crtc_hsync;
    crtc_vsync_n <= not crtc_vsync;
    vga0_mode <= '1' when vid_mode(0) = '1' and vid_mode(1) = '0' else '0';

-----------------------------------------------
-- Scan Doubler from RGB2VGA project
-----------------------------------------------

    rgbi_in <= r_out & g_out & b_out & '0';

    inst_rgb2vga_scandoubler: entity work.rgb2vga_scandoubler
    generic map (
        -- WIDTH is width of combined rgbi in/out ports
        WIDTH => RGB_WIDTH * 3 + 1
    )
    port map (
        clock => clock_32,
        clken => vid_clken,
        clk25 => clock_27,
        rgbi_in => rgbi_in,
        hSync_in => crtc_hsync,
        vSync_in => crtc_vsync,
        rgbi_out => rgbi_out,
        hSync_out => vga1_hs,
        vSync_out => vga1_vs
    );

    vga1_r  <= rgbi_out(RGB_WIDTH * 3 downto RGB_WIDTH * 2 + 1);
    vga1_g  <= rgbi_out(RGB_WIDTH * 2 downto RGB_WIDTH * 1 + 1);
    vga1_b  <= rgbi_out(RGB_WIDTH * 1 downto RGB_WIDTH * 0 + 1);

    vga1_mode <= '1' when vid_mode(0) = '1' and vid_mode(1) = '1' else '0';

-----------------------------------------------
-- RGBHV Multiplexor
-----------------------------------------------

    -- CRTC drives video out (CSYNC on HSYNC output, VSYNC high)
    hsync_int   <= vga0_hs when vga0_mode = '1' else
                    vga1_hs when vga1_mode = '1' else
                    not (crtc_hsync or crtc_vsync);

    vsync_int   <= vga0_vs when vga0_mode = '1' else
                   vga1_vs when vga1_mode = '1' else
                   '1';

    video_hsync <= hsync_int xor vid_mode(2);

    video_vsync <= vsync_int xor vid_mode(3);

    final_r <= vga0_r when vga0_mode = '1' else
               vga1_r when vga1_mode = '1' else
               r_out;

    final_g <= vga0_g when vga0_mode = '1' else
               vga1_g when vga1_mode = '1' else
               g_out;

    final_b <= vga0_b when vga0_mode = '1' else
               vga1_b when vga1_mode = '1' else
               b_out;

    map_video_nula: if IncludeVideoNuLA generate
    begin
        video_red   <= final_r;
        video_green <= final_g;
        video_blue  <= final_b;
    end generate;

    map_video_orig: if not IncludeVideoNuLA generate
    begin
        video_red   <= (others => final_r(0));
        video_green <= (others => final_g(0));
        video_blue  <= (others => final_b(0));
    end generate;

-----------------------------------------------
-- Master 128 additions
-----------------------------------------------

    -- RTC/CMOS
    inst_rtc : entity work.rtc port map (
        clk          => clock_32,
        cpu_clken    => cpu_clken,
        hard_reset_n => hard_reset_n,
        reset_n      => reset_n,
        ce           => rtc_ce,
        as           => rtc_as,
        ds           => rtc_ds,
        r_nw         => rtc_r_nw,
        adi          => rtc_adi,
        do           => rtc_do,
        keyb_dip     => keyb_dip
    );

    -- RTC/CMOS is controlled from the system
    -- PB7 -> address strobe (AS) active high
    -- PB6 -> chip enable (CE) active high
    -- PB3..0 drives IC32 (4-16 line decoder)
    -- IC32(2) -> data strobe (active high)
    -- IC32(1) -> read (1) / write (0)
    rtc_adi    <= sys_via_pa_out;
    rtc_as     <= sys_via_pb_out(7);
    rtc_ce     <= sys_via_pb_out(6);
    rtc_ds     <= ic32(2);
    rtc_r_nw   <= ic32(1);

    process(clock_32,reset_n)
    begin
        if reset_n = '0' then
            acccon <= (others => '0');
            vdu_op <= '0';
        elsif rising_edge(clock_32) then
            if (cpu_clken = '1') then
                -- Access Control Register 0xFE34
                if acccon_enable = '1' and cpu_r_nw = '0' then
                    acccon <= cpu_do;
                end if;
                -- vdu op indicates the last opcode fetch in 0xC000-0xDFFF
                if cpu_sync = '1' then
                    if cpu_a(15 downto 13) = "110" then
                        vdu_op <= '1';
                    else
                        vdu_op <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process;
    acc_irr <= acccon(7);
    acc_tst <= acccon(6);
    acc_ifj <= acccon(5);
    acc_itu <= acccon(4);
    acc_y   <= acccon(3);
    acc_x   <= acccon(2);
    acc_e   <= acccon(1);
    acc_d   <= acccon(0);

    -- Debugging output
    cpu_addr <= cpu_a(15 downto 0);

    -- Test output
    test <= mouse_via_pb_in(7 downto 5) & "0" & mouse_via_cb2_in &  mouse_via_pb_in(2) &  mouse_via_cb1_in & mouse_via_pb_in(0);

end architecture;
