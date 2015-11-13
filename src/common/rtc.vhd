library ieee ;
use ieee.std_logic_1164.all ;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity rtc is
    port (
        clk        : in  std_logic;
        cpu_clken  : in  std_logic;
        reset_n    : in  std_logic;
        ce         : in  std_logic; -- chip enable
        as         : in  std_logic; -- address strobe
        ds         : in  std_logic; -- data strobe
        r_nw       : in  std_logic;
        adi        : in  std_logic_vector(7 downto 0); -- address/data in
        do         : out std_logic_vector(7 downto 0) -- data out
    );
end entity;

architecture rtl of rtc is

    signal ds_r : std_logic;
    signal as_r : std_logic;
    signal addr : std_logic_vector(5 downto 0);
    
    type rtc_ram_type is array(0 to 63) of std_logic_vector(7 downto 0);

    signal rtc_ram : rtc_ram_type := (
        x"30", -- RTC Seconds
        x"00", -- RTC Seconds Alarm
        x"02", -- RTC Minutes
        x"00", -- RTC Minutes Alarm
        x"18", -- RTC Hours
        x"00", -- RTC Hours Alarm
        x"06", -- RTC Day of Week
        x"07", -- RTC Date of Month
        x"11", -- RTC Month
        x"15", -- RTC Year
        x"00", -- RTC Register A
        x"00", -- RTC Register B
        x"00", -- RTC Register C
        x"00", -- RTC Register D
        x"00", -- CMOS  0 - Econet station number
        x"FE", -- CMOS  1 - Econet file server identity (lo)
        x"00", -- CMOS  2 - Econet file server identity (hi)
        x"EB", -- CMOS  3 - Econet print server identity (lo)
        x"00", -- CMOS  4 - Econet print server identity (hi)
        x"C3", -- CMOS  5 - Default Filing System / Language (default file system MMFS)
        x"FF", -- CMOS  6 - ROM frugal bits (*INSERT/*UNPLUG)
        x"DD", -- CMOS  7 - ROM frugal bits (*INSERT/*UNPLUG) (disable DFS/ADFS)
        x"00", -- CMOS  8 - Edit startup settings
        x"00", -- CMOS  9 - reserved for telecommunications applications
        x"F7", -- CMOS 10 - VDU mode and *TV settings
        x"E3", -- CMOS 11 - ADFS startup options, keyboard settings, floppy params
        x"20", -- CMOS 12 - Keyboard auto-repeat delay
        x"08", -- CMOS 13 - Keyboard auto-repeat rate
        x"0A", -- CMOS 14 - Printer ignore character
        x"2C", -- CMOS 15 - Default printer type, serial baud rate, ignore status and TUBE select
        x"80", -- CMOS 16 - Default serial data format, auto boot option, int/ext TUBE, bell amplitude
        x"00", -- CMOS 17 - reserved for ANFS
        x"00", -- CMOS 18 - reserved for ANFS
        x"00", -- CMOS 19 - reserved for ANFS
        x"00", -- CMOS 20 - reserved for future use by Acorn
        x"00", -- CMOS 21 - reserved for future use by Acorn
        x"00", -- CMOS 22 - reserved for future use by Acorn
        x"00", -- CMOS 23 - reserved for future use by Acorn
        x"00", -- CMOS 24 - reserved for future use by Acorn
        x"00", -- CMOS 25 - reserved for future use by Acorn
        x"00", -- CMOS 26 - reserved for future use by Acorn
        x"00", -- CMOS 27 - reserved for future use by Acorn
        x"00", -- CMOS 28 - reserved for future use by Acorn
        x"00", -- CMOS 29 - reserved for future use by Acorn
        x"00", -- CMOS 30 - reserved for future use by third parties
        x"00", -- CMOS 31 - reserved for future use by third parties
        x"00", -- CMOS 32 - reserved for future use by third parties
        x"00", -- CMOS 33 - reserved for future use by third parties
        x"00", -- CMOS 34 - reserved for future use by third parties
        x"00", -- CMOS 35 - reserved for future use by third parties
        x"00", -- CMOS 36 - reserved for future use by third parties
        x"00", -- CMOS 37 - reserved for future use by third parties
        x"00", -- CMOS 38 - reserved for future use by third parties
        x"00", -- CMOS 39 - reserved for future use by third parties
        x"00", -- CMOS 40 - reserved for future use by the user
        x"00", -- CMOS 41 - reserved for future use by the user
        x"00", -- CMOS 42 - reserved for future use by the user
        x"00", -- CMOS 43 - reserved for future use by the user
        x"00", -- CMOS 44 - reserved for future use by the user
        x"00", -- CMOS 45 - reserved for future use by the user
        x"00", -- CMOS 46 - reserved for future use by the user
        x"00", -- CMOS 47 - reserved for future use by the user
        x"00", -- CMOS 48 - reserved for future use by the user
        x"00"  -- CMOS 49 - reserved for future use by the user
        );
    
begin
    
    process(clk,reset_n)
    begin
        if reset_n = '0' then
            as_r <= '0';
            ds_r <= '0';
            do <= (others => '0');
        elsif rising_edge(clk) then
            if (cpu_clken = '1') then
                
                as_r <= as;
                ds_r <= ds;
                
                -- Latch the RTC Address of the falling edge of rtc_as
                if ce = '1' and as = '0' and as_r = '1' then
                    addr <= adi(5 downto 0);
                end if;
                
                -- Latch the Write Data on the falling edge of rtc_ds
                if ce = '1' and ds = '0' and ds_r = '1' and r_nw = '0' then
                    rtc_ram(to_integer(unsigned(addr))) <= adi;
                end if;
                
                -- Read Data
                do <= rtc_ram(to_integer(unsigned(addr)));
            end if;
        end if;
    end process;

    
end architecture rtl;
