library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;
use ieee.std_logic_textio.all;

entity m6522_tb is
    generic (
        UseAlanDCore : boolean := false
        );
end entity;

architecture rtl of m6522_tb is

    signal clock_48         :   std_logic := '0';
    signal hard_reset_n     :   std_logic := '1';
    signal div3_counter     :   unsigned(1 downto 0) := (others => '0');
    signal clken_counter    :   unsigned(3 downto 0) := (others => '0');
    signal mhz16_clken      :   std_logic;
    signal via_cs2_l        :   std_logic;
    signal via_ena_4        :   std_logic;
    signal via_p2_h         :   std_logic;

-- CPU signals
    signal via_enable       :   std_logic := '0';
    signal cpu_clken        :   std_logic;
    signal cpu_cycle_mask   :   unsigned(1 downto 0) := (others => '0');

    signal cpu_irq_n        :   std_logic;
    signal cpu_nmi_n        :   std_logic;
    signal cpu_r_nw         :   std_logic;
    signal cpu_sync         :   std_logic;
    signal cpu_a            :   std_logic_vector(15 downto 0);
    signal cpu_di           :   std_logic_vector(7 downto 0);
    signal cpu_do           :   std_logic_vector(7 downto 0);

    -- VIA signals
    constant VIA_ADDRESS    :   std_logic_vector(11 downto 0) := x"FE6";

    signal via_do       :   std_logic_vector(7 downto 0);
    signal via_do_oe_n  :   std_logic;
    signal via_irq_n    :   std_logic;
    signal via_ca1_in   :   std_logic := '0';
    signal via_ca2_in   :   std_logic := '0';
    signal via_ca2_out  :   std_logic;
    signal via_ca2_oe_n :   std_logic;
    signal via_pa_in    :   std_logic_vector(7 downto 0) := (others => '0');
    signal via_pa_out   :   std_logic_vector(7 downto 0);
    signal via_pa_oe_n  :   std_logic_vector(7 downto 0);
    signal via_cb1_in   :   std_logic := '0';
    signal via_cb1_out  :   std_logic;
    signal via_cb1_oe_n :   std_logic;
    signal via_cb2_in   :   std_logic := '0';
    signal via_cb2_out  :   std_logic;
    signal via_cb2_oe_n :   std_logic;
    signal via_pb_in    :   std_logic_vector(7 downto 0) := (others => '0');
    signal via_pb_out   :   std_logic_vector(7 downto 0);
    signal via_pb_oe_n  :   std_logic_vector(7 downto 0);

    -- RAM signals
    type ram_type is array (0 to 65535) of std_logic_vector(7 downto 0);
    shared variable ram : ram_type := (others => x"00");
    signal ram_do       :   std_logic_vector(7 downto 0);
    signal ram_address  : integer;

    -- RTW's VIA test program assembled to 4400
    signal prog : ram_type := (
        x"78",x"A9",x"EA",x"8D",x"04",x"02",x"A9",x"45",
        x"8D",x"05",x"02",x"AD",x"4E",x"FE",x"85",x"70",
        x"A9",x"7F",x"8D",x"4E",x"FE",x"8D",x"6E",x"FE",
        x"A9",x"C0",x"8D",x"6E",x"FE",x"A9",x"00",x"8D",
        x"6B",x"FE",x"85",x"71",x"58",x"A2",x"04",x"8E",
        x"64",x"FE",x"A0",x"00",x"8C",x"65",x"FE",x"B1",
        x"00",x"A9",x"01",x"CE",x"65",x"FE",x"AD",x"01",
        x"10",x"E6",x"71",x"8C",x"65",x"FE",x"A1",x"00",
        x"CE",x"65",x"FE",x"AD",x"02",x"10",x"E6",x"71",
        x"8C",x"65",x"FE",x"B1",x"00",x"CE",x"65",x"FE",
        x"AD",x"03",x"10",x"E6",x"71",x"8C",x"65",x"FE",
        x"AD",x"34",x"12",x"CE",x"65",x"FE",x"AD",x"04",
        x"10",x"E6",x"71",x"8C",x"65",x"FE",x"A5",x"12",
        x"CE",x"65",x"FE",x"AD",x"05",x"10",x"E6",x"71",
        x"8C",x"65",x"FE",x"A9",x"01",x"CE",x"65",x"FE",
        x"AD",x"06",x"10",x"E6",x"71",x"8C",x"65",x"FE",
        x"A1",x"00",x"AD",x"34",x"12",x"AD",x"64",x"FE",
        x"AD",x"07",x"10",x"E6",x"71",x"8C",x"65",x"FE",
        x"A1",x"00",x"A5",x"12",x"AD",x"64",x"FE",x"AD",
        x"08",x"10",x"E6",x"71",x"8C",x"65",x"FE",x"A1",
        x"00",x"A9",x"01",x"AD",x"64",x"FE",x"AD",x"09",
        x"10",x"E6",x"71",x"8C",x"65",x"FE",x"B1",x"00",
        x"A9",x"01",x"AD",x"64",x"FE",x"AD",x"0A",x"10",
        x"E6",x"71",x"8C",x"65",x"FE",x"A1",x"00",x"AD",
        x"64",x"FE",x"AD",x"0B",x"10",x"E6",x"71",x"8C",
        x"65",x"FE",x"B1",x"00",x"AD",x"34",x"12",x"2E",
        x"64",x"FE",x"AD",x"0C",x"10",x"8E",x"64",x"FE",
        x"E6",x"71",x"8C",x"65",x"FE",x"B1",x"00",x"A5",
        x"12",x"2E",x"64",x"FE",x"AD",x"0D",x"10",x"8E",
        x"64",x"FE",x"E6",x"71",x"8C",x"65",x"FE",x"B1",
        x"00",x"A9",x"01",x"2E",x"64",x"FE",x"AD",x"0E",
        x"10",x"8E",x"64",x"FE",x"E6",x"71",x"8C",x"65",
        x"FE",x"A1",x"00",x"2E",x"64",x"FE",x"AD",x"0F",
        x"10",x"8E",x"64",x"FE",x"E6",x"71",x"8C",x"65",
        x"FE",x"B1",x"00",x"2E",x"64",x"FE",x"AD",x"10",
        x"10",x"8E",x"64",x"FE",x"E6",x"71",x"8C",x"65",
        x"FE",x"AD",x"34",x"12",x"2E",x"64",x"FE",x"AD",
        x"11",x"10",x"8E",x"64",x"FE",x"E6",x"71",x"8C",
        x"65",x"FE",x"A5",x"12",x"2E",x"64",x"FE",x"AD",
        x"12",x"10",x"8E",x"64",x"FE",x"E6",x"71",x"8C",
        x"65",x"FE",x"A9",x"01",x"2E",x"64",x"FE",x"AD",
        x"13",x"10",x"8E",x"64",x"FE",x"E6",x"71",x"8C",
        x"65",x"FE",x"A1",x"00",x"B1",x"00",x"AD",x"14",
        x"10",x"AD",x"14",x"20",x"E6",x"71",x"8C",x"65",
        x"FE",x"A1",x"00",x"AD",x"34",x"12",x"AD",x"15",
        x"10",x"AD",x"15",x"20",x"E6",x"71",x"8C",x"65",
        x"FE",x"A1",x"00",x"A5",x"12",x"AD",x"16",x"10",
        x"AD",x"16",x"20",x"E6",x"71",x"8C",x"65",x"FE",
        x"A1",x"00",x"A9",x"01",x"AD",x"17",x"10",x"AD",
        x"17",x"20",x"E6",x"71",x"8C",x"65",x"FE",x"B1",
        x"00",x"A9",x"01",x"AD",x"18",x"10",x"AD",x"18",
        x"20",x"E6",x"71",x"8C",x"65",x"FE",x"A1",x"00",
        x"AD",x"19",x"10",x"AD",x"19",x"20",x"E6",x"71",
        x"8C",x"65",x"FE",x"A1",x"00",x"A9",x"01",x"8D",
        x"65",x"FE",x"AD",x"1A",x"10",x"E6",x"71",x"8C",
        x"65",x"FE",x"B1",x"00",x"A9",x"01",x"8D",x"65",
        x"FE",x"AD",x"1B",x"10",x"E6",x"71",x"8C",x"65",
        x"FE",x"A1",x"00",x"8D",x"65",x"FE",x"AD",x"1C",
        x"10",x"E6",x"71",x"78",x"A5",x"70",x"8D",x"4E",
        x"FE",x"A9",x"7F",x"8D",x"6E",x"FE",x"A9",x"93",
        x"8D",x"04",x"02",x"A9",x"DC",x"8D",x"05",x"02",
        x"58",x"60",x"86",x"72",x"BA",x"E8",x"E8",x"BD",
        x"00",x"01",x"85",x"73",x"E8",x"BD",x"00",x"01",
        x"A6",x"71",x"9D",x"00",x"43",x"A5",x"73",x"9D",
        x"00",x"40",x"AD",x"6D",x"FE",x"9D",x"00",x"41",
        x"AD",x"64",x"FE",x"9D",x"00",x"42",x"A6",x"72",
        x"A5",x"FC",x"40",x"00",x"00",x"00",x"00",x"00",
        x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",
        others => x"00"
        );

begin

    -- Generate the main 48MHz clock
    p_clk : process
    begin
        wait for 10.41666666 ns;
        clock_48 <= not clock_48;
    end process;

    -- Main process
    p_main : process
        variable a : integer;
        variable result : line;
    begin
        -- memory clear
        for i in 0 to 32767 loop
            ram(i) := x"00";
        end loop;

        -- program
        for i in 0 to 1023 loop
            ram(16#4400# + i) := prog(i);
        end loop;

        -- hack - RTW's program relies on some junk in ZP!
        ram(16#0004#) := x"00";
        ram(16#0005#) := x"40";

        -- vectors (same as BBC)
        ram(16#FFFA#) := x"00";
        ram(16#FFFB#) := x"0D";
        ram(16#FFFC#) := x"CD";
        ram(16#FFFD#) := x"D9";
        ram(16#FFFE#) := x"1C";
        ram(16#FFFF#) := x"DC";

        -- IRQ handler (same as BBC, no BRK handler)
        -- DC1C : 85 FC    : STA $FC
        -- DC1E : 68       : PLA
        -- DC1F : 48       : PHA
        -- DC20 : 29 10    : AND #$10
        -- DC22 : D0 03    : BNE $DC27
        -- DC24 : 6C 04 02 : JMP ($0204)
        ram(16#DC1C#) := x"85";
        ram(16#DC1D#) := x"FC";
        ram(16#DC1E#) := x"68";
        ram(16#DC1F#) := x"48";
        ram(16#DC20#) := x"29";
        ram(16#DC21#) := x"10";
        ram(16#DC22#) := x"D0";
        ram(16#DC23#) := x"03";
        ram(16#DC24#) := x"6C";
        ram(16#DC25#) := x"04";
        ram(16#DC26#) := x"02";

        -- OS
        -- D9CD : A9 40    : LDA #$40
        -- D9CF : 8D 00 0D : STA $0D00
        -- D9D2 : 78       : SEI
        -- D9D3 : D8       : CLD
        -- D9D4 : A2 FF    : LDX #$FF
        -- D9D6 : 9A       : TXS
        -- D9D6 : 48       : PHA
        -- D9D6 : 28       : PLP -- otherwise ghdl gives lots of warnings
        -- D9D9 : 20 00 40 : JSR $4400
        -- D9DC : 4C DA D9 : JMP $D9DA
        ram(16#D9CD#) := x"A9";
        ram(16#D9CE#) := x"40";
        ram(16#D9CF#) := x"8D";
        ram(16#D9D0#) := x"00";
        ram(16#D9D1#) := x"D0";
        ram(16#D9D2#) := x"78";
        ram(16#D9D3#) := x"D8";
        ram(16#D9D4#) := x"A2";
        ram(16#D9D5#) := x"FF";
        ram(16#D9D6#) := x"9A";
        ram(16#D9D7#) := x"48";
        ram(16#D9D8#) := x"28";
        ram(16#D9D9#) := x"20";
        ram(16#D9DA#) := x"00";
        ram(16#D9DB#) := x"44";
        ram(16#D9DC#) := x"4C";
        ram(16#D9DD#) := x"DC";
        ram(16#D9DE#) := x"D9";

        hard_reset_n <= '0';

        for i in 1 to 10 loop
            wait until rising_edge(cpu_clken);
        end loop;
        hard_reset_n <= '1';

        wait for 1900 us;

        writeline(output, result);
        write(result, string'("--------------------------------------------------"));
        writeline(output, result);
        write(result, string'("VIATEST (by Rich Talbot-Watkins"));
        writeline(output, result);
        write(result, string'("--------------------------------------------------"));
        writeline(output, result);
        write(result, string'("Test:      IRQ Addr:              IFR:      T1C-L:"));
        writeline(output, result);
        for i in 0 to 28 loop
            write(result, string'("[test "));
            hwrite(result, std_logic_vector(to_unsigned(i + 1, 8)));
            write(result, string'("]: "));
            a := to_integer(unsigned(ram(16#4000# + i))) +
                 to_integer(unsigned(ram(16#4300# + i))) * 256;
            hwrite(result, std_logic_vector(to_unsigned(a, 16)));
            if a > 0 then
                write(result, string'(" ("));
                hwrite(result, ram(a));
                write(result, string'(" "));
                hwrite(result, ram(a+1));
                write(result, string'(" "));
                hwrite(result, ram(a+2));
                write(result, string'(")"));
            else
                write(result, string'("           "));
            end if;
            write(result, string'("        "));
            hwrite(result, ram(16#4100# + i));
            write(result, string'("        "));
            hwrite(result, ram(16#4200# + i));
            writeline(output, result);
        end loop;
        write(result, string'("--------------------------------------------------"));
        writeline(output, result);

        wait;
    end process;


    ram_address <= to_integer(unsigned(cpu_a));
    process(clock_48)
    begin
        if rising_edge(clock_48) then
            if cpu_r_nw = '0' then
                ram(ram_address) := cpu_do;
                ram_do <= cpu_do;
            else
                ram_do <= ram(ram_address);
            end if;
        end if;
    end process;

    cmos: if UseAlanDCore generate
        signal cpu_a_tmp : unsigned(15 downto 0);
        signal cpu_do_tmp : unsigned(7 downto 0);
    begin

        core : entity work.r65c02
        port map (
            reset    => hard_reset_n,
            clk      => clock_48,
            enable   => cpu_clken,
            nmi_n    => cpu_nmi_n,
            irq_n    => cpu_irq_n,
            di       => unsigned(cpu_di),
            do       => cpu_do_tmp,
            addr     => cpu_a_tmp,
            nwe      => cpu_r_nw,
            sync     => cpu_sync,
            sync_irq => open,
            Regs     => open
        );
        cpu_do <= std_logic_vector(cpu_do_tmp);
        cpu_a  <= std_logic_vector(cpu_a_tmp);
    end generate;

    nmos: if not UseAlanDCore generate
        signal cpu_a_tmp : std_logic_vector(23 downto 0);
    begin
        core : entity work.T65
            port map (
                Mode    => "00",
                Res_n   => hard_reset_n,
                Enable  => cpu_clken,
                Clk     => clock_48,
                Rdy     => '1',
                Abort_n => '1',
                IRQ_n   => cpu_irq_n,
                NMI_n   => cpu_nmi_n,
                SO_n    => '1',
                R_W_n   => cpu_r_nw,
                Sync    => cpu_sync,
                A       => cpu_a_tmp,
                DI      => cpu_di,
                DO      => cpu_do
                );
        cpu_a <= cpu_a_tmp(15 downto 0);
    end generate;

    cpu_irq_n <= via_irq_n;
    cpu_nmi_n <= '1';

    via_enable <= '1' when cpu_a(15 downto 4) = VIA_ADDRESS else '0';

    cpu_di <= via_do when via_enable = '1' else ram_do;

    via : entity work.m6522
        port map (
            I_RS        => cpu_a(3 downto 0),
            I_DATA      => cpu_do,
            O_DATA      => via_do,
            O_DATA_OE_L => via_do_oe_n,
            I_RW_L      => cpu_r_nw,
            I_CS1       => via_enable,
            I_CS2_L     => via_cs2_l,
            O_IRQ_L     => via_irq_n,
            I_CA1       => via_ca1_in,
            I_CA2       => via_ca2_in,
            O_CA2       => via_ca2_out,
            O_CA2_OE_L  => via_ca2_oe_n,
            I_PA        => via_pa_in,
            O_PA        => via_pa_out,
            O_PA_OE_L   => via_pa_oe_n,
            I_CB1       => via_cb1_in,
            O_CB1       => via_cb1_out,
            O_CB1_OE_L  => via_cb1_oe_n,
            I_CB2       => via_cb2_in,
            O_CB2       => via_cb2_out,
            O_CB2_OE_L  => via_cb2_oe_n,
            I_PB        => via_pb_in,
            O_PB        => via_pb_out,
            O_PB_OE_L   => via_pb_oe_n,
            I_P2_H      => via_p2_h,
            RESET_L     => hard_reset_n, -- VIA is reset by power on reset only
            ENA_4       => via_ena_4,
            CLK         => clock_48
            );



    process(clock_48)
    begin
        if rising_edge(clock_48) then

            -- Divide 48MHz by 3 to get 16MHz and 8MHz
            if div3_counter = 2 then
                div3_counter <= (others => '0');
            else
                div3_counter <= div3_counter + 1;
            end if;

            -- 16MHz (video) clock enable
            if div3_counter = 1 then
                mhz16_clken <= '1';
            else
                mhz16_clken <= '0';
            end if;

            if mhz16_clken = '1' then
                clken_counter <= clken_counter + 1;
            end if;


            -- VIA control signals
            -- (0:H 4:H 8:L 12:L)
            if div3_counter = 2 and clken_counter(1 downto 0) = 3 then
                via_ena_4 <= '1';
                if clken_counter(3 downto 2) = 3 then
                    -- Cycle: 15:2 so via_p2_h 0->1 happens start of 0:0
                    via_p2_h <= '1';
                    -- Cycle_mask changes on cycles 3:1 and 11:1 so we need to look ahead
                    if cpu_cycle_mask = "01" then
                        via_cs2_l <= '0';
                    else
                        via_cs2_l <= '1';
                    end if;
                elsif clken_counter(3 downto 2) = 1 then
                    -- Cycle: 7:2 so via_p2_h 1->0 happens start of 8:0
                    via_p2_h <= '0';
                    via_cs2_l <= '1';
                end if;
            else
                via_ena_4 <= '0';
            end if;

            -- 2MHz clock enable
            if div3_counter = 1 and clken_counter(2 downto 0) = 3 then
                -- Compute cycle stretching
                if via_enable = '1' and cpu_cycle_mask = "00" then
                    -- Block CPU cycles until 1 MHz cycle has completed
                    if clken_counter(3) = '1' then
                        cpu_cycle_mask <= "01";
                    else
                        cpu_cycle_mask <= "10";
                    end if;
                end if;
                if cpu_cycle_mask /= "00" then
                    cpu_cycle_mask <= cpu_cycle_mask - 1;
                end if;
            end if;

            -- CPU clock enable (taking account of cycle stretching)
            if div3_counter = 2 and clken_counter(2 downto 0) = 3 and cpu_cycle_mask = "00" then
                cpu_clken <= '1';
            else
                cpu_clken <= '0';
            end if;


        end if;
    end process;


end rtl;
