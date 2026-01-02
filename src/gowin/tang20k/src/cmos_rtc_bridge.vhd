library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity cmos_rtc_bridge is
    port (
        clock        : in  std_logic;
        reset        : in  std_logic;

        -- external RTC interface from BeebFpga Core
        ext_rtc_ce   : in  std_logic;
        ext_rtc_as   : in  std_logic;
        ext_rtc_ds   : in  std_logic;
        ext_rtc_r_nw : in  std_logic;
        ext_rtc_adi  : in  std_logic_vector(7 downto 0);
        ext_rtc_do   : out std_logic_vector(7 downto 0) := x"00";

        -- register callbacks from I3C2 controller
        reg_write    : in  std_logic;
        reg_addr     : in  std_logic_vector(4 downto 0);
        reg_data     : in  std_logic_vector(7 downto 0);

        -- interface with I3C2 program to handle ram initialization on power up reset
        init_done    : out std_logic;

        -- interface with I3C2 program to handle pending writes of dirty ram data
        cmos_write_req : out std_logic := '0';
        cmos_addr      : out std_logic_vector(7 downto 0) := (others => '0');
        cmos_data      : out std_logic_vector(7 downto 0) := (others => '0');
        cmos_write_ack : in  std_logic
    );
end cmos_rtc_bridge;

architecture Behavioral of cmos_rtc_bridge is

    -- Cached copy of HS146818 RTC registers (64x8 RAM)
    type rtc_ram_type is array(0 to 63) of std_logic_vector(7 downto 0);
    signal rtc_ram        : rtc_ram_type;

    -- 64x1 register array to track dirty registers that need writing back
    signal dirty          : std_logic_vector(63 downto 0);

    -- Port A of the RAM is connected to the BeebFPGA core
    signal rtc_addr       : std_logic_vector(5 downto 0);

    -- Port B of the RAM is connected to the external PCF8583 RTC
    signal scrub_addr     : std_logic_vector(5 downto 0) := (others => '0');

    -- Register for the rtc address and data
    signal ext_rtc_as_r : std_logic;
    signal ext_rtc_ds_r : std_logic;

begin

    process(clock)
    begin
        if rising_edge(clock) then
            if reg_write = '1' then
                case reg_addr is
                    when "00101" =>
                        -- RTC Register 2 - BCD seconds
                        rtc_ram(0) <= reg_data;
                    when "00110" =>
                        -- RTC Register 3 - BCD minutes
                        rtc_ram(2) <= reg_data;
                    when "00111" =>
                        -- RTC Register 4 - BCD hours
                        rtc_ram(4) <= reg_data;
                    when "01000" =>
                        -- RTC Register 5 - 7:6 Year; 5:0 BCD Date
                        rtc_ram(7) <= "00"     & reg_data(5 downto 0);
                        rtc_ram(9) <= "001001" & reg_data(7 downto 6); -- This is hard coded!!!! it will break in 2028.
                    when "01001" =>
                        -- RTC Register 6 - 7:5 Weekday; 4:0 BCD Month
                        rtc_ram(6) <= "00000"  & (reg_data(7 downto 5) + "001");
                        rtc_ram(8) <= "000"    & reg_data(4 downto 0);
                    when "01010" =>
                        -- RTC CMOS Init: Reset RTC CMOS address
                        rtc_addr <= "001110"; -- Master CMOS starts at address 0E
                        init_done <= '0';
                    when "01011" =>
                        -- RTC CMOS Init: Write next RTC/CMOS address
                        rtc_ram(to_integer(unsigned(rtc_addr))) <= reg_data;
                        rtc_addr <= rtc_addr + 1;
                        if rtc_addr = 0 then
                            init_done <= '1';
                        end if;
                    when others =>
                        null;
                end case;
            end if;

            if ext_rtc_ce = '1' then
                ext_rtc_as_r <= ext_rtc_as;
                ext_rtc_ds_r <= ext_rtc_ds;

                -- Latch the RTC Address of the falling edge of rtc_as
                if ext_rtc_as = '0' and ext_rtc_as_r = '1' then
                    rtc_addr <= ext_rtc_adi(5 downto 0);
                end if;

                -- Latch the Write Data on the falling edge of rtc_ds
                if ext_rtc_ds = '0' and ext_rtc_ds_r = '1' and ext_rtc_r_nw = '0' then
                    rtc_ram(to_integer(unsigned(rtc_addr))) <= ext_rtc_adi;
                    -- Mark the location as dirty, so it get's written back to I2C
                    dirty(to_integer(unsigned(rtc_addr))) <= '1';
                end if;

                -- Read Data
                ext_rtc_do <= rtc_ram(to_integer(unsigned(rtc_addr)));
            end if;

            if dirty(to_integer(unsigned(scrub_addr))) = '1' then
                cmos_write_req <= '1';
                cmos_addr <= "10" & scrub_addr;
                cmos_data <= rtc_ram(to_integer(unsigned(scrub_addr)));
                if cmos_write_ack = '1' then
                    cmos_write_req <= '0';
                    dirty(to_integer(unsigned(scrub_addr))) <= '0';
                    scrub_addr <= scrub_addr + 1;
                end if;
            else
                scrub_addr <= scrub_addr + 1;
            end if;

        end if;
    end process;

end architecture;
