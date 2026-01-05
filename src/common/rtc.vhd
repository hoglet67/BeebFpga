library ieee ;
use ieee.std_logic_1164.all ;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity rtc is
    generic (
        OverrideCMOS : boolean -- Overide CMOS/RTC mode settings with keyb_dip
    );
    port (
        clk          : in  std_logic;
        cpu_clken    : in  std_logic;
        hard_reset_n : in  std_logic;
        reset_n      : in  std_logic;
        ce           : in  std_logic; -- chip enable
        as           : in  std_logic; -- address strobe
        ds           : in  std_logic; -- data strobe
        r_nw         : in  std_logic;
        adi          : in  std_logic_vector(7 downto 0); -- address/data in
        do           : out std_logic_vector(7 downto 0); -- data out

        -- second RAM port for external access
        rtc_mgmt_we   : in  std_logic;
        rtc_mgmt_addr : in  std_logic_vector(5 downto 0);
        rtc_mgmt_din  : in  std_logic_vector(8 downto 0);
        rtc_mgmt_dout : out std_logic_vector(8 downto 0);

        -- copro settings
        copro_mode   : in  std_logic;
        copro_ext    : in  std_logic;
        -- bits 0..3 set mode; bit 4 sets autoboot
        keyb_dip     : in  std_logic_vector(7 downto 0)  -- keyboard DIP
    );
end entity;

architecture rtl of rtc is

    signal ds_r : std_logic;
    signal as_r : std_logic;

    type rtc_ram_type is array(0 to 63) of std_logic_vector(8 downto 0);

-- CMOS configuration RAM allocation
--
-- From http://beebwiki.mdfs.net/index.php/CMOS_configuration_RAM_allocation
--
--   Location  Settings                                 Configured with
--   -----------------------------------------------------------------------------
--    0        Econet Station Number                    *SetStation nnn
--    1        File server station number               *Config. FS nnn
--    2        File server network number               *Config. FS nnn.sss
--    3        Printer server station number            *Config. PS nnn
--    4        Printer server network number            *Config. PS nnn.sss
--    5 b0-b3  Default filing system ROM                *Config. File nn
--      b4-b7  Default language ROM                     *Config. Lang nn
--    6        ROMs 0-7 unplugged/inserted              *Insert nn/*Unplug nn
--    7        ROMs 8-15 unplugged/inserted             *Insert nn/*Unplug nn
--    8 b0-b2  EDIT screen mode
--      b3     EDIT TAB to columns/words
--      b4     EDIT overwrite/insert
--      b5     EDIT display returns
--      b6-b7  spare
--    9        Telecoms software
--   10 b0-b3  Default screen mode b0-b2,b7             *Config. Mode nn
--      b4     Default TV interlace                     *Config. TV xx,n
--      b5-b7  Default TV position, 0 to 3, -4 to -1    *Config. TV nn,x
--   11 b0-b2  Default floppy speed                     *Config. FDrive n
--      b3     Shift Caps on startup          \         *Config. ShCaps
--      b4     No Lock on startup              (*fx202) *Config. NoCaps
--      b5     Caps Lock on startup           /         *Config. Caps
--      b6     ADFS load directory on startup           *Config. NoDir/Dir
--      b7     ADFS floppy/hard drive on startup        *Config. Floppy/Hard
--   12        Keyboard repeat delay           (*fx11)  *Config. Delay nnn
--   13        Keyboard repeat rate            (*fx12)  *Config. Repeat nnn
--   14        Printer ignore character        (*fx246) *Config. Ignore nnn
--   15 b0     Ignore/enable Tube                       *Config. NoTube/Tube
--      b1     Ignore printer ignore character (*fx182) *Config. Ignore/Ignore nnn
--      b2-b4  Default serial speed 0-7     (*fx7/*fx8) *Config. Baud n
--      b5-b7  Default printer device, 0-7     (*fx245) *Config. Print n
--   16 b0     Default to shadow screen on start (MER)  *Config. Shadow
--      b1     Default BEEP quiet/loud                  *Config. Quiet/Loud
--      b2     Internal/External Tube                   *Config. InTube/ExTube
--      b3     Scrolling enabled/protected              *Config. Scroll/NoScroll
--      b4     Noboot/boot on reset                     *Config. NoBoot/Boot
--      b5-b7  Default serial data format      (*fx192) *Config. Data n
--   17 b0     ANFS raise 2 pages of workspace          *Config. NoSpace/Space
--      b1     ANFS run *FindLib on logon               *-Net-Opt 5,n
--      b2-b3                                           *-Net-Opt 6,n
--             b2 ANFS use &0Bxx-&0Cxx or &0Exx-&0Fxx workspace
--             b3 unused
--      b4-b5  unused                                   *-Net-Opt 7,n
--      b6-b7                                           *-Net-Opt 8,n
--             b6 ANFS protected
--             b7 Display version number on startup
--   18 b0-b3  Compact joystick speed         \         *Config. Stick nn
--      b4     unused                          (*fx190)
--      b5     Compact joystick proportional/switched   *Config. Proportional/Switched
--      b6-b7  Century 19-22                  /
--   19        Country code                    (*fx240) *Config. Country nnn
--   20-29     Reserved for Acorn
--   20 b0-b3  ARM CoPro CPU type (JGH ARM Modules)     *Config. CPU <cpuname>
--      b4-b7
--   30-45     Allocated to ROM 0-15
--   46-49     Reserved for user applications
--
--   255       EEPROM size

    -- bits 2..0 (mode) overlaid by DIP switches/config
    constant ini10 : std_logic_vector(7 downto 0) := x"F7";

    -- bit 0 (tube) overlaid by DIP switches/config
    -- (b4..b2) = 110 = *CONFIGURE BAUD 7 = 9600
    constant ini15 : std_logic_vector(7 downto 0) := x"38";

    -- bit 2 (intube/extube) and 4 (noboot/boot) overlaid by DIP switches/config
    -- (b7..b5) = 101 = *CONFIGURE DATA 5 = 8n1
    constant ini16 : std_logic_vector(7 downto 0) := x"A2";

    -- initialize with dirty bit clean, so these values never get written back to an external RTC
    shared variable rtc_ram : rtc_ram_type := (
        '0' & x"30", -- RTC Seconds
        '0' & x"00", -- RTC Seconds Alarm
        '0' & x"02", -- RTC Minutes
        '0' & x"00", -- RTC Minutes Alarm
        '0' & x"18", -- RTC Hours
        '0' & x"00", -- RTC Hours Alarm
        '0' & x"06", -- RTC Day of Week
        '0' & x"07", -- RTC Date of Month
        '0' & x"11", -- RTC Month
        '0' & x"15", -- RTC Year
        '0' & x"00", -- RTC Register A
        '0' & x"00", -- RTC Register B
        '0' & x"00", -- RTC Register C
        '0' & x"00", -- RTC Register D
        '0' & x"00", -- CMOS  0 - Econet station number
        '0' & x"FE", -- CMOS  1 - Econet file server identity (lo)
        '0' & x"00", -- CMOS  2 - Econet file server identity (hi)
        '0' & x"EB", -- CMOS  3 - Econet print server identity (lo)
        '0' & x"00", -- CMOS  4 - Econet print server identity (hi)
        '0' & x"C9", -- CMOS  5 - Default Filing System / Language (default file system MMFS)
        '0' & x"FF", -- CMOS  6 - ROM frugal bits (*INSERT/*UNPLUG)
        '0' & x"FF", -- CMOS  7 - ROM frugal bits (*INSERT/*UNPLUG)
        '0' & x"00", -- CMOS  8 - Edit startup settings
        '0' & x"00", -- CMOS  9 - reserved for telecommunications applications
        '0' & ini10, -- CMOS 10 - VDU mode and *TV settings
        '0' & x"63", -- CMOS 11 - ADFS startup options, keyboard settings, floppy params
        '0' & x"20", -- CMOS 12 - Keyboard auto-repeat delay
        '0' & x"08", -- CMOS 13 - Keyboard auto-repeat rate
        '0' & x"0A", -- CMOS 14 - Printer ignore character
        '0' & ini15, -- CMOS 15 - Default printer type, serial baud rate, ignore status and TUBE select
        '0' & ini16, -- CMOS 16 - Default serial data format, auto boot option, int/ext TUBE, bell amplitude
        '0' & x"00", -- CMOS 17 - reserved for ANFS
        '0' & x"00", -- CMOS 18 - reserved for ANFS
        '0' & x"00", -- CMOS 19 - reserved for ANFS
        '0' & x"00", -- CMOS 20 - reserved for future use by Acorn
        '0' & x"00", -- CMOS 21 - reserved for future use by Acorn
        '0' & x"00", -- CMOS 22 - reserved for future use by Acorn
        '0' & x"00", -- CMOS 23 - reserved for future use by Acorn
        '0' & x"00", -- CMOS 24 - reserved for future use by Acorn
        '0' & x"00", -- CMOS 25 - reserved for future use by Acorn
        '0' & x"00", -- CMOS 26 - reserved for future use by Acorn
        '0' & x"00", -- CMOS 27 - reserved for future use by Acorn
        '0' & x"00", -- CMOS 28 - reserved for future use by Acorn
        '0' & x"00", -- CMOS 29 - reserved for future use by Acorn
        '0' & x"00", -- CMOS 30 - reserved for future use by third parties
        '0' & x"00", -- CMOS 31 - reserved for future use by third parties
        '0' & x"00", -- CMOS 32 - reserved for future use by third parties
        '0' & x"00", -- CMOS 33 - reserved for future use by third parties
        '0' & x"00", -- CMOS 34 - reserved for future use by third parties
        '0' & x"00", -- CMOS 35 - reserved for future use by third parties
        '0' & x"00", -- CMOS 36 - reserved for future use by third parties
        '0' & x"00", -- CMOS 37 - reserved for future use by third parties
        '0' & x"00", -- CMOS 38 - reserved for future use by third parties
        '0' & x"00", -- CMOS 39 - reserved for future use by third parties
        '0' & x"00", -- CMOS 40 - reserved for future use by the user
        '0' & x"00", -- CMOS 41 - reserved for future use by the user
        '0' & x"00", -- CMOS 42 - reserved for future use by the user
        '0' & x"00", -- CMOS 43 - reserved for future use by the user
        '0' & x"00", -- CMOS 44 - reserved for future use by the user
        '0' & x"00", -- CMOS 45 - reserved for future use by the user
        '0' & x"00", -- CMOS 46 - reserved for future use by the user
        '0' & x"00", -- CMOS 47 - reserved for future use by the user
        '0' & x"00", -- CMOS 48 - reserved for future use by the user
        '0' & x"00"  -- CMOS 49 - reserved for future use by the user
        );


    type RTC_STATE_TYPE is (
        INIT, WRITE_10, WRITE_15, WRITE_16, RUNNING
    );

    signal rtc_state : RTC_STATE_TYPE := INIT;

    signal porta_we   : std_logic;
    signal porta_addr : std_logic_vector(5 downto 0);
    signal porta_din  : std_logic_vector(8 downto 0);
    signal porta_dout : std_logic_vector(8 downto 0);

    signal portb_we   : std_logic;
    signal portb_addr : std_logic_vector(5 downto 0);
    signal portb_din  : std_logic_vector(8 downto 0);
    signal portb_dout : std_logic_vector(8 downto 0);

    signal hard_reset_n_last : std_logic := '1';

begin

    process(clk)
    begin
        if rising_edge(clk) then

            hard_reset_n_last <= hard_reset_n;

            porta_we <= '0';

            -- It's important to initialize quickly at the start of
            -- powerup reset, so any changes made through the mgmt
            -- interface take priority. Otherwise setting like TUBE,
            -- IN/EXTUBE cannot be overridden by setting in an
            -- external CMOS RAM.

            if hard_reset_n = '0' and hard_reset_n_last = '1' then
                rtc_state <= INIT;

            else

                case rtc_state is

                    when INIT =>
                        as_r <= '0';
                        ds_r <= '0';
                        if OverrideCMOS then
                            rtc_state <= WRITE_10;
                        else
                            rtc_state <= RUNNING;
                        end if;

                    -- Copy the screen mode from the DIP switches into CMOS on power up
                    when WRITE_10 =>
                        porta_we   <= '1';
                        porta_addr <= std_logic_vector(to_unsigned(24, 6));
                        -- write with dirty bit clean,
                        porta_din  <= '0' & (ini10 xor ("00000" & keyb_dip(2 downto 0)));
                        rtc_state  <= WRITE_15;

                    -- Copy the Co Pro mode from the into CMOS on power up
                    when WRITE_15 =>
                        porta_we   <= '1';
                        porta_addr <= std_logic_vector(to_unsigned(29, 6));
                        -- write with dirty bit clean,
                        porta_din  <= '0' & (ini15 xor ("0000000" & copro_mode));
                        rtc_state <= WRITE_16;

                    -- Copy the noboot/boot mode from the DIP switches into CMOS on power up
                    when WRITE_16 =>
                        porta_we   <= '1';
                        porta_addr <= std_logic_vector(to_unsigned(30, 6));
                        -- write with dirty bit clean,
                        porta_din  <= '0' & (ini16 xor ("000" & keyb_dip(3) & "0" & copro_ext & "00"));
                        rtc_state <= RUNNING;

                    when RUNNING =>

                        if reset_n = '0' then
                            as_r <= '0';
                            ds_r <= '0';

                        elsif (cpu_clken = '1') then
                            as_r <= as;
                            ds_r <= ds;

                            -- Latch the RTC Address of the falling edge of rtc_as
                            if ce = '1' and as = '0' and as_r = '1' then
                                porta_addr <= adi(5 downto 0);
                            end if;

                            if ce = '1' and ds = '0' and ds_r = '1' and r_nw = '0' then
                                porta_we  <= '1';
                                -- Write with dirty bit set so changes persisted
                                porta_din <= '1' & adi;
                            end if;

                        end if;
                end case;
            end if;
        end if;
    end process;

    -- Port A connect to the 6502
    do <= porta_dout(7 downto 0);

    -- Port B connects to the external RTC management interface
    portb_we      <= rtc_mgmt_we;
    portb_addr    <= rtc_mgmt_addr;
    portb_din     <= rtc_mgmt_din;
    rtc_mgmt_dout <= portb_dout;

    -- Clean logic to infer a dual port RAM with common clock

    process(clk)
    begin
        if rising_edge(clk) then
            if porta_we = '1' then
                rtc_ram(to_integer(unsigned(porta_addr))) := porta_din;
            end if;
            porta_dout <= rtc_ram(to_integer(unsigned(porta_addr)));
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if portb_we = '1' then
                rtc_ram(to_integer(unsigned(portb_addr))) := portb_din;
            end if;
            portb_dout <= rtc_ram(to_integer(unsigned(portb_addr)));
        end if;
    end process;


end architecture rtl;
