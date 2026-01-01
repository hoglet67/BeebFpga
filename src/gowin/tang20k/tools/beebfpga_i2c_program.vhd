library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity beebfpga_i2c_program is
   Port ( clk     : in    STD_LOGIC;
          data    : out std_logic_vector(8 downto 0);
          address : in std_logic_vector(9 downto 0)
         );
end beebfpga_i2c_program;
architecture Behavioral of beebfpga_i2c_program is
begin
   process(clk)
   begin
      if rising_edge(clk) then
         case address is
           when "0000000000" => data <= "110010000";
           when "0000000001" => data <= "100000001";
           when "0000000010" => data <= "111000101";
           when "0000000011" => data <= "111100011";
           when "0000000100" => data <= "011111111";
           when "0000000101" => data <= "011101010";
           when "0000000110" => data <= "110010000";
           when "0000000111" => data <= "100000000";
           when "0000001000" => data <= "011111111";
           when "0000001001" => data <= "110010001";
           when "0000001010" => data <= "011000100";
           when "0000001011" => data <= "011000000";
           when "0000001100" => data <= "011111111";
           when "0000001101" => data <= "110010000";
           when "0000001110" => data <= "100000001";
           when "0000001111" => data <= "111010101";
           when "0000010000" => data <= "111100011";
           when "0000010001" => data <= "011111111";
           when "0000010010" => data <= "011101010";
           when "0000010011" => data <= "110010000";
           when "0000010100" => data <= "100000000";
           when "0000010101" => data <= "011111111";
           when "0000010110" => data <= "110010001";
           when "0000010111" => data <= "011000100";
           when "0000011000" => data <= "011000001";
           when "0000011001" => data <= "011111111";
           when "0000011010" => data <= "110010000";
           when "0000011011" => data <= "100000001";
           when "0000011100" => data <= "111100101";
           when "0000011101" => data <= "111100011";
           when "0000011110" => data <= "011111111";
           when "0000011111" => data <= "011101010";
           when "0000100000" => data <= "110010000";
           when "0000100001" => data <= "100000000";
           when "0000100010" => data <= "011111111";
           when "0000100011" => data <= "110010001";
           when "0000100100" => data <= "011000100";
           when "0000100101" => data <= "011000010";
           when "0000100110" => data <= "011111111";
           when "0000100111" => data <= "110010000";
           when "0000101000" => data <= "100000001";
           when "0000101001" => data <= "111110101";
           when "0000101010" => data <= "111100011";
           when "0000101011" => data <= "011111111";
           when "0000101100" => data <= "011101010";
           when "0000101101" => data <= "110010000";
           when "0000101110" => data <= "100000000";
           when "0000101111" => data <= "011111111";
           when "0000110000" => data <= "110010001";
           when "0000110001" => data <= "011000100";
           when "0000110010" => data <= "011000011";
           when "0000110011" => data <= "011111111";
           when "0000110100" => data <= "010110000";
           when "0000110101" => data <= "010100000";
           when "0000110110" => data <= "000000000";
           when others => data <= (others =>'0');
        end case;
     end if;
   end process;
end Behavioral;
