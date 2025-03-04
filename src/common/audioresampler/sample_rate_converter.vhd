-- Audio Sample Rate Converter for BeebFPGA using a Polyphase filter
--
-- Copyright (c) 2025 David Banks
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.sample_rate_converter_pkg.all;

entity sample_rate_converter is
    generic (
        NUM_CHANNELS      : integer;
        VOLUME_WIDTH      : integer := 8;
        OUTPUT_RATE       : integer;
        OUTPUT_WIDTH      : integer;
        OUTPUT_SHIFT      : integer := 12;
        FILTER_NTAPS      : integer;
        FILTER_L          : t_int_array;
        FILTER_M          : integer;
        FILTER_SHIFT      : integer := 16;
        CHANNEL_TYPE      : t_channel_type_array;
        BUFFER_A_WIDTH    : integer;
        COEFF_A_WIDTH     : integer;
        ACCUMULATOR_WIDTH : integer;
        BUFFER_SIZE       : t_int_array
        );
    port (
        clk               : in  std_logic;
        clk_en            : in  std_logic := '1';
        reset_n           : in  std_logic;

        -- Master volume
        volume            : in  unsigned(VOLUME_WIDTH - 1 downto 0);

        -- Input Channels
        channel_clken     : in  std_logic_vector(NUM_CHANNELS - 1 downto 0) := (others => '1');
        channel_load      : in  std_logic_vector(NUM_CHANNELS - 1 downto 0) := (others => '0');
        channel_in        : in  t_sample_array(0 to NUM_CHANNELS - 1);

        -- Stereo output
        mixer_strobe      : out std_logic;
        clip_l            : out std_logic;
        clip_r            : out std_logic;
        mixer_l           : out signed(OUTPUT_WIDTH - 1 downto 0);
        mixer_r           : out signed(OUTPUT_WIDTH - 1 downto 0)
        );
end entity;

architecture rtl of sample_rate_converter is

    -- ------------------------------------------------------------------------------
    -- Pre-calculate M MOD L and M DIV L for each channel
    -- ------------------------------------------------------------------------------

    function init_m_mod_l(m : in integer; l : in t_int_array) return t_int_array is
        variable ret : t_int_array(0 to NUM_CHANNELS - 1);
    begin
        for i in 0 to NUM_CHANNELS - 1 loop
            ret(i) := m mod l(i);
        end loop;
        return ret;
    end function;

    function init_m_div_l(m : in integer; l : in t_int_array) return t_int_array is
        variable ret : t_int_array(0 to NUM_CHANNELS - 1);
    begin
        for i in 0 to NUM_CHANNELS - 1 loop
            ret(i) := m / l(i);
        end loop;
        return ret;
    end function;

    constant M_MOD_L : t_int_array := init_m_mod_l(FILTER_M, FILTER_L);

    constant M_DIV_L : t_int_array := init_m_div_l(FILTER_M, FILTER_L);

    -- ------------------------------------------------------------------------------
    -- Input Data Latches
    -- ------------------------------------------------------------------------------

    -- A sample register (per channel) to capture input data before it's written to the RAM
    signal channel_data : t_sample_array(0 to NUM_CHANNELS - 1);

    -- A register with a bit per channel to indicate data is pending on that channel
    signal channel_dav : std_logic_vector(NUM_CHANNELS - 1 downto 0);

    -- A function that returns true if all bits of the SLV are zero, or the SLV is an empty slice
    function all_bits_clear(slv : in std_logic_vector; lo : integer; hi : integer) return boolean is
        variable ret : boolean;
    begin
        ret := true;
        if hi >= lo then
            for i in lo to hi loop
                if slv(i) = '1' then
                    ret := false;
                end if;
            end loop;
        end if;
        return ret;
    end function;

    -- ------------------------------------------------------------------------------
    -- Filter Coefficient ROM
    -- ------------------------------------------------------------------------------

    -- Note: as the filter coefficients are symettric, only half are stored

    -- Coefficient ROM address and data ports
    signal coeff_rd_addr : unsigned(COEFF_A_WIDTH - 1 downto 0) := (others => '0');
    signal coeff_rd_data : signed(SAMPLE_WIDTH - 1 downto 0) := (others => '0');

    -- Coefficient address (per channel) used during the filter calculation
    type t_coeff_addr_array is array(0 to NUM_CHANNELS - 1)
        of unsigned(COEFF_A_WIDTH downto 0);

    -- It's called k to match the variable in the C code
    signal k : t_coeff_addr_array :=  (others => (others => '0'));

    -- ------------------------------------------------------------------------------
    -- Buffer RAM
    -- ------------------------------------------------------------------------------

    -- Note: the buffer RAM holds a circular buffer (per channel) to
    -- store the recent history of channel input values. These are
    -- used in the filter calculation.

    -- Buffer RAM Ports address and data ports and the write enable signal
    signal buffer_wr_addr : unsigned(BUFFER_A_WIDTH - 1 downto 0) := (others => '0');
    signal buffer_rd_addr : unsigned(BUFFER_A_WIDTH - 1 downto 0) := (others => '0');
    signal buffer_wr_data : signed(SAMPLE_WIDTH - 1 downto 0) := (others => '0');
    signal buffer_rd_data : signed(SAMPLE_WIDTH - 1 downto 0) := (others => '0');
    signal buffer_we      : std_logic := '0';

    -- A function to initialize the base address of each buffer from the passed-in sizes
    function init_buffer_base(i_buffer_size : in t_int_array)
        return t_int_array is
        variable tmp : t_int_array(0 to NUM_CHANNELS - 1);
        variable sum : integer;
    begin
        sum := 0;
        for i in 0 to NUM_CHANNELS - 1 loop
            tmp(i) := sum;
            sum := sum + i_buffer_size(i);
        end loop;
        return tmp;
    end function;

    -- The base address of each buffer
    constant BUFFER_BASE : t_int_array := init_buffer_base(BUFFER_SIZE);

    -- Buffer read / write pointers
    type t_buffer_addr_array is array(0 to NUM_CHANNELS - 1)
        of unsigned(BUFFER_A_WIDTH - 1 downto 0);
    signal rd_addr : t_buffer_addr_array;
    signal wr_addr : t_buffer_addr_array;

    -- The initial offset offset between read and write pointers
    -- (initially the buffer will contain this many zero)
    constant RD_WR_OFFSET : integer := 4;

    -- ------------------------------------------------------------------------------
    -- State variables
    -- ------------------------------------------------------------------------------

    type t_state_main is (
        st_idle,
        st_output,
        st_setup,
        st_mult_accumulate,
        st_save,
        st_stall1,
        st_stall2,
        st_stall3,
        st_scale_lsb,
        st_scale_msb,
        st_complete
        );

    -- Main (currently only) state machine
    signal state 	         : t_state_main := st_idle;

    -- Counter to iterate through the channels
    signal current_channel : unsigned(1 downto 0) := (others => '0'); -- should depend on NUM_CHANNELS!

    -- Counter to track the number of multiplies in the filter calculation (i.e. the number of taps)
    signal multiply_count  : unsigned(COEFF_A_WIDTH - 1 downto 0) := (others => '0');

    -- Temporary coefficient index that's updated as the filter calculation proceedes
    -- Note: It's got one extra bit as it represents the unreflected coefficient index
    signal coeff_index     : unsigned(COEFF_A_WIDTH downto 0) := (others => '0');

    -- Temporary buffer rd address that's updated as the filter calculation proceedes
    signal sample_addr     : unsigned(BUFFER_A_WIDTH - 1 downto 0) := (others => '0');

    -- Counter to deterime when the next output sample is due
    signal rate_counter    : unsigned(9 downto 0); -- TODO: determine width from output rate

    -- ------------------------------------------------------------------------------
    -- DSP Pipeline
    -- ------------------------------------------------------------------------------

    -- The DSP pipeline is controlled delayed versions of the main state
    type t_pipe_state is array(0 to 4) of t_state_main;
    signal pipe_state : t_pipe_state  := (others => st_idle);

    -- Various other small state variable flow down the pipleline as well
    type t_pipe_channel is array(0 to 4) of unsigned (1 downto 0);
    signal pipe_channel : t_pipe_channel := (others => (others => '0'));

    -- The DSP multiplier input/output registers
    signal mult_a_in       : signed(SAMPLE_WIDTH - 1 downto 0);
    signal mult_b_in       : signed(SAMPLE_WIDTH - 1 downto 0);
    signal mult_out        : signed(SAMPLE_WIDTH * 2 - 1 downto 0);

    -- The DSP accumulator output register
    signal accumulator     : signed(ACCUMULATOR_WIDTH - 1 downto 0);

    -- A snapshot of the final channel value after the filter
    -- calculation is complete. It's in sign and magnitude format so a
    -- 2*SAMPLE_WIDTH x SAMPLE_WIDTH multiple can be done with the
    -- single multiplier over two cycles.
    signal channel_mag_lsb : signed(SAMPLE_WIDTH - 1 downto 0); -- will always hold a positive value
    signal channel_mag_msb : signed(SAMPLE_WIDTH - 1 downto 0); -- will always hold a positive value
    signal channel_sign    : std_logic;

    -- A snapshot of the channel scale value (L * volume) calculated
    -- during the setup state.
    signal scale_factor    : signed(SAMPLE_WIDTH - 1 downto 0);

    -- The mixer sum, calculated across the N channels
    signal mixer_sum_l     : signed(SAMPLE_WIDTH * 2 - 1 downto 0) := to_signed(0, SAMPLE_WIDTH * 2);
    signal mixer_sum_r     : signed(SAMPLE_WIDTH * 2 - 1 downto 0) := to_signed(0, SAMPLE_WIDTH * 2);

    -- Constants for output clipping
    constant MIN_OUTPUT    : integer := -(2 ** (OUTPUT_WIDTH - 1));
    constant MAX_OUTPUT    : integer := 2 ** (OUTPUT_WIDTH - 1) - 1;

    -- For debugging (in a simulation)
    signal debug_state   : std_logic_vector(3 downto 0);
    signal debug_state0  : std_logic_vector(3 downto 0);
    signal debug_state1  : std_logic_vector(3 downto 0);
    signal debug_state2  : std_logic_vector(3 downto 0);
    signal debug_state3  : std_logic_vector(3 downto 0);
    signal debug_state4  : std_logic_vector(3 downto 0);
begin

    ----------------------------------------------------------------------------------
    -- Debugging (in a simulation)
    ----------------------------------------------------------------------------------

    debug_state  <= std_logic_vector(to_unsigned(t_state_main'pos(state ), 4));
    debug_state0 <= std_logic_vector(to_unsigned(t_state_main'pos(pipe_state(0)), 4));
    debug_state1 <= std_logic_vector(to_unsigned(t_state_main'pos(pipe_state(1)), 4));
    debug_state2 <= std_logic_vector(to_unsigned(t_state_main'pos(pipe_state(2)), 4));
    debug_state3 <= std_logic_vector(to_unsigned(t_state_main'pos(pipe_state(3)), 4));
    debug_state4 <= std_logic_vector(to_unsigned(t_state_main'pos(pipe_state(4)), 4));

    ----------------------------------------------------------------------------------
    -- Channel input latches and buffer writing
    ----------------------------------------------------------------------------------

    process(clk)
    begin
        if rising_edge(clk) then
            if clk_en = '1' then
                buffer_we <= '0';
                for i in 0 to NUM_CHANNELS - 1 loop
                    if reset_n = '0' then
                        wr_addr(i) <= to_unsigned(BUFFER_BASE(i) + RD_WR_OFFSET, BUFFER_A_WIDTH);
                        channel_dav(i) <= '0';
                        channel_data(i) <= to_signed(0, SAMPLE_WIDTH);
                    else
                        -- Latch the channel input sample as soon as it appears
                        if channel_dav(i) = '0' and channel_clken(i) = '1' and channel_load(i) = '1' then
                            channel_dav(i) <= '1';
                            channel_data(i) <= channel_in(i);
                        end if;
                        -- build a priority encode to serialize multiple simultaneous buffer writes
                        if channel_dav(i) = '1' and all_bits_clear(channel_dav, 0, i - 1) then
                            buffer_wr_addr <= wr_addr(i);
                            buffer_wr_data <= channel_data(i);
                            buffer_we <= '1';
                            channel_dav(i) <= '0';
                            -- Buffers no longer have any alignment constraints
                            if wr_addr(i) = BUFFER_BASE(i) + BUFFER_SIZE(i) - 1 then
                                wr_addr(i) <= to_unsigned(BUFFER_BASE(i), BUFFER_A_WIDTH);
                            else
                                wr_addr(i) <= wr_addr(i) + 1;
                            end if;
                        end if;
                    end if;
                end loop;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------------
    -- Main state machine
    ----------------------------------------------------------------------------------

    process(clk)
        -- One extra bit, as these are unreflected indexes
        variable tmp_coeff  : unsigned(COEFF_A_WIDTH downto 0);
        variable tmp_k      : unsigned(COEFF_A_WIDTH downto 0);
        -- One extra bit, so wrap calculation works at end of buffer
        variable tmp_n      : unsigned(BUFFER_A_WIDTH downto 0);
        variable buffer_end : integer;
    begin
        if rising_edge(clk) then
            if clk_en = '1' then
                if reset_n = '0' then
                    rate_counter <= (others => '1'); -- TODO: is this delay necessary?
                    state <= st_idle;
                    current_channel <= (others => '0');
                    for i in 0 to NUM_CHANNELS - 1 loop
                        k(i) <= to_unsigned(0, COEFF_A_WIDTH + 1);
                        rd_addr(i) <= to_unsigned(BUFFER_BASE(i), BUFFER_A_WIDTH);
                    end loop;
                else
                    -- Precalculate the end of the current channel buffer; used for wrapping
                    buffer_end := BUFFER_BASE(to_integer(current_channel)) + BUFFER_SIZE(to_integer(current_channel)) - 1;
                    -- When this reaches zero, it's time to start computing a new output sample
                    if rate_counter = 0 then
                        rate_counter <= to_unsigned(OUTPUT_RATE - 1, rate_counter'length);
                    else
                        rate_counter <= rate_counter - 1;
                    end if;
                    case state is
                        when st_idle =>
                            -- This state wait until the output sample is due
                            if rate_counter = 0 then
                                state <= st_output;
                            end if;
                        when st_output =>
                            -- This state triggers the outputs to be updated with the new values
                            state <= st_setup;
                        when st_setup =>
                            -- This state sets up the FIR filter calculation
                            coeff_index <= k(to_integer(current_channel));
                            multiply_count <= to_unsigned(FILTER_NTAPS / FILTER_L(to_integer(current_channel)) - 1, COEFF_A_WIDTH);
                            sample_addr <= rd_addr(to_integer(current_channel));
                            state <= st_mult_accumulate;
                        when st_mult_accumulate =>
                            -- Reflect the coefficient (the filter is symettric)
                            tmp_coeff := coeff_index;
                            if tmp_coeff >= FILTER_NTAPS / 2 then
                                tmp_coeff := FILTER_NTAPS - 1 - tmp_coeff;
                            end if;
                            -- Update the Coeff ROM/Buffer RAM read addresses
                            coeff_rd_addr <= tmp_coeff(COEFF_A_WIDTH - 1 downto 0);
                            buffer_rd_addr <= sample_addr;
                            -- Decrement the sample address (moving earlier in time)
                            -- handling wrapping from the buffer start back to the buffer end
                            if sample_addr = BUFFER_BASE(to_integer(current_channel)) then
                                sample_addr <= to_unsigned(buffer_end, BUFFER_A_WIDTH);
                            else
                                sample_addr <= sample_addr - 1;
                            end if;
                            -- Increment the filter index by L (this doesn't neet to wrap)
                            coeff_index <= coeff_index + FILTER_L(to_integer(current_channel));
                            -- Decrement the multiply loop counter
                            if multiply_count = 0 then
                                state <= st_save;
                            else
                                multiply_count <= multiply_count - 1;
                            end if;
                        when st_save =>
                            -- This state reads the filter result (in
                            -- the accumulator) and saves it in sign
                            -- and magnitude format);
                            state <= st_stall1;
                        when st_stall1 =>
                            -- We now need to stall the pipline for a
                            -- few cycles before the final scalimg of
                            -- the channel.
                            state <= st_stall2;
                        when st_stall2 =>
                            state <= st_stall3;
                        when st_stall3 =>
                            state <= st_scale_lsb;
                        when st_scale_lsb =>
                            -- Calculate the least significant half of
                            -- the scaled filter result. Scaling is by
                            -- L * Volume.
                            state <= st_scale_msb;
                        when st_scale_msb =>
                            -- Calculate the most significant half of
                            -- the scaled filter result.
                            state <= st_complete;
                        when st_complete =>
                            -- This state updates the channel phase
                            -- k(i) and the buffer read pointer
                            -- rd_addr(i) ready for computing the next
                            -- sample.
                            --
                            -- It's equivalent to the following C code:
                            --   k += M % L;
                            --   if (k >= L) {
                            --     k -= L;
                            --     n += (M / L) + 1;
                            --   } else {
                            --     n += (M / L);
                            --   }
                            tmp_k := k(to_integer(current_channel)) + M_MOD_L(to_integer(current_channel));
                            tmp_n := "0" & (rd_addr(to_integer(current_channel)) + to_unsigned(M_DIV_L(to_integer(current_channel)), BUFFER_A_WIDTH));
                            if tmp_k >= FILTER_L(to_integer(current_channel)) then
                                tmp_k := tmp_k - FILTER_L(to_integer(current_channel));
                                tmp_n := tmp_n + 1;
                            end if;
                            k(to_integer(current_channel)) <= tmp_k;
                            -- Handle wrapping
                            if tmp_n > buffer_end then
                                tmp_n := tmp_n - BUFFER_SIZE(to_integer(current_channel));
                            end if;
                            rd_addr(to_integer(current_channel)) <= tmp_n(BUFFER_A_WIDTH - 1 downto 0);
                            -- Move on to the next channel, or loop back to idle if done
                            if current_channel = NUM_CHANNELS - 1 then
                                current_channel <= (others => '0');
                                state <= st_idle;
                            else
                                current_channel <= current_channel + 1;
                                state <= st_setup;
                            end if;
                        when others =>
                            state <= st_idle;
                     end case;
                 end if;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------------
    -- DSP pipeline control
    ----------------------------------------------------------------------------------

    process(clk)
    begin
        if rising_edge(clk) then
            -- Control signals delayed to match the pipeline depth
            for i in pipe_state'high downto pipe_state'low + 1 loop
                pipe_state(i) <= pipe_state(i - 1);
            end loop;
            pipe_state(pipe_state'low) <= state;
            for i in pipe_channel'high downto pipe_channel'low + 1 loop
                pipe_channel(i) <= pipe_channel(i - 1);
            end loop;
            pipe_channel(pipe_channel'low) <= current_channel;
        end if;
    end process;

    ----------------------------------------------------------------------------------
    -- DSP pipeline stage 0 : Block RAM
    ----------------------------------------------------------------------------------

    -- Single Port Coefficient ROM
    inst_coeff_rom : entity work.coeff_rom
        generic map (
            A_WIDTH => COEFF_A_WIDTH,
            D_WIDTH => SAMPLE_WIDTH
            )
        port map (
            clk => clk,
            clk_en => clk_en,
            addr => coeff_rd_addr,
            data => coeff_rd_data
            );


    -- Dual Port Buffer RAM
    inst_buffer_ram : entity work.buffer_ram
        generic map (
            A_WIDTH => BUFFER_A_WIDTH,
            D_WIDTH => SAMPLE_WIDTH
            )
        port map (
            clk => clk,
            clk_en => clk_en,
            we => buffer_we,
            wr_addr => buffer_wr_addr,
            wr_data => buffer_wr_data,
            rd_addr => buffer_rd_addr,
            rd_data => buffer_rd_data
            );

    ----------------------------------------------------------------------------------
    -- DSP pipeline stage 1: Multiply operand selection
    ----------------------------------------------------------------------------------

    process(clk)
    begin
        if rising_edge(clk) then
            if clk_en = '1' then
                case pipe_state(1) is
                    when st_setup =>
                        -- Calculate a scale factor that is volume(8 bits) * L
                        mult_a_in <= to_signed(to_integer(volume), SAMPLE_WIDTH);
                        mult_b_in <= to_signed(FILTER_L(to_integer(current_channel)), SAMPLE_WIDTH);
                    when st_scale_lsb =>
                        -- Multiply the bottom half of the channel magnitude by the scale factor
                        mult_a_in <= channel_mag_lsb;
                        mult_b_in <= scale_factor;
                    when st_scale_msb =>
                        -- Multiply the top half of the channel magnitude by the scale factor
                        mult_a_in <= channel_mag_msb;
                        mult_b_in <= scale_factor;
                    when others =>
                        -- Default to getting operand from the block RAMs
                        mult_a_in <= coeff_rd_data;
                        mult_b_in <= buffer_rd_data;
                end case;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------------
    -- DSP pipeline stage 2 - 18x18 Multiply
    ----------------------------------------------------------------------------------

    process(clk)
    begin
        if rising_edge(clk) then
            if clk_en = '1' then
                mult_out <= mult_a_in * mult_b_in;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------------
    -- DSP pipeline stage 3a - Accumulator
    ----------------------------------------------------------------------------------

    -- Note: all the different stage 3 consume the multipler output

    process(clk)
    begin
        if rising_edge(clk) then
            if clk_en = '1' then
                if pipe_state(3) = st_setup then
                    -- Clear the accumulator
                    accumulator <= to_signed(0, accumulator'length);
                elsif pipe_state(3) = st_mult_accumulate then
                    -- Accumulate the next Sample * Coefficient value
                    accumulator <= accumulator + mult_out;
                end if;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------------
    -- DSP pipeline stage 3b - Calculate scale factor
    ----------------------------------------------------------------------------------

    process(clk)
    begin
        if rising_edge(clk) then
            if clk_en = '1' then
                if pipe_state(3) = st_setup then
                    -- Save the volume * L scale factor
                    scale_factor <= mult_out(SAMPLE_WIDTH - 1 downto 0);
                end if;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------------
    -- DSP pipeline stage 3c - Mix the channel into the left/right sums
    ----------------------------------------------------------------------------------

    process(clk)
        variable tmp_type  : t_channel_type;
        variable tmp_value : signed(SAMPLE_WIDTH * 2 - 1 downto 0);
    begin
        if rising_edge(clk) then
            if clk_en = '1' then
                -- Extract the channel type into a variable
                tmp_type := CHANNEL_TYPE(to_integer(pipe_channel(3)));
                -- The multipler result is the channel magnitue * scale factor; both are positive
                tmp_value := mult_out;
                if channel_sign = '1' then
                    tmp_value := -tmp_value;
                end if;
                case pipe_state(3) is
                    when st_scale_lsb =>
                        -- Update the mixer sum with the LSB partial product result
                        if tmp_type = left_channel or tmp_type = mono then
                            mixer_sum_l <= mixer_sum_l + tmp_value;
                        end if;
                        if tmp_type = right_channel or tmp_type = mono then
                            mixer_sum_r <= mixer_sum_r + tmp_value;
                        end if;
                    when st_scale_msb =>
                        -- Update the mixer sum with the MSB partial product result
                        -- This needs scaling by 2**(SAMPLE_WIDTH-1)
                        if tmp_type = left_channel or tmp_type = mono then
                            mixer_sum_l(SAMPLE_WIDTH * 2 - 1 downto SAMPLE_WIDTH - 1) <=
                                mixer_sum_l(SAMPLE_WIDTH * 2 - 1 downto SAMPLE_WIDTH - 1) + tmp_value(SAMPLE_WIDTH - 1 downto 0);
                        end if;
                        if tmp_type = right_channel or tmp_type = mono then
                            mixer_sum_r(SAMPLE_WIDTH * 2 - 1 downto SAMPLE_WIDTH - 1) <=
                                mixer_sum_r(SAMPLE_WIDTH * 2 - 1 downto SAMPLE_WIDTH - 1) + tmp_value(SAMPLE_WIDTH - 1 downto 0);
                        end if;
                    when st_output =>
                        mixer_sum_l <= to_signed(0, mixer_sum_l'length);
                        mixer_sum_r <= to_signed(0, mixer_sum_r'length);
                    when others =>
                        -- hold the currentt value
                end case;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------------
    -- DSP pipeline stage 3d - update the outputs
    ----------------------------------------------------------------------------------
    -- Pondering gain....
    --
    -- Input samples and filter coefficents are 18 bit signed numbers
    --
    -- The DSP pipeline does:
    --   [1]       filter = sum(input sample x filter coeffient)
    --   [2]  channel_mag = filter  >> FILTER_SHIFT (=16)
    --   [3]      channel = channel_mag * L * volume
    --   [4]   mixer_sum += channel * sign
    --
    -- The filter coefficients were calculated to provide an overall
    -- filter gain of 256. There is also a fixed scaling factor of
    -- 2^16 so the coefficients occupy as much of the 18-bits of
    -- precision as possible.
    --
    -- The interpolation process reduces the gain by a factor of L, so
    -- the overall gain at the end of step [1] is:
    --
    --    Music 5000: L=128 => Gain of   2.00 * 2^16
    --           PSG: L= 24 => Gain of  10.67 * 2^16
    --           SID: L=  6 => Gain of  42.67 * 2^16
    --    Note: the gain come from 256/L
    --
    -- Step [2] divides by 2^16, so the overall:
    --
    --    Music 5000: L=128 => Gain of  2.00
    --           PSG: L= 24 => Gain of 10.35
    --           SID: L=  6 => Gain of 42.67
    --
    -- Step [3] multiplies by L * volume (0..255), so overall:
    --
    -- All sources now have a gain of 256 * volume
    --
    --   [1] filter = sum(input sample x filter coeffient)
    --
    -- For our current sources and filter, the worst case number of
    -- multiplies is NTAPS (=3840) / Lmin = 3840 / 6 = 640. This is
    -- for the SID channel.
    --
    -- The inputs are 18 bit signed (1+17) so a minimum precision of
    -- 1 + 17 + 17 + ceil(log2(640)) = 45 bits.
    --
    -- In practice, this can be left to the DSP accumulator, which is
    -- 54 bits wide in Gowin and 48 bits wide in Xilinx/Altera. This
    -- is set by the ACCUMULATOR_WIDTH generic.
    --
    --   [2] channel_mag = filter >> 16
    --
    -- This needs 45 - 16 = 29 bits.
    --
    --   [3] channel = channel_mag * L * volume
    --
    -- This step is implemented as two partial multiplies
    --
    --    scale_factor = L * volume (precalculated)     [ 16 bits  ]
    -- channel_mag_lsb = channel_magnitude (16. .0)     [ 17 bits  ]
    -- channel_mag_msb = channel_magnitude (32..17)     [ 17 bits  ]
    --        product1 = channel_mag_lsb * scale_factor [ 33 bits  ]
    --        product2 = channel_mag_msb * scale_factor [ 33 bits? ]
    --         channel = product1 + product2 << 17      [ 51 bits? ]
    --
    -- At first inspection, it appears the result needs 51 bits!  But
    -- it's actually much less than this. One reason is L terms in
    -- scale_factor and channel_magnitude cancel out. This saves 7
    -- bits. The other is filter coefficients are calculated so the
    -- gain is fixed.
    --
    -- The channel result size is best thought of as needing:
    --    sample width: 18 bits (1+17)
    --     filter gain:  8 bits (fixed at 256)
    --          volume:  8 bits
    --                  --
    --                  34 bits
    --
    --   [4] mixer_sum += channel * sign
    --
    -- This is implemented by adding the two partial products.
    --
    --     mixer_sum += sign * product1
    --     mixer_sum += sign * product2 << 17
    --
    -- So using 2 * SAMPLE_WIDTH for the channel sum will suffice.
    --
    -- The final issue is mapping the mixer_sum (2 * SAMPLE_WIDTH=36)
    -- to the output port (OUTPUT_WIDTH=20)
    --
    -- The best way to think of the mixer sum is as a fixed point
    -- value with 33 digits to the right of the point:
    --     . <17 bits> <8 bits> <8 bits>
    --
    -- <17 bits> comes from the magnitude of the input values
    --  <8 bits> comes from the fixed filter gain of 256
    --  <8 bits> comes from the volume gain (assuming max volume of 255)
    --
    -- This now needs mapping to a final value that us OUTPUT_WIDTH
    -- (=20) bits wide.
    --
    -- This raises the question of overflow.
    --
    -- If we select the 20 bits to the right of the decimal point
    -- (bits 32..13) then with one source playing, even at at volume
    -- 255, it will never clip:
    --
    --                          mixer_sum
    --                     <bit 33> . <bit 32>            <bit 0>
    --                           |     |                       |
    --   <sign extesion + overflow> . <17 bits> <8 bits> <8 bits>
    --                       <sign> . <19 bits>         <14 bits>
    --
    -- If three sources are playing at the same time, then clipping is
    -- possible, bit if that happens the user can turn the volume
    -- down. So this seams reasonable.
    --
    -- But, the Music 5000 tracks can be well below the 0dB level,
    -- if only a few of the 16 possible channels are active.
    --
    -- It's probably better to arrange things so a volume of, say 64,
    -- would give unity gain. This then gives scope for the user to
    -- boost Music 5000 tracks by 12dB if necessary.
    --
    -- So instead of selecting bits 33..14, we select propose
    -- selecting bits 31..12 and range check to avoid clipping.
    --
    -- The RHS of this range is configured as a generic (OUTPUT_SHIFT).

    process(clk)
        variable tmp : signed(2 * SAMPLE_WIDTH - OUTPUT_SHIFT - 1 downto 0);
    begin
        if rising_edge(clk) then
            if clk_en = '1' then
                -- This actually happens much later, when the rate counter expires
                if pipe_state(3) = st_output then
                    mixer_strobe  <= '1';
                    -- Select the bits to output using OUTPUT_SHIFT as per above long discussion
                    tmp := mixer_sum_l(2 * SAMPLE_WIDTH - 1 downto OUTPUT_SHIFT);
                    if tmp < MIN_OUTPUT then
                        tmp := to_signed(MIN_OUTPUT, tmp'length);
                        clip_l <= '1';
                    elsif tmp > MAX_OUTPUT then
                        tmp := to_signed(MAX_OUTPUT, tmp'length);
                        clip_l <= '1';
                    else
                        clip_l <= '0';
                    end if;
                    mixer_l <= tmp(OUTPUT_WIDTH - 1 downto 0);
                    tmp := mixer_sum_r(2 * SAMPLE_WIDTH - 1 downto OUTPUT_SHIFT);
                    if tmp < MIN_OUTPUT then
                        tmp := to_signed(MIN_OUTPUT, tmp'length);
                        clip_r <= '1';
                    elsif tmp > MAX_OUTPUT then
                        clip_r <= '1';
                        tmp := to_signed(MAX_OUTPUT, tmp'length);
                    else
                        clip_r <= '0';
                    end if;
                    mixer_r <= tmp(OUTPUT_WIDTH - 1 downto 0);
                else
                    mixer_strobe  <= '0';
                end if;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------------
    -- DSP pipeline stage 4 - Save the filter result in sign/magnitude format
    ----------------------------------------------------------------------------------

    -- Note: stage 4 snapshots the accumulator into channel sign and
    -- magnitude registers. Thesefeeds back to stage 1, so the state
    -- machine must insert several stall states before using the
    -- channel sum/magnitude values

    process(clk)
        variable tmp : signed(SAMPLE_WIDTH * 2 - 1 downto 0);
        function fn_min(a : in integer; b : in integer) return integer is
        begin
            if a < b then
                return a;
            else
                return b;
            end if;
        end function;
    begin
        if rising_edge(clk) then
            if clk_en = '1' then
                if pipe_state(4) = st_save then
                    channel_sign <= '0';
                    -- Truncate to account for 2^15 scaling of filter coeffients for representation as integers
                    tmp := accumulator(fn_min(ACCUMULATOR_WIDTH - 1, SAMPLE_WIDTH * 2 + FILTER_SHIFT - 1) downto FILTER_SHIFT);
                    if tmp < 0 then
                        channel_sign <= '1';
                        tmp := -tmp;
                    else
                        channel_sign <= '0';
                    end if;
                    channel_mag_lsb <= signed("0" & std_logic_vector(tmp(SAMPLE_WIDTH     - 2 downto                0)));
                    channel_mag_msb <= signed("0" & std_logic_vector(tmp(SAMPLE_WIDTH * 2 - 3 downto SAMPLE_WIDTH - 1)));
                end if;
            end if;
        end if;
    end process;

end architecture;
