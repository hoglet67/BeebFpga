----------------------------------------------------------------------------------
-- Engineer: Mike Field <hamster@snap.net.nz>
--
-- Module Name:    serialiser - Behavioral
-- Description:
--
-- Converts a sample to S/PDIF format and send it out on the wire
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity spdif_serializer is
    Port (
        clk          : in  std_logic;
        clken        : in  std_logic := '1';
        auxAudioBits : in  std_logic_vector (3 downto 0);
        sample       : in  std_logic_vector (19 downto 0);
        load         : in  std_logic;
        channelA     : out std_logic;
        spdifOut     : out std_logic);
end spdif_serializer;

architecture Behavioral of spdif_serializer is

    signal bits            : std_logic_vector(63 downto 0) := (others => '0');
    signal current         : std_logic := '0';
    signal preamble        : std_logic_vector (7 downto 0);
    signal sample2         : std_logic_vector (19 downto 0);
    signal subframeCount   : std_logic_vector (7 downto 0) := "00000000";
    signal parity          : std_logic;

    constant subcode       : std_logic := '0'; -- Remember to change process sensitibity list
    constant channelStatus : std_logic := '0'; -- Remember to change process sensitibity list
    constant validity      : std_logic := '0'; -- Remember to change process sensitibity list

begin
    sample2     <= sample(19 downto 0);
    spdifOut    <= current;
    channelA    <= not subFrameCount(0);

    parity <= auxAudioBits(3) xor auxAudioBits(2) xor auxAudioBits(1)  xor auxAudioBits(0) xor
              sample2(19)     xor sample2(18)     xor sample2(17)      xor sample2(16)      xor
              sample2(15)     xor sample2(14)     xor sample2(13)      xor sample2(12)      xor
              sample2(11)     xor sample2(10)     xor sample2(9)       xor sample2(8)       xor
              sample2(7)      xor sample2(6)      xor sample2(5)       xor sample2(4)       xor
              sample2(3)      xor sample2(2)      xor sample2(1)       xor sample2(0)       xor
              subcode         xor validity        xor channelStatus    xor '0';

    process (subFrameCount)
    begin
        if subframeCount = "00000000" then
            preamble <= "00111001"; -- M preamble
        else
            if subframeCount(0) = '0' then
                preamble <= "11001001"; -- Y preamble
            else
                preamble <= "01101001"; -- Z preamble
            end if;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if clken = '1' then
                if load = '1' then
                    bits <= parity           & "1" & channelStatus    & "1" & subcode          & "1" & validity         & "1" &
                            sample2(19)      & "1" & sample2(18)      & "1" & sample2(17)      & "1" & sample2(16)      & "1" &
                            sample2(15)      & "1" & sample2(14)      & "1" & sample2(13)      & "1" & sample2(12)      & "1" &
                            sample2(11)      & "1" & sample2(10)      & "1" & sample2( 9)      & "1" & sample2( 8)      & "1" &
                            sample2( 7)      & "1" & sample2( 6)      & "1" & sample2( 5)      & "1" & sample2( 4)      & "1" &
                            sample2( 3)      & "1" & sample2( 2)      & "1" & sample2( 1)      & "1" & sample2( 0)      & "1" &
                            auxAudioBits(3)  & "1" & auxAudioBits(2)  & "1" & auxAudioBits(1)  & "1" & auxAudioBits(0)  & "1" &
                            preamble;

                    if subframeCount = 191 then
                        subFrameCount <= (others => '0');
                    else
                        subFrameCount <= subFrameCount +1;
                    end if;
                else
                    bits <= "0" & bits(63 downto 1);
                end if;
                current <= current xor bits(0) xor '0';
            end if;
        end if;
    end process;
end Behavioral;
