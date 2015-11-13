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
        UseICEDebugger : boolean := false;
        UseT65Core     : boolean := false;
        UseAlanDCore   : boolean := true
    );
    port (
        -- Clocks
        clock_32       : in    std_logic;
        clock_24       : in    std_logic;
        clock_27       : in    std_logic;

        -- Hard reset (active low)
        hard_reset_n   : in    std_logic;

        -- Keboard
        ps2_clk        : in    std_logic;
        ps2_data       : in    std_logic;

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
        ModeM128       : in    std_logic
    );
end entity;

architecture rtl of bbc_micro_core is

-------------
-- Signals
-------------

signal reset_n      :   std_logic;
signal reset_n_out  :   std_logic;
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
signal mhz4_clken       :   std_logic; -- Used by 6522
signal mhz2_clken       :   std_logic; -- Used for latching CPU address for clock stretch
signal mhz1_clken       :   std_logic; -- 1 MHz bus and associated peripherals, 6522 phase 2

-- SAA5050 needs a 12 MHz clock enable relative to a 24 MHz clock
signal ttxt_clken_counter   :   unsigned(1 downto 0);
signal ttxt_clken       :   std_logic;

-- CPU signals
signal cpu_mode         :   std_logic_vector(1 downto 0);
signal cpu_ready        :   std_logic;
signal cpu_abort_n      :   std_logic;
signal cpu_irq_n        :   std_logic;
signal cpu_nmi_n        :   std_logic;
signal cpu_so_n         :   std_logic;
signal cpu_r_nw         :   std_logic;
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
signal crtc_hsync       :   std_logic;
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
signal r_out            :   std_logic;
signal g_out            :   std_logic;
signal b_out            :   std_logic;

-- Scandoubler signals (Mist)
signal vga0_r           :   std_logic_vector(1 downto 0);
signal vga0_g           :   std_logic_vector(1 downto 0);
signal vga0_b           :   std_logic_vector(1 downto 0);
signal vga0_hs          :   std_logic;
signal vga0_vs          :   std_logic;
signal vga0_mode        :   std_logic;
-- Scandoubler signals (RGB2VGA)
signal vga1_r           :   std_logic_vector(1 downto 0);
signal vga1_g           :   std_logic_vector(1 downto 0);
signal vga1_b           :   std_logic_vector(1 downto 0);
signal vga1_hs          :   std_logic;
signal vga1_vs          :   std_logic;
signal vga1_mode        :   std_logic;
signal rgbi_out         :   std_logic_vector(3 downto 0);
signal vsync_int        :   std_logic;
signal hsync_int        :   std_logic;


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
signal sound_ao         :   signed(7 downto 0);

-- Memory enables
signal ram_enable       :   std_logic;      -- 0x0000
signal rom_enable       :   std_logic;      -- 0x8000 (BASIC/sideways ROMs)
signal mos_enable       :   std_logic;      -- 0xC000

-- IO region enables
signal io_fred          :   std_logic;      -- 0xFC00 (1 MHz bus)
signal io_jim           :   std_logic;      -- 0xFD00 (1 MHz bus)
signal io_sheila        :   std_logic;      -- 0xFE00 (System peripherals)

-- SHIELA
signal crtc_enable      :   std_logic;      -- 0xFE00-FE07
signal acia_enable      :   std_logic;      -- 0xFE08-FE0F
signal serproc_enable   :   std_logic;      -- 0xFE10-FE1F
signal vidproc_enable   :   std_logic;      -- 0xFE20-FE2F
signal romsel_enable    :   std_logic;      -- 0xFE30-FE3F
signal sys_via_enable   :   std_logic;      -- 0xFE40-FE5F
signal user_via_enable  :   std_logic;      -- 0xFE60-FE7F
--signal fddc_enable      :   std_logic;      -- 0xFE80-FE9F
--signal adlc_enable      :   std_logic;      -- 0xFEA0-FEBF (Econet)
--signal tube_enable      :   std_logic;      -- 0xFEE0-FEFF

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

    GenDebug: if UseICEDebugger generate

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
                Res_n_in     => reset_n,
                Res_n_out    => reset_n_out,
                Rdy          => cpu_ready,
                trig         => "00",
                avr_RxD      => avr_RxD,
                avr_TxD      => avr_TxD,
                sw1          => '0',
                nsw2         => hard_reset_n,
                led3         => open,
                led6         => open,
                led8         => open,
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

    GenT65Core: if UseT65Core and not UseICEDebugger generate
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
        reset_n_out <= '1';
        avr_TxD <= '1';
    end generate;

    GenAlanDCore: if UseAlanDCore and not UseICEDebugger generate
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
        reset_n_out <= '1';
        avr_TxD <= '1';
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

    video_ula : entity work.vidproc port map (
        clock_32,
        vid_clken,
        hard_reset_n,
        crtc_clken,
        vidproc_enable,
        cpu_a(0),
        cpu_do,
        ext_Dout,
        vidproc_invert_n,
        vidproc_disen,
        crtc_cursor,
        r_in, g_in, b_in,
        r_out, g_out, b_out
        );

    teletext : entity work.saa5050 port map (
        clock_24, -- This runs at 12 MHz, which we can't derive from the 32 MHz clock
        ttxt_clken,
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

    -- Keyboard
    keyb : entity work.keyboard port map (
        clock_32, hard_reset_n, mhz1_clken,
        ps2_clk, ps2_data,
        keyb_enable_n,
        keyb_column,
        keyb_row,
        keyb_out,
        keyb_int,
        keyb_break,
        keyb_dip
        );

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

    -- Sound generator (and drive logic for I2S codec)
    sound : entity work.sn76489_top port map (
        clock_32, mhz4_clken,
        reset_n, '0', sound_enable_n,
        sound_ready, sound_di,
        sound_ao
        );

    audio_l <= std_logic_vector(sound_ao) & "00000000";
    audio_r <= std_logic_vector(sound_ao) & "00000000";

--------------------------------------------------------
-- Reset generation
--------------------------------------------------------

    -- Keyboard and System VIA and Video are by a power up reset signal
    -- Rest of system is reset by all of the above plus keyboard BREAK key
    reset_n <= reset_n_out and hard_reset_n and not keyb_break;

--------------------------------------------------------
-- Clock enable generation
--------------------------------------------------------

    -- 32 MHz clock split into 32 cycles
    -- CPU is on 0 and 16 (but can be masked by 1 MHz bus accesses)
    -- Video is on all odd cycles (16 MHz)
    -- 1 MHz cycles are on cycle 31 (1 MHz)
    vid_clken <= clken_counter(0); -- 1,3,5...
    mhz4_clken <= clken_counter(0) and clken_counter(1) and clken_counter(2); -- 7/15/23/31
    mhz2_clken <= mhz4_clken and clken_counter(3); -- 15/31
    mhz1_clken <= mhz2_clken and clken_counter(4); -- 31
    cpu_cycle <= not (clken_counter(0) or clken_counter(1) or clken_counter(2) or clken_counter(3)); -- 0/16
    cpu_clken <= cpu_cycle and not cpu_cycle_mask(1) and not cpu_cycle_mask(0);

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
    ttxt_clk_gen: process(clock_24)
    begin
        if rising_edge(clock_24) then
            ttxt_clken <= not ttxt_clken;
        end if;
    end process;

    -- CPU configuration and fixed signals
    cpu_mode <= "00"; -- 6502
    cpu_ready <= '1';
    cpu_abort_n <= '1';
    cpu_nmi_n <= '1';
    cpu_so_n <= '1';

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
    io_jim <= '1' when cpu_a(15 downto 8) = "11111101" else '0';
    io_sheila <= '1' when cpu_a(15 downto 8) = "11111110" else '0';
    -- The following IO regions are accessed at 1 MHz and hence will stall the
    -- CPU accordingly
    mhz1_enable <= io_fred or io_jim or
        adc_enable or sys_via_enable or user_via_enable or
        serproc_enable or acia_enable or crtc_enable;

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
    process(cpu_a,io_sheila,ModeM128)
    begin
        -- All regions normally de-selected
        crtc_enable <= '0';
        acia_enable <= '0';
        serproc_enable <= '0';
        vidproc_enable <= '0';
        romsel_enable <= '0';
        sys_via_enable <= '0';
        user_via_enable <= '0';
 --     fddc_enable <= '0';
 --     adlc_enable <= '0';
        adc_enable <= '0';
--      tube_enable <= '0';
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
                            if ModeM128 = '1' then
                                adc_enable <= '1';
                            end if;
                        end if;
                    end if;
                when "001" =>
                    -- 0xFE20
                    if cpu_a(4) = '0' then
                        -- 0xFE20
                        vidproc_enable <= '1';
                    elsif ModeM128 = '1' then
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
                when "010" => sys_via_enable <= '1';    -- 0xFE40
                when "011" => user_via_enable <= '1';   -- 0xFE60
--              when "100" => fddc_enable <= '1';       -- 0xFE80
--              when "101" => adlc_enable <= '1';       -- 0xFEA0
                when "110" =>
                    -- 0xFEC0
                    if ModeM128 = '0' then
                        adc_enable <= '1';
                    end if;
--              when "111" => tube_enable <= '1';       -- 0xFEE0
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
                user_via_do_r <= user_via_do;
                sys_via_do_r  <= sys_via_do;
            end if;
        end if;
    end process;

    -- CPU data bus mux and interrupts
    cpu_di <=
        ext_Dout      when ram_enable = '1' or rom_enable = '1' or mos_enable = '1' else
        crtc_do       when crtc_enable = '1' else
        adc_do        when adc_enable = '1' else
        "00000010"    when acia_enable = '1' else
        sys_via_do_r  when sys_via_enable = '1' else
        user_via_do_r when user_via_enable = '1' else
        -- Master 128 additions
        romsel when romsel_enable = '1' and ModeM128 = '1' else
        acccon when acccon_enable = '1' and ModeM128 = '1' else
        "11111110"    when io_sheila = '1' else
        "11111111"    when io_fred = '1' or io_jim = '1' else
        (others => '0'); -- un-decoded locations are pulled down by RP1

    cpu_irq_n <= not ((not sys_via_irq_n) or (not user_via_irq_n) or acc_irr) when ModeM128 = '1' else
                 not ((not sys_via_irq_n) or (not user_via_irq_n));
    -- SRAM bus
    ext_nCS <= '0';

    -- Synchronous outputs to External Memory

    -- ext_A is 18..0 providing a 512KB address space

    -- External Memory Map in 16KB pages
    -- 0x00000-0x5FFFF is ROM
    -- 0x60000-0x7FFFF is RAM

    -- 000 00xx xxxx xxxx xxxx = Master MOS 3.20
    -- 000 01xx xxxx xxxx xxxx = Master ROM 9
    -- 000 10xx xxxx xxxx xxxx = Master ROM A
    -- 000 11xx xxxx xxxx xxxx = Master ROM B
    -- 001 00xx xxxx xxxx xxxx = Master ROM C
    -- 001 01xx xxxx xxxx xxxx = Master ROM D
    -- 001 10xx xxxx xxxx xxxx = Master ROM E
    -- 001 11xx xxxx xxxx xxxx = Master ROM F
    -- 010 00xx xxxx xxxx xxxx = Beeb OS 1.20
    -- 010 01xx xxxx xxxx xxxx = Beeb ROM 9
    -- 010 10xx xxxx xxxx xxxx = Beeb ROM A
    -- 010 11xx xxxx xxxx xxxx = Beeb ROM B
    -- 011 00xx xxxx xxxx xxxx = Beeb ROM C
    -- 011 01xx xxxx xxxx xxxx = Beeb ROM D
    -- 011 10xx xxxx xxxx xxxx = Beeb ROM E
    -- 011 11xx xxxx xxxx xxxx = Beeb ROM F
    -- 100 00xx xxxx xxxx xxxx = Master ROM 0
    -- 100 01xx xxxx xxxx xxxx = Master ROM 1
    -- 100 10xx xxxx xxxx xxxx = Master ROM 2
    -- 100 11xx xxxx xxxx xxxx = Master ROM 3
    -- 101 00xx xxxx xxxx xxxx = Beeb ROM 0
    -- 101 01xx xxxx xxxx xxxx = Beeb ROM 1
    -- 101 10xx xxxx xxxx xxxx = Beeb ROM 2
    -- 101 11xx xxxx xxxx xxxx = Beeb ROM 3
    -- 110 00xx xxxx xxxx xxxx = Main memory
    -- 110 01xx xxxx xxxx xxxx = Main memory
    -- 110 1000 xxxx xxxx xxxx = Filing System RAM (4K, at C000-CFFF) (M128)
    -- 110 1001 xxxx xxxx xxxx = Filing System RAM (4K, at D000-DFFF) (M128)
    -- 110 1010 xxxx xxxx xxxx = Private RAM (4K, at 8000-8FFF) (M128)
    -- 110 1011 xxxx xxxx xxxx = Shadow memory (4K, at 3000-3FFF) (M128)
    -- 110 11xx xxxx xxxx xxxx = Shadow memory (16K, at 4000-7FFF) (M128)
    -- 111 00xx xxxx xxxx xxxx = RAM Slot 4
    -- 111 01xx xxxx xxxx xxxx = RAM Slot 5
    -- 111 10xx xxxx xxxx xxxx = RAM Slot 6
    -- 111 11xx xxxx xxxx xxxx = RAM Slot 7

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
            if vid_clken = '1' then
                -- Fetch data from previous CPU cycle
                if rom_enable = '1' then
                    if ModeM128 = '1' and cpu_a(15 downto 12) = "1000" and romsel(7) = '1' then
                        -- Master 128, RAM bit maps 8000-8FFF as private RAM
                        ext_A   <= "1101010" & cpu_a(11 downto 0);
                        ext_nWE <= cpu_r_nw;
                        ext_nOE <= not cpu_r_nw;
                    else
                        case romsel(3 downto 2) is
                            when "00" =>
                                if ModeM128 = '1' then
                                    ext_A <= "100" & romsel(1 downto 0) & cpu_a(13 downto 0);
                                else
                                    ext_A <= "101" & romsel(1 downto 0) & cpu_a(13 downto 0);
                                end if;
                            when "01" =>
                                -- ROM slots 4,5,6,7 are writeable on the Beeb and Master
                                ext_A <= "111" & romsel(1 downto 0) & cpu_a(13 downto 0);
                                ext_nWE <= cpu_r_nw;
                                ext_nOE <= not cpu_r_nw;
                            when others =>
                                -- TODO: Exclude OS rom from appearing in Slot 8?
                                if ModeM128 = '1' then
                                    ext_A <= "00" & romsel(2 downto 0) & cpu_a(13 downto 0);
                                else
                                    ext_A <= "01" & romsel(2 downto 0) & cpu_a(13 downto 0);
                                end if;
                        end case;
                    end if;
                elsif mos_enable = '1' then
                    if ModeM128 = '1' then
                        if cpu_a(15 downto 13) = "110" and acc_y = '1' then
                            -- Master 128, Y bit maps C000-DFFF as filing system RAM
                            ext_A   <= "110100" &  cpu_a(12 downto 0);
                            ext_nWE <= cpu_r_nw;
                            ext_nOE <= not cpu_r_nw;
                        else
                            -- Master OS 3.20
                            ext_A <= "00000" & cpu_a(13 downto 0);
                        end if;
                    else
                        -- Model B OS 1.20
                        ext_A <= "01000" & cpu_a(13 downto 0);
                    end if;
                elsif ram_enable = '1' then
                    if ModeM128 = '1' and (cpu_a(15 downto 12) = "0011"  or cpu_a(15 downto 14) = "01") and (acc_x = '1' or (acc_e = '1' and vdu_op = '1' and cpu_sync = '0')) then
                        -- Shadow RAM
                        ext_A   <= "1101" & cpu_a(14 downto 0);
                    else
                        -- Main RAM
                        ext_A   <= "1100" & cpu_a(14 downto 0);
                    end if;
                    ext_nWE <= cpu_r_nw;
                    ext_nOE <= not cpu_r_nw;
                end if;
            else
                -- Fetch data from previous display cycle
                if ModeM128 = '1' then
                    -- Master 128
                    ext_A <= "110" & acc_d & display_a;
                else
                    -- Model B
                    ext_A <= "1100" & display_a;
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
    ttxt_glr <= not crtc_hsync;
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
    sys_via_pa_in <= rtc_do when ModeM128 = '1' and rtc_ce = '1' and rtc_ds = '1' and rtc_r_nw = '1' else
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

    inst_mist_scandoubler: entity work.mist_scandoubler port map (
        clk => clock_32,
        clk_16 => clock_32,
        clk_16_en => vid_clken,
        scanlines => '0',
        hs_in => not crtc_hsync,
        vs_in => not crtc_vsync,
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
    vga0_mode <= '1' when vid_mode(0) = '1' and vid_mode(1) = '0' else '0';

-----------------------------------------------
-- Scan Doubler from RGB2VGA project
-----------------------------------------------

    inst_rgb2vga_scandoubler: entity work.rgb2vga_scandoubler port map (
        clock => clock_32,
        clken => vid_clken,
        clk25 => clock_27,
        rgbi_in => r_out & g_out & b_out & '0',
        hSync_in => crtc_hsync,
        vSync_in => crtc_vsync,
        rgbi_out => rgbi_out,
        hSync_out => vga1_hs,
        vSync_out => vga1_vs
    );
    vga1_r <= rgbi_out(3) & rgbi_out(3);
    vga1_g <= rgbi_out(2) & rgbi_out(2);
    vga1_b <= rgbi_out(1) & rgbi_out(1);

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

    video_red   <= vga0_r(1) & vga0_r(0) & "00" when vga0_mode = '1' else
                   vga1_r(1) & vga1_r(0) & "00" when vga1_mode = '1' else
                   r_out & r_out & r_out & r_out;

    video_green <= vga0_g(1) & vga0_g(0) & "00" when vga0_mode = '1' else
                   vga1_g(1) & vga1_g(0) & "00" when vga1_mode = '1' else
                   g_out & g_out & g_out & g_out;

    video_blue  <= vga0_b(1) & vga0_b(0) & "00" when vga0_mode = '1' else
                   vga1_b(1) & vga1_b(0) & "00" when vga1_mode = '1' else
                   b_out & b_out & b_out & b_out;

-----------------------------------------------
-- Master 128 additions
-----------------------------------------------

    -- RTC/CMOS
    inst_rtc : entity work.rtc port map (
        clk        => clock_32,
        cpu_clken  => cpu_clken,
        reset_n    => reset_n,
        ce         => rtc_ce,
        as         => rtc_as,
        ds         => rtc_ds,
        r_nw       => rtc_r_nw,
        adi        => rtc_adi,
        do         => rtc_do
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

end architecture;
