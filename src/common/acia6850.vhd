--===========================================================================--
--                                                                           --
--                  Synthesizable 6850 compatible ACIA                       --
--                                                                           --
--===========================================================================--
--
--  File name      : acia6850.vhd
--
--  Entity name    : acia6850
--
--  Purpose        : Implements a RS232 6850 compatible
--                   Asynchronous Communications Interface Adapter (ACIA)
--
--  Dependencies   : ieee.std_logic_1164
--                   ieee.numeric_std
--                   ieee.std_logic_unsigned
--
--  Author         : John E. Kent
--
--  Email          : dilbert57@opencores.org
--
--  Web            : http://opencores.org/project,system09
--
--  Origins        : miniUART written by Ovidiu Lupas olupas@opencores.org
--
--  Registers      :
--
--  IO address + 0 Read - Status Register
--
--     Bit[7] - Interrupt Request Flag
--     Bit[6] - Receive Parity Error (parity bit does not match)
--     Bit[5] - Receive Overrun Error (new character received before last read)
--     Bit[4] - Receive Framing Error (bad stop bit)
--     Bit[3] - Clear To Send level
--     Bit[2] - Data Carrier Detect (lost modem carrier)
--     Bit[1] - Transmit Buffer Empty (ready to accept next transmit character)
--     Bit[0] - Receive Data Ready (character received)
--
--  IO address + 0 Write - Control Register
--
--     Bit[7]     - Rx Interupt Enable
--          0     - disabled
--          1     - enabled
--     Bits[6..5] - Transmit Control
--        0 0     - TX interrupt disabled, RTS asserted
--        0 1     - TX interrupt enabled,  RTS asserted
--        1 0     - TX interrupt disabled, RTS cleared
--        1 1     - TX interrupt disabled, RTS asserted, Send Break
--     Bits[4..2] - Word Control
--      0 0 0     - 7 data, 2 stop, even parity
--      0 0 1     - 7 data, 2 stop, odd  parity
--      0 1 0     - 7 data, 1 stop, even parity
--      0 1 1     - 7 data, 1 stop, odd  parity
--      1 0 0     - 8 data, 2 stop, no   parity
--      1 0 1     - 8 data, 1 stop, no   parity
--      1 1 0     - 8 data, 1 stop, even parity
--      1 1 1     - 8 data, 1 stop, odd  parity
--     Bits[1..0] - Baud Control
--        0 0     - Baud Clk divide by 1
--        0 1     - Baud Clk divide by 16
--        1 0     - Baud Clk divide by 64
--        1 1     - Reset
--
--  IO address + 1 Read - Receive Data Register
--
--     Read when Receive Data Ready bit set
--     Read resets Receive Data Ready bit
--
--  IO address + 1 Write - Transmit Data Register
--
--     Write when Transmit Buffer Empty bit set
--     Write resets Transmit Buffer Empty Bit
--
--
--  Copyright (C) 2002 - 2012 John Kent
--
--  This program is free software: you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation, either version 3 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
--===========================================================================--
--                                                                           --
--                              Revision  History                            --
--                                                                           --
--===========================================================================--
--
-- Version Author        Date         Changes
--
-- 0.1     Ovidiu Lupas  2000-01-15   New model
-- 1.0     Ovidiu Lupas  2000-01      Synthesis optimizations
-- 2.0     Ovidiu Lupas  2000-04      Bugs removed - the RSBusCtrl did not
--                                    process all possible situations
--
-- 3.0     John Kent     2002-10      Changed Status bits to match MC6805
--                                    Added CTS, RTS, Baud rate control & Software Reset
-- 3.1     John Kent     2003-01-05   Added Word Format control a'la mc6850
-- 3.2     John Kent     2003-07-19   Latched Data input to UART
-- 3.3     John Kent     2004-01-16   Integrated clkunit in rxunit & txunit
--                                    TX / RX Baud Clock now external
--                                    also supports x1 clock and DCD.
-- 3.4     John Kent     2005-09-13   Removed LoadCS signal.
--                                    Fixed ReadCS and Read
--                                    in miniuart_DCD_Init process
-- 3.5     John Kent     2006-11-28   Cleaned up code.
--
-- 4.0     John Kent     2007-02-03   Renamed ACIA6850
-- 4.1     John Kent     2007-02-06   Made software reset synchronous
-- 4.2     John Kent     2007-02-25   Changed sensitivity lists
--                                    Rearranged Reset process.
-- 4.3     John Kent     2010-06-17   Updated header
-- 4.4     John Kent     2010-08-27   Combined with ACIA_RX & ACIA_TX
--                                    Renamed to acia6850
-- 4.5     John Kent     2012-02-04   Re-arranged Rx & Tx Baud clock edge detect.
-- 4.6     John Kent     3021-01-30   Double sample RxC, TxC, and RxD with cpu_clk
--                                    for 125MHz Clock on Zybo Z7 board.
--

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.std_logic_unsigned.all;
--library unisim;
--  use unisim.vcomponents.all;

-----------------------------------------------------------------------
-- Entity for ACIA_6850                                              --
-----------------------------------------------------------------------

entity acia6850 is
  port (
    --
    -- CPU Interface signals
    --
    clk      : in  std_logic;                     -- CPU Clock
    rst      : in  std_logic;                     -- Reset input (active high)
    cs       : in  std_logic;                     -- miniUART Chip Select
    addr     : in  std_logic;                     -- Register Select
    rw       : in  std_logic;                     -- Read / Not Write
    data_in  : in  std_logic_vector(7 downto 0);  -- Data Bus In
    data_out : out std_logic_vector(7 downto 0);  -- Data Bus Out
    irq      : out std_logic;                     -- Interrupt Request out
    --
    -- RS232 Interface Signals
    --
    RxC   : in  std_logic;              -- Receive Baud Clock
    TxC   : in  std_logic;              -- Transmit Baud Clock
    RxD   : in  std_logic;              -- Receive Data
    TxD   : out std_logic;              -- Transmit Data
    DCD_n : in  std_logic;              -- Data Carrier Detect
    CTS_n : in  std_logic;              -- Clear To Send
    RTS_n : out std_logic               -- Request To send
    );
end acia6850;  --================== End of entity ==============================--

-------------------------------------------------------------------------------
-- Architecture for ACIA_6850 Interface registees
-------------------------------------------------------------------------------

architecture rtl of acia6850 is

  -----------------------------------------------------------------------------
  -- Reset Signals
  -----------------------------------------------------------------------------
  signal ac_rst        : std_logic;          -- Reset (Software & Hardware)
  signal rx_rst        : std_logic;          -- Receive Reset (Software & Hardware)
  signal tx_rst        : std_logic;          -- Transmit Reset (Software & Hardware)

  --------------------------------------------------------------------
  --  Status Register: status_reg
  ----------------------------------------------------------------------
  --
  -----------+--------+-------+--------+--------+--------+--------+--------+
  --  Irq    | PErr   | OErr  | FErr   |  CTS   |  DCD   | TxRdy  | RxRdy  |
  -----------+--------+-------+--------+--------+--------+--------+--------+
  --
  -- Irq   - Bit[7] - Interrupt request
  -- PErr  - Bit[6] - Receive Parity error (parity bit does not match)
  -- OErr  - Bit[5] - Receive Overrun error (new character received before last read)
  -- FErr  - Bit[4] - Receive Framing Error (bad stop bit)
  -- CTS   - Bit[3] - Clear To Send level
  -- DCD   - Bit[2] - Data Carrier Detect (lost modem carrier)
  -- TxRdy - Bit[1] - Transmit Buffer Empty (ready to accept next transmit character)
  -- RxRdy - Bit[0] - Receive Data Ready (character received)
  --
  constant RXRBIT       : integer := 0; -- Receive Data Ready
  constant TXRBIT       : integer := 1; -- Transmir Data Ready
  constant DCDBIT       : integer := 2; -- Data Carrier Detect
  constant CTSBIT       : integer := 3; -- Clear To Send (inverted)
  constant FERBIT       : integer := 4; -- Framing Error
  constant OERBIT       : integer := 5; -- Over Run Error
  constant PERBIT       : integer := 6; -- Parity error
  constant IRQBIT       : integer := 7; -- Interrupt Request Flag


  ----------------------------------------------------------------------
  --  Control Register: control_reg
  ----------------------------------------------------------------------
  --
  -----------+--------+--------+--------+--------+--------+--------+--------+
  --  RIEBIT | TX1BIT | TX0BIT | DATBIT | STPBIT | POEBIT | BD1BIT | BD0BIT |
  -----------+--------+--------+--------+--------+--------+--------+--------+
  -- RIEBIT - Bit[7]
  -- 0       - Rx Interrupt disabled
  -- 1       - Rx Interrupt enabled
  --
  -- TXnBIT - Bits[6..5]
  -- 0 0     - RTS low,  Tx Interrupt Disabled
  -- 0 1     - RTS low,  Tx Interrupt Enable
  -- 1 0     - RTS high, Tx interrupt Disabled
  -- 1 1     - RTS low,  Tx interrupt Disabled, send break
  --
  -- DATBIT, STPBIT, POEBIT - Bits[4..2]
  -- 0 0 0   - 7 data, 2 stop, even parity
  -- 0 0 1   - 7 data, 2 stop, odd  parity
  -- 0 1 0   - 7 data, 1 stop, even parity
  -- 0 1 1   - 7 data, 1 stop, odd  parity
  -- 1 0 0   - 8 data, 2 stop, no   parity
  -- 1 0 1   - 8 data, 1 stop, no   parity
  -- 1 1 0   - 8 data, 1 stop, even parity
  -- 1 1 1   - 8 data, 1 stop, odd  parity
  -- BDnBIT - Bits[1..0]
  -- 0 0     - Baud Clk divide by 1
  -- 0 1     - Baud Clk divide by 16
  -- 1 0     - Baud Clk divide by 64
  -- 1 1     - reset

  constant BD0BIT       : integer := 0; -- Baud clock divider 0=>1/64 1=>16/RESET
  constant BD1BIT       : integer := 1; -- Baud clock divider 0=>1/16 1=>64/RESET
  constant POEBIT       : integer := 2; -- parity 0=>even 1=>odd            (ctrl(DATBIT)=1 & ctrl(STPBIT)=0 => no parity)
  constant STPBIT       : integer := 3; -- stop bits 0=>2 stop 1=>1 stop    (ctrl(DATBIT)=1 & ctrl(STPBIT)=0 & ctrl(POEBIT)=1 => 1 stop bit)
  constant DATBIT       : integer := 4; -- data bits 0=>7 data bits 1=>8 data bits
  constant TX0BIT       : integer := 5; -- Transmit control 0=>TX IRQ disabled 1=>RTS_N low
  constant TX1BIT       : integer := 6; -- Transmit control 1=>TX IRQ disabled 0=>RTS_N low (ctrl(TX0BIT)=1 & ctrl(TX1BIT)=1 => break)
  constant RIEBIT       : integer := 7; -- receive interrupt enable

  signal status_reg     : std_logic_vector(7 downto 0) := (others => '0'); -- status register        IO+0 RW=1
  signal control_reg    : std_logic_vector(7 downto 0) := (others => '0'); -- control register       IO+0 RW=0
  signal rx_data_reg    : std_logic_vector(7 downto 0) := (others => '0'); -- receive data register  IO+1 RW=1
  signal tx_data_reg    : std_logic_vector(7 downto 0) := (others => '0'); -- transmit data registet IO+1 RW=0

  signal status_read    : std_logic := '0';   -- Read status register
  signal rx_data_read   : std_logic := '0';   -- Read receive buffer
  signal tx_data_write  : std_logic := '0';   -- Write Transmit buffer

  signal RxRdy          : std_logic := '0';   -- Receive Data ready
  signal TxRdy          : std_logic := '1';   -- Transmit buffer empty
  signal DCDInt         : std_logic := '0';   -- DCD Interrupt
  signal FErr           : std_logic := '0';   -- Receive Data ready
  signal OErr           : std_logic := '0';   -- Receive Data ready
  signal PErr           : std_logic := '0';   -- Receive Data ready
  signal TxIE           : std_logic := '0';   -- Transmit interrupt enable
  signal RxIE           : std_logic := '0';   -- Receive interrupt enable

  --
  -- status register error bit controls
  --
  signal status_rxr_set : std_logic := '0';
  signal status_txr_set : std_logic := '0';
  signal status_fer_set : std_logic := '0';
  signal status_fer_clr : std_logic := '0';
  signal status_oer_set : std_logic := '0';
  signal status_oer_clr : std_logic := '0';
  signal status_per_set : std_logic := '0';
  signal status_per_clr : std_logic := '0';


  type dcd_state_type is (DCD_State_Idle, DCD_State_Int, DCD_State_Reset);

  signal DCDState       : DCD_State_Type;     -- DCD Reset state sequencer
  signal DCDDel         : std_logic := '0';   -- Delayed DCD_n
  signal DCDEdge        : std_logic := '0';   -- Rising DCD_N Edge Pulse

  -----------------------------------------------------------------------------
  -- RX & TX state machine types
  -----------------------------------------------------------------------------

  type state_type is ( start_state, data_state, parity_state, stop_state,  idle_state );

  -----------------------------------------------------------------------------
  -- RX Signals
  -----------------------------------------------------------------------------

  signal rx_current_state : state_type;                 -- receive bit current state
  signal rx_next_state    : state_type;                 -- receive bit next state

  signal RxDat          : std_logic := '1';                     -- Resampled RxD bit
  signal RxDDel         : Std_Logic_Vector(1 downto 0) := "11"; -- Delayed RxD Input
  signal RxDEdge        : Std_Logic := '0';                     -- RxD Edge pulse
  signal RxCDel         : Std_Logic_Vector(1 downto 0) := "00"; -- Delayed RxC Input
  signal RxCEdge        : Std_Logic := '0';                     -- RxC Edge pulse
  signal RxClkCnt       : Std_Logic_Vector(5 downto 0) := (others => '0'); -- Rx Baud Clock Counter
  signal RxBdClk        : Std_Logic := '0';             -- Rx Baud Clock
  signal RxBdDel        : Std_Logic := '0';             -- Delayed Rx Baud Clock
  signal RxBdEdgeRise   : Std_Logic := '0';             -- Rx Baud Clock rising edge
  signal RxBdEdgeFall   : Std_Logic := '0';             -- Rx Baud Clock falling edge

  signal rx_parity      : Std_Logic := '0';             -- Calculated RX parity bit
  signal rx_bit_count   : Std_Logic_Vector(3 downto 0) := (others => '0');  -- Rx Bit counter
  signal rx_shift_reg   : Std_Logic_Vector(7 downto 0) := (others => '0');  -- Shift Register

  -----------------------------------------------------------------------------
  -- TX Signals
  -----------------------------------------------------------------------------

  signal tx_current_state : state_type;                 -- Transmitter current state
  signal tx_next_state    : state_type;                 -- Transmitter next state

  signal TxOut          : std_logic := '1';             -- Transmit data bit
  signal TxDat          : std_logic := '1';             -- Transmit data bit
  signal TxCDel         : Std_Logic_Vector(1 downto 0) := "00";             -- Delayed TxC Input
  signal TxCEdge        : Std_Logic := '0';             -- TxC Edge pulse
  signal TxClkCnt       : Std_Logic_Vector(5 downto 0) := (others => '0');  -- Tx Baud Clock Counter
  signal TxBdClk        : Std_Logic := '0';             -- Tx Baud Clock
  signal TxBdDel        : Std_Logic := '0';             -- Delayed Tx Baud Clock
  signal TxBdEdgeRise   : Std_Logic := '0';             -- Tx Baud Clock rising edge
  signal TxBdEdgeFall   : Std_Logic := '0';             -- Tx Baud Clock falling edge

  signal tx_parity      : Std_logic := '0';              -- Parity Bit
  signal tx_bit_count   : Std_Logic_Vector(3 downto 0) := (others => '0');  -- Data Bit Counter
  signal tx_shift_reg   : Std_Logic_Vector(7 downto 0) := (others => '0');  -- Transmit shift register
  --
  -- Data register controls
  --
  type data_reg_type   is (data_reg_rst,  data_reg_load,   data_reg_idle);
  signal rx_data_ctrl   : data_reg_type;

  --
  -- Shift register controls
  --
  type shift_reg_type  is (shift_reg_rst, shift_reg_load, shift_reg_shift, shift_reg_idle);
  signal rx_shift_ctrl  : shift_reg_type;
  signal tx_shift_ctrl  : shift_reg_type;

  --
  -- Count register controls
  --
  type count_reg_type  is (count_reg_rst, count_reg_decr,  count_reg_idle);
  signal rx_count_ctrl  : count_reg_type;
  signal tx_count_ctrl  : count_reg_type;

begin

---------------------------------------------------------------
-- ACIA Reset may be hardware or software
---------------------------------------------------------------
  acia_reset : process( clk, ac_rst, dcd_n )
  begin
    --
    -- ACIA reset Synchronous
    -- Includes software reset
    --
    if falling_edge(clk) then
      ac_rst <= (control_reg(1) and control_reg(0)) or rst;
    end if;
    -- Receiver reset
    rx_rst <= ac_rst or DCD_n;
    -- Transmitter reset
    tx_rst <= ac_rst;

  end process;


-----------------------------------------------------------------------------
-- Generate Read / Write strobes.
-----------------------------------------------------------------------------

  acia_read_write : process( clk )
  begin
    if falling_edge(clk) then
      status_read   <= '0';
      tx_data_write <= '0';
      rx_data_read  <= '0';
      if rst = '1' then
        control_reg(1 downto 0) <= "11";
        control_reg(7 downto 2) <= (others => '0');
        tx_data_reg   <= (others => '0');
      else
        if cs = '1' then
          if addr = '0' then              -- Control / Status register
            if rw = '0' then              -- write control register
              control_reg   <= data_in;
            else                          -- read status register
              status_read   <= '1';
            end if;
          else                            -- Data Register
            if rw = '0' then              -- write transmiter register
              tx_data_reg <= data_in;
              tx_data_write <= '1';
            else                          -- read receiver register
              rx_data_read  <= '1';
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- ACIA Status Register
  -----------------------------------------------------------------------------

  acia_status : process( RxRdy, TxRdy, DCDInt, CTS_n, FErr, OErr, PErr, RxIE, TxIE,  status_reg, control_reg )
  begin
    TxIE <= (not control_reg(TX1BIT)) and control_reg(TX0BIT);
    RxIE <= control_reg(RIEBIT);
    status_reg(RXRBIT) <= RxRdy;
    status_reg(TXRBIT) <= TxRdy and (not CTS_n);
    status_reg(DCDBIT) <= DCDInt;                -- Data Carrier Detect
    status_reg(CTSBIT) <= CTS_n;                 -- Clear To Send
    status_reg(FERBIT) <= FErr;
    status_reg(OERBIT) <= OErr;
    status_reg(PERBIT) <= PErr;
    status_reg(IRQBIT) <= (RxIE and RxRdy) or
                          (RxIE and DCDInt) or
                          (TxIE and TxRdy and (not CTS_n));
    irq <= status_reg(IRQBIT);
  end process;

  -----------------------------------------------------------------------------
  -- ACIA Rx data ready status
  -----------------------------------------------------------------------------

  acia_rx_data_ready : process( clk )
  begin
    if falling_edge( clk ) then
      if rx_rst = '1' then
        RxRdy <= '0';
      else
        if RxBdEdgeFall = '1' and status_rxr_set = '1' then
          RxRdy <= '1';
        elsif rx_data_read  = '1' then
          RxRdy <= '0';
        end if;
      end if;
    end if;
  end process;


  -----------------------------------------------------------------------------
  -- ACIA Tx data ready status
  -----------------------------------------------------------------------------

  acia_tx_data_ready : process( clk )
  begin
    if falling_edge( clk ) then
      if tx_rst = '1' then
         TxRdy <= '1';
      else
        if TxBdEdgeRise = '1' and status_txr_set = '1' then
          TxRdy <= '1';
        elsif  tx_data_write  = '1' then
          TxRdy <= '0';
        end if;
      end if;
    end if;
  end process;


  -----------------------------------------------------------------------------
  -- ACIA Framing Error
  -----------------------------------------------------------------------------

  acia_fer_status : process( clk )
  begin
    if falling_edge( clk ) then
      if rx_rst = '1' then
        FErr <= '0';
      elsif RxBdEdgeFall = '1' then
        if status_fer_clr = '1' then
          FErr <= '0';
        end if;
        if status_fer_set = '1' then
          FErr <= '1';
        end if;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- ACIA Over-run Error
  -----------------------------------------------------------------------------

  acia_oer_status : process( clk )
  begin
    if falling_edge( clk ) then
      if rx_rst = '1' then
        OErr <= '0';
      elsif RxBdEdgeFall = '1' then
        if status_oer_set = '1' then
          OErr <= '1';
        end if;
        if status_oer_clr = '1' or rx_data_read = '1' then
          OErr <= '0';
        end if;
      end if;
    end if;
  end process;


  -----------------------------------------------------------------------------
  -- ACIA Parity Error
  -----------------------------------------------------------------------------

  acia_per_status : process( clk )
  begin
    if falling_edge( clk ) then
      if rx_rst = '1' then
        PErr <= '0';
      elsif RxBdEdgeFall = '1' and status_per_set = '1' then
        PErr <= '1';
      elsif RxBdEdgeFall = '1' and status_per_clr = '1' then
        PErr <= '0';
      elsif rx_data_read = '1' then
        PErr <= '0';
      end if;
    end if;
  end process;

---------------------------------------------------------------
-- Set Data Output Multiplexer
--------------------------------------------------------------

  acia_data_mux : process( addr, rx_data_reg, status_reg )
  begin
    if addr = '1' then
      data_out <= rx_data_reg;               -- read receiver register
    else
      data_out <= status_reg;               -- read status register
    end if;
  end process;

---------------------------------------------------------------
-- Data Carrier Detect Edge rising edge detect
---------------------------------------------------------------
  acia_dcd_edge : process( clk )
  begin
    if falling_edge(clk) then
      if ac_rst = '1' then
        DCDDel  <= '0';
        DCDEdge <= '0';
      else
        DCDDel  <= DCD_n;
        DCDEdge <= DCD_n and (not DCDDel);
      end if;
    end if;
  end process;


---------------------------------------------------------------
-- Data Carrier Detect Interrupt
---------------------------------------------------------------
-- If Data Carrier is lost, an interrupt is generated
-- To clear the interrupt, first read the status register
--      then read the data receive register

  acia_dcd_int : process( clk )
  begin
    if falling_edge(clk) then
      if ac_rst = '1' then
        DCDInt   <= '0';
        DCDState <= DCD_State_Idle;
      else
        case DCDState is
        when DCD_State_Idle =>
          -- DCD Edge activates interrupt
          if DCDEdge = '1' then
            DCDInt   <= '1';
            DCDState <= DCD_State_Int;
          end if;
        when DCD_State_Int =>
          -- To reset DCD interrupt,
          -- First read status
          if status_read = '1' then
            DCDState <= DCD_State_Reset;
          end if;
        when DCD_State_Reset =>
          -- Then read receive register
          if rx_data_read = '1' then
            DCDInt   <= '0';
            DCDState <= DCD_State_Idle;
          end if;
        when others =>
          null;
        end case;
      end if;
    end if;
  end process;


  ---------------------------------------------------------------------
  -- Receiver Clock Edge Detection
  ---------------------------------------------------------------------
  -- A rising edge will produce a one CPU clock cycle pulse
  --
  acia_rx_clock_edge : process( clk )
  begin
    if falling_edge(clk) then
      if rx_rst = '1' then
        RxCDel  <= "00";
        RxCEdge <= '0';
      else
        --
        -- RxClkEdge is one CPU clock cycle wide
        --
        RxCDel(0) <= RxC;
        RxCDel(1) <= RxCDel(0);
        RxCEdge <= (not RxCDel(1)) and RxCDel(0);
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------
  -- Receiver Data Edge Detection
  ---------------------------------------------------------------------
  --
  -- If there is a falling edge on the RxD line
  -- and the ACIA receiver is in the start, stop or idle state
  -- RxDatEdge is generated to reset the Baud Clock divide
  -- so that it is synchronized to the edge of the data
  -- 2021-01-30 JEK Double clock RxD
  acia_rx_data_edge : process( clk )
  begin
    if falling_edge(clk) then
      if (rx_rst = '1') then
        RxDDel(0) <= RxD;
		  RxDDel(1) <= RxDDel(0);
        RxDEdge <= '0';
      else
        RxDDel(0) <= RxD;
		  RxDDel(1) <= RxDDel(0);
        RxDEdge <= not(RxDDel(0)) and RxDDel(1);
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------
  -- Receiver Clock Divider
  ---------------------------------------------------------------------
  -- Hold the Rx Clock divider in reset when the receiver is disabled
  -- Advance the count only on a rising Rx clock edge
  --
  acia_rx_clock_divide : process( clk )
  begin
    if falling_edge(clk) then
      if (rx_rst = '1') or (RxDEdge = '1') then
        --
        -- Reset counter on rx_rst or falling data edge
        --
        RxClkCnt  <= (others => '0');
      elsif RxCEdge = '1' then
        --
        -- increment count on Rx Clock edge
        --
        RxClkCnt <= RxClkCnt + "000001";
      end if;
    end if;
  end process;


-----------------------------------------------------------------------------
-- ACIA RX Baud select
-----------------------------------------------------------------------------
-- 2021-01-30 JEK change RxC to RxCDel(0)
  acia_rx_baud_control : process( clk )
  begin
    ---------------------------------------------------------------------
    -- Receive Baud Clock Selector
    ---------------------------------------------------------------------
    -- control_reg(BD1BIT downto BD0BIT)
    -- 0 0     - Baud Clk divide by 1
    -- 0 1     - Baud Clk divide by 16
    -- 1 0     - Baud Clk divide by 64
    -- 1 1     - reset
    if falling_edge(clk) then
      case control_reg(BD1BIT downto BD0BIT) is
      when "00" =>	                         -- Div by 1
        RxBdClk <= RxCDel(0);
      when "01" =>	                         -- Div by 16
        RxBdClk <= RxClkCnt(3);
      when "10" =>	                         -- Div by 64
        RxBdClk <= RxClkCnt(5);
      when others =>                          -- Software reset
        RxBdClk <= '0';
      end case;
    end if;

  end process;


  ---------------------------------------------------------------------
  -- Receiver Baud Clock Edge Detection
  ---------------------------------------------------------------------
  -- A Rising Baud Clock edge will produce a single CPU clock pulse
  --
  acia_rx_baud_edge : process( clk )
  begin
    if falling_edge(clk) then
      if rx_rst = '1' then
        RxBdDel      <= '0';
        RxBdEdgeRise <= '0';
        RxBdEdgeFall <= '0';
      else
        RxBdDel      <= RxBdClk;
        RxBdEdgeRise <= not(RxBdDel) and     RxBdClk;
        RxBdEdgeFall <=     RxBdDel  and not(RxBdClk);
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------
  -- Receiver process
  ---------------------------------------------------------------------
  -- WdFmt - Bits[4..2]
  -- 0 0 0   - 7 data, even parity, 2 stop
  -- 0 0 1   - 7 data, odd  parity, 2 stop
  -- 0 1 0   - 7 data, even parity, 1 stop
  -- 0 1 1   - 7 data, odd  parity, 1 stop
  -- 1 0 0   - 8 data, no   parity, 2 stop
  -- 1 0 1   - 8 data, no   parity, 1 stop
  -- 1 1 0   - 8 data, even parity, 1 stop
  -- 1 1 1   - 8 data, odd  parity, 1 stop
  --
  -- Registers activated on rising bit clock edge
  -- State transitions on falling bit clock edge
  --
  acia_rx_receive : process( rx_current_state, control_reg, rx_bit_count, RxDat, rx_parity, RxRdy )
  begin
          rx_data_ctrl   <= data_reg_idle;
          rx_shift_ctrl  <= shift_reg_idle;
          rx_next_state  <= start_state;

          status_rxr_set <= '0';                       -- receive data ready
          status_fer_clr <= '0';                       -- framing error status
          status_fer_set <= '0';                       -- framing error status
          status_oer_clr <= '0';                       -- over-run error status
          status_oer_set <= '0';                       -- over-run error status
          status_per_clr <= '0';                       -- parity  error status
          status_per_set <= '0';                       -- parity  error status

          case rx_current_state is
          when start_state =>
            rx_shift_ctrl <= shift_reg_rst;            -- Reset Shift register on rising baud clock
            if RxDat = '0' then                        -- RxDat = '0' => start bit
              rx_next_state <= data_state;             -- if low, start shifting in data
            end if;

          when data_state =>                           -- Receiving data bits
            --  on rising baud clock edge
            rx_shift_ctrl <= shift_reg_shift;          -- shift in data bit

            -- on falling baud clock edge transition state
            if rx_bit_count = "0000" then               -- All bits shifted in ?
              --                                       -- yes, transition to parity or stop state
              -- if control_reg(DATBIT) = '1' and control_reg(STPBIT) = '0'
              -- then 8 data bit, no parity
              --
              if control_reg(DATBIT)='1' and control_reg(STPBIT)='0' then
                rx_next_state  <= stop_state;          -- 8 data, 1 or 2 stops, no parity => stop_state
              else
                rx_next_state <= parity_state;         -- control_reg(DATBIT) = '0' => 7 data + parity or
              end if;                                  -- control_reg(STPBIT) = '1' => 8 data + parity => parity_state
            else
              rx_next_state <= data_state;             -- bit count none zero => remain in data state
            end if;

          when parity_state =>                         -- Receive Parity bit
            -- on rising baud clock edge:
            if control_reg(DATBIT) = '0' then          -- if 7 data bits, shift parity into MSB
              rx_shift_ctrl <= shift_reg_shift;        -- 7 data + parity
            end if;

            -- on falling baud clock edge, set parity
            if rx_parity = (RxDat xor control_reg(POEBIT)) then
              status_per_set <= '1';                   -- set parity  error status
            else
              status_per_clr <= '1';                   -- resetset parity  error status
            end if;
            rx_next_state <= stop_state;

          when stop_state =>                           -- stop bit (Only one required for RX)
            -- on falling baud clock edge
            rx_data_ctrl   <= data_reg_load;             -- load receive data reg with shift register
            status_rxr_set <= '1';                       -- flag receive data ready

            -- on falling baud clock edge
            if control_reg(DATBIT)='1' and control_reg(STPBIT)='0' then
                status_per_clr <= '1';                 -- reset parity  error status if no parity
            end if;

            -- on falling baud clock edge
            if RxRdy = '1' then                        -- Has previous data been read ?
              status_oer_set <= '1';                   -- no, set over-run  error status
            else
              status_oer_clr <= '1';                   -- yes, reset over-run  error status
            end if;

            -- on falling baud clock edge
            if RxDat = '1' then                          -- stop bit received ?
              status_fer_clr <= '1';                   -- yes, reset framing error status
            else
              status_fer_set <= '1';                   -- no, set framing error status
            end if;

            -- on falling baud clock edge
            if RxDat = '0' then                        -- wait until RxDat returns high
              rx_next_state  <= idle_state;
            end if;

          when idle_state =>
            if RxDat = '0' then                        -- wait until RxD returns high
              rx_next_state <= idle_state;
            end if;

          when others =>
            null;
          end case;
  end process;

  ---------------------------------------------------------------------
  -- Rx State machine
  ---------------------------------------------------------------------
  --
  -- State machine transitions on the falling edge of the Rx Baud clock
  --
  acia_rx_state : process( clk )
  begin
    if falling_edge( clk ) then
      if rx_rst = '1' then
        rx_current_state <= start_state;
      else
        if RxBdEdgeFall = '1' then
          rx_current_state <= rx_next_state;
        end if;
      end if;
    end if;

  end process;


  -----------------------------------------------------------------------------
  -- ACIA Rx Shift Register
  -----------------------------------------------------------------------------
  -- 2021-01-30 JEK change RxD to RxDDel(0)
  --
  acia_rx_shift_reg : process( clk )
  begin
    if falling_edge( clk ) then
      if rx_rst = '1' then
        RxDat <= '1';
        rx_bit_count <= (others=>'0');
        rx_shift_reg <= (others=>'0');
        rx_parity    <= '0';
      elsif RxBdEdgeRise = '1' then
        RxDat <= RxDDel(0);
        case rx_shift_ctrl is
        when shift_reg_rst =>
          if control_reg(DATBIT) = '0' then  -- control_reg(DATBIT) = '0' => 7 data bits
            rx_bit_count <= "0111";
          else                               -- control_reg(DATBIT) = '1' => 8 data bits
            rx_bit_count <= "1000";
          end if;
          rx_shift_reg <= (others=>'0');
          rx_parity    <= '0';
        when shift_reg_shift =>
          rx_bit_count <= rx_bit_count - "0001";
          rx_shift_reg <= RxDDel(0) & rx_shift_reg(7 downto 1);
          rx_parity    <= rx_parity xor RxDDel(0);
        when others =>
          null;
        end case;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- ACIA Rx Data Register
  -----------------------------------------------------------------------------

  acia_rx_data_reg : process( clk )
  begin
    if falling_edge( clk ) then
      if rx_rst = '1' then
        rx_data_reg <= (others=>'0');
      elsif RxBdEdgeFall = '1' then
        case rx_data_ctrl is
        when data_reg_rst =>
          rx_data_reg <= (others=>'0');
        when data_reg_load =>
          rx_data_reg  <= rx_shift_reg;
        when others =>
          null;
        end case;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- ACIA TX control
  -----------------------------------------------------------------------------

  acia_tx_control : process( control_reg, TxDat )
  begin
    case control_reg(TX1BIT downto TX0BIT) is
      when "00" =>                      -- Disable TX Interrupts, Assert RTS
        TxD   <= TxDat;
        RTS_n <= '0';
      when "01" =>                      -- Enable TX interrupts, Assert RTS
        TxD   <= TxDat;
        RTS_n <= '0';
      when "10" =>                      -- Disable Tx Interrupts, Clear RTS
        TxD   <= TxDat;
        RTS_n <= '1';
      when "11" =>                      -- Disable Tx interrupts, Assert RTS, send break
        TxD   <= '0';
        RTS_n <= '0';
      when others =>
        null;
    end case;
  end process;

  ---------------------------------------------------------------------
  -- Transmit Clock Edge Detection
  -- A rising edge will produce a one clock cycle pulse
  ---------------------------------------------------------------------
  -- 2021-01-30 JEK add one more bit to TxCDel. Double sample TxC
  acia_tx_clock_edge : process( clk )
  begin
    if falling_edge(clk) then
      if tx_rst = '1' then
        TxCDel(1 downto 0) <= "00";
        TxCEdge <= '0';
      else
        TxCDel(0) <= TxC;
		  TxCDel(1) <= TxCDel(0);
        TxCEdge <= (not TxCDel(1)) and TxCDel(0);
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------
  -- Transmit Clock Divider
  -- Advance the count only on an input clock pulse
  ---------------------------------------------------------------------

  acia_tx_clock_divide : process( clk )
  begin
    if falling_edge(clk) then
      if tx_rst = '1' then
        TxClkCnt <= (others=>'0');
      elsif TxCEdge = '1' then
        TxClkCnt <= TxClkCnt + "000001";
      end if;
    end if;
  end process;


-----------------------------------------------------------------------------
-- ACIA TX Baud select
-----------------------------------------------------------------------------
-- 2021-01-30 JEK change TxC to TxCDel(0)
  acia_tx_baud_select : process( clk )
  begin

    ---------------------------------------------------------------------
    -- Transmit Baud Clock Selector
    ---------------------------------------------------------------------
    -- control_reg(BD1BIT downto BD0BIT)
    -- 0 0     - Baud Clk divide by 1
    -- 0 1     - Baud Clk divide by 16
    -- 1 0     - Baud Clk divide by 64
    -- 1 1     - reset
    if falling_edge(clk) then
      case control_reg(BD1BIT downto BD0BIT) is
      when "00" =>	                         -- Div by 1
        TxBdClk <= TxCDel(0);
      when "01" =>	                         -- Div by 16
        TxBdClk <= TxClkCnt(3);
      when "10" =>	                         -- Div by 64
        TxBdClk <= TxClkCnt(5);
      when others =>                          -- Software reset
        TxBdClk <= '0';
      end case;
    end if;

  end process;


  ---------------------------------------------------------------------
  -- Transmit Baud Clock Edge Detection
  ---------------------------------------------------------------------
  -- A Falling edge will produce a single pulse on TxBdEdgeFall
  --
  acia_tx_baud_edge : process( clk )
  begin
    if falling_edge(clk) then
      if tx_rst = '1' then
        TxBdDel      <= '0';
        TxBdEdgeRise <= '0';
        TxBdEdgeFall <= '0';
      else
        TxBdDel  <= TxBdClk;
        TxBdEdgeRise <= (not TxBdDel) and TxBdClk;
        TxBdEdgeFall <= TxBdDel and (not TxBdClk);
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Implements the Tx unit
  -----------------------------------------------------------------------------
  -- WdFmt - Bits[4..2]
  -- 0 0 0   - 7 data, even parity, 2 stop
  -- 0 0 1   - 7 data, odd  parity, 2 stop
  -- 0 1 0   - 7 data, even parity, 1 stop
  -- 0 1 1   - 7 data, odd  parity, 1 stop
  -- 1 0 0   - 8 data, no   parity, 2 stop
  -- 1 0 1   - 8 data, no   parity, 1 stop
  -- 1 1 0   - 8 data, even parity, 1 stop
  -- 1 1 1   - 8 data, odd  parity, 1 stop
  acia_tx_transmit : process( tx_current_state, TxRdy, tx_bit_count, tx_shift_reg, control_reg, tx_parity )
  begin
          status_txr_set <= '0';
          case tx_current_state is
          when idle_state =>
            TxOut <= '1';
            tx_shift_ctrl <= shift_reg_idle;
            if TxRdy = '0' then
              tx_next_state <= start_state;
            else
              tx_next_state <= idle_state;
            end if;

          when start_state =>
            TxOut         <= '0';                    -- Start bit
            tx_shift_ctrl <= shift_reg_load;         -- Load Shift reg with Tx Data
            tx_next_state <= data_state;

          when data_state =>
            TxOut <= tx_shift_reg(0);
            tx_shift_ctrl <= shift_reg_shift;        -- shift tx shift reg
            if tx_bit_count = "000" then
              if (control_reg(DATBIT) = '1') and (control_reg(STPBIT) = '0') then
                if control_reg(POEBIT) = '0' then    -- 8 data bits
                  tx_next_state <= stop_state;       -- 2 stops
                else
                  status_txr_set <= '1';
                  tx_next_state <= idle_state;       -- 1 stop
                end if;
              else
                tx_next_state <= parity_state;        -- parity
              end if;
            else
              tx_next_state <= data_state;
            end if;

          when parity_state =>                        -- 7/8 data + parity bit
            if control_reg(POEBIT) = '0' then
              TxOut <= not(tx_parity);                -- even parity
            else
              TxOut <= tx_parity;                     -- odd parity
            end if;
            tx_shift_ctrl <= shift_reg_idle;
            if control_reg(STPBIT) = '0' then
              tx_next_state <= stop_state;            -- 2 stops
            else
              status_txr_set <= '1';
              tx_next_state <= idle_state;            -- 1 stop
            end if;

          when stop_state =>                          -- first of two stop bits
            TxOut          <= '1';
            tx_shift_ctrl  <= shift_reg_idle;
            status_txr_set <= '1';
            tx_next_state  <= idle_state;

 --         when others =>
 --           null;

          end case;
  end process;

  ---------------------------------------------------------------------
  -- Tx State machine
  ---------------------------------------------------------------------
  --
  -- State machine transitions on the rising edge of the Tx Baud clock
  --
  acia_tx_state : process( clk )
  begin
     if falling_edge( clk ) then
      if tx_rst = '1' then
        tx_current_state <= idle_state;
      else
        if TxBdEdgeRise = '1' then
          tx_current_state <= tx_next_state;
        end if;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- ACIA tx Shift Register
  -----------------------------------------------------------------------------

  acia_tx_shift_reg : process( clk )
  begin
    if falling_edge( clk ) then
      if tx_rst = '1' then
        tx_bit_count <= (others=>'0');
        tx_shift_reg <= (others=>'1');
        tx_parity    <= '0';
        TxDat        <= '1';
      elsif TxBdEdgeFall = '1' then
        TxDat <= TxOut;
        case tx_shift_ctrl is
        when shift_reg_load =>
          if control_reg(DATBIT) = '0' then  -- control_reg(DATBIT) = '0' => 7 data bits
            tx_bit_count <= "0111";
          else                               -- control_reg(DATBIT) = '1' => 8 data bits
            tx_bit_count <= "1000";
          end if;
          tx_shift_reg  <= tx_data_reg;
          tx_parity     <= '0';
        when shift_reg_shift =>
          tx_bit_count <= tx_bit_count - "0001";
          tx_shift_reg <= '1' & tx_shift_reg(7 downto 1);
          tx_parity    <= tx_parity xor tx_shift_reg(0);
        when others =>
          null;
        end case;
      end if;
    end if;
  end process;


end rtl;
