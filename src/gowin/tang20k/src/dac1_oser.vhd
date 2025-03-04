library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dac1_oser is
    port (
        rst_i             : in     std_logic;
        clk_sample_i      : in     std_logic; -- 27 MHz
        clk_dac_px_i      : in     std_logic; -- 40.5 MHz
        clk_dac_i         : in     std_logic; -- 405 MHz
        sample_i          : in     unsigned(3 downto 0);
        bitstream_o       : out    std_logic
   );
end dac1_oser;

architecture rtl of dac1_oser is

   COMPONENT OSER10
      GENERIC (GSREN:string:="false";
         LSREN:string:="true"
      );
      PORT(
         Q:OUT std_logic;
         D0:IN std_logic;
         D1:IN std_logic;
         D2:IN std_logic;
         D3:IN std_logic;
         D4:IN std_logic;
         D5:IN std_logic;
         D6:IN std_logic;
         D7:IN std_logic;
         D8:IN std_logic;
         D9:IN std_logic;
         FCLK:IN std_logic;
         PCLK:IN std_logic;
         RESET:IN std_logic
      );
   END COMPONENT;

   function PAT(i:unsigned) return std_logic_vector is
       variable R : std_logic_vector(14 downto 0);
   begin
       case to_integer(i) is
           when  1 => R := "000000010000000";
           when  2 => R := "000000011000000";
           when  3 => R := "000000111000000";
           when  4 => R := "000000111100000";
           when  5 => R := "000001111100000";
           when  6 => R := "000001111110000";
           when  7 => R := "000011111110000";
           when  8 => R := "000011111111000";
           when  9 => R := "000111111111000";
           when 10 => R := "000111111111100";
           when 11 => R := "001111111111100";
           when 12 => R := "001111111111110";
           when 13 => R := "011111111111110";
           when 14 => R := "011111111111111";
           when 15 => R := "111111111111111";
           when others => R := "000000000000000";
      end case;
      return R;
   end function;

   signal r_pat0      : std_logic_vector(9 downto 0);
   signal r_pat1      : std_logic_vector(9 downto 0);
   signal r_pat2      : std_logic_vector(9 downto 0);
   signal r_pat       : std_logic_vector(9 downto 0);
   signal r_pattern   : std_logic_vector(14 downto 0);
   signal count       : unsigned(1 downto 0);

begin

    -- 27MHz input samples, calculate 15-bit pattern
    process(clk_sample_i)
    begin
        if rising_edge(clk_sample_i) then
            r_pattern <= PAT(sample_i);
        end if;
    end process;

    -- 81MHz split pattern into 3x 10-bit output samples
    process(clk_dac_px_i)
    begin
        if rising_edge(clk_dac_px_i) then
            if count = 2 then
                r_pat0 <= r_pattern(9 downto 0);
                r_pat1 <= r_pattern(4 downto 0) & r_pattern(14 downto 10);
                r_pat2 <= r_pattern(14 downto 5);
                count <= (others => '0');
            else
                count <= count + 1;
            end if;
            case to_integer(count) is
                when 1      => r_pat <= r_pat1;
                when 2      => r_pat <= r_pat2;
                when others => r_pat <= r_pat0;
            end case;
        end if;
    end process;

    -- 405MHz serial
    e_ser10:OSER10
        GENERIC MAP (
            GSREN=>"false",
            LSREN=>"true"
            )
        PORT MAP (
            Q     => bitstream_o,
            D0    => r_pat(0),
            D1    => r_pat(1),
            D2    => r_pat(2),
            D3    => r_pat(3),
            D4    => r_pat(4),
            D5    => r_pat(5),
            D6    => r_pat(6),
            D7    => r_pat(7),
            D8    => r_pat(8),
            D9    => r_pat(9),
            FCLK  => clk_dac_i,
            PCLK  => clk_dac_px_i,
            RESET => '0'
            );

end rtl;
