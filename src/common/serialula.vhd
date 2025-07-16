library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity serialula is
    generic (
        -- Board revision 1 or 2, affects the CasOut logic
        BOARD_REV      : integer := 1;

        -- If both are true, the mode is determined by the jumper at run time
        MODEL_VLSI     : boolean := true;
        MODEL_FERRANTI : boolean := false
    );
    port (
        -- Fast clock (16/13 MHz)
        clk      : in  std_logic;
        clken    : in  std_logic := '1';

        -- Mode Jumper (used to enable VLSI_SERPROC mode)
        jp1      : in  std_logic := '0';  -- off/1=Ferranti on/0=VLSI

        -- Interface to 6502
        E        : in  std_logic;
        Data     : in  std_logic_vector(7 downto 0);
        nCS      : in  std_logic;

        -- Interface to Cassette Port
        CasMotor : out std_logic;
        CasIn    : in  std_logic;
        CasOut   : out std_logic_vector(1 downto 0);

        -- Interface to ACIA
        TxC      : out std_logic;
        TxD      : in  std_logic;
        RxC      : out std_logic;
        RxD      : out std_logic;
        DCD      : out std_logic;
        RTSI     : in  std_logic;
        CTSO     : out std_logic;

        -- Interface to RS423 Port
        Din      : in  std_logic;
        Dout     : out std_logic;
        CTSI     : in  std_logic;
        RTSO     : out std_logic
        );
end serialula;

architecture RTL of serialula is

    constant HIGH_TONE_THRESHOLD_VLSI     : integer := 445;

    constant HIGH_TONE_THRESHOLD_FERRANTI : integer := 962;

    function HIGH_TONE_BITS return integer is
    begin
        if MODEL_FERRANTI then
            return 10;
        else
            return 9;
        end if;
    end function;

    function HIGH_TONE_MAX return unsigned is
    begin
        if MODEL_FERRANTI then
            return "1111111111";
        else
            return "111111111";
        end if;
    end function;

    signal vlsi_mode            : std_logic;
    signal control              : std_logic_vector(7 downto 0);
    signal ctrl_tx_baud         : std_logic_vector(2 downto 0);
    signal ctrl_rx_baud         : std_logic_vector(2 downto 0);
    signal ctrl_reverse_tones   : std_logic;
    signal ctrl_rs423_sel       : std_logic;
    signal ctrl_motor_on        : std_logic;
    signal clk_divider          : unsigned(9 downto 0);
    signal tx_clk               : std_logic;
    signal rx_clk               : std_logic;
    signal sine_in              : unsigned(2 downto 0);
    signal burst_counter        : unsigned(2 downto 0);
    signal high_tone_counter    : unsigned(HIGH_TONE_BITS-1 downto 0);
    signal high_tone_threshold  : unsigned(HIGH_TONE_BITS-1 downto 0);
    signal high_tone_detect     : std_logic;
    signal txd_s                : std_logic;
    signal enable_s             : std_logic;
    signal cas_clk_recovered    : std_logic;
    signal cas_din_recovered    : std_logic;
    signal cas_din_synchronized : std_logic;
    signal cas_din_filtered     : std_logic;
    signal cas_din_edge         : std_logic;
    signal filter_counter       : unsigned(1 downto 0);
    signal bit_counter          : unsigned(7 downto 0);
    signal burst0               : std_logic;
    signal burst1               : std_logic;
    signal is_long              : std_logic;
    signal is_long_last         : std_logic;

begin

    vlsi_mode <= (not jp1) when MODEL_VLSI and MODEL_FERRANTI else
                 '1'       when MODEL_VLSI else
                 '0';

    -- =================================================
    -- Control reguster
    -- =================================================

    -- Update the control register on the falling edge of the 2MHz clock
    -- Note: reads do seem to corrupt this register

    process(E)
    begin
        if falling_edge(E) then
            if nCS = '0' then
                control <= Data;
            end if;
        end if;
    end process;

    ctrl_tx_baud       <= control(2 downto 0);
    ctrl_rx_baud       <= control(5 downto 3);
    ctrl_reverse_tones <= control(3) and vlsi_mode;
    ctrl_rs423_sel     <= control(6);
    ctrl_motor_on      <= control(7);

    -- =================================================
    -- Master clock divider
    -- =================================================

    process(clk)
    begin
        if rising_edge(clk) then
            if clken = '1' then
                clk_divider <= clk_divider + 1;
            end if;
        end if;
    end process;

    -- =================================================
    -- Transmit baud rate generator
    -- =================================================

    process(ctrl_tx_baud, clken, clk_divider)
    begin
        case (ctrl_tx_baud) is
            when "000" =>
                -- 19200 baud
                tx_clk <= clken; -- this is a bit ugly, but acia doesn't care about duty cycle
            when "100" =>
                --  9600 baud
                tx_clk <= clk_divider(0);
            when "010" =>
                --  4800 baud
                tx_clk <= clk_divider(1);
            when "110" =>
                --  2400 baud
                tx_clk <= clk_divider(2);
            when "001" =>
                --  1200 baud
                tx_clk <= clk_divider(3);
            when "101" =>
                --   300 baud
                tx_clk <= clk_divider(5);
            when "011" =>
                --   150 baud
                tx_clk <= clk_divider(6);
            when "111" =>
                --    75 baud
                tx_clk <= clk_divider(7);
            when others =>
                null;
        end case;
    end process;


    -- =================================================
    -- Receive baud rate generator
    -- =================================================

    process(ctrl_rx_baud, clken, clk_divider)
    begin
        case (ctrl_rx_baud) is
            when "000" =>
                -- 19200 baud
                rx_clk <= clken; -- this is a bit ugly, but acia doesn't care about duty cycle
            when "100" =>
                --  9600 baud
                rx_clk <= clk_divider(0);
            when "010" =>
                --  4800 baud
                rx_clk <= clk_divider(1);
            when "110" =>
                --  2400 baud
                rx_clk <= clk_divider(2);
            when "001" =>
                --  1200 baud
                rx_clk <= clk_divider(3);
            when "101" =>
                --   300 baud
                rx_clk <= clk_divider(5);
            when "011" =>
                --   150 baud
                rx_clk <= clk_divider(6);
            when "111" =>
                --    75 baud
                rx_clk <= clk_divider(7);
            when others =>
                null;
        end case;
    end process;

    -- =================================================
    -- Synchronise/filter raw CasIn and detect edges
    -- =================================================

    -- We don't have any evidance (yet) that the real ULA
    -- does any filtering of the input

    process(clk)
    begin
        if rising_edge(clk) then
            if clken = '1' then
                if clk_divider(0) = '1' then
                    cas_din_edge <= '0';
                    cas_din_synchronized <= CasIn;
                    if cas_din_filtered = cas_din_synchronized then
                        filter_counter <= (others => '0');
                    else
                        filter_counter <= filter_counter + 1;
                        if filter_counter = "11" then
                            cas_din_filtered <= cas_din_synchronized;
                            cas_din_edge <= '1';
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- =================================================
    -- Cassette Data Seperator
    -- =================================================

    burst0 <= '1' when bit_counter = x"08" else '0';  -- 13us after the edge
    burst1 <= '1' when bit_counter = x"B0" else '0';  -- 260us after the edge

    process(clk)
    begin
        if rising_edge(clk) then
            if clken = '1' then
                if clk_divider(0) = '1' then

                    -- Measure the gap between edges with an 8-bit saturating counter
                    if cas_din_edge = '1' then
                        bit_counter <= (others => '0');
                    elsif bit_counter /= x"FF" then
                        bit_counter <= bit_counter + 1;
                    end if;

                    -- Clock recovery, generate a burst of 4 clock pulses
                    if burst0 = '1' or burst1 = '1' or burst_counter > 0 then
                        burst_counter <= burst_counter + 1;
                    end if;
                    if burst_counter > 0 then
                        cas_clk_recovered <= not burst_counter(0);
                    else
                        cas_clk_recovered <= '1';
                    end if;

                    -- Track the length of the last two gaps between edges
                    if cas_din_edge = '1' then
                        is_long <= '0';
                        is_long_last <= is_long;
                    elsif burst1 = '1' then
                        is_long <= '1';
                    end if;

                    -- Data recovery, make the data decision on each edge
                    if cas_din_edge = '1' then
                        if is_long = '1' then
                            -- last gap long: output a zero
                            cas_din_recovered <= ctrl_reverse_tones;
                        elsif is_long_last = '0' then
                            -- last two gaps short: output a one
                            cas_din_recovered <= not ctrl_reverse_tones;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- =================================================
    -- High Tone Run-in Detect
    -- =================================================

    high_tone_threshold <= to_unsigned(HIGH_TONE_THRESHOLD_VLSI, HIGH_TONE_BITS) when vlsi_mode = '1' else
                           to_unsigned(HIGH_TONE_THRESHOLD_FERRANTI, HIGH_TONE_BITS);

    process(clk)
    begin
        if rising_edge(clk) then
            if clken = '1' then
                if clk_divider(7 downto 0) = x"FF" then
                    if cas_din_recovered = '0' or ctrl_motor_on = '0' then
                        high_tone_counter <= (others => '0');
                    elsif high_tone_counter /= HIGH_TONE_MAX then
                        high_tone_counter <= high_tone_counter + 1;
                    end if;
                    if high_tone_counter = high_tone_threshold then
                        high_tone_detect <= '1';
                    else
                        high_tone_detect <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process;


    -- =================================================
    -- Sine Wave Synthesis
    -- =================================================

    -- The Ferranti Serial ULA produces 4 discrete levels:
    --
    --               1200Hz 2400Hz
    -- 00: 2.95V for 208us  104us
    -- 01: 3.36V for 104us   52us
    -- 10: 4.52V for 104us   52us
    -- 11: 4.92V for 208us  104us
    -- 10: 4.52V for 104us   52us
    -- 01: 3.36V for 104us   52us
    --               -----  -----
    -- etc           832us  416us
    --
    -- At 1200 baud:
    --    TxD = 0 -> one cycle  of 1200 Hz
    --    TxD = 1 -> two cycles of 2400 Hz

    sine_in <= clk_divider(8 downto 6) when txd_s = '1' else
               clk_divider(9 downto 7);

    process(clk)
    begin
        if rising_edge(clk) then
            -- Sample TxD and Enable once per bit period
            if clken = '1' then
                if clk_divider(9 downto 0) = "1111111111" then
                    txd_s <= TxD xor ctrl_reverse_tones;
                    enable_s <= not ctrl_rs423_sel and not RTSI;
                end if;
            end if;
        end if;
    end process;


    -- Note: the polarity doesn't matter (the Ferranti and
    -- VLSI parts actually have opposite polarities).
    --
    -- Note: bit transitions (between low and high tones)
    -- should happen at the zero crossings.
    --         V                                V
    --                             +-------+
    --                             |       |
    --                         +---+       +---+
    --                         |               |
    --                         |               |
    --                         |               |
    --         |               |
    --         |               |
    --         |               |
    --         +---+       +---+
    --             |       |
    --             +-------+
    --
    -- Sine_in |000|001|010|011|100|101|110|111|

    BOARD_REV_01: if BOARD_REV = 1 generate

        -- Note: this change fixes a 90 degree phase shift error
        -- in previous commits.
        --
        -- Uses open drain drivers and a pullup (R1) to 5V
        --
        -- Sine_in |000|001|010|011|100|101|110|111|
        -- CasOut1 | 0 | 0 | 0 | 0 | Z | Z | Z | Z | (Pin 37 = 1K8)
        -- CasOut0 | Z | 0 | 0 | Z | 0 | Z | Z | 0 | (Pin 38 = 10K)
        --
        -- Output 00 when !enable_s so CasOut sits at lowest voltage

        CasOut(1) <= 'Z' when (enable_s = '1' and sine_in(2) = '1') else '0';
        CasOut(0) <= 'Z' when (enable_s = '1' and (sine_in(2) xor sine_in(2) xor sine_in(2)) = '0') else '0';

    end generate;


    BOARD_REV_02: if (BOARD_REV = 2) generate

        -- Uses push-pull drivers and a bias voltage of 1.65V
        --
        -- Sine_in |000|001|010|011|100|101|110|111|
        -- CasOut1 | 0 | 0 | 0 | 0 | 1 | 1 | 1 | 1 | (Pin 37 = 1K8)
        -- CasOut0 | Z | 0 | 0 | Z | Z | 1 | 1 | Z | (Pin 38 = 510R)
        --
        -- Output ZZ when !enable_s so CasOut sits at 1.65V

        -- Normal phase sine wave
        CasOut(1) <= sine_in(2) when (enable_s = '1') else 'Z';
        CasOut(0) <= sine_in(2) when (enable_s = '1' and (sine_in(1) xor sine_in(0)) = '1') else 'Z';

    end generate;

    -- =================================================
    -- Output Multiplexers
    -- =================================================

    Dout <= not TxD;
    TxC  <= tx_clk;
    DCD  <= '0'      when ctrl_rs423_sel = '1' else high_tone_detect;
    RxC  <= rx_clk   when ctrl_rs423_sel = '1' else cas_clk_recovered;
    RxD  <= not Din  when ctrl_rs423_sel = '1' else cas_din_recovered;
    RTSO <= not RTSI when ctrl_rs423_sel = '1' else '0';
    CTSO <= not CTSI when ctrl_rs423_sel = '1' else '0';
    CasMotor <= ctrl_motor_on;

end RTL;
