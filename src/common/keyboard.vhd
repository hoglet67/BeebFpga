-- BBC Micro for Altera DE1
--
-- Copyright (c) 2011 Mike Stirling
--
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- * Redistributions of source code must retain the above copyright notice,
--   this list of conditions and the following disclaimer.
--
-- * Redistributions in synthesized form must reproduce the above copyright
--   notice, this list of conditions and the following disclaimer in the
--   documentation and/or other materials provided with the distribution.
--
-- * Neither the name of the author nor the names of other contributors may
--   be used to endorse or promote products derived from this software without
--   specific prior written agreement from the author.
--
-- * License is granted for non-commercial use only.  A fee may not be charged
--   for redistributions as source code or in synthesized/hardware form without
--   specific prior written agreement from the author.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--
-- BBC keyboard implementation with interface to PS/2
--
-- (C) 2011 Mike Stirling
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity keyboard is
generic (
        MainClockSpeed : natural := 48000000;
        LEDUpdateSpeed : natural := 20
    );
port (
    CLOCK       :   in  std_logic;
    nRESET      :   in  std_logic;
    CLKEN_1MHZ  :   in  std_logic;

    -- to PS/2 interface
    KEYB_CMD     :  out std_logic_vector(7 downto 0);
    KEYB_WRITE   :  out std_logic := '0';

    -- from PS/2 interface
    KEYB_DATA    :  in std_logic_vector(7 downto 0);
    KEYB_VALID   :  in std_logic;
    KEYB_ERROR   :  in std_logic;
    KEYB_BUSY    :  in std_logic;

    -- LEDs (in from core out to PS/2)
    LED_MOTOR    :  in std_logic;
    LED_CAPS     :  in std_logic;
    LED_SHIFT    :  in std_logic;

    -- If 1 then column is incremented automatically at
    -- 1 MHz rate
    AUTOSCAN    :   in  std_logic;

    COLUMN      :   in  std_logic_vector(3 downto 0);
    ROW         :   in  std_logic_vector(2 downto 0);

    -- 1 when currently selected key is down (AUTOSCAN disabled)
    KEYPRESS    :   out std_logic;
    -- 1 when any key is down (except row 0)
    INT         :   out std_logic;
    -- BREAK key output - 1 when pressed
    BREAK_OUT   :   out std_logic;

    -- DIP switch inputs
    DIP_SWITCH  :   in  std_logic_vector(7 downto 0);

    -- Config button outputs
    CONFIG_KEY  :   in  std_logic;
    CONFIG      :   out std_logic_vector(9 downto 0);

    DBG_STATE   :   out std_logic_vector(5 downto 0)
    );
end entity;

architecture rtl of keyboard is

    function ceil_log2(i : natural) return natural is
    begin
        return integer(ceil(log2(real(i))));
    end function;


-- Active high version of reset
signal rst          :   std_logic;

-- Internal signals
type key_matrix is array(0 to 15) of std_logic_vector(7 downto 0);
signal keys               : key_matrix;
signal col                : unsigned(3 downto 0);
signal extended           : std_logic;
signal releasex           : std_logic;
signal right_alt          : std_logic;
signal config_mod         : std_logic;
signal config_fn          : std_logic_vector(9 downto 0);
signal config_fn_last     : std_logic_vector(9 downto 0);

constant LED_CTR_MAX      : natural := integer(MainClockSpeed / LEDUpdateSpeed) - 1;
signal   r_led_ctr        : unsigned(ceil_log2(LED_CTR_MAX) downto 0);
signal   i_cur_leds       : std_logic_vector(2 downto 0);
signal   r_cur_leds       : std_logic_vector(2 downto 0);

signal   i_keyb_write_ack : std_logic; -- '1' when our write has been ack'd (write asserted and busy deasserted)
signal   i_keyb_write     : std_logic;

signal   dbg_valid_tgl    : std_logic := '0';

-- Initialization state machine
type init_state is (
    reset,
    send_rst_cmd,
    ack_rst_cmd,
    get_bat_result,
    send_id_cmd,
    ack_id_cmd,
    get_id1,
    get_id2,
--  send_disable_cmd,
--  ack_disable_cmd,
    enabled,
    disabled,
    protocol_error,
    update_leds,
    update_leds_data,
    update_led_ack
    );

signal state: init_state;
begin

    DBG_STATE <=
        dbg_valid_tgl &
        "0" &
        std_logic_vector(to_unsigned(init_state'pos(state), 4));

    i_keyb_write_ack <= i_keyb_write and not KEYB_BUSY;
    KEYB_WRITE <= i_keyb_write;

    i_cur_leds <= LED_CAPS & LED_SHIFT & LED_MOTOR;

    rst <= not nRESET;

    -- There are now three possible config modifiers:
    -- 1. An external config key (e.g. a physical button on the FPGA board)
    -- 2. The right alt key
    -- 3. The left alt key AND control (kept for legacy reasons)
    config_mod <= '1' when CONFIG_KEY = '1' or right_alt = '1' or (keys(0)(5) = '1' and keys(1)(0) = '1') else '0';

    -- Initialization State Machine
    process(CLOCK)
        procedure WR(cmd:std_logic_vector(7 downto 0); next_state:init_state) is
        begin
            keyb_cmd <= cmd;
            i_keyb_write <= '1';
            if i_keyb_write_ack = '1' then
                i_keyb_write <= '0';
                state <= next_state;
            end if;
        end procedure WR;
    begin
        if rising_edge(CLOCK) then

            if rst = '1' then
                state <= reset;
                i_keyb_write <= '0';
                r_led_ctr <= to_unsigned(LED_CTR_MAX, r_led_ctr'length);
            else
                case state is
                    when reset =>
                        if rst = '0' then
                            state <= send_rst_cmd;
                        end if;
                    when send_rst_cmd =>
                        -- Send the RST command
                        WR(x"FF", ack_rst_cmd);
                    when ack_rst_cmd =>
                        -- A keyboard/mouse responds with FA (Ack) then AA or FC
                        if keyb_valid = '1' then
                            if keyb_data = x"FA" then
                                state <= get_bat_result;
                            else
                                state <= protocol_error;
                            end if;
                        end if;
                    when get_bat_result =>
                        if keyb_valid = '1' then
                            if keyb_data = x"AA" then
                                state <= send_id_cmd;
                            else
                                state <= protocol_error;
                            end if;
                        end if;
                    when send_id_cmd =>
                        -- Send the ID command
                        WR(x"F2", ack_id_cmd);
                    when ack_id_cmd =>
                        -- A keyboard responds with FA (Ack) then AB 83
                        -- A mouse responds with FA (Ack) then 00
                        -- Under some circumstances a MS intelli mouse response
                        -- with FA (Ack) then 03 or 04
                        if keyb_valid = '1' then
                            if keyb_data = x"FA" then
                                state <= get_id1;
                            else
                                state <= protocol_error;
                            end if;
                        end if;
                    when get_id1 =>
                        if keyb_valid = '1' then
                            if keyb_data = x"AB" then
                                -- Keyboard, skip an additional ID byte (AB)
                                state <= get_id2;
                            elsif keyb_data = x"00" or keyb_data = x"03" or keyb_data = x"04" then
                                -- Mouse, disable data reporting
--                              state <= send_disable_cmd;
                                state <= disabled;
                            else
                                state <= protocol_error;
                            end if;
                        end if;
                    when get_id2 =>
                        if keyb_valid = '1' then
                            if keyb_data = x"83" then
                                state <= update_leds;
                            else
                                state <= protocol_error;
                            end if;
                        end if;

--                    when send_disable_cmd =>
--                        if keyb_busy = '0' then
--                            keyb_cmd   <= x"F5";
--                            keyb_write <= '1';
--                            state      <= ack_disable_cmd;
--                        end if;
--                    when ack_disable_cmd =>
--                        keyb_write <= '0';
--                        if keyb_valid = '1' then
--                            if keyb_data = x"FA" then
--                                state <= disabled;
--                            else
--                                state <= protocol_error;
--                            end if;
--                        end if;

                    when update_leds =>

                        WR(x"ED", update_led_ack);

                    when update_led_ack =>
                        r_cur_leds <= i_cur_leds;
                        if r_led_ctr(r_led_ctr'high) = '1' then
                            state <= enabled;
                            r_led_ctr <= to_unsigned(LED_CTR_MAX, r_led_ctr'length);
                        else
                            r_led_ctr <= r_led_ctr - 1;
                        end if;
                        if keyb_valid = '1' then
                            if keyb_data = x"FA" then
                                state <= update_leds_data;
                            else
                                state <= enabled;
                            end if;
                        end if;

                    when update_leds_data =>
                        WR("00000" & r_cur_leds, enabled);

                    when enabled =>
                        if r_led_ctr(r_led_ctr'high) = '1' then
                            r_led_ctr <= to_unsigned(LED_CTR_MAX, r_led_ctr'length);
                            if r_cur_leds /= i_cur_leds then
                                state <= update_leds;
                            end if;
                        else
                            r_led_ctr <= r_led_ctr - 1;
                        end if;


                    when disabled =>
                        -- Sit in this state until the next reset

                    when protocol_error =>
                        -- Sit in this state until the next reset

                end case;
            end if;
        end if;
    end process;


    -- Column counts automatically when AUTOSCAN is enabled, otherwise
    -- value is loaded from external input
    process(CLOCK,nRESET)
    begin
        if nRESET = '0' then
            col <= (others => '0');
        elsif rising_edge(CLOCK) then
            if AUTOSCAN = '0' then
                -- If autoscan disabled then transfer current COLUMN to counter
                -- immediately (don't wait for next 1 MHz cycle)
                col <= unsigned(COLUMN);
            elsif CLKEN_1MHZ = '1' then
                -- Otherwise increment the counter once per 1 MHz tick
                col <= col + 1;
            end if;
        end if;
    end process;

    -- Generate interrupt if any key in currently scanned column is pressed
    -- (apart from in row 0).  Output selected key status if autoscan disabled.
    process(keys,col,ROW,AUTOSCAN)
    variable k : std_logic_vector(7 downto 0);
    begin
        -- Shortcut to current key column
        k := keys(to_integer(col));

        -- Interrupt if any key pressed in rows 1 to 7.
        INT <= k(7) or k(6) or k(5) or k(4) or k(3) or k(2) or k(1);

        -- Determine which key is pressed
        -- Inhibit output during auto-scan
        if AUTOSCAN = '0' then
            KEYPRESS <= k(to_integer(unsigned(ROW)));
        else
            KEYPRESS <= '0';
        end if;
    end process;

    -- Decode PS/2 data
    process(CLOCK,nRESET)
    begin
        if nRESET = '0' then
            releasex <= '0';
            extended <= '0';

            BREAK_OUT <= '0';

            keys(0) <= (others => '0');
            keys(1) <= (others => '0');
            keys(2) <= (others => '0');
            keys(3) <= (others => '0');
            keys(4) <= (others => '0');
            keys(5) <= (others => '0');
            keys(6) <= (others => '0');
            keys(7) <= (others => '0');
            keys(8) <= (others => '0');
            keys(9) <= (others => '0');
            -- These non-existent rows are used in the BBC master
            keys(10) <= (others => '0');
            keys(11) <= (others => '0');
            keys(12) <= (others => '0');
            keys(13) <= (others => '0');
            keys(14) <= (others => '0');
            keys(15) <= (others => '0');

            right_alt <= '0';
            config_fn <= (others => '0');
            config_fn_last <= (others => '0');

            CONFIG <= (others => '0');

        elsif rising_edge(CLOCK) then

            -- Output Config F1..F10 as a single cycle pulse
            CONFIG <= config_fn and not(config_fn_last);
            config_fn_last <= config_fn;

            -- To stop Quartus inferring latches
            keys(10)(0) <= '0';
            keys(11)(0) <= '0';
            keys(12)(0) <= '0';
            keys(12)(1) <= '0';
            keys(12)(2) <= '0';
            keys(13) <= (others => '0');
            keys(14) <= (others => '0');
            keys(15) <= (others => '0');

            -- Copy DIP switches through to row 0
            keys( 2)(0) <= DIP_SWITCH(7);
            keys( 3)(0) <= DIP_SWITCH(6);
            keys( 4)(0) <= DIP_SWITCH(5);
            keys( 5)(0) <= DIP_SWITCH(4);
            keys( 6)(0) <= DIP_SWITCH(3);
            keys( 7)(0) <= DIP_SWITCH(2);
            keys( 8)(0) <= DIP_SWITCH(1);
            keys( 9)(0) <= DIP_SWITCH(0);

            -- Test if a key was pressed
            if keyb_valid = '1' and state = enabled then

                dbg_valid_tgl <= not dbg_valid_tgl;

                -- Decode keyboard input
                if keyb_data = X"e0" then
                    -- Extended key code follows
                    extended <= '1';
                elsif keyb_data = X"f0" then
                    -- Releasex code follows
                    releasex <= '1';
                else
                    -- Cancel extended/releasex flags for next time
                    releasex <= '0';
                    extended <= '0';

                    if extended = '1' then

                        -- Decode extended scan codes
                        case keyb_data is
                            when X"11" => right_alt   <= not releasex; -- RIGHT ALT (Config)
                            when X"14" => keys( 1)(0) <= not releasex; -- RIGHT CTRL (CTRL)
                            when X"69" => keys( 9)(6) <= not releasex; -- END (COPY)
                            when X"75" => keys( 9)(3) <= not releasex; -- UP
                            when X"6B" => keys( 9)(1) <= not releasex; -- LEFT
                            when X"72" => keys( 9)(2) <= not releasex; -- DOWN
                            when X"74" => keys( 9)(7) <= not releasex; -- RIGHT
                            when x"4A" => keys(10)(4) <= not releasex; -- Keypad /
                            when x"5A" => keys(12)(3) <= not releasex; -- Keypad Return
                            when x"70" => keys(12)(5) <= not releasex; -- INSERT Keypad ,
                            when x"71" => keys(11)(4) <= not releasex; -- DELETE Keypad Delete
                            when others => null;
                        end case;

                    else

                        -- Decode normal scan codes
                        -- If the config modifer is active, function keys decode as config keys
                        case keyb_data is
                            when X"12" => keys( 0)(0) <= not releasex; -- Left SHIFT
                            when X"59" => keys( 0)(0) <= not releasex; -- Right SHIFT
                            when X"15" => keys( 0)(1) <= not releasex; -- Q
                            when X"09" => if config_mod = '1' then
                                              config_fn(0) <= not releasex;
                                          else
                                              keys( 0)(2) <= not releasex; -- F10 (F0)
                                          end if;
                            when X"16" => keys( 0)(3) <= not releasex; -- 1
                            when X"58" => keys( 0)(4) <= not releasex; -- CAPS LOCK
                            when X"11" => keys( 0)(5) <= not releasex; -- LEFT ALT (SHIFT LOCK)
                            when X"0D" => keys( 0)(6) <= not releasex; -- TAB
                            when X"76" => keys( 0)(7) <= not releasex; -- ESCAPE
                            when X"14" => keys( 1)(0) <= not releasex; -- LEFT CTRL (CTRL)
                            when X"26" => keys( 1)(1) <= not releasex; -- 3
                            when X"1D" => keys( 1)(2) <= not releasex; -- W
                            when X"1E" => keys( 1)(3) <= not releasex; -- 2
                            when X"1C" => keys( 1)(4) <= not releasex; -- A
                            when X"1B" => keys( 1)(5) <= not releasex; -- S
                            when X"1A" => keys( 1)(6) <= not releasex; -- Z
                            when X"05" => if config_mod = '1' then
                                              config_fn(1) <= not releasex;
                                          else
                                              keys( 1)(7) <= not releasex; -- F1
                                          end if;
                            when X"25" => keys( 2)(1) <= not releasex; -- 4
                            when X"24" => keys( 2)(2) <= not releasex; -- E
                            when X"23" => keys( 2)(3) <= not releasex; -- D
                            when X"22" => keys( 2)(4) <= not releasex; -- X
                            when X"21" => keys( 2)(5) <= not releasex; -- C
                            when X"29" => keys( 2)(6) <= not releasex; -- SPACE
                            when X"06" => if config_mod = '1' then
                                              config_fn(2) <= not releasex;
                                          else
                                              keys( 2)(7) <= not releasex; -- F2
                                          end if;
                            when X"2E" => keys( 3)(1) <= not releasex; -- 5
                            when X"2C" => keys( 3)(2) <= not releasex; -- T
                            when X"2D" => keys( 3)(3) <= not releasex; -- R
                            when X"2B" => keys( 3)(4) <= not releasex; -- F
                            when X"34" => keys( 3)(5) <= not releasex; -- G
                            when X"2A" => keys( 3)(6) <= not releasex; -- V
                            when X"04" => if config_mod = '1' then
                                              config_fn(3) <= not releasex;
                                          else
                                              keys( 3)(7) <= not releasex; -- F3
                                          end if;
                            when X"0C" => if config_mod = '1' then
                                              config_fn(4) <= not releasex;
                                          else
                                              keys( 4)(1) <= not releasex; -- F4
                                          end if;
                            when X"3D" => keys( 4)(2) <= not releasex; -- 7
                            when X"36" => keys( 4)(3) <= not releasex; -- 6
                            when X"35" => keys( 4)(4) <= not releasex; -- Y
                            when X"33" => keys( 4)(5) <= not releasex; -- H
                            when X"32" => keys( 4)(6) <= not releasex; -- B
                            when X"03" => if config_mod = '1' then
                                              config_fn(5) <= not releasex;
                                          else
                                              keys( 4)(7) <= not releasex; -- F5
                                          end if;
                            when X"3E" => keys( 5)(1) <= not releasex; -- 8
                            when X"43" => keys( 5)(2) <= not releasex; -- I
                            when X"3C" => keys( 5)(3) <= not releasex; -- U
                            when X"3B" => keys( 5)(4) <= not releasex; -- J
                            when X"31" => keys( 5)(5) <= not releasex; -- N
                            when X"3A" => keys( 5)(6) <= not releasex; -- M
                            when X"0B" => if config_mod = '1' then
                                              config_fn(6) <= not releasex;
                                          else
                                              keys( 5)(7) <= not releasex; -- F6
                                          end if;
                            when X"83" => if config_mod = '1' then
                                              config_fn(7) <= not releasex;
                                          else
                                              keys( 6)(1) <= not releasex; -- F7
                                          end if;
                            when X"46" => keys( 6)(2) <= not releasex; -- 9
                            when X"44" => keys( 6)(3) <= not releasex; -- O
                            when X"42" => keys( 6)(4) <= not releasex; -- K
                            when X"4B" => keys( 6)(5) <= not releasex; -- L
                            when X"41" => keys( 6)(6) <= not releasex; -- ,
                            when X"0A" => if config_mod = '1' then
                                              config_fn(8) <= not releasex;
                                          else
                                              keys( 6)(7) <= not releasex; -- F8
                                          end if;
                            when X"4E" => keys( 7)(1) <= not releasex; -- -
                            when X"45" => keys( 7)(2) <= not releasex; -- 0
                            when X"4D" => keys( 7)(3) <= not releasex; -- P
                            when X"0E" => keys( 7)(4) <= not releasex; -- ` (@)
                            when X"4C" => keys( 7)(5) <= not releasex; -- ;
                            when X"49" => keys( 7)(6) <= not releasex; -- .
                            when X"01" => if config_mod = '1' then
                                              config_fn(9) <= not releasex;
                                          else
                                              keys( 7)(7) <= not releasex; -- F9
                                          end if;
                            when X"55" => keys( 8)(1) <= not releasex; -- = (^)
                            when X"5D" => keys( 8)(2) <= not releasex; -- # (_)
                            when X"54" => keys( 8)(3) <= not releasex; -- [
                            when X"52" => keys( 8)(4) <= not releasex; -- '
                            when X"5B" => keys( 8)(5) <= not releasex; -- ]
                            when X"4A" => keys( 8)(6) <= not releasex; -- /
                            when X"61" => keys( 8)(7) <= not releasex; -- \
                            when X"5A" => keys( 9)(4) <= not releasex; -- RETURN
                            when X"66" => keys( 9)(5) <= not releasex; -- BACKSPACE (DELETE)
                            when x"74" => keys(10)(1) <= not releasex; -- Keypad 6
                            when x"75" => keys(10)(2) <= not releasex; -- Keypad 8
                            when x"79" => keys(10)(3) <= not releasex; -- Keypad +
                            when x"77" => keys(10)(5) <= not releasex; -- Keypad #
                            when x"70" => keys(10)(6) <= not releasex; -- Keypad 0
                            when x"6B" => keys(10)(7) <= not releasex; -- Keypad 4
                            when x"6C" => keys(11)(1) <= not releasex; -- Keypad 7
                            when x"7D" => keys(11)(2) <= not releasex; -- Keypad 9
                            when x"7B" => keys(11)(3) <= not releasex; -- Keypad -
                            when x"7C" => keys(11)(5) <= not releasex; -- Keypad *
                            when x"69" => keys(11)(6) <= not releasex; -- Keypad 1
                            when x"73" => keys(11)(7) <= not releasex; -- Keypad 5
                            when x"71" => keys(12)(4) <= not releasex; -- Keypad .
                            when x"7A" => keys(12)(6) <= not releasex; -- Keypad 3
                            when x"72" => keys(12)(7) <= not releasex; -- Keypad 2

                            -- F12 is used for the BREAK key, which in the real BBC asserts
                            -- reset.  Here we pass this out to the top level which may
                            -- optionally OR it in to the system reset
                            when X"07" => BREAK_OUT <= not releasex; -- F12 (BREAK)

                            when others => null;
                        end case;

                    end if;
                end if;
            end if;
        end if;
    end process;

end architecture;
