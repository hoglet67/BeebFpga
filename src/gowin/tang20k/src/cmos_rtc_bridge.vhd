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

    -- HD146818 RTC register address constants
    constant RTC_SECS_REG          : std_logic_vector(5 downto 0) := "000000";
    constant RTC_MINS_REG          : std_logic_vector(5 downto 0) := "000010";
    constant RTC_HOURS_REG         : std_logic_vector(5 downto 0) := "000100";
    constant RTC_WEEKDAY_REG       : std_logic_vector(5 downto 0) := "000110";
    constant RTC_DAY_REG           : std_logic_vector(5 downto 0) := "000111";
    constant RTC_MONTH_REG         : std_logic_vector(5 downto 0) := "001000";
    constant RTC_YEAR_REG          : std_logic_vector(5 downto 0) := "001001";
    constant RTC_CMOS_BASE         : std_logic_vector(5 downto 0) := "001110";  -- Master CMOS ram starts at RTC register 0E

    -- I2C PCF8583 register address constants
    constant I2C_SECS_REG          : std_logic_vector(7 downto 0) := x"02";
    constant I2C_MINS_REG          : std_logic_vector(7 downto 0) := x"03";
    constant I2C_HOURS_REG         : std_logic_vector(7 downto 0) := x"04";
    constant I2C_YEAR_DAY_REG      : std_logic_vector(7 downto 0) := x"05";
    constant I2C_WEEKDAY_MONTH_REG : std_logic_vector(7 downto 0) := x"06";

    -- I2C2 Callback identifiers constants
    constant CB_SECS               : std_logic_vector(4 downto 0) := "00101";
    constant CB_MINS               : std_logic_vector(4 downto 0) := "00110";
    constant CB_HOURS              : std_logic_vector(4 downto 0) := "00111";
    constant CB_YEAR_DAY           : std_logic_vector(4 downto 0) := "01000";
    constant CB_WEEKDAY_MONTH      : std_logic_vector(4 downto 0) := "01001";
    constant CB_INIT_RESET         : std_logic_vector(4 downto 0) := "01010";
    constant CB_INIT_NEXT          : std_logic_vector(4 downto 0) := "01011";

    -- Cached copy of HD146818 RTC CMOS RAM registers (64x8 RAM)
    type rtc_ram_type is array(0 to 63) of std_logic_vector(8 downto 0);
    signal rtc_ram        : rtc_ram_type;

    -- Port A of the RAM is connected to the BeebFPGA core
    signal rtc_addr       : std_logic_vector(5 downto 0);

    -- Additional registers for the beeb side RTC address and data
    signal ext_rtc_as_r : std_logic;
    signal ext_rtc_ds_r : std_logic;

    -- Port B of the RAM is connected to the external PCF8583 RTC
    signal portb_we                : std_logic;
    signal portb_addr              : std_logic_vector(5 downto 0) := (others => '0');
    signal portb_addr1             : std_logic_vector(5 downto 0) := (others => '0'); -- delayed one cycle to match dout
    signal portb_din               : std_logic_vector(7 downto 0) := (others => '0');
    signal portb_dout              : std_logic_vector(8 downto 0) := (others => '0');

    -- Additional registers for managing the scrubbimg
    signal scrub_addr              : std_logic_vector(5 downto 0) := (others => '0');
    signal next_scrub_addr         : std_logic_vector(5 downto 0) := (others => '0');
    signal last_year               : std_logic_vector(1 downto 0) := (others => '0');
    signal last_day                : std_logic_vector(5 downto 0) := (others => '0');
    signal last_weekday            : std_logic_vector(2 downto 0) := (others => '0');
    signal last_month              : std_logic_vector(4 downto 0) := (others => '0');

    type state_type is (
        ST_IDLE,
        ST_INIT1,
        ST_INIT2,
        ST_WRITE_HMS1,
        ST_WRITE_HMS2,
        ST_WRITE_YEAR1,
        ST_WRITE_YEAR2,
        ST_WRITE_DAY0,
        ST_WRITE_DAY1,
        ST_WRITE_DAY2,
        ST_WRITE_WEEKDAY1,
        ST_WRITE_WEEKDAY2,
        ST_WRITE_MONTH0,
        ST_WRITE_MONTH1,
        ST_WRITE_MONTH2,
        ST_WRITE_DONE
        );

    signal state : state_type;

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
    -- The rtc_xxx regsisters and the rtc_ram RAM act as a cache,
    -- holding the latest emulated HD146818 RTC/CMOS RAM state
    --
    -- 6502 reads are serviced immediately from this cache. 6502
    -- writes are written to cache, and the address written is marked
    -- as dirty (in the 64-bit dirty register)
    --
    -- During power -p reset the cache is initialized from the
    -- external RTC via I2C
    --
    -- Asynchronously (every ~10ms) the rtc_xxx registers holding the
    -- date/time are refreshed from the external RTC. These are
    -- discrete registers to allow multiple updates at the same
    -- time. If an rtc_xxx register is marked as dirty (i.e. it was
    -- written by the 6502), asnchronous updates to that register are
    -- suspended until it has been written back to the external
    -- RTC. This ensures 6502 writes are not lost.
    --
    -- A background scrubber process tests for dirty cache addresses
    -- by scanning the 64-bit dirty register. If an address is marked
    -- as dirty, the correponsing data is read from the cache and
    -- written back to the external RTC.

    -- Port A connects the cache to the BeebFPGA core
    process(clock)
    begin
        if rising_edge(clock) then
            if ext_rtc_ce = '1' then
                ext_rtc_as_r <= ext_rtc_as;
                ext_rtc_ds_r <= ext_rtc_ds;

                -- Latch the RTC Address of the falling edge of rtc_as
                if ext_rtc_as = '0' and ext_rtc_as_r = '1' then
                    rtc_addr <= ext_rtc_adi(5 downto 0);
                end if;

                -- Latch the Write Data on the falling edge of rtc_ds
                if ext_rtc_ds = '0' and ext_rtc_ds_r = '1' and ext_rtc_r_nw = '0' then
                    -- Bit 8 = 1 mark the location as dirty so it gets
                    -- written back to external RTC (this will also
                    -- suspend async updates)
                    rtc_ram(to_integer(unsigned(rtc_addr))) <= "1" & ext_rtc_adi;
                else
                    ext_rtc_do <= rtc_ram(to_integer(unsigned(rtc_addr)))(7 downto 0);
                end if;
            end if;
        end if;
    end process;

    next_scrub_addr <= scrub_addr + 1;

    -- Port B connect the cache to the external RTC interface, supported by the I2C3 controller
    process(clock)
    begin
        if rising_edge(clock) then

            -- Defaults
            portb_we <= '0';
            portb_din <= reg_data;

            -- A delayed version to match dout
            portb_addr1 <= portb_addr;

            if reset = '1' then

                state <= ST_IDLE;
                scrub_addr <= (others => '0');
                init_done <= '0';
                cmos_write_req <= '0';
                cmos_addr <= (others => '0');
                cmos_data <= (others => '0');

            else

                case state is

                    when ST_IDLE =>
                        if reg_write = '1' then
                            -- Time updates take priority
                            case reg_addr is
                                when CB_INIT_RESET =>
                                    -- detect initialiation (load of cache on power up)
                                    portb_addr <= RTC_CMOS_BASE;
                                    state <= ST_INIT1;
                                    init_done <= '0';
                                when CB_SECS =>
                                    portb_addr <= RTC_SECS_REG;
                                    state <= ST_WRITE_HMS1;
                                when CB_MINS =>
                                    portb_addr <= RTC_MINS_REG;
                                    state <= ST_WRITE_HMS1;
                                when CB_HOURS =>
                                    portb_addr <= RTC_HOURS_REG;
                                    state <= ST_WRITE_HMS1;
                                when CB_YEAR_DAY =>
                                    portb_addr <= RTC_YEAR_REG;
                                    state <= ST_WRITE_YEAR1;
                                when CB_WEEKDAY_MONTH =>
                                    portb_addr <= RTC_WEEKDAY_REG;
                                    state <= ST_WRITE_WEEKDAY1;
                                when others =>
                                    null;
                            end case;
                        else
                            if portb_addr1 = RTC_YEAR_REG then
                                last_year <= portb_dout(1 downto 0);
                            end if;
                            if portb_addr1 = RTC_DAY_REG then
                                last_day <= portb_dout(5 downto 0);
                            end if;
                            if portb_addr1 = RTC_WEEKDAY_REG then
                                last_weekday <= portb_dout(2 downto 0);
                            end if;
                            if portb_addr1 = RTC_MONTH_REG then
                                last_month <= portb_dout(4 downto 0);
                            end if;
                            if cmos_write_req = '0' then
                                -- test for dirty data
                                if portb_dout(8) = '1' then
                                    -- immediately re-write data as clean because it will be flushed
                                    portb_addr <= portb_addr1;
                                    portb_din <= portb_dout(7 downto 0);
                                    portb_we <= '1';
                                    -- request a writeback from the I23C controller
                                    cmos_write_req <= '1';
                                    -- setup the CMOS address
                                    case portb_addr1 is
                                        when RTC_SECS_REG =>
                                            cmos_addr <= I2C_SECS_REG;
                                        when RTC_MINS_REG =>
                                            cmos_addr <= I2C_MINS_REG;
                                        when RTC_HOURS_REG =>
                                            cmos_addr <= I2C_HOURS_REG;
                                        when RTC_YEAR_REG | RTC_DAY_REG =>
                                            cmos_addr <= I2C_YEAR_DAY_REG;
                                        when RTC_WEEKDAY_REG | RTC_MONTH_REG =>
                                            cmos_addr <= I2C_WEEKDAY_MONTH_REG;
                                        when others =>
                                            cmos_addr <= "10" & portb_addr1;
                                    end case;
                                    -- setup the CMOS data to be written
                                    case portb_addr1 is
                                        when RTC_YEAR_REG =>
                                            cmos_data <= portb_dout(1 downto 0) & last_day;
                                        when RTC_DAY_REG =>
                                            cmos_data <= last_year & portb_dout(5 downto 0);
                                        when RTC_WEEKDAY_REG =>
                                            cmos_data <= (portb_dout(2 downto 0) - "001") & last_month;
                                        when RTC_MONTH_REG =>
                                            cmos_data <= (last_weekday - "001") & portb_dout(4 downto 0);
                                        when others =>
                                            cmos_data <= portb_dout(7 downto 0);
                                    end case;
                                else
                                    portb_addr <= next_scrub_addr;
                                    scrub_addr <= next_scrub_addr;
                                end if;
                            elsif cmos_write_ack = '1' then
                                -- lower the write request
                                cmos_write_req <= '0';
                                -- rewind the scrub address
                                portb_addr <= scrub_addr;
                            end if;
                        end if;

                    when ST_INIT1 =>
                        if reg_write = '1' and reg_addr = CB_INIT_NEXT then
                            portb_we <= '1';
                            state <= ST_INIT2;
                        end if;

                    when ST_INIT2 =>
                        if portb_addr = "111111" then
                            portb_addr <= scrub_addr;
                            state <= ST_IDLE;
                            init_done <= '1';
                        else
                            portb_addr <= portb_addr + 1;
                            state <= ST_INIT1;
                        end if;

                    when ST_WRITE_HMS1 =>
                        -- Read the dirty flag
                        state <= ST_WRITE_HMS2;

                    when ST_WRITE_HMS2 =>
                        -- Write the register only if the dirty flag clean
                        portb_we <= not portb_dout(8);
                        state <= ST_WRITE_DONE;

                    when ST_WRITE_YEAR1 =>
                        -- Read the dirty flag
                        state <= ST_WRITE_YEAR2;

                    when ST_WRITE_YEAR2 =>
                        -- Write the register only if the dirty flag clean
                        portb_we <= not portb_dout(8);
                        -- MS bits of year are hard coded!!!! it will break in 2028.
                        portb_din <= "001001" & reg_data(7 downto 6);
                        state <= ST_WRITE_DAY0;

                    when ST_WRITE_DAY0 =>
                        -- Switch to the day address
                        portb_addr <= RTC_DAY_REG;
                        state <= ST_WRITE_DAY1;

                    when ST_WRITE_DAY1 =>
                        -- Read the dirty flag
                        state <= ST_WRITE_DAY2;

                    when ST_WRITE_DAY2 =>
                        -- Write the register only if the dirty flag clean
                        portb_we <= not portb_dout(8);
                        portb_din <= "00" & reg_data(5 downto 0);
                        state <= ST_WRITE_DONE;

                    when ST_WRITE_WEEKDAY1 =>
                        -- Read the dirty flag
                        state <= ST_WRITE_WEEKDAY2;

                    when ST_WRITE_WEEKDAY2 =>
                        -- Write the register only if the dirty flag clean
                        portb_we <= not portb_dout(8);
                        portb_din <= "00000" & (reg_data(7 downto 5) + "001");
                        state <= ST_WRITE_MONTH0;

                    when ST_WRITE_MONTH0 =>
                        -- Switch to the day address
                        portb_addr <= RTC_MONTH_REG;
                        state <= ST_WRITE_MONTH1;

                    when ST_WRITE_MONTH1 =>
                        -- Read the dirty flag
                        state <= ST_WRITE_MONTH2;

                    when ST_WRITE_MONTH2 =>
                        -- Write the register only if the dirty flag clean
                        portb_we <= not portb_dout(8);
                        portb_din <= "000" & reg_data(4 downto 0);
                        state <= ST_WRITE_DONE;

                    when ST_WRITE_DONE =>
                        portb_addr <= scrub_addr;
                        state <= ST_IDLE;

                    when others =>
                        state <= ST_IDLE;

                end case;
            end if;

            if portb_we = '1' then
                -- We never write dirty data through this port
                rtc_ram(to_integer(unsigned(portb_addr))) <= "0" & portb_din;
            else
                -- Read data
                portb_dout <= rtc_ram(to_integer(unsigned(portb_addr)));
            end if;
        end if;
    end process;

end architecture;
