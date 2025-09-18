library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity rgb2vga_dpram is
    generic (
        AWIDTH    : integer;
        DWIDTH    : integer
        );
    port (
        wrclock   : in  std_logic;
        wrclken   : in  std_logic;
        wren      : in  std_logic;
        wraddress : in  std_logic_vector(AWIDTH - 1 downto 0);
        data      : in  std_logic_vector(DWIDTH - 1 downto 0);
        rdclock   : in  std_logic;
        rdclken   : in  std_logic;
        rdaddress : in  std_logic_vector(AWIDTH - 1 downto 0);
        q         : out std_logic_vector(DWIDTH - 1 downto 0)
        );
end;

architecture behavioral of rgb2vga_dpram is

    type ram_type is array (2**AWIDTH - 1 downto 0) of std_logic_vector(DWIDTH - 1 downto 0);
    shared variable RAM : ram_type;

begin

    process (wrclock)
    begin
        if rising_edge(wrclock) then
            if wrclken = '1' then
                if wren = '1' then
                    RAM(conv_integer(wraddress)) := data;
                end if;
            end if;
        end if;
    end process;

    process (rdclock)
    begin
        if rising_edge(rdclock) then
            if rdclken = '1' then
                q <= RAM(conv_integer(rdaddress));
            end if;
        end if;
    end process;

end behavioral;
