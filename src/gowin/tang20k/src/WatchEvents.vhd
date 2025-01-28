library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity WatchEvents is
    port (
        clk   : in  std_logic;
        srst  : in  std_logic;
        din   : in  std_logic_vector(71 downto 0);
        wr_en : in  std_logic;
        rd_en : in  std_logic;
        dout  : out std_logic_vector(71 downto 0);
        full  : out std_logic;
        empty : out std_logic
        );
end WatchEvents;

architecture behavioral of WatchEvents is

begin

    fifo : entity work.WatchEventsCore
        port map (
            Clk => clk,
            Reset => srst,
            WrEn => wr_en,
            RdEn => rd_en,
            Data => din,
            Empty => empty,
            Full => full,
            Q => dout
            );

end behavioral;
