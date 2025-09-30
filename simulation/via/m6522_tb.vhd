library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity m6522_tb is
end entity;

architecture rtl of m6522_tb is

    signal clock_48         :   std_logic := '0';
    signal hard_reset_n     :   std_logic := '0';
    signal div3_counter     :   unsigned(1 downto 0) := (others => '0');
    signal clken_counter    :   unsigned(3 downto 0) := (others => '0');
    signal mhz16_clken      :   std_logic;
    signal via_cs2_l        :   std_logic;
    signal via_ena_4        :   std_logic;
    signal via_p2_h         :   std_logic;

-- CPU signals
    signal via_enable       :   std_logic := '0';
    signal cpu_clken        :   std_logic;
    signal cpu_r_nw         :   std_logic;
    signal cpu_cycle_mask   :   unsigned(1 downto 0) := (others => '0');
    signal cpu_a            :   std_logic_vector(3 downto 0);
    signal cpu_d            :   std_logic_vector(7 downto 0);

-- System VIA signals
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

    signal cpu_irq_n    :   std_logic := '1';
    signal cpu_sync     :   std_logic := '0';
begin

    -- Generate the main 48MHz clock
    p_clk : process
    begin
        wait for 10.41666666 ns;
        clock_48 <= not clock_48;
    end process;

    p_main : process

        procedure VIA_READ(
            addr : in std_logic_vector(3 downto 0)) is
        begin
            cpu_a <= addr;
            cpu_r_nw <= '1';
            via_enable <= '1';
            wait until rising_edge(cpu_clken);
            cpu_a <= x"0";
            via_enable <= '0';
        end procedure;

        procedure VIA_WRITE(
            addr : in std_logic_vector(3 downto 0);
            data : in std_logic_vector(7 downto 0)) is
        begin
            cpu_d <= data;
            cpu_a <= addr;
            cpu_r_nw <= '0';
            via_enable <= '1';
            wait until rising_edge(cpu_clken);
            cpu_d <= x"00";
            cpu_a <= x"0";
            cpu_r_nw <= '1';
            via_enable <= '0';
        end procedure;

      procedure VIA_TEST(
          cycles : in integer) is
      begin
          -- STA &FE65
          cpu_sync <= '1';
          wait until rising_edge(cpu_clken);
          cpu_sync <= '0';
          wait until rising_edge(cpu_clken);
          wait until rising_edge(cpu_clken);
          cpu_irq_n <= via_irq_n;
          VIA_WRITE(x"5", x"00");
          -- DELAY
          for i in 1 to cycles loop
              cpu_irq_n <= via_irq_n;
              wait until rising_edge(cpu_clken);
          end loop;
          -- LDA &FE64
          cpu_sync <= '1';
          wait until rising_edge(cpu_clken);
          cpu_sync <= '0';
          wait until rising_edge(cpu_clken);
          wait until rising_edge(cpu_clken);
          cpu_irq_n <= via_irq_n;
          VIA_READ(x"4");
          -- LDA ABS
          cpu_sync <= '1';
          wait until rising_edge(cpu_clken);
          cpu_sync <= '0';
          wait until rising_edge(cpu_clken);
          wait until rising_edge(cpu_clken);
          cpu_irq_n <= via_irq_n;
          wait until rising_edge(cpu_clken);
      end procedure;



    begin
        wait until rising_edge(cpu_clken);
        hard_reset_n <= '0';
        wait until rising_edge(cpu_clken);
        hard_reset_n <= '1';
        wait until rising_edge(cpu_clken);
        wait until rising_edge(cpu_clken);
        wait until rising_edge(cpu_clken);
        wait until rising_edge(cpu_clken);
        VIA_WRITE(x"B", x"00");
        wait until rising_edge(cpu_clken);
        VIA_WRITE(x"E", x"7F");
        wait until rising_edge(cpu_clken);
        VIA_WRITE(x"E", x"C0");
        wait until rising_edge(cpu_clken);
        VIA_WRITE(x"4", x"04");
        wait until rising_edge(cpu_clken);
        wait until rising_edge(cpu_clken);
        wait until rising_edge(cpu_clken);
        wait until rising_edge(cpu_clken);
        wait until rising_edge(cpu_clken);
        VIA_TEST(15);
        VIA_TEST(14);
        VIA_TEST(13);
        VIA_TEST(12);
        VIA_TEST(11);
        VIA_TEST(10);
        VIA_TEST( 9);
        VIA_TEST( 8);
        VIA_TEST( 7);
        VIA_TEST( 6);
        VIA_TEST( 5);
        VIA_TEST( 4);
        VIA_TEST( 3);
        VIA_TEST( 2);
        wait;
    end process;

    system_via : entity work.m6522
        port map (
            I_RS        => cpu_a,
            I_DATA      => cpu_d,
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
            RESET_L     => hard_reset_n, -- System VIA is reset by power on reset only
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
