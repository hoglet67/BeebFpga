library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;

entity mem_tang_20k is
    generic (
        PRJ_ROOT             : string;
        MOS_NAME             : string;
        SIM                  : boolean;
        UseDBSDRAMCtrl       : boolean;
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

        O_sdram_clk       : out   std_logic;
        O_sdram_cke       : out   std_logic;
        O_sdram_cs_n      : out   std_logic;
        O_sdram_cas_n     : out   std_logic;
        O_sdram_ras_n     : out   std_logic;
        O_sdram_wen_n     : out   std_logic;
        IO_sdram_dq       : inout std_logic_vector(31 downto 0);
        O_sdram_addr      : out   std_logic_vector(10 downto 0);
        O_sdram_ba        : out   std_logic_vector(1 downto 0);
        O_sdram_dqm       : out   std_logic_vector(3 downto 0);

        m128_mode         : in     std_logic;

        led               : out   std_logic_vector(5 downto 0);

        FLASH_CS          : out   std_logic;                     -- Active low FLASH chip select
        FLASH_SI          : out   std_logic;                     -- Serial output to FLASH chip SI pin
        FLASH_CK          : out   std_logic;                     -- FLASH clock
        FLASH_SO          : in    std_logic                      -- Serial input from FLASH chip SO pin
        );
end mem_tang_20k;

architecture rtl of mem_tang_20k is

    --------------------------------------------------------
    -- NESTang SDRAM Controller Component (Verilog)
    --------------------------------------------------------
    component sdramctl_nestang
        port (
            -- SDRAM side interface

            SDRAM_DQ   : inout std_logic_vector(31 downto 0);
            SDRAM_A    : out   std_logic_vector(10 downto 0);
            SDRAM_BA   : out   std_logic_vector(1 downto 0);
            SDRAM_nCS  : out   std_logic;
            SDRAM_nWE  : out   std_logic;
            SDRAM_nRAS : out   std_logic;
            SDRAM_nCAS : out   std_logic;
            SDRAM_CLK  : out   std_logic;
            SDRAM_CKE  : out   std_logic;
            SDRAM_DQM  : out   std_logic_vector(3 downto 0);

            -- Logic side interface
            clk        : in    std_logic;
            clk_sdram  : in    std_logic;                     -- phase shifted from clk (normally 180-degrees)
            resetn     : in    std_logic;
            rd         : in    std_logic;                     -- command: read
            wr         : in    std_logic;                     -- command: write
            refresh    : in    std_logic;                     -- command: auto refresh. 4096 refresh cycles in 64ms. Once per 15us.
            addr       : in    std_logic_vector(22 downto 0); -- byte address, buffered at rd/wr pulse time
            din        : in    std_logic_vector(7 downto 0);  -- data input, buffered at wr pulse time
            dout       : out   std_logic_vector(7 downto 0);  -- data output, available 4 cycles after rd becomes 1
                                                              -- output is buffered until next read request
            dout32     : out   std_logic_vector(31 downto 0); -- 32-bit data output
            data_ready : out   std_logic;                     -- available 6 cycles after wr is set
            busy       : out   std_logic                      -- 0: ready for next command
            );
    end component;


    constant ROMSIZE : natural := 32768;

    type mem_mos_t is array(0 to ROMSIZE) of std_logic_vector(7 downto 0);

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

    -- sdram controller
    signal i_sdram_cmd_read    : std_logic;
    signal i_sdram_cmd_write   : std_logic;
    signal i_sdram_cyc         : std_logic;
    signal i_sdram_we          : std_logic;
    signal i_sdram_addr        : std_logic_vector(22 downto 0);
    signal i_sdram_din         : std_logic_vector(7 downto 0);
    signal i_sdram_dout        : std_logic_vector(7 downto 0);
    signal i_sdram_busy        : std_logic;
    signal i_sdram_data_ready  : std_logic;

    -- from bootstrap to sdram controller
    signal i_X_Din         : std_logic_vector(7 downto 0);
    signal i_X_Dout        : std_logic_vector(7 downto 0);
    signal i_X_A_stb       : std_logic;
    signal i_X_A           : std_logic_vector(18 downto 0);
    signal i_X_nWE_long    : std_logic;
    signal i_X_nOE         : std_logic;
    signal i_X_nCS         : std_logic;

-----------------------------------------------
-- Bootstrap ROM Image from SPI FLASH into SRAM
-----------------------------------------------

    -- These are settings for use with a minimal 64K ROM config
    --
    --        Beeb          Master
    -- 0 -> 4 MOS 1.20      4 MOS 3.20
    -- 1 -> 8 MMFS          9 MMFS
    -- 2 -> E Ram Master    C Basic II
    -- 3 -> F Basic II      F Terminal
    constant user_rom_map_beeb_minimal    : std_logic_vector(63 downto 0) := x"000000000000FE84";
    constant user_rom_map_master_minimal  : std_logic_vector(63 downto 0) := x"000000000000FC94";
    constant user_rom_map_full            : std_logic_vector(63 downto 0) := x"FEDCBA9876543210";
    signal   user_rom_map                 : std_logic_vector(63 downto 0);

    -- start address of user data in FLASH as obtained from bitmerge.py
    -- this mus be beyond the end of the bitstream

    constant user_address_beeb            : std_logic_vector(23 downto 0) := x"500000";
    constant user_address_master_minimal  : std_logic_vector(23 downto 0) := x"510000";
    constant user_address_master_full     : std_logic_vector(23 downto 0) := x"540000";
    signal   user_address                 : std_logic_vector(23 downto 0);
    signal   user_length                  : std_logic_vector(23 downto 0);

    -- length of user data in FLASH = 256KB (16x 16K ROM) images
    constant user_length_full             : std_logic_vector(23 downto 0) := x"040000";

    -- length of user data in FLASH = 64KB (4x 16K ROM) images
    constant user_length_minimal          : std_logic_vector(23 downto 0) := x"010000";

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

    -- Dominic's SDRAM Controller
    gen_sdramctl_dominic : if UseDBSDRAMCtrl generate
        inst_sdramclt_dominic : entity work.sdramctl_dominic
            generic map (
                CLOCKSPEED  => 96000000,
                T_CAS_EXTRA => 1
                )
            port map (
                Clk          => CLK_96,

                sdram_DQ_io  => IO_sdram_dq,
                sdram_A_o    => O_sdram_addr,
                sdram_BS_o   => O_sdram_ba,
                sdram_CKE_o  => O_sdram_cke,
                sdram_nCS_o  => O_sdram_cs_n,
                sdram_nRAS_o => O_sdram_ras_n,
                sdram_nCAS_o => O_sdram_cas_n,
                sdram_nWE_o  => O_sdram_wen_n,
                sdram_DQM_o  => O_sdram_dqm,

                ctl_rfsh_i   => '0',
                ctl_reset_i  => not rst_n,
                ctl_stall_o  => i_sdram_busy,
                ctl_cyc_i    => i_sdram_cyc,
                ctl_we_i     => i_sdram_we,
                ctl_A_i      => i_sdram_addr,
                ctl_D_wr_i   => i_sdram_din,
                ctl_D_rd_o   => i_sdram_dout,
                ctl_ack_o    => i_sdram_data_ready
                );

        O_sdram_clk <= CLK_96_P;
    end generate;

    -- NESTang SDRAM Controller
    gen_sdramclt_nestang : if not UseDBSDRAMCtrl generate
        inst_sdramctl_nestang : sdramctl_nestang
            port map (
                clk        => CLK_96,
                clk_sdram  => CLK_96_p,

                resetn     => rst_n,
                addr       => i_sdram_addr,
                rd         => i_sdram_cmd_read,
                wr         => i_sdram_cmd_write,
                refresh    => '0',
                din        => i_sdram_din,
                dout       => i_sdram_dout,
                data_ready => i_sdram_data_ready,
                busy       => i_sdram_busy,

                SDRAM_DQ   => IO_sdram_dq,
                SDRAM_A    => O_sdram_addr,
                SDRAM_BA   => O_sdram_ba,
                SDRAM_nCS  => O_sdram_cs_n,
                SDRAM_nWE  => O_sdram_wen_n,
                SDRAM_nRAS => O_sdram_ras_n,
                SDRAM_nCAS => O_sdram_cas_n,
                SDRAM_CLK  => O_sdram_clk,
                SDRAM_CKE  => O_sdram_cke,
                SDRAM_DQM  => O_sdram_dqm
                );
    end generate;


    --DB: TODO: eliminate if possible for latency, this required for timing closure
    p_reg:process(CLK_48)
    begin
        if rising_edge(CLK_48) then
            -- Controls for NESTang Controller
            i_sdram_cmd_read  <= not(i_X_nCS) and i_X_A_stb and not i_X_nOE;
            i_sdram_cmd_write <= not(i_X_nCS) and i_X_A_stb and not i_X_nWE_long;
            -- Controls for Dominic SDRAM Controller
            i_sdram_cyc  <= not(i_X_nCS) and i_X_A_stb;
            i_sdram_we   <= not i_X_nWE_long;
            -- SDRAM address is structured as:
            --   bits 22..21 are the bank (4 banks)
            --   bits 20..10 are the row (2048 rows)
            --   bits 9..2 are the column (256 cols)
            --   bits 1..0 are the byte offset (selecting 8 bits out of 32)
            --
            --
            -- i_X_A(9:0) is the BBC refresh address: feed this in as the row
            i_sdram_addr <= "000" & i_X_A(9 downto 0) & "0" & i_X_A(18 downto 10);
            i_sdram_din <= i_X_Din;
        end if;
    end process;


    p_reset:process(CLK_48, rst_n)
    begin
        if rst_n = '0' then
            READY <= '0';
            i_bootstrap_reset_n <= '0';
        elsif rising_edge(CLK_48) then
            if i_sdram_busy = '0' then
                i_bootstrap_reset_n <= '1';
            end if;
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
                SRAM_nWE        => open,
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

        i_X_Dout <= i_sdram_dout;

    end generate;

    NotGenBootstrap: if not IncludeBootstrap generate

        i_bootstrap_busy <= '0';
        i_X_A_stb      <= core_A_stb;
        i_X_nOE        <= core_nOE;
        i_X_nWE_long   <= core_nWE_long;
        i_X_nCS        <= core_nCS;
        i_X_A          <= core_A;
        i_X_Din        <= core_Din;
        core_Dout      <= i_X_Dout;

        FLASH_CS       <= '1';
        FLASH_SI       <= '1';
        FLASH_CK       <= '1';

        -- Minimal Model B ROM set
        p_ram_rd:process(CLK_48)
        begin
            if rising_edge(CLK_48) then
                if core_A(18) = '0' then
                    i_X_Dout <= r_mem_rom(to_integer(unsigned(core_A(14 downto 0))));
                else
                    if core_A(0) = '0' then
                        i_X_Dout <= i_sdram_dout(7 downto 0);
                    else
                        i_X_Dout <= i_sdram_dout(15 downto 8);
                    end if;
                end if;
            end if;
        end process;
    end generate;

    --------------------------------------------------------
    -- Statemachine for debugging bootstrap failures
    --------------------------------------------------------

    mon : if IncludeMonitor generate

        -- Note:
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
            variable cmd_write1 : std_logic;
            variable cmd_write2 : std_logic;
            variable test_write : std_logic;
            variable cmd_read1  : std_logic;
            variable cmd_read2  : std_logic;
            variable test_read  : std_logic;
        begin
            if rising_edge(CLK_48) then
                case (state) is
                    when DBG_00 =>
                        if rst_n = '0' then
                            if IncludeBootstrap then
                                state <= DBG_01;
                            else
                                state <= DBG_08;
                            end if;
                        end if;
                    when DBG_01 =>
                        if rst_n = '1' then
                            state <= DBG_02;
                        end if;
                    when DBG_02 =>
                        if i_bootstrap_reset_n = '0' then
                            state <= DBG_03;
                        end if;
                    when DBG_03 =>
                        -- The i_X_A term skips over the bootstrap writing zeros
                        if i_bootstrap_reset_n = '1' and i_X_A = ADDR_VEC1 then
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
                    when others =>
                        if rst_n = '0' then
                            state <= DBG_00;
                        end if;
                end case;
                -- Check writes at the start of the write cycle
                test_write := cmd_write1 and not cmd_write2;
                cmd_write2 := cmd_write1;
                if i_X_nCS = '0' and i_X_A_stb = '1' and i_X_nWE_long = '0' then
                    cmd_write1 := '1';
                elsif i_sdram_busy = '0' then
                    cmd_write1 := '0';
                end if;
                -- Check reads at the end of the read cycle
                test_read  := not cmd_read1 and cmd_read2;
                cmd_read2  := cmd_read1;
                if i_X_nCS = '0' and i_X_A_stb = '1' and i_X_nOE = '0' then
                    cmd_read1 := '1';
                elsif i_sdram_data_ready = '1' then
                    cmd_read1 := '0';
                end if;
            end if;
        end process;

        led <= state(5 downto 0)  xor "111111";

    end generate;

    not_mon : if not IncludeMonitor generate

        led <= "111111";

    end generate;

end rtl;
