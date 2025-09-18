library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity linedelay is
    generic (
        WIDTH   : integer;
        DEPTH   : integer
    );
    port (
        clock   : in  std_logic;
        clken   : in  std_logic;
        bypass  : in  std_logic;
        din     : in  std_logic_vector(WIDTH - 1 downto 0);
        dout    : out std_logic_vector(WIDTH - 1 downto 0)
        );
end linedelay;

architecture Behavioral of linedelay is

    function Log2( input:integer ) return integer is
        variable temp,log:integer;
    begin
        temp:=input;
        log:=0;
        while (temp /= 0) loop
            temp:=temp/2;
            log:=log+1;
        end loop;
        return log;
    end function log2;

    constant AWIDTH : integer := Log2(DEPTH);

    type ram_type is array (0 to DEPTH - 1) of std_logic_vector (WIDTH - 1 downto 0);
    signal ram    : ram_type;
    signal dout_r : std_logic_vector (WIDTH - 1 downto 0);
    signal rdaddr : unsigned(AWIDTH - 1 downto 0) := (others => '0');
    signal wraddr : unsigned(AWIDTH - 1 downto 0) := (others => '0');

begin
    process(clock)
    begin
        if rising_edge(clock) then
            if clken = '1' then

                -- the register in the block ram gives one additional delay
                dout_r <= ram(to_integer(rdaddr));

                -- the RAM gives DEPTH - 1 delay slots. There is
                -- always one unused slots to avoid reading and
                -- writing the same address in the same cycle.
                ram(to_integer(wraddr)) <= din;

                -- Increment rdaddr modulo DEPTH
                if rdaddr = DEPTH - 1 then
                    rdaddr <= (others => '0');
                else
                    rdaddr <= rdaddr + 1;
                end if;

                -- wraddr lags rdaddr by one cycle
                wraddr <= rdaddr;
            end if;
        end if;
    end process;

    dout <= din when bypass = '1' else dout_r;

end Behavioral;
