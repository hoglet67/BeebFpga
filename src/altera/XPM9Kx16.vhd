library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

use WORK.SynthCtrlPack.all; -- Synthesis control

entity XPM9Kx16 is port(
    cp2       : in  std_logic;
    ce        : in  std_logic;
    address   : in  std_logic_vector(13 downto 0);
    din       : in  std_logic_vector(15 downto 0);
    dout      : out std_logic_vector(15 downto 0);
    we        : in  std_logic
    );
end XPM9Kx16;

-- TODO: Add firmware....

architecture RTL of XPM9Kx16 is

type ram_type is array (16383 downto 0) of std_logic_vector (15 downto 0);
    
signal RAM : ram_type;

begin

    process (cp2)
    begin
        if rising_edge(cp2) then
            if ce = '1' then
                if (we = '1') then
                    RAM(conv_integer(address)) <= din;
                end if;
                dout <= RAM(conv_integer(address));
            end if;
        end if;
    end process;

end RTL;
