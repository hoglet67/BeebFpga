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

    -- Cached copy of HD146818RTC clock registers in 24-hour BCD format
    signal rtc_secs    : std_logic_vector(5 downto 0);
    signal rtc_mins    : std_logic_vector(5 downto 0);
    signal rtc_hours   : std_logic_vector(4 downto 0);
    signal rtc_weekday : std_logic_vector(2 downto 0);
    signal rtc_day     : std_logic_vector(5 downto 0);
    signal rtc_month   : std_logic_vector(4 downto 0);
    signal rtc_year    : std_logic_vector(7 downto 0);

    -- Cached copy of HD146818 RTC registers (64x8 RAM)
    type rtc_ram_type is array(0 to 63) of std_logic_vector(7 downto 0);
    signal rtc_ram        : rtc_ram_type;

    -- 64x1 register array to track dirty registers that need writing back
    signal dirty          : std_logic_vector(63 downto 0);

    -- Port A of the RAM is connected to the BeebFPGA core
    signal rtc_addr       : std_logic_vector(5 downto 0);

    -- Port B of the RAM is connected to the external PCF8583 RTC
    signal scrub_addr     : std_logic_vector(5 downto 0) := (others => '0');

    -- Port A of the RAM is connected to the BeebFPGA core
    signal init_addr       : std_logic_vector(5 downto 0);

    -- Register for the rtc address and data
    signal ext_rtc_as_r : std_logic;
    signal ext_rtc_ds_r : std_logic;

    -- HD146818 RTC register addresses
    constant RTC_SECS_REG          : std_logic_vector(5 downto 0) := "000000";
    constant RTC_MINS_REG          : std_logic_vector(5 downto 0) := "000010";
    constant RTC_HOURS_REG         : std_logic_vector(5 downto 0) := "000100";
    constant RTC_WEEKDAY_REG       : std_logic_vector(5 downto 0) := "000110";
    constant RTC_DAY_REG           : std_logic_vector(5 downto 0) := "000111";
    constant RTC_MONTH_REG         : std_logic_vector(5 downto 0) := "001000";
    constant RTC_YEAR_REG          : std_logic_vector(5 downto 0) := "001001";
    constant RTC_CMOS_BASE         : std_logic_vector(5 downto 0) := "001110";  -- Master CMOS ram starts at RTC register 0E

    -- I2C PCF8583 register addresses
    constant I2C_SECS_REG          : std_logic_vector(7 downto 0) := x"02";
    constant I2C_MINS_REG          : std_logic_vector(7 downto 0) := x"03";
    constant I2C_HOURS_REG         : std_logic_vector(7 downto 0) := x"04";
    constant I2C_YEAR_DAY_REG      : std_logic_vector(7 downto 0) := x"05";
    constant I2C_WEEKDAY_MONTH_REG : std_logic_vector(7 downto 0) := x"06";

    -- I2C2 Callback identifiers
    constant CB_SECS               : std_logic_vector(4 downto 0) := "00101";
    constant CB_MINS               : std_logic_vector(4 downto 0) := "00110";
    constant CB_HOURS              : std_logic_vector(4 downto 0) := "00111";
    constant CB_YEAR_DAY           : std_logic_vector(4 downto 0) := "01000";
    constant CB_WEEKDAY_MONTH      : std_logic_vector(4 downto 0) := "01001";
    constant CB_INIT_RESET         : std_logic_vector(4 downto 0) := "01010";
    constant CB_INIT_NEXT          : std_logic_vector(4 downto 0) := "01011";

begin

    -- 146818                     PCF8583
    --
    -- 00 : RTC Seconds           => 02
    -- 01 : RTC Seconds Alarm     not implemented
    -- 02 : RTC Minutes           => 03
    -- 03 : RTC Minutes Alarm     not implemented
    -- 04 : RTC Hours             => 04
    -- 05 : RTC Hours Alarm       not implemented
    -- 06 : RTC Day of Week       => 06 (bits 7:5)
    -- 07 : RTC Date of Month     => 05 (bits 5:0)
    -- 08 : RTC Month             => 06 (bits 4:0)
    -- 09 : RTC Year              => 05 (bits 7:6) -- TODO FIX Year 2028 bug!
    -- 0A : RTC Register A        not implemented
    -- 0B : RTC Register B        not implemented
    -- 0C : RTC Register C        not implemented
    -- 0D : RTC Register D        not implemented
    -- 0E : CMOS 0                mapped to 8E
    -- ..                         ..
    -- 3F : CMOS 49               mapped to BF


    -- The memory model is as follows:
    --
    -- The set of rtc_xxx regs and the rtc_ram act as a cache, holding
    -- the latest state
    --
    -- 6502 reads can be services immediately from this cache. 6502
    -- writes are writted to the address in cache, and that address
    -- flaged as dirty
    --
    -- During power up reset the cache is initialized from the
    -- external RTC ia I2C
    --
    -- Asynchronously (every ~10ms) the rtc_xxx register holding the
    -- date/time are refreshed from the external RTC. These are
    -- discrete register to allow multiple updates at the same time.
    --
    -- A background scrubber process tests for dirty cache addresses,
    -- and arranged for these to be written by to the external RTC.

    process(clock)
    begin
        if rising_edge(clock) then
            if reg_write = '1' then
                case reg_addr is
                    when CB_SECS =>
                        -- RTC Register 2 - BCD seconds
                        if dirty(to_integer(unsigned(RTC_SECS_REG))) = '0' then
                            rtc_secs <= reg_data(5 downto 0);
                        end if;
                    when CB_MINS =>
                        -- RTC Register 3 - BCD minutes
                        if dirty(to_integer(unsigned(RTC_MINS_REG))) = '0' then
                            rtc_mins <= reg_data(5 downto 0);
                        end if;
                    when CB_HOURS =>
                        -- RTC Register 4 - BCD hours
                        if dirty(to_integer(unsigned(RTC_HOURS_REG))) = '0' then
                            rtc_hours <= reg_data(4 downto 0);
                        end if;
                    when CB_YEAR_DAY =>
                        -- RTC Register 5 - 7:6 Year; 5:0 BCD Date
                        if dirty(to_integer(unsigned(RTC_YEAR_REG))) = '0' then
                            rtc_year <= "001001" & reg_data(7 downto 6); -- This is hard coded!!!! it will break in 2028.
                        end if;
                        if dirty(to_integer(unsigned(RTC_DAY_REG))) = '0' then
                            rtc_day <= reg_data(5 downto 0);
                        end if;
                    when CB_WEEKDAY_MONTH =>
                        -- RTC Register 6 - 7:5 Weekday; 4:0 BCD Month
                        if dirty(to_integer(unsigned(RTC_WEEKDAY_REG))) = '0' then
                            rtc_weekday <= reg_data(7 downto 5) + "001";
                        end if;
                        if dirty(to_integer(unsigned(RTC_MONTH_REG))) = '0' then
                            rtc_month <= reg_data(4 downto 0);
                        end if;
                    when CB_INIT_RESET =>
                        -- RTC CMOS Init: Reset RTC CMOS address
                        init_addr <= RTC_CMOS_BASE;
                        init_done <= '0';
                    when CB_INIT_NEXT =>
                        -- RTC CMOS Init: Write next RTC/CMOS address
                        rtc_ram(to_integer(unsigned(init_addr))) <= reg_data;
                        init_addr <= init_addr + 1;
                        if init_addr = 0 then
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
                    case rtc_addr is
                        when RTC_SECS_REG =>
                            rtc_secs <= ext_rtc_adi(5 downto 0);
                        when RTC_MINS_REG =>
                            rtc_mins <= ext_rtc_adi(5 downto 0);
                        when RTC_HOURS_REG =>
                            rtc_hours <= ext_rtc_adi(4 downto 0);
                        when RTC_WEEKDAY_REG =>
                            rtc_weekday <= ext_rtc_adi(2 downto 0);
                        when RTC_DAY_REG =>
                            rtc_day <= ext_rtc_adi(5 downto 0);
                        when RTC_MONTH_REG =>
                            rtc_month <= ext_rtc_adi(4 downto 0);
                        when RTC_YEAR_REG =>
                            rtc_year <= ext_rtc_adi(7 downto 0);
                        when others =>
                            rtc_ram(to_integer(unsigned(rtc_addr))) <= ext_rtc_adi;
                    end case;
                    -- Mark the location as dirty so it gets written back to I2C (this will also suspect async updates)
                    dirty(to_integer(unsigned(rtc_addr))) <= '1';
                end if;

                -- Read Data
                case rtc_addr is
                    when RTC_SECS_REG =>
                        ext_rtc_do <= "00" & rtc_secs;
                    when RTC_MINS_REG =>
                        ext_rtc_do <= "00" & rtc_mins;
                    when RTC_HOURS_REG =>
                        ext_rtc_do <= "000" & rtc_hours;
                    when RTC_WEEKDAY_REG =>
                        ext_rtc_do <= "00000" & rtc_weekday;
                    when RTC_DAY_REG =>
                        ext_rtc_do <= "00" & rtc_day;
                    when RTC_MONTH_REG =>
                        ext_rtc_do <= "000" & rtc_month;
                    when RTC_YEAR_REG =>
                        ext_rtc_do <= rtc_year;
                    when others =>
                        ext_rtc_do <= rtc_ram(to_integer(unsigned(rtc_addr)));
                end case;

            end if;

            -- Slowly write back dirty data to I2C RTC
            if dirty(to_integer(unsigned(scrub_addr))) = '1' then
                cmos_write_req <= '1';
                case scrub_addr is
                    when RTC_SECS_REG =>
                        cmos_addr <= I2C_SECS_REG;
                        cmos_data <= "00" & rtc_secs;
                    when RTC_MINS_REG =>
                        cmos_addr <= I2C_MINS_REG;
                        cmos_data <= "00" & rtc_mins;
                    when RTC_HOURS_REG =>
                        cmos_addr <= I2C_HOURS_REG;
                        cmos_data <= "000" & rtc_hours;
                    when RTC_YEAR_REG | RTC_DAY_REG =>
                        cmos_addr <= I2C_YEAR_DAY_REG;
                        cmos_data <= rtc_year(1 downto 0) & rtc_day;
                    when RTC_WEEKDAY_REG | RTC_MONTH_REG =>
                        cmos_addr <= I2C_WEEKDAY_MONTH_REG;
                        cmos_data <= (rtc_weekday - "001") & rtc_month;
                    when others =>
                        cmos_addr <= "10" & scrub_addr;
                        cmos_data <= rtc_ram(to_integer(unsigned(scrub_addr)));
                end case;
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
