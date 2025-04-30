
library ieee; 
use ieee.std_logic_1164.all;

entity g_lfsr is 
generic(
   G_M             : integer           := 7;
   G_POLY          : std_logic_vector  := "1100000"; -- x^7+x^6+1 
   G_SEED          : std_logic_vector  := "1010101"
   );
port (
   clk_i          : in  std_logic;
   clken_i        : in  std_logic;
   srst_i         : in  std_logic;
   bit_o          : out std_logic
);
end g_lfsr;

architecture rtl of g_lfsr is  
   signal r_lfsr           : std_logic_vector (G_M-1 downto 0) := G_SEED;
   signal w_mask           : std_logic_vector (G_M-1 downto 0);
begin  
   bit_o  <= r_lfsr(0);
   
   g_mask:for K in G_M-1 downto 0 generate
      w_mask(k)  <= G_POLY(K) and r_lfsr(0);
   end generate g_mask;
   
   p_lfsr:process (clk_i) begin 
      if rising_edge(clk_i) then 
         if srst_i = '1' then
            r_lfsr <= G_SEED;
         elsif clken_i = '1' then 
            r_lfsr <= ('0' & r_lfsr(G_M-1 downto 1)) xor w_mask;
         end if; 
      end if; 
   end process; 
end architecture rtl;