library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity shift_register is
    port (
        clock           : in  std_logic;
        js_clk          : in  std_logic;
        js_data         : in  std_logic;
        js_load_n       : out std_logic;
        joystick1       : out std_logic_vector(4 downto 0);
        joystick2       : out std_logic_vector(4 downto 0);
        jumper          : out std_logic_vector(5 downto 0)
    );
end entity;

architecture rtl of shift_register is
    signal last_js_clk : std_logic := '0';
    signal sr_counter  : unsigned(3 downto 0) := (others => '0');
    signal sr_mirror   : std_logic_vector(15 downto 0) := (others => '0');
begin

    process(clock)
    begin
        if rising_edge(clock) then
            -- external 74LV165A clocked on rising edge, so work here on falling edge
            if js_clk = '0' and last_js_clk = '1' then
                if sr_counter = "1111" then
                    js_load_n <= '0';
                else
                    js_load_n <= '1';
                end if;
                if sr_counter = "0000" then
                    joystick1 <= sr_mirror(12 downto 8);
                    joystick2 <= sr_mirror(4 downto 0);
                    jumper    <= sr_mirror(7 downto 5) & sr_mirror(15 downto 13);
                end if;
                sr_mirror  <= sr_mirror(14 downto 0) & js_data;
                sr_counter <= sr_counter + 1;
            end if;
            last_js_clk <= js_clk;
        end if;
    end process;

end architecture;
