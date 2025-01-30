library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity iir_filter is
    generic (
        W_IO        : integer := 18; -- Width of external data inputs/outputs
        W_DAT       : integer := 25; -- Width of internal data data nodes, giving headroom for filter gain
        W_SUM       : integer := 48; -- Width of internal summers
        W_COEFF     : integer := 18; -- Width of coefficients -- This needs to match the multipier width
        W_FRAC      : integer := 16  -- Width of fractional part of coefficients
        );
    port (
        clk         : in  std_logic;
        load        : in  std_logic;
        lin         : in  std_logic_vector(W_IO - 1 downto 0);
        lout        : out std_logic_vector(W_IO - 1 downto 0);
        rin         : in  std_logic_vector(W_IO - 1 downto 0);
        rout        : out std_logic_vector(W_IO - 1 downto 0)
       );
end iir_filter;

architecture Behavioral of iir_filter is

    signal state : unsigned(6 downto 0) := (others => '0');

    signal lin0  : signed(W_DAT - 1 downto 0) := (others => '0');
    signal lin1  : signed(W_DAT - 1 downto 0) := (others => '0');
    signal lin2  : signed(W_DAT - 1 downto 0) := (others => '0');
    signal ltmp0 : signed(W_DAT - 1 downto 0) := (others => '0');
    signal ltmp1 : signed(W_DAT - 1 downto 0) := (others => '0');
    signal ltmp2 : signed(W_DAT - 1 downto 0) := (others => '0');
    signal lout0 : signed(W_DAT - 1 downto 0) := (others => '0');
    signal lout1 : signed(W_DAT - 1 downto 0) := (others => '0');
    signal lout2 : signed(W_DAT - 1 downto 0) := (others => '0');
    signal rin0  : signed(W_DAT - 1 downto 0) := (others => '0');
    signal rin1  : signed(W_DAT - 1 downto 0) := (others => '0');
    signal rin2  : signed(W_DAT - 1 downto 0) := (others => '0');
    signal rtmp0 : signed(W_DAT - 1 downto 0) := (others => '0');
    signal rtmp1 : signed(W_DAT - 1 downto 0) := (others => '0');
    signal rtmp2 : signed(W_DAT - 1 downto 0) := (others => '0');
    signal rout0 : signed(W_DAT - 1 downto 0) := (others => '0');
    signal rout1 : signed(W_DAT - 1 downto 0) := (others => '0');
    signal rout2 : signed(W_DAT - 1 downto 0) := (others => '0');

    signal multa : signed(W_COEFF - 1 downto 0);
    signal multb : signed(W_DAT - 1 downto 0);
    signal multbx : signed(W_COEFF - 1 downto 0);
    signal multout : signed(W_COEFF + W_COEFF - 1 downto 0);
    signal multoutx : signed(W_COEFF + W_DAT - 1 downto 0);
    signal sum : signed(W_SUM - 1 downto 0);
    signal sum_shifted : signed(W_SUM - W_FRAC - 1 downto 0);
    signal sum_saturated : signed(W_DAT - 1 downto 0);

    constant MAX_NEG : signed(W_DAT - 1 downto 0) := ('1', others => '0');
    constant MAX_POS : signed(W_DAT - 1 downto 0) := ('0', others => '1');

    constant SUM_ZERO : signed(W_SUM - 1 downto 0) := (others => '0');

    -- http://jaggedplanet.com/iir/iir-explorer.asp
    --
    -- Butterworth, Low-pass, Order 3, Sample rate 46875, Cutoff 3214
    --
    -- REAL biquada[]={0.6545294918791053,-1.503352371060256,-0.640959826975052};
    -- REAL biquadb[]={1,2,1};
    -- REAL gain=147.38757472209932;
    -- REAL xyv[]={0,0,0,0,0,0,0,0,0};
    --
    -- REAL applyfilter(REAL v)
    -- {
    --   int i,b,xp=0,yp=3,bqp=0;
    --   REAL out=v/gain;
    --   for (i=8; i>0; i--) {xyv[i]=xyv[i-1];}
    --   for (b=0; b<NBQ; b++)
    --   {
    --     int len=(b==NBQ-1)?1:2;
    --     xyv[xp]=out;
    --     for(i=0; i<len; i++) { out+=xyv[xp+len-i]*biquadb[bqp+i]-xyv[yp+len-i]*biquada[bqp+i]; }
    --     bqp+=len;
    --     xyv[yp]=out;
    --     xp=yp; yp+=len+1;
    --   }
    --   return out;
    -- }
    --                 b12                 b11                b21
    -- REAL biquadb[]={1,                  2,                 1};
    -- REAL biquada[]={0.6545294918791053,-1.503352371060256,-0.640959826975052};
    --                 a12                 a11                a21
    --
    -- Note, the sign of axx coefficients needs flipping, as our
    -- implementation adds rather than subtracts these
    --
    -- BiQuad 1: 2nd Order b10=1 b11=2 b12=1 a11=1.503352371060256 a12=-0.6545294918791053
    -- BiQuad 2: 1st Order b20=1 b21=1 b22=0 a21=0.640959826975052 a12=0
    --
    -- Gain is 147.38757472209932 which is taken account of currently
    -- because W_DAT - W_IO = 7, so the final output is attenuated by 128.

    constant gain : real := 147.38757472209932 / 128.0;

    constant b10 : signed(W_COEFF - 1 downto 0) := to_signed(integer( 1.0 / gain         * (2.0 ** W_FRAC)), W_COEFF);
    constant b11 : signed(W_COEFF - 1 downto 0) := to_signed(integer( 2.0 / gain         * (2.0 ** W_FRAC)), W_COEFF);
    constant b12 : signed(W_COEFF - 1 downto 0) := to_signed(integer( 1.0 / gain         * (2.0 ** W_FRAC)), W_COEFF);
    constant a11 : signed(W_COEFF - 1 downto 0) := to_signed(integer( 1.503352371060256  * (2.0 ** W_FRAC)), W_COEFF);
    constant a12 : signed(W_COEFF - 1 downto 0) := to_signed(integer(-0.6545294918791053 * (2.0 ** W_FRAC)), W_COEFF);

    constant b20 : signed(W_COEFF - 1 downto 0) := to_signed(integer( 1.0                * (2.0 ** W_FRAC)), W_COEFF);
    constant b21 : signed(W_COEFF - 1 downto 0) := to_signed(integer( 1.0                * (2.0 ** W_FRAC)), W_COEFF);
    constant b22 : signed(W_COEFF - 1 downto 0) := to_signed(integer( 0.0                * (2.0 ** W_FRAC)), W_COEFF);
    constant a21 : signed(W_COEFF - 1 downto 0) := to_signed(integer( 0.640959826975052  * (2.0 ** W_FRAC)), W_COEFF);
    constant a22 : signed(W_COEFF - 1 downto 0) := to_signed(integer( 0.0                * (2.0 ** W_FRAC)), W_COEFF);

    --
    -- The IIT Filter pipeline runs at 6MHz and a 2-channel sample
    -- needs to be processed every 128 cycles (46.875KHz)
    --
    -- The state machine that coordinates this is basically a counter.
    --
    -- State 00->0F - Execute BiQuad 1 on the L channel (lin0  => ltmp0)
    -- State 10->1F - Execute BiQuad 2 on the L channel (ltmp0 => lout0)
    -- State 20->2F - Execute BiQuad 1 on the R channel (rin0  => rtmp0)
    -- State 30->3F - Execute BiQuad 2 on the R channel (rtmp0 => rout0)
    -- State 40->7F - Spare

    -- Each BiQuad needs to perform five coeff (W_COEFF=18) x data
    -- (W_DATA=25) multiplies.
    --
    -- Earlier versions of this design used two DSP48A1 cores; this
    -- version uses only one, as the multiply is decomposed into:
    --   LSB: coeff [signed] * data(  N-1 downto 0) [unsigned]
    --   MSB: coeff [signed] * data(W_DAT downto N)   [signed]
    -- so that a single DSP48A1 multiplier can be used.
    --
    -- N = W_DAT - W_COEFF = 7 (currently)
    --
    -- The pipeline operates as follows:
    --
    --      multa   multb   multout          sum
    -- 00 - 0       0       0                 + 0
    -- 01 - 0       0       0                 + 0
    -- 02 - 0       0       0                 + 0
    -- 03 - b12     lin2    0                 + 0
    -- 04 - b12     lin2    b12 * lsb(lin2)   + 0
    -- 05 - b11     lin1    b12 * msb(lin2)   = b12 * lsb(lin2)
    -- 06 - b11     lin1    b11 * lsb(lin1)   + b12 * msb(lin2) << N
    -- 07 - b10     lin0    b11 * msb(lin1)   + b11 * lsb(lin1)
    -- 08 - b10     lin0    b10 * lsb(lin0)   + b11 * msb(lin1) << N
    -- 09 - a12     ltmp2   b10 * msb(lin0)   + b10 * lsb(lin0)
    -- 0A - a12     ltmp2   a12 * lsb(ltmp2)  + b10 * msb(lin0) << N
    -- 0B - a11     ltmp1   a12 * msb(ltmp2)  + a12 * lsb(ltmp2)
    -- 0C - a11     ltmp1   a11 * lsb(ltmp1)  + a12 * msb(ltmp1) << N
    -- 0D - 0       0       a11 * msb(ltmp1)  + a11 * lsb(ltmp1)
    -- 0E - 0       0       0                 + a11 * msb(ltmp1) << N
    -- 0F - 0       0       0                 ===> ltmp0
    -- 10 - 0       0       0                 + 0
    -- 11 - 0       0       0                 + 0
    -- 12 - 0       0       0                 + 0
    -- 13 - b22     ltmp2   0                 + 0
    -- 14 - b22     ltmp2   b22 * lsb(ltmp2)  + 0
    -- 15 - b21     ltmp1   b22 * msb(ltmp2)  = b22 * lsb(ltmp2)
    -- 16 - b21     ltmp1   b21 * lsb(ltmp1)  + b22 * msb(ltmp2) << N
    -- 17 - b20     ltmp0   b21 * msb(ltmp1)  + b21 * lsb(ltmp1)
    -- 18 - b20     ltmp0   b20 * lsb(ltmp0)  + b21 * msb(ltmp1) << N
    -- 19 - a22     lout2   b20 * msb(ltmp0)  + b20 * lsb(ltmp0)
    -- 1A - a22     lout2   a22 * lsb(lout2)  + b20 * msb(ltmp0) << N
    -- 1B - a21     lout1   a22 * msb(lout2)  + a22 * lsb(lout2)
    -- 1C - a21     lout1   a21 * lsb(lout1)  + a22 * msb(lout1) << N
    -- 1D - 0       0       a21 * msb(lout1)  + a21 * lsb(lout1)
    -- 1E - 0       0       0                 + a21 * msb(lout1) << N
    -- 1F - 0       0       0                 ===> lout0
    -- 20 - 0       0       0                 + 0
    -- 21 - 0       0       0                 + 0
    -- 22 - 0       0       0                 + 0
    -- 23 - b12     rin2    0                 + 0
    -- 24 - b12     rin2    b12 * lsb(rin2)   + 0
    -- 25 - b11     rin1    b12 * msb(rin2)   = b12 * lsb(rin2)
    -- 26 - b11     rin1    b11 * lsb(rin1)   + b12 * msb(rin2) << N
    -- 27 - b10     rin0    b11 * msb(rin1)   + b11 * lsb(rin1)
    -- 28 - b10     rin0    b10 * lsb(rin0)   + b11 * msb(rin1) << N
    -- 29 - a12     rtmp2   b10 * msb(rin0)   + b10 * lsb(rin0)
    -- 2A - a12     rtmp2   a12 * lsb(rtmp2)  + b10 * msb(rin0) << N
    -- 2B - a11     rtmp1   a12 * msb(rtmp2)  + a12 * lsb(rtmp2)
    -- 2C - a11     rtmp1   a11 * lsb(rtmp1)  + a12 * msb(rtmp1) << N
    -- 2D - 0       0       a11 * msb(rtmp1)  + a11 * lsb(rtmp1)
    -- 2E - 0       0       0                 + a11 * msb(rtmp1) << N
    -- 2F - 0       0       0                 ===> rtmp0
    -- 30 - 0       0       0                 + 0
    -- 31 - 0       0       0                 + 0
    -- 32 - 0       0       0                 + 0
    -- 33 - b22     rtmp2   0                 + 0
    -- 34 - b22     rtmp2   b22 * lsb(rtmp2)  + 0
    -- 35 - b21     rtmp1   b22 * msb(rtmp2)  = b22 * lsb(rtmp2)
    -- 36 - b21     rtmp1   b21 * lsb(rtmp1)  + b22 * msb(rtmp2) << N
    -- 37 - b20     rtmp0   b21 * msb(rtmp1)  + b21 * lsb(rtmp1)
    -- 38 - b20     rtmp0   b20 * lsb(rtmp0)  + b21 * msb(rtmp1) << N
    -- 39 - a22     rout2   b20 * msb(rtmp0)  + b20 * lsb(rtmp0)
    -- 3A - a22     rout2   a22 * lsb(rout2)  + b20 * msb(rtmp0) << N
    -- 3B - a21     rout1   a22 * msb(rout2)  + a22 * lsb(rout2)
    -- 3C - a21     rout1   a21 * lsb(rout1)  + a22 * msb(rout1) << N
    -- 3D - 0       0       a21 * msb(rout1)  + a21 * lsb(rout1)
    -- 3E - 0       0       0                 + a21 * msb(rout1) << N
    -- 3F - 0       0       0                 ===> rout0
    --
    -- Future enhancements:
    --
    -- 1. Currently W_COEFF needs to be 18, i.e. the same size as the
    -- DSP48A1 multiplier. Might be better to introduce W_MUL, and allow
    -- W_COEFF to be smaller. That's mostly just cosmetic
    --
    -- 2. It might be possible to use a small RAM to store the state
    -- variables (lin0..2, ltmp0..2, lout0..2, etc). There are 18 of
    -- these. It would take multiple cycles to shift these, assuming
    -- the RAM is single ported. But there is 32 cycles spare.
    --

begin

    sum_shifted <= sum(W_SUM - 1 downto W_FRAC);

    sum_saturated <= MAX_POS when sum_shifted > MAX_POS else
                     MAX_NEG when sum_shifted < MAX_NEG else
                     sum_shifted(W_DAT - 1 downto 0);

    multbx <= multb(W_DAT - 1 downto W_DAT - W_COEFF) when state(0) = '0' else -- MSB
              resize('0' & multb(W_DAT - W_COEFF - 1 downto 0), W_COEFF);      -- LSB

    multoutx <= resize(multout, W_DAT + W_COEFF) when state(0) = '0' else      -- LSB
                (multout & resize("0", W_DAT - W_COEFF));                      -- MSB

    process(clk)
    begin
        if rising_edge(clk) then

            multout <= multa * multbx;

            if state(3 downto 0) = "0100" then
                sum <= SUM_ZERO + multoutx; -- load
            else
                sum <= sum + multoutx; -- accumulate
            end if;

            -- Load / shift registers once per sample period
            if load = '1' then
                lin0  <= resize(signed(lin), W_DAT);
                lin1  <= lin0;
                lin2  <= lin1;
                ltmp1 <= ltmp0;
                ltmp2 <= ltmp1;
                lout1 <= lout0;
                lout2 <= lout1;
                rin0  <= resize(signed(rin), W_DAT);
                rin1  <= rin0;
                rin2  <= rin1;
                rtmp1 <= rtmp0;
                rtmp2 <= rtmp1;
                rout1 <= rout0;
                rout2 <= rout1;
            end if;

            -- Muliplier A input (coefficient)
            case state(4 downto 1) is
                when "0001" =>
                    multa <= b12;
                when "0010" =>
                    multa <= b11;
                when "0011" =>
                    multa <= b10;
                when "0100" =>
                    multa <= a12;
                when "0101" =>
                    multa <= a11;
                when "1001" =>
                    multa <= b22;
                when "1010" =>
                    multa <= b21;
                when "1011" =>
                    multa <= b20;
                when "1100" =>
                    multa <= a22;
                when "1101" =>
                    multa <= a21;
                when others =>
                    multa <= (others => '0');
            end case;

            -- Muliplier B input (coefficient)
            case state(6 downto 1) is
                when "000001" =>
                    multb <= lin2;
                when "000010" =>
                    multb <= lin1;
                when "000011" =>
                    multb <= lin0;
                when "000100" =>
                    multb <= ltmp2;
                when "000101" =>
                    multb <= ltmp1;
                when "001001" =>
                    multb <= ltmp2;
                when "001010" =>
                    multb <= ltmp1;
                when "001011" =>
                    multb <= ltmp0;
                when "001100" =>
                    multb <= lout2;
                when "001101" =>
                    multb <= lout1;
                when "010001" =>
                    multb <= rin2;
                when "010010" =>
                    multb <= rin1;
                when "010011" =>
                    multb <= rin0;
                when "010100" =>
                    multb <= rtmp2;
                when "010101" =>
                    multb <= rtmp1;
                when "011001" =>
                    multb <= rtmp2;
                when "011010" =>
                    multb <= rtmp1;
                when "011011" =>
                    multb <= rtmp0;
                when "011100" =>
                    multb <= rout2;
                when "011101" =>
                    multb <= rout1;
                when others =>
                    multb <= (others => '0');
            end case;

            if state = "0001110" then
                ltmp0 <= sum_saturated(W_DAT - 1 downto 0);
            end if;

            if state = "0011110" then
                lout0 <= sum_saturated(W_DAT - 1 downto 0);
            end if;

            if state = "0101110" then
                rtmp0 <= sum_saturated(W_DAT - 1 downto 0);
            end if;

            if state = "0111110" then
                rout0 <= sum_saturated(W_DAT - 1 downto 0);
            end if;

            if state = "0111111" then
                lout <= std_logic_vector(lout0(W_DAT - 1 downto W_DAT - W_IO));
                rout <= std_logic_vector(rout0(W_DAT - 1 downto W_DAT - W_IO));
            end if;

            if state = "0000000" then
                if load = '1' then
                    state <= "0000001";
                end if;
            elsif state < "0111111" then
                state <= state + 1;
            else
                state <= "0000000";
            end if;

        end if;
    end process;

end Behavioral;
