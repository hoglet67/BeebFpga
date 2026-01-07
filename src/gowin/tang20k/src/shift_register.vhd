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
        fire1_n         : out std_logic; -- analog joystick 1 fire
        fire2_n         : out std_logic; -- analog joystick 2 fire
        lpstb_n         : out std_logic; -- light pen strobe
        joystick1       : out std_logic_vector(4 downto 0); -- switched joystick 1
        joystick2       : out std_logic_vector(4 downto 0); -- switched joystick 2
        jumper          : out std_logic_vector(7 downto 0)
    );
end entity;

architecture rtl of shift_register is
    signal last_js_clk : std_logic := '0';
    signal sr_counter  : unsigned(4 downto 0) := (others => '0');
    signal sr_mirror   : std_logic_vector(16 downto 0) := (others => '0');
begin

    process(clock)
    begin
        if rising_edge(clock) then
            -- external 74LV165A clocked on rising edge, so work here on falling edge
            if js_clk = '0' and last_js_clk = '1' then
                if sr_counter(4) = '1' then
                    js_load_n <= '0';
                    sr_counter <= (others => '0');
                else
                    js_load_n <= '1';
                    sr_counter <= sr_counter + 1;
                end if;
                if sr_counter = "00000" then
                    if sr_mirror(0) = '0' then -- the DS pin of U4 is used to distinguish board versions
                        -- v1.00
                        joystick1 <= sr_mirror(13 downto 9);
                        joystick2 <= sr_mirror(5 downto 1);
                        fire1_n   <= sr_mirror(13); -- fire button of switched joystick1, for testing only
                        fire2_n   <= sr_mirror(5);  -- fire button of switched joystick2, for testing only
                        lpstb_n   <= '1';
                        jumper    <= "11" & sr_mirror(8 downto 6) & sr_mirror(16 downto 14);
                    else
                        -- v1.01 and later
                        joystick1 <= sr_mirror(5 downto 1); -- allow the one switches joystick to be used
                        joystick2 <= sr_mirror(5 downto 1); -- as either joystick1 or joystick2
                        fire1_n   <= sr_mirror(9);
                        fire2_n   <= sr_mirror(10);
                        lpstb_n   <= sr_mirror(11);
                        jumper    <= sr_mirror(13 downto 12) & sr_mirror(8 downto 6) & sr_mirror(16 downto 14);
                    end if;
                end if;
                sr_mirror  <= sr_mirror(15 downto 0) & js_data;
            end if;
            last_js_clk <= js_clk;
        end if;
    end process;

end architecture;
