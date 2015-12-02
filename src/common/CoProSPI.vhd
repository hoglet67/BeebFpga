library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.tube_comp_pack.all;

entity CoProSPI is
    port (

        -- Host
        h_clk        : in    std_logic;
        h_cs_b       : in    std_logic;
        h_rdnw       : in    std_logic;
        h_addr       : in    std_logic_vector(2 downto 0);
        h_data_in    : in    std_logic_vector(7 downto 0);
        h_data_out   : out   std_logic_vector(7 downto 0);
        h_rst_b      : in    std_logic;
        h_irq_b      : out    std_logic;

        -- Parasite Clock (32 MHz)
        p_clk        : in    std_logic;

        -- SPI Slave
        p_spi_ssel   : in std_logic;
        p_spi_sck    : in std_logic;
        p_spi_mosi   : in std_logic;
        p_spi_miso   : out std_logic;

        -- Interrupts/Control
        p_irq_b      : out std_logic;
        p_nmi_b      : out std_logic;
        p_rst_b      : out std_logic;

        -- Test signals for debugging
        test         : out    std_logic_vector(7 downto 0)
    );
end;

architecture BEHAVIORAL of CoProSPI is

    signal p_rst_b_int   : std_logic;

    signal p_cs_b        : std_logic;
    signal p_rdnw        : std_logic;
    signal p_addr        : std_logic_vector (2 downto 0);
    signal p_data_in     : std_logic_vector (7 downto 0);
    signal p_data_out    : std_logic_vector (7 downto 0);

    signal di_req        : std_logic;
    signal di            : std_logic_vector (7 downto 0);
    signal wren          : std_logic;
    signal wr_ack        : std_logic;
    signal do_valid      : std_logic;
    signal do            : std_logic_vector (7 downto 0);

    type SPI_STATE_TYPE is (
        IDLE,
        CMD,
        WRITE1,
        WRITE2,
        READ1,
        READ2,
        READ3
    );

    signal spi_state : SPI_STATE_TYPE := IDLE;

begin

---------------------------------------------------------------------
-- instantiated components
---------------------------------------------------------------------

    inst_tube: tube port map (
        -- host
        h_addr          => h_addr,
        h_cs_b          => h_cs_b,
        h_data_in       => h_data_in,
        h_data_out      => h_data_out,
        h_phi2          => not h_clk,
        h_rdnw          => h_rdnw,
        h_rst_b         => h_rst_b,
        h_irq_b         => h_irq_b,
        -- parasite
        p_addr          => p_addr,
        p_cs_b          => p_cs_b,
        p_data_in       => p_data_in,
        p_data_out      => p_data_out,
        p_rdnw          => p_rdnw,
        p_phi2          => p_clk,
        p_rst_b         => p_rst_b_int,
        p_nmi_b         => p_nmi_b,
        p_irq_b         => p_irq_b,
        -- test
        test            => open
    );
    p_rst_b <= p_rst_b_int;

    inst_spi_slave : entity work.spi_slave
    generic map (
        N  => 8,                        -- 32bit serial word length is default
        CPOL => '0',                    -- SPI mode selection (mode 0 default)
        CPHA => '0',                    -- CPOL = clock polarity, CPHA = clock phase.
        PREFETCH => 3                   -- prefetch lookahead cycles
    )
    port map (
        clk_i           => p_clk,       -- internal interface clock (clocks di/do registers)
        spi_ssel_i      => p_spi_ssel,  -- spi bus slave select line
        spi_sck_i       => p_spi_sck,   -- spi bus sck clock (clocks the shift register core)
        spi_mosi_i      => p_spi_mosi,  -- spi bus mosi input
        spi_miso_o      => p_spi_miso,  -- spi bus spi_miso_o output
        di_req_o        => di_req,      -- preload lookahead data request line
        di_i            => di,          -- parallel load data in (clocked in on rising edge of clk_i)
        wren_i          => wren,        -- user data write enable
        wr_ack_o        => wr_ack,      -- write acknowledge
        do_valid_o      => do_valid,    -- do_o data valid strobe, valid during one clk_i rising edge.
        do_o            => do,          -- parallel output (clocked out on falling clk_i)
        --- debug ports
        do_transfer_o   => open,
        wren_o          => open,
        rx_bit_next_o   => open,
        state_dbg_o     => open,
        sh_reg_dbg_o    => open
    );



---------------------------------------------------------------------
-- State Machine Interfacing SPI
---------------------------------------------------------------------

-- This first transmitted by from the Pi would be the addressing byte.
-- The most significant bit would be the Read/ NotWrite bit, the middle
-- 4 bits would be always zero and then the 3 least significant bits
-- would be A2, A1, A0.
-- After the first byte if writing the subsequent bytes sent from the
-- Pi would fill the FIFO.
-- After the first byte if reading the subsequent bytes from the FPGA
-- will be from the FIFO/ Register.

-- Master -> Slave:

    -- Connext the data paths directly together
    p_data_in <= do;
    di <= p_data_out;

    process(p_clk)
    begin
        if rising_edge(p_clk) then
            if p_rst_b_int = '0' or p_spi_ssel = '1' then
                spi_state <= IDLE;
                p_addr <= (others => '1');
                p_rdnw <= '1';
                p_cs_b <= '1';
                wren   <= '0';
            else
                case spi_state is
                -- Wait for command, then latch it
                when IDLE =>
                    if do_valid = '1' then
                        if do(6 downto 3) = "0000" then
                            p_addr <= do(2 downto 0);
                            p_rdnw <= do(7);
                            spi_state <= CMD;
                        end if;
                    end if;
                -- Command received, wait for do_valid to be re-asserted
                when CMD =>
                    if do_valid = '0' then
                        if p_rdnw = '0' then
                            spi_state <= WRITE1;
                        else
                            spi_state <= READ1;
                        end if;
                    end if;
                -- Process write command
                when WRITE1 =>
                    if do_valid = '1' then
                        -- assert CS for one cycle
                        p_cs_b <= '0';
                        spi_state <= WRITE2;
                    end if;
                when WRITE2 =>
                    p_cs_b <= '1';
                    if do_valid = '0' then
                        spi_state <= IDLE;
                    end if;
                -- Process read command
                when READ1 =>
                    p_cs_b <= '0';
                    spi_state <= READ2;
                when READ2 =>
                    p_cs_b <= '0';
                    wren <= '1';
                    spi_state <= READ3;
                when READ3 =>
                    p_cs_b <= '1';
                    wren <= '0';
                    if wr_ack = '1' then
                        spi_state <= IDLE;
                    end if;
                when others =>
                    spi_state <= IDLE;
                end case;
            end if;
        end if;
    end process;

    test(0) <= '1' when spi_state = IDLE   else '0';
    test(1) <= '1' when spi_state = CMD    else '0';
    test(2) <= '1' when spi_state = WRITE1 else '0';
    test(3) <= '1' when spi_state = WRITE2 else '0';
    test(4) <= '1' when spi_state = READ1  else '0';
    test(5) <= '1' when spi_state = READ2  else '0';
    test(6) <= '1' when spi_state = READ3  else '0';

end BEHAVIORAL;
