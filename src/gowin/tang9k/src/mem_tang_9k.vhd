library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.psram_pack.all;

-- Generic top-level entity for Altera DE1 board
entity mem_tang_9k is
generic (
      PRJ_ROOT : string
   );
port(
   CLK_96         : in  std_logic;
   CLK_96_P    : in  std_logic;
   CLK_48         : in  std_logic;
   rst_n       : in  std_logic;

   READY       : out std_logic;

   ext_A           : in    std_logic_vector (18 downto 0);
   ext_Din         : in    std_logic_vector (7 downto 0);
   ext_Dout        : out   std_logic_vector (7 downto 0);
   ext_nCS         : in    std_logic;
   ext_nWE         : in    std_logic;
   ext_nOE         : in    std_logic;

   O_psram_ck     : out    std_logic_vector(1 downto 0);
   IO_psram_rwds  : inout  std_logic_vector(1 downto 0);
   IO_psram_dq    : inout  std_logic_vector(15 downto 0);
   O_psram_cs_n   : out    std_logic_vector(1 downto 0);
    O_psram_reset_n  : out    std_logic_vector(1 downto 0)
   
);
end mem_tang_9k;

architecture rtl of mem_tang_9k is

   type mem_mos_t is array(0 to 16383) of std_logic_vector(7 downto 0);

   impure function MEM_INIT_FILE(file_name:STRING) return mem_mos_t is
   FILE infile : text is in file_name;
   variable arr : mem_mos_t := (others => (others => '0'));
   variable inl : line;
   variable count : integer;
   begin
      count := 0;
      while not(endfile(infile)) and count < 16384 loop
         readline(infile, inl);
         read(inl, arr(count));
         count := count + 1;
      end loop;

      return arr;
   end function;

   signal r_mem_rom : mem_mos_t := MEM_INIT_FILE(PRJ_ROOT & "/roms/bbcb/os12.bit");

   type mem_ram_t is array(0 to 16383) of std_logic_vector(7 downto 0);

   signal r_mem_ram : mem_ram_t;

   signal i_psram_cmd_read    : std_logic;
   signal i_psram_cmd_write   : std_logic;
   signal i_psram_addr        : std_logic_vector(21 downto 0);
   signal i_psram_din         : std_logic_vector(15 downto 0);
   signal i_psram_dout        : std_logic_vector(15 downto 0);
   signal i_psram_busy        : std_logic;
begin

   e_psram:PsramController
   generic map (
      FREQ => 96000000,
      LATENCY => 4
   )
   port map (
      clk         => CLK_96,
      clk_p       => CLK_96_P,
      resetn      => rst_n,
      read        => i_psram_cmd_read,
      write       => i_psram_cmd_write,
      addr        => i_psram_addr,
      din         => i_psram_din,
      byte_write  => '1',                                                   
      dout        => i_psram_dout,
      busy        => i_psram_busy,

      O_psram_ck     => O_psram_ck,
      IO_psram_rwds  => IO_psram_rwds,
      IO_psram_dq    => IO_psram_dq,
      O_psram_cs_n   => O_psram_cs_n

   );

   p_reset:process(CLK_96, rst_n)
   begin
      if rst_n = '0' then
         READY <= '0';        
      elsif rising_edge(CLK_96) then
         if i_psram_busy = '0' then
            READY <= '1';
         end if;
      end if;
   end process;

   p_ram_rd:process(CLK_48)
   begin
      if rising_edge(CLK_48) then
         if ext_A(18) = '0' then
            ext_Dout <= r_mem_rom(to_integer(unsigned(ext_A(13 downto 0))));
         else
            ext_Dout <= r_mem_ram(to_integer(unsigned(ext_A(13 downto 0))));
         end if;
      end if;
   end process;
   
   p_wr:process(CLK_48)
   begin
      if rising_edge(CLK_48) then
         if ext_nCS = '0' and ext_nWE = '0' then
            if ext_A(18) = '1' then
               r_mem_ram(to_integer(unsigned(ext_A(13 downto 0)))) <= ext_Din;
            end if;
         end if;
      end if;

   end process;


end rtl;


