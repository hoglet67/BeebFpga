library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;

entity mem_tang_primer_20k is
    generic (
        PRJ_ROOT             : string;
        MOS_NAME             : string;
        SIM                  : boolean;
        IncludeMonitor       : boolean := false;
        IncludeBootstrap     : boolean;
        IncludeMinimalMaster : boolean := false;  -- Creates a build to test 4x16K ROM Images
        IncludeMinimalBeeb   : boolean := false   -- Creates a build to test 4x16K ROM Images

        );
    port(
        CLK_96            : in  std_logic;
        CLK_96_P          : in  std_logic;
        CLK_48            : in  std_logic;

        rst_n             : in  std_logic;

        READY             : out std_logic;

        core_A_stb        : in    std_logic;
        core_A            : in    std_logic_vector (18 downto 0);
        core_Din          : in    std_logic_vector (7 downto 0);
        core_Dout         : out   std_logic_vector (7 downto 0);
        core_nCS          : in    std_logic;
        core_nWE          : in    std_logic;
        core_nWE_long     : in    std_logic;
        core_nOE          : in    std_logic;

        m128_mode         : in     std_logic;

        led               : out   std_logic_vector(5 downto 0);

        FLASH_CS          : out   std_logic;                     -- Active low FLASH chip select
        FLASH_SI          : out   std_logic;                     -- Serial output to FLASH chip SI pin
        FLASH_CK          : out   std_logic;                     -- FLASH clock
        FLASH_SO          : in    std_logic                      -- Serial input from FLASH chip SO pin
        );
end mem_tang_primer_20k;

architecture rtl of mem_tang_primer_20k is

    constant ROMSIZE : natural := 49152;

    type mem_mos_t is array(0 to ROMSIZE-1) of std_logic_vector(7 downto 0);
    type mem_ram_t is array(0 to 32767) of std_logic_vector(7 downto 0);

    impure function MEM_INIT_FILE(file_name:STRING) return mem_mos_t is
        FILE infile : text is in file_name;
        variable arr : mem_mos_t := (others => (others => '0'));
        variable inl : line;
        variable count : integer;
    begin
        if not IncludeBootstrap then
            count := 0;
            while not(endfile(infile)) and count < ROMSIZE loop
                readline(infile, inl);
                read(inl, arr(count));
                count := count + 1;
            end loop;
        end if;

        return arr;
    end function;

    signal r_mem_rom : mem_mos_t := MEM_INIT_FILE(PRJ_ROOT & MOS_NAME);
    signal r_mem_ram : mem_ram_t;

    -- from bootstrap to bsram controller
    signal i_X_Din         : std_logic_vector(7 downto 0);
    signal i_X_Dout        : std_logic_vector(7 downto 0);
    signal i_X_A_stb       : std_logic;
    signal i_X_A           : std_logic_vector(18 downto 0);
    signal i_X_nWE_long    : std_logic;
    signal i_X_nWE         : std_logic;
    signal i_X_nOE         : std_logic;
    signal i_X_nCS         : std_logic;


    signal i_X_nROM        : std_logic;
    signal i_X_nRAM        : std_logic;

-----------------------------------------------
-- Bootstrap ROM Image from SPI FLASH into SRAM
-----------------------------------------------

    -- These are settings for use with a minimal 48K ROM config
    --
    --        Beeb          ----- master not supported yet ---- Master
    -- 0 -> 4 MOS 1.20      ----- master not supported yet ---- 4 MOS 3.20
    -- 1 -> 8 MMFS          ----- master not supported yet ---- 9 MMFS
    -- 2 -> F Ram Master    ----- master not supported yet ---- C Basic II
    -- 3 -> F Basic II      ----- master not supported yet ---- F Terminal
    constant user_rom_map_beeb_minimal    : std_logic_vector(63 downto 0) := x"0000000000000DE4";
    constant user_rom_map_master_minimal  : std_logic_vector(63 downto 0) := x"0000000000000DE4"; -- TODO: figure out a 3 rom master configuration
    constant user_rom_map_full            : std_logic_vector(63 downto 0) := x"FEDCBA9876543210";
    signal   user_rom_map                 : std_logic_vector(63 downto 0);

    -- start address of user data in FLASH as obtained from bitmerge.py
    -- this mus be beyond the end of the bitstream

    constant user_address_beeb            : std_logic_vector(23 downto 0) := x"300000";
    constant user_address_master_minimal  : std_logic_vector(23 downto 0) := x"310000";
    constant user_address_master_full     : std_logic_vector(23 downto 0) := x"340000";
    signal   user_address                 : std_logic_vector(23 downto 0);
    signal   user_length                  : std_logic_vector(23 downto 0);

    -- length of user data in FLASH = 256KB (16x 16K ROM) images
    constant user_length_full             : std_logic_vector(23 downto 0) := x"040000";

    -- length of user data in FLASH = 48KB (3x 16K ROM) images
    constant user_length_minimal          : std_logic_vector(23 downto 0) := x"00C000";

    -- high when FLASH is being copied to SRAM, can be used by user as active high reset
    signal   i_bootstrap_busy  : std_logic;

    signal   i_bootstrap_reset_n  : std_logic;


    -- Signals for the bootstrap health monitor
    signal ADDR_INS0 : std_logic_vector(18 downto 0);
    signal ADDR_INS1 : std_logic_vector(18 downto 0);
    signal ADDR_VEC0 : std_logic_vector(18 downto 0);
    signal ADDR_VEC1 : std_logic_vector(18 downto 0);

    signal DATA_INS0 : std_logic_vector(7 downto 0);
    signal DATA_INS1 : std_logic_vector(7 downto 0);
    signal DATA_VEC0 : std_logic_vector(7 downto 0);
    signal DATA_VEC1 : std_logic_vector(7 downto 0);

    -- Bit 5 is the error bit
    -- Bit 4 is the done bit
    -- Bit 3 is the write/read bit (0 = write, 1 = read)

    constant DBG_00 : std_logic_vector(5 downto 0) := "000000";
    constant DBG_01 : std_logic_vector(5 downto 0) := "000001";
    constant DBG_02 : std_logic_vector(5 downto 0) := "000010";
    constant DBG_03 : std_logic_vector(5 downto 0) := "000011";
    constant DBG_04 : std_logic_vector(5 downto 0) := "000100";
    constant DBG_05 : std_logic_vector(5 downto 0) := "000101";
    constant DBG_06 : std_logic_vector(5 downto 0) := "000110";
    constant DBG_07 : std_logic_vector(5 downto 0) := "000111";
    constant DBG_08 : std_logic_vector(5 downto 0) := "001000";
    constant DBG_09 : std_logic_vector(5 downto 0) := "001001";
    constant DBG_0A : std_logic_vector(5 downto 0) := "001010";
    constant DBG_0B : std_logic_vector(5 downto 0) := "001011";
    constant DBG_0C : std_logic_vector(5 downto 0) := "001100";
    constant DBG_0D : std_logic_vector(5 downto 0) := "001101";
    constant DBG_0E : std_logic_vector(5 downto 0) := "001110";
    constant DBG_0F : std_logic_vector(5 downto 0) := "001111";
    constant DBG_DONE : std_logic_vector(5 downto 0) := "011111";
    signal   state  : std_logic_vector(5 downto 0) := DBG_00;

begin

    p_reset:process(CLK_48, rst_n)
    begin
        if rst_n = '0' then
            READY <= '0';
            i_bootstrap_reset_n <= '0';
        elsif rising_edge(CLK_48) then
            i_bootstrap_reset_n <= '1';
            READY <= not i_bootstrap_busy;
        end if;
    end process;


--------------------------------------------------------
-- BOOTSTRAP SPI FLASH to SRAM
--------------------------------------------------------

    GenBootstrap: if IncludeBootstrap generate


        user_address <=   user_address_master_minimal when m128_mode = '1' and     IncludeMinimalMaster else
                          user_address_master_full    when m128_mode = '1' and not IncludeMinimalMaster else
                          user_address_beeb;

        user_length  <=   user_length_minimal         when m128_mode = '1' and     IncludeMinimalMaster else
                          user_length_minimal         when m128_mode = '0' and     IncludeMinimalBeeb   else
                          user_length_full;

        user_rom_map <=   user_rom_map_master_minimal when m128_mode = '1' and     IncludeMinimalMaster else
                          user_rom_map_beeb_minimal   when m128_mode = '0' and     IncludeMinimalBeeb   else
                          user_rom_map_full;

        inst_bootstrap: entity work.bootstrap
            port map(
                clock           => CLK_48,
                powerup_reset_n => i_bootstrap_reset_n,
                bootstrap_busy  => i_bootstrap_busy,
                user_address    => user_address,
                user_length     => user_length,
                user_rom_map    => user_rom_map,
                RAM_A_stb       => core_A_stb,
                RAM_nOE         => core_nOE,
                RAM_nWE         => core_nWE,
                RAM_nWE_long    => core_nWE_long,
                RAM_nCS         => core_nCS,
                RAM_A           => core_A,
                RAM_Din         => core_Din,
                RAM_Dout        => core_Dout,
                SRAM_A_stb      => i_X_A_stb,
                SRAM_nOE        => i_X_nOE,
                SRAM_nWE        => i_X_nWE,
                SRAM_nWE_long   => i_X_nWE_long,
                SRAM_nCS        => i_X_nCS,
                SRAM_A          => i_X_A,
                SRAM_D_out      => i_X_Din,
                SRAM_D_in       => i_X_Dout,
                FLASH_CS        => FLASH_CS,
                FLASH_SI        => FLASH_SI,
                FLASH_CK        => FLASH_CK,
                FLASH_SO        => FLASH_SO
                );

    end generate;

    NotGenBootstrap: if not IncludeBootstrap generate

        i_bootstrap_busy <= '0';
        i_X_A_stb      <= core_A_stb;
        i_X_nOE        <= core_nOE;
        i_X_nWE        <= core_nWE;
        i_X_nWE_long   <= core_nWE_long;
        i_X_nCS        <= core_nCS;
        i_X_A          <= core_A;
        i_X_Din        <= core_Din;
        core_Dout      <= i_X_Dout;

        FLASH_CS       <= '1';
        FLASH_SI       <= '1';
        FLASH_CK       <= '1';

    end generate;

    
    i_X_nROM <= '0' when i_X_A(18 downto 14) = "00100" else -- MOS
                '0' when i_X_A(18 downto 14) = "01101" else -- D
                '0' when i_X_A(18 downto 14) = "01110" else -- E
                '1';

    i_X_nRAM <= '0' when i_X_A(18 downto 15) = "1100" else -- main CPU ram
                '1';

    p_ram_rd:process(CLK_48)
    begin
        if rising_edge(CLK_48) then
            if i_X_nCS = '0' and i_X_nOE = '0' and i_X_A_stb = '1' then
                if i_X_nROM = '0' then
                    i_X_Dout <= r_mem_rom(to_integer(unsigned(i_X_A(15 downto 0))));
                elsif i_X_nRAM = '0' then
                    i_X_Dout <= r_mem_ram(to_integer(unsigned(i_X_A(14 downto 0))));
                else
                    i_X_Dout <= (others => '1');
                end if;
            end if;
        end if;
    end process;

    p_ram_wr:process(CLK_48)
    begin
        if rising_edge(CLK_48) then
            if i_X_nCS = '0' and i_X_nWE_long = '0' and i_X_A_stb = '1' then
                if i_X_nROM = '0' then
                    r_mem_rom(to_integer(unsigned(i_X_A(15 downto 0)))) <= i_X_Din;
                elsif i_X_nRAM = '0' then
                    r_mem_ram(to_integer(unsigned(i_X_A(14 downto 0)))) <= i_X_Din;
                end if;
            end if;
        end if;
    end process;


    --------------------------------------------------------
    -- Statemachine for debugging bootstrap failures
    --------------------------------------------------------

    mon : if IncludeMonitor generate

         -- Notes:
        --
        --   The monitor runs from the system clock domain (CLK_48)
        --   not the memory clock domain, so it better checks what
        --   bbc_micro_core sees.
        --
        --   Writes are checked at the start of the memory access.
        --
        --   Reads need to be checked at the end of the memory access,
        --   when the read data is avilable. It's problematic to use
        --   the data ready signal as a trigger, as the memory clock
        --   is faster (CLK_96), so sampling this back to CLK_48 is
        --   unreliable. So instead we check a fixed amount (5 system
        --   clocks cycle) later. This matches how bbc_micro_core
        --   latches the read data at the end of the 6 cycle memory
        --   access slot.
        --
        --   The OS is always mapped into rom slot 4 10000-13FFF
        --   On the Beeb the reset address of D9CD becomed 119CD
        --   On the Master the reset address of E364 becomed 12364

        ADDR_INS0 <= "001" & x"2364" when m128_mode = '1' else  "001" & x"19CD";
        ADDR_INS1 <= "001" & x"2365" when m128_mode = '1' else  "001" & x"19CE";
        ADDR_VEC0 <= "001" & x"3FFC";
        ADDR_VEC1 <= "001" & x"3FFD";

        DATA_INS0 <= x"A9";
        DATA_INS1 <= x"40";
        DATA_VEC0 <= x"64" when m128_mode = '1' else x"CD";
        DATA_VEC1 <= x"E3" when m128_mode = '1' else x"D9";

        process(CLK_48)
            variable test_write : std_logic;
            variable test_read  : std_logic;
            variable read_delay : std_logic_vector(2 downto 0);
        begin
            if rising_edge(CLK_48) then

                if rst_n = '0' then
                    state <= DBG_00;
                else
                case (state) is
                    when DBG_00 =>
                            if IncludeBootstrap then
                                state <= DBG_01;
                            else
                                state <= DBG_0A;
                        end if;
                    when DBG_01 =>
                        if rst_n = '1' then
                            state <= DBG_02;
                        end if;
                    when DBG_02 =>
--TODO: skip this stage - sdram controller not present so no delay
--                        if i_bootstrap_reset_n = '0' then
                              state <= DBG_03;
--                        end if;
                    when DBG_03 =>
                        -- The i_X_A term skips over the bootstrap writing zeros
                            if i_bootstrap_reset_n = '1' and test_write = '1' and i_X_A = ADDR_VEC1 then
                            state <= DBG_04;
                        end if;
                    when DBG_04 =>
                        if test_write = '1' then
                            if i_X_A = ADDR_INS0 then
                                if i_X_Din = DATA_INS0 then
                                    state <= DBG_05;
                                else
                                    state(5) <= '1';
                                end if;
                            end if;
                        end if;
                    when DBG_05 =>
                        if test_write = '1' then
                            if i_X_A = ADDR_INS1 then
                                if i_X_Din = DATA_INS1 then
                                    state <= DBG_06;
                                else
                                    state(5) <= '1';
                                end if;
                            end if;
                        end if;
                    when DBG_06 =>
                        if test_write = '1' then
                            if i_X_A = ADDR_VEC0 then
                                if i_X_Din = DATA_VEC0 then
                                    state <= DBG_07;
                                else
                                    state(5) <= '1';
                                end if;
                            end if;
                        end if;
                    when DBG_07 =>
                        if  test_write = '1' then
                            if i_X_A = ADDR_VEC1 then
                                if i_X_Din = DATA_VEC1 then
                                    state <= DBG_08;
                                else
                                    state(5) <= '1';
                                end if;
                            end if;
                        end if;
                    when DBG_08 =>
                        if i_bootstrap_busy = '1' then
                            state <= DBG_09;
                        end if;
                    when DBG_09 =>
                        if i_bootstrap_busy = '0' then
                            state <= DBG_0A;
                        end if;
                    when DBG_0A =>
                        if test_read = '1' then
                            if i_X_A = ADDR_VEC0 then
                                if i_X_Dout = DATA_VEC0 then
                                    state <= DBG_0B;
                                else
                                    state(5) <= '1';
                                end if;
                            end if;
                        end if;
                    when DBG_0B =>
                        if test_read = '1' then
                            if i_X_A = ADDR_VEC1 then
                                    if i_X_Dout = DATA_VEC1 then
                                    state <= DBG_0C;
                                else
                                    state(5) <= '1';
                                end if;
                            end if;
                        end if;
                    when DBG_0C =>
                        if test_read = '1' then
                            if i_X_A = ADDR_INS0 then
                                    if i_X_Dout = DATA_INS0 then
                                    state <= DBG_0D;
                                else
                                    state(5) <= '1';
                                end if;
                            end if;
                        end if;
                    when DBG_0D =>
                        if test_read = '1' then
                            if i_X_A = ADDR_INS1 then
                                    if i_X_Dout = DATA_INS1 then
                                    state <= DBG_DONE;
                                else
                                    state(5) <= '1';
                                end if;
                            end if;
                        end if;
                        when others => null;
                end case;
                end if;
                test_write := not (i_X_nCS or i_X_nWE_long) and i_X_A_stb;
                test_read  := read_delay(0);
                read_delay := (not (i_X_nCS or i_X_nOE) and i_X_A_stb) & read_delay(read_delay'high downto 1);
            end if;
        end process;

        led <= state xor "111111";

    end generate;

    not_mon : if not IncludeMonitor generate

        led <= "111111";

    end generate;

end rtl;
