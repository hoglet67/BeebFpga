library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity multiboot is
    generic (
        CORE_ID    : integer
    );
    port (
        clock           : in  std_logic;
        powerup_reset_n : in  std_logic;
        btn1            : in  std_logic;
        btn2            : in  std_logic;
        btn3            : in  std_logic;
        jumper          : in  std_logic_vector(5 downto 0);
        led             : out std_logic_vector(5 downto 0);
        reconfig        : out std_logic := '0'
    );
end entity;

architecture rtl of multiboot is
    signal powerup_reset_n_last : std_logic := '1';
    signal reconfig_r : std_logic := '0';
begin

        process(clock)
        begin
            if rising_edge(clock) then
                -- wait until the end of the power up reset period to ensure the jumpers are stable
                if powerup_reset_n_last = '0' and powerup_reset_n = '1' and CORE_ID >= 0 and unsigned(jumper(1 downto 0)) /= to_unsigned(CORE_ID, 2) then
                    reconfig_r <= '1';
                end if;
                powerup_reset_n_last <= powerup_reset_n;
            end if;
        end process;

    reconfig <= reconfig_r;
    led <=  (others => '1') when CORE_ID < 0 else (CORE_ID => '0', others => '1');

end architecture;
