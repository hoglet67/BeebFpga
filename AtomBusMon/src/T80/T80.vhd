--------------------------------------------------------------------------------
-- ****
-- T80(c) core. Attempt to finish all undocumented features and provide
--              accurate timings.
-- Version 350.
-- Copyright (c) 2018 Sorgelig
--  Test passed: ZEXDOC, ZEXALL, Z80Full(*), Z80memptr
--  (*) Currently only SCF and CCF instructions aren't passed X/Y flags check as
--      correct implementation is still unclear.
--
-- ****
-- T80(b) core. In an effort to merge and maintain bug fixes ....
--
-- Ver 303 add undocumented DDCB and FDCB opcodes by TobiFlex 20.04.2010
-- Ver 301 parity flag is just parity for 8080, also overflow for Z80, by Sean Riddle
-- Ver 300 started tidyup.
--
-- MikeJ March 2005
-- Latest version from www.fpgaarcade.com (original www.opencores.org)
--
-- ****
-- Z80 compatible microprocessor core
--
-- Version : 0250
-- Copyright (c) 2001-2002 Daniel Wallner (jesus@opencores.org)
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- Redistributions in synthesized form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
--
-- Neither the name of the author nor the names of other contributors may
-- be used to endorse or promote products derived from this software without
-- specific prior written permission.
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
-- Please report bugs to the author, but before you do so, please
-- make sure that this is not a derivative work and that
-- you have the latest version of this file.
--
-- The latest version of this file can be found at:
--      http://www.opencores.org/cvsweb.shtml/t80/
--
-- Limitations :
--
-- File history :
--
--      0208 : First complete release
--      0210 : Fixed wait and halt
--      0211 : Fixed Refresh addition and IM 1
--      0214 : Fixed mostly flags, only the block instructions now fail the zex regression test
--      0232 : Removed refresh address output for Mode > 1 and added DJNZ M1_n fix by Mike Johnson
--      0235 : Added clock enable and IM 2 fix by Mike Johnson
--      0237 : Changed 8080 I/O address output, added IntE output
--      0238 : Fixed (IX/IY+d) timing and 16 bit ADC and SBC zero flag
--      0240 : Added interrupt ack fix by Mike Johnson, changed (IX/IY+d) timing and changed flags in GB mode
--      0242 : Added I/O wait, fixed refresh address, moved some registers to RAM
--      0247 : Fixed bus req/ack cycle
--      0250 : Added R800 Multiplier by TobiFlex 2017.10.15
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use work.T80_Pack.all;

entity T80 is
	generic(
		Mode   : integer := 0;  -- 0 => Z80, 1 => Fast Z80, 2 => 8080, 3 => GB
		IOWait : integer := 0;  -- 0 => Single cycle I/O, 1 => Std I/O cycle
		Flag_C : integer := 0;
		Flag_N : integer := 1;
		Flag_P : integer := 2;
		Flag_X : integer := 3;
		Flag_H : integer := 4;
		Flag_Y : integer := 5;
		Flag_Z : integer := 6;
		Flag_S : integer := 7
	);
	port(
		RESET_n    : in  std_logic;
		CLK_n      : in  std_logic;
		CEN        : in  std_logic;
		WAIT_n     : in  std_logic;
		INT_n      : in  std_logic;
		NMI_n      : in  std_logic;
		BUSRQ_n    : in  std_logic;
		M1_n       : out std_logic;
		IORQ       : out std_logic;
		NoRead     : out std_logic;
		Write      : out std_logic;
		RFSH_n     : out std_logic;
		HALT_n     : out std_logic;
		BUSAK_n    : out std_logic;
		A          : out std_logic_vector(15 downto 0);
		DInst      : in  std_logic_vector(7 downto 0);
		DI         : in  std_logic_vector(7 downto 0);
		DO         : out std_logic_vector(7 downto 0);
		MC         : out std_logic_vector(2 downto 0);
		TS         : out std_logic_vector(2 downto 0);
		IntCycle_n : out std_logic;
		NMICycle_n : out std_logic;
		IntE       : out std_logic;
		Stop       : out std_logic;
		R800_mode  : in  std_logic := '0';
		out0       : in  std_logic := '0';  -- 0 => OUT(C),0, 1 => OUT(C),255
		REG        : out std_logic_vector(211 downto 0); -- IFF2, IFF1, IM, IY, HL', DE', BC', IX, HL, DE, BC, PC, SP, R, I, F', A', F, A

		DIRSet     : in  std_logic := '0';
		DIR        : in  std_logic_vector(211 downto 0) := (others => '0') -- IFF2, IFF1, IM, IY, HL', DE', BC', IX, HL, DE, BC, PC, SP, R, I, F', A', F, A
	);
end T80;

architecture rtl of T80 is

	-- Registers
	signal ACC, F               : std_logic_vector(7 downto 0);
	signal Ap, Fp               : std_logic_vector(7 downto 0);
	signal I                    : std_logic_vector(7 downto 0);
	signal R                    : unsigned(7 downto 0);
	signal SP, PC               : unsigned(15 downto 0);

	signal RegDIH               : std_logic_vector(7 downto 0);
	signal RegDIL               : std_logic_vector(7 downto 0);
	signal RegBusA              : std_logic_vector(15 downto 0);
	signal RegBusB              : std_logic_vector(15 downto 0);
	signal RegBusC              : std_logic_vector(15 downto 0);
	signal RegAddrA_r           : std_logic_vector(2 downto 0);
	signal RegAddrA             : std_logic_vector(2 downto 0);
	signal RegAddrB_r           : std_logic_vector(2 downto 0);
	signal RegAddrB             : std_logic_vector(2 downto 0);
	signal RegAddrC             : std_logic_vector(2 downto 0);
	signal RegWEH               : std_logic;
	signal RegWEL               : std_logic;
	signal Alternate            : std_logic;

	-- Help Registers
	signal WZ                   : std_logic_vector(15 downto 0);        -- MEMPTR register
	signal TmpAddr2             : std_logic_vector(15 downto 0);        -- Temporary address register
	signal IR                   : std_logic_vector(7 downto 0);         -- Instruction register
	signal ISet                 : std_logic_vector(1 downto 0);         -- Instruction set selector
	signal RegBusA_r            : std_logic_vector(15 downto 0);
	signal MULU_Prod32          : std_logic_vector(31 downto 0);
	signal MULU_tmp             : std_logic_vector(31 downto 0);
	signal MULU_Fakt1           : std_logic_vector(15 downto 0);

	signal ID16                 : signed(15 downto 0);
	signal Save_Mux             : std_logic_vector(7 downto 0);

	signal TState               : unsigned(2 downto 0);
	signal MCycle               : std_logic_vector(2 downto 0);
	signal IntE_FF1             : std_logic;
	signal IntE_FF2             : std_logic;
	signal Halt_FF              : std_logic;
	signal BusReq_s             : std_logic := '0';
	signal BusAck               : std_logic := '0';
	signal ClkEn                : std_logic;
	signal NMI_s                : std_logic;
	signal IStatus              : std_logic_vector(1 downto 0);

	signal DI_Reg               : std_logic_vector(7 downto 0);
	signal T_Res                : std_logic;
	signal XY_State             : std_logic_vector(1 downto 0);
	signal Pre_XY_F_M           : std_logic_vector(2 downto 0);
	signal NextIs_XY_Fetch      : std_logic;
	signal XY_Ind               : std_logic;
	signal No_BTR               : std_logic;
	signal BTR_r                : std_logic;
	signal Auto_Wait            : std_logic;
	signal Auto_Wait_t1         : std_logic;
	signal Auto_Wait_t2         : std_logic;
	signal IncDecZ              : std_logic;

	-- ALU signals
	signal BusB                 : std_logic_vector(7 downto 0);
	signal BusA                 : std_logic_vector(7 downto 0);
	signal ALU_Q                : std_logic_vector(7 downto 0);
	signal F_Out                : std_logic_vector(7 downto 0);

	-- Registered micro code outputs
	signal Read_To_Reg_r        : std_logic_vector(4 downto 0);
	signal Arith16_r            : std_logic;
	signal Z16_r                : std_logic;
	signal ALU_Op_r             : std_logic_vector(3 downto 0);
	signal Save_ALU_r           : std_logic;
	signal PreserveC_r          : std_logic;
	signal MCycles              : std_logic_vector(2 downto 0);

	-- Micro code outputs
	signal MCycles_d            : std_logic_vector(2 downto 0);
	signal TStates              : std_logic_vector(2 downto 0);
	signal IntCycle             : std_logic;
	signal NMICycle             : std_logic;
	signal Inc_PC               : std_logic;
	signal Inc_WZ               : std_logic;
	signal IncDec_16            : std_logic_vector(3 downto 0);
	signal Prefix               : std_logic_vector(1 downto 0);
	signal Read_To_Acc          : std_logic;
	signal Read_To_Reg          : std_logic;
	signal Set_BusB_To          : std_logic_vector(3 downto 0);
	signal Set_BusA_To          : std_logic_vector(3 downto 0);
	signal ALU_Op               : std_logic_vector(3 downto 0);
	signal Save_ALU             : std_logic;
	signal Rot_Akku             : std_logic;
	signal PreserveC            : std_logic;
	signal Arith16              : std_logic;
	signal Set_Addr_To          : std_logic_vector(2 downto 0);
	signal Jump                 : std_logic;
	signal JumpE                : std_logic;
	signal JumpXY               : std_logic;
	signal Call                 : std_logic;
	signal RstP                 : std_logic;
	signal LDZ                  : std_logic;
	signal LDW                  : std_logic;
	signal LDSPHL               : std_logic;
	signal LDHLSP               : std_logic;
	signal ADDSPdd              : std_logic;
	signal IORQ_i               : std_logic;
	signal Special_LD           : std_logic_vector(2 downto 0);
	signal ExchangeDH           : std_logic;
	signal ExchangeRp           : std_logic;
	signal ExchangeAF           : std_logic;
	signal ExchangeRS           : std_logic;
	signal I_DJNZ               : std_logic;
	signal I_CPL                : std_logic;
	signal I_CCF                : std_logic;
	signal I_SCF                : std_logic;
	signal I_RETN               : std_logic;
	signal I_BT                 : std_logic;
	signal I_BC                 : std_logic;
	signal I_BTR                : std_logic;
	signal I_RLD                : std_logic;
	signal I_RRD                : std_logic;
	signal I_RXDD               : std_logic;
	signal I_INRC               : std_logic;
	signal I_MULUB              : std_logic;
	signal I_MULU               : std_logic;
	signal SetWZ                : std_logic_vector(1 downto 0);
	signal SetDI                : std_logic;
	signal SetEI                : std_logic;
	signal IMode                : std_logic_vector(1 downto 0);
	signal Halt                 : std_logic;
	signal XYbit_undoc          : std_logic;
	signal No_PC                : std_logic;
	signal DOR                  : std_logic_vector(127 downto 0);

begin

	REG <= IntE_FF2 & IntE_FF1 & IStatus & DOR & std_logic_vector(PC) & std_logic_vector(SP) & std_logic_vector(R) & I & Fp & Ap & F & ACC when Alternate = '0'
			 else IntE_FF2 & IntE_FF1 & IStatus & DOR(127 downto 112) & DOR(47 downto 0) & DOR(63 downto 48) & DOR(111 downto 64) &
						std_logic_vector(PC) & std_logic_vector(SP) & std_logic_vector(R) & I & Fp & Ap & F & ACC;

	mcode : T80_MCode
		generic map(
			Mode   => Mode,
			Flag_C => Flag_C,
			Flag_N => Flag_N,
			Flag_P => Flag_P,
			Flag_X => Flag_X,
			Flag_H => Flag_H,
			Flag_Y => Flag_Y,
			Flag_Z => Flag_Z,
			Flag_S => Flag_S)
		port map(
			IR          => IR,
			ISet        => ISet,
			MCycle      => MCycle,
			F           => F,
			NMICycle    => NMICycle,
			IntCycle    => IntCycle,
			XY_State    => XY_State,
			MCycles     => MCycles_d,
			TStates     => TStates,
			Prefix      => Prefix,
			Inc_PC      => Inc_PC,
			Inc_WZ      => Inc_WZ,
			IncDec_16   => IncDec_16,
			Read_To_Acc => Read_To_Acc,
			Read_To_Reg => Read_To_Reg,
			Set_BusB_To => Set_BusB_To,
			Set_BusA_To => Set_BusA_To,
			ALU_Op      => ALU_Op,
			Save_ALU    => Save_ALU,
			Rot_Akku    => Rot_Akku,
			PreserveC   => PreserveC,
			Arith16     => Arith16,
			Set_Addr_To => Set_Addr_To,
			IORQ        => IORQ_i,
			Jump        => Jump,
			JumpE       => JumpE,
			JumpXY      => JumpXY,
			Call        => Call,
			RstP        => RstP,
			LDZ         => LDZ,
			LDW         => LDW,
			LDSPHL      => LDSPHL,
			LDHLSP      => LDHLSP,
			ADDSPdd     => ADDSPdd,
			Special_LD  => Special_LD,
			ExchangeDH  => ExchangeDH,
			ExchangeRp  => ExchangeRp,
			ExchangeAF  => ExchangeAF,
			ExchangeRS  => ExchangeRS,
			I_DJNZ      => I_DJNZ,
			I_CPL       => I_CPL,
			I_CCF       => I_CCF,
			I_SCF       => I_SCF,
			I_RETN      => I_RETN,
			I_BT        => I_BT,
			I_BC        => I_BC,
			I_BTR       => I_BTR,
			I_RLD       => I_RLD,
			I_RRD       => I_RRD,
			I_INRC      => I_INRC,
			I_MULUB     => I_MULUB,
			I_MULU      => I_MULU,
			SetWZ       => SetWZ,
			SetDI       => SetDI,
			SetEI       => SetEI,
			IMode       => IMode,
			Halt        => Halt,
			NoRead      => NoRead,
			Write       => Write,
			R800_mode   => R800_mode,
			No_PC       => No_PC,
			XYbit_undoc => XYbit_undoc);

	alu : T80_ALU
		generic map(
			Mode   => Mode,
			Flag_C => Flag_C,
			Flag_N => Flag_N,
			Flag_P => Flag_P,
			Flag_X => Flag_X,
			Flag_H => Flag_H,
			Flag_Y => Flag_Y,
			Flag_Z => Flag_Z,
			Flag_S => Flag_S)
		port map(
			Arith16 => Arith16_r,
			Z16     => Z16_r,
			WZ      => WZ,
			XY_State=> XY_State,
			ALU_Op  => ALU_Op_r,
			Rot_Akku    => Rot_Akku,
			IR      => IR(5 downto 0),
			ISet    => ISet,
			BusA    => BusA,
			BusB    => BusB,
			F_In    => F,
			Q       => ALU_Q,
			F_Out   => F_Out);

	ClkEn <= CEN and not BusAck;

	T_Res <= '1' when TState = unsigned(TStates) else '0';

	NextIs_XY_Fetch <= '1' when XY_State /= "00" and XY_Ind = '0' and
							((Set_Addr_To = aXY) or
							(MCycle = "001" and IR = "11001011") or
							(MCycle = "001" and IR = "00110110")) else '0';

	Save_Mux <= BusB when ExchangeRp = '1' else
		DI_Reg when Save_ALU_r = '0' else
		ALU_Q;

	process (RESET_n, CLK_n)
		variable n : std_logic_vector(7 downto 0);
		variable ioq : std_logic_vector(8 downto 0);
		variable temp_c : unsigned(8 downto 0);
		variable temp_h : unsigned(4 downto 0);
	begin
		if RESET_n = '0' then
			PC <= (others => '0');  -- Program Counter
			A <= (others => '0');
			WZ <= (others => '0');
			IR <= "00000000";
			ISet <= "00";
			XY_State <= "00";
			IStatus <= "00";
			MCycles <= "000";
			DO <= "00000000";

			ACC <= (others => '1');
			F <= (others => '1');
			if Mode = 3 then
				ACC <= (others => '0');
				F <= "11110000";
			end if;

			Ap <= (others => '1');
			Fp <= (others => '1');
			I <= (others => '0');
			R <= (others => '0');
			SP <= (others => '1');
			Alternate <= '0';

			Read_To_Reg_r <= "00000";
			Arith16_r <= '0';
			BTR_r <= '0';
			Z16_r <= '0';
			ALU_Op_r <= "0000";
			Save_ALU_r <= '0';
			PreserveC_r <= '0';
			XY_Ind <= '0';
			I_RXDD <= '0';

		elsif rising_edge(CLK_n) then

			if DIRSet = '1' then
				ACC <= DIR( 7 downto  0);
				F   <= DIR(15 downto  8);
				Ap  <= DIR(23 downto 16);
				Fp  <= DIR(31 downto 24);
				I   <= DIR(39 downto 32);
				R   <= unsigned(DIR(47 downto 40));
				SP  <= unsigned(DIR(63 downto 48));
				PC  <= unsigned(DIR(79 downto 64));
				A <= DIR(79 downto 64);
				IStatus <= DIR(209 downto 208);

			elsif ClkEn = '1' then
				ALU_Op_r <= "0000";
				Save_ALU_r <= '0';
				Read_To_Reg_r <= "00000";

				MCycles <= MCycles_d;

				if LDHLSP = '1' and MCycle = "011" and TState = 1 then
					temp_c := unsigned('0'&SP(7 downto 0))+unsigned('0'&Save_Mux);
					temp_h := unsigned('0'&SP(3 downto 0))+unsigned('0'&Save_Mux(3 downto 0));
					F(Flag_Z) <= '0';
					F(Flag_N) <= '0';
					F(Flag_H) <= temp_h(4);
					F(Flag_C) <= temp_c(8);
				end if;

				if ADDSPdd = '1' and TState = 1 then
					temp_c := unsigned('0'&SP(7 downto 0))+unsigned('0'&Save_Mux);
					temp_h := unsigned('0'&SP(3 downto 0))+unsigned('0'&Save_Mux(3 downto 0));
					F(Flag_Z) <= '0';
					F(Flag_N) <= '0';
					F(Flag_H) <= temp_h(4);
					F(Flag_C) <= temp_c(8);
				end if;

				if Mode = 3 then
					IStatus <= "10";
				elsif IMode /= "11" then
					IStatus <= IMode;
				end if;

				Arith16_r <= Arith16;
				PreserveC_r <= PreserveC;
				if ISet = "10" and ALU_OP(2) = '0' and ALU_OP(0) = '1' and MCycle = "011" then
					Z16_r <= '1';
				else
					Z16_r <= '0';
				end if;

				if MCycle  = "001" and TState(2) = '0' then
				-- MCycle = 1 and TState = 1, 2, or 3

					if TState = 2 and Wait_n = '1' then
						if Mode < 2 then
							A(7 downto 0) <= std_logic_vector(R);
							A(15 downto 8) <= I;
							R(6 downto 0) <= R(6 downto 0) + 1;
						end if;

						if Jump = '0' and Call = '0' and NMICycle = '0' and IntCycle = '0' and not (Halt_FF = '1' or Halt = '1') then
							PC <= PC + 1;
						end if;

						if IntCycle = '1' and IStatus = "01" then
							IR <= "11111111";
						elsif Halt_FF = '1' or (IntCycle = '1' and IStatus = "10") or NMICycle = '1' then
							IR <= "00000000";
						else
							IR <= DInst;
						end if;

						if Mode <= 1 and IntCycle = '1' and IStatus = "10" then
							-- IM2 vector address low byte from bus
							WZ(7 downto 0) <= DInst;
						end if;

						ISet <= "00";
						if Prefix /= "00" then
							if Prefix = "11" then
								if IR(5) = '1' then
									XY_State <= "10";
								else
									XY_State <= "01";
								end if;
							else
								if Prefix = "10" then
									XY_State <= "00";
									XY_Ind <= '0';
								end if;
								ISet <= Prefix;
							end if;
						else
							XY_State <= "00";
							XY_Ind <= '0';
						end if;
					end if;

				else
				-- either (MCycle > 1) OR (MCycle = 1 AND TState > 3)

					if MCycle = "110" then
						XY_Ind <= '1';
						if Prefix = "01" then
							ISet <= "01";
						end if;
					end if;

					if T_Res = '1' then
						BTR_r <= (I_BT or I_BC or I_BTR) and not No_BTR;
						if Jump = '1' then
							A(15 downto 8) <= DI_Reg;
							A(7 downto 0) <= WZ(7 downto 0);
							PC(15 downto 8) <= unsigned(DI_Reg);
							PC(7 downto 0) <= unsigned(WZ(7 downto 0));
						elsif JumpXY = '1' then
							A <= RegBusC;
							PC <= unsigned(RegBusC);
						elsif Call = '1' or RstP = '1' then
							A <= WZ;
							PC <= unsigned(WZ);
						elsif MCycle = MCycles and NMICycle = '1' then
							A <= "0000000001100110";
							PC <= "0000000001100110";
						elsif ((Mode /= 3 and MCycle = "011") or (Mode = 3 and MCycle = "100"))
							and IntCycle = '1' and IStatus = "10" then
							A(15 downto 8) <= I;
							A(7 downto 0) <= WZ(7 downto 0);
							PC(15 downto 8) <= unsigned(I);
							PC(7 downto 0) <= unsigned(WZ(7 downto 0));
						else
							case Set_Addr_To is
							when aXY =>
								if XY_State = "00" then
									A <= RegBusC;
								else
									if NextIs_XY_Fetch = '1' then
										A <= std_logic_vector(PC);
									else
										A <= WZ;
									end if;
								end if;
							when aIOA =>
								if Mode = 3 then
									-- Memory map I/O on GBZ80
									A(15 downto 8) <= (others => '1');
								elsif Mode = 2 then
									-- Duplicate I/O address on 8080
									A(15 downto 8) <= DI_Reg;
								else
									A(15 downto 8) <= ACC;
								end if;
								A(7 downto 0) <= DI_Reg;
								WZ <= (ACC & DI_Reg) + "1";
							when aSP =>
								A <= std_logic_vector(SP);
							when aBC =>
								if Mode = 3 and IORQ_i = '1' then
									-- Memory map I/O on GBZ80
									A(15 downto 8) <= (others => '1');
									A(7 downto 0) <= RegBusC(7 downto 0);
								else
									A <= RegBusC;
									if SetWZ = "01" then
										WZ <= RegBusC + "1";
									end if;
									if SetWZ = "10" then
										WZ(7 downto 0) <= RegBusC(7 downto 0) + "1";
										WZ(15 downto 8) <= ACC;
									end if;
								end if;
							when aDE =>
								A <= RegBusC;
								if SetWZ = "10" then
									WZ(7 downto 0) <= RegBusC(7 downto 0) + "1";
									WZ(15 downto 8) <= ACC;
								end if;
							when aZI =>
								if Inc_WZ = '1' then
									A <= std_logic_vector(unsigned(WZ) + 1);
								else
									A(15 downto 8) <= DI_Reg;
									A(7 downto 0) <= WZ(7 downto 0);
									if SetWZ = "10" then
										WZ(7 downto 0) <= WZ(7 downto 0) + "1";
										WZ(15 downto 8) <= ACC;
									end if;
								end if;
							when others =>
								if ISet = "10" and IR(7 downto 4) = x"B" and IR(2 downto 1) = "01" and MCycle = 3 and No_BTR = '0' then
									-- INIR, INDR, OTIR, OTDR
									A <= RegBusA_r;
								elsif No_PC = '0' or No_BTR = '1' or (I_DJNZ = '1' and IncDecZ = '1') or Mode > 1 then
									A <= std_logic_vector(PC);
								end if;
							end case;
						end if;

						if SetWZ = "11" then
							WZ <= std_logic_vector(ID16);
						end if;

						Save_ALU_r <= Save_ALU;
						ALU_Op_r <= ALU_Op;

						if Mode = 3 then
							if I_CPL = '1' then
								-- CPL
								ACC <= not ACC;
								F(Flag_H) <= '1';
								F(Flag_N) <= '1';
							end if;
							if I_CCF = '1' then
								-- CCF
								F(Flag_C) <= not F(Flag_C);
								F(Flag_H) <= '0';
								F(Flag_N) <= '0';
							end if;
							if I_SCF = '1' then
								-- SCF
								F(Flag_C) <= '1';
								F(Flag_H) <= '0';
								F(Flag_N) <= '0';
							end if;
						else
							if I_CPL = '1' then
								-- CPL
								ACC <= not ACC;
								F(Flag_Y) <= not ACC(5);
								F(Flag_H) <= '1';
								F(Flag_X) <= not ACC(3);
								F(Flag_N) <= '1';
							end if;
							if I_CCF = '1' then
								-- CCF
								F(Flag_C) <= not F(Flag_C);
								F(Flag_Y) <= ACC(5);
								F(Flag_H) <= F(Flag_C);
								F(Flag_X) <= ACC(3);
								F(Flag_N) <= '0';
							end if;
							if I_SCF = '1' then
								-- SCF
								F(Flag_C) <= '1';
								F(Flag_Y) <= ACC(5);
								F(Flag_H) <= '0';
								F(Flag_X) <= ACC(3);
								F(Flag_N) <= '0';
							end if;
						end if;
					end if;

					if (TState = 2 and I_BTR = '1' and IR(0) = '1') or (TState = 1 and I_BTR = '1' and IR(0) = '0') then
						ioq := ('0' & DI_Reg) + ('0' & std_logic_vector(ID16(7 downto 0)));
						F(Flag_N) <= DI_Reg(7);
						F(Flag_C) <= ioq(8);
						F(Flag_H) <= ioq(8);
						ioq := (ioq and ('0'&x"07")) xor ('0'&BusA);
						F(Flag_P) <= not (ioq(0) xor ioq(1) xor ioq(2) xor ioq(3) xor ioq(4) xor ioq(5) xor ioq(6) xor ioq(7));
					end if;

					if TState = 2 and Wait_n = '1' then
						if ISet = "01" and MCycle = "111" then
							IR <= DInst;
						end if;
						if JumpE = '1' then
							PC <= unsigned(signed(PC) + signed(DI_Reg));
							WZ <= std_logic_vector(signed(PC) + signed(DI_Reg));
						elsif Inc_PC = '1' then
							PC <= PC + 1;
						end if;
						if BTR_r = '1' then
							PC <= PC - 2;
						end if;
						if RstP = '1' then
							WZ <= (others =>'0');
							WZ(5 downto 3) <= IR(5 downto 3);
						end if;
					end if;
					if TState = 3 and MCycle = "110" then
						WZ <= std_logic_vector(signed(RegBusC) + signed(DI_Reg));
					end if;

					if MCycle = "011" and TState = 4 and No_BTR = '0' then
						if I_BT = '1' or I_BC = '1' then
							WZ <= std_logic_vector(PC)-"1";
						end if;
					end if;

					if (TState = 2 and Wait_n = '1') or (TState = 4 and MCycle = "001") then
						if IncDec_16(2 downto 0) = "111" then
							if IncDec_16(3) = '1' then
								SP <= SP - 1;
							else
								SP <= SP + 1;
							end if;
						end if;
					end if;

					if ADDSPdd = '1' and TState = 2 then
						WZ <= std_logic_vector(SP);
						SP <= unsigned(signed(SP)+signed(Save_Mux));
					end if;

					if LDSPHL = '1' then
						SP <= unsigned(RegBusC);
					end if;
					if ExchangeAF = '1' then
						Ap <= ACC;
						ACC <= Ap;
						Fp <= F;
						F <= Fp;
					end if;
					if ExchangeRS = '1' then
						Alternate <= not Alternate;
					end if;
				end if;

				if TState = 3 then
					if LDZ = '1' then
						WZ(7 downto 0) <= DI_Reg;
					end if;
					if LDW = '1' then
						WZ(15 downto 8) <= DI_Reg;
					end if;

					if Special_LD(2) = '1' then
						case Special_LD(1 downto 0) is
						when "00" =>
							ACC <= I;
							F(Flag_P) <= IntE_FF2;
							F(Flag_S) <= I(7);

							if I = x"00" then
								F(Flag_Z) <= '1';
							else
								F(Flag_Z) <= '0';
							end if;

							F(Flag_Y) <= I(5);
							F(Flag_H) <= '0';
							F(Flag_X) <= I(3);
							F(Flag_N) <= '0';


						when "01" =>
							ACC <= std_logic_vector(R);
							F(Flag_P) <= IntE_FF2;
							F(Flag_S) <= R(7);

							if R = x"00" then
								F(Flag_Z) <= '1';
							else
								F(Flag_Z) <= '0';
							end if;

							F(Flag_Y) <= R(5);
							F(Flag_H) <= '0';
							F(Flag_X) <= R(3);
							F(Flag_N) <= '0';

						when "10" =>
							I <= ACC;
						when others =>
							R <= unsigned(ACC);
						end case;
					end if;
				end if;

				if (I_DJNZ = '0' and Save_ALU_r = '1') or ALU_Op_r = "1001" then
					if Mode = 3 then
						F(6) <= F_Out(6);
						F(5) <= F_Out(5);
						F(7) <= F_Out(7);
						if PreserveC_r = '0' then
							F(4) <= F_Out(4);
						end if;
					else
						F(7 downto 1) <= F_Out(7 downto 1);
						if PreserveC_r = '0' then
							F(Flag_C) <= F_Out(0);
						end if;
					end if;
				end if;
				if T_Res = '1' and I_INRC = '1' then
					F(Flag_H) <= '0';
					F(Flag_N) <= '0';
					F(Flag_X) <= DI_Reg(3);
					F(Flag_Y) <= DI_Reg(5);
					if DI_Reg(7 downto 0) = "00000000" then
						F(Flag_Z) <= '1';
					else
						F(Flag_Z) <= '0';
					end if;
					F(Flag_S) <= DI_Reg(7);
					F(Flag_P) <= not (DI_Reg(0) xor DI_Reg(1) xor DI_Reg(2) xor DI_Reg(3) xor
						DI_Reg(4) xor DI_Reg(5) xor DI_Reg(6) xor DI_Reg(7));
				end if;

				if TState = 1 and Auto_Wait_t1 = '0' then
					-- Keep D0 from M3 for RLD/RRD (Sorgelig)
					I_RXDD <= I_RLD or I_RRD;
					if I_RXDD='0' then
						DO <= BusB;
					end if;
					if I_RLD = '1' then
						DO(3 downto 0) <= BusA(3 downto 0);
						DO(7 downto 4) <= BusB(3 downto 0);
					end if;
					if I_RRD = '1' then
						DO(3 downto 0) <= BusB(7 downto 4);
						DO(7 downto 4) <= BusA(3 downto 0);
					end if;
				end if;

				if T_Res = '1' then
					Read_To_Reg_r(3 downto 0) <= Set_BusA_To;
					Read_To_Reg_r(4) <= Read_To_Reg;
					if Read_To_Acc = '1' then
						Read_To_Reg_r(3 downto 0) <= "0111";
						Read_To_Reg_r(4) <= '1';
					end if;
				end if;

				if TState = 1 and I_BT = '1' then
					F(Flag_X) <= ALU_Q(3);
					F(Flag_Y) <= ALU_Q(1);
					F(Flag_H) <= '0';
					F(Flag_N) <= '0';
				end if;
				if TState = 1 and I_BC = '1' then
					n := ALU_Q - ("0000000" & F_Out(Flag_H));
					F(Flag_X) <= n(3);
					F(Flag_Y) <= n(1);
				end if;
				if I_BC = '1' or I_BT = '1' then
					F(Flag_P) <= IncDecZ;
				end if;

				if (TState = 1 and Save_ALU_r = '0' and Auto_Wait_t1 = '0') or
					(Save_ALU_r = '1' and ALU_OP_r /= "0111") then
					case Read_To_Reg_r is
					when "10111" =>
						ACC <= Save_Mux;
					when "10110" =>
						DO <= Save_Mux;
					when "11000" =>
						SP(7 downto 0) <= unsigned(Save_Mux);
					when "11001" =>
						SP(15 downto 8) <= unsigned(Save_Mux);
					when "11011" =>
						if Mode = 3 then
							F(7 downto 4) <= Save_Mux(7 downto 4);
							F(3 downto 0) <= "0000"; -- bit 3 to 0 always return 0
						else
							F <= Save_Mux;
						end if;
					when others =>
					end case;
					if XYbit_undoc='1' then
						DO <= ALU_Q;
					end if;
				end if;
			end if;
		end if;
	end process;

---------------------------------------------------------------------------
--
-- Multiply
--
---------------------------------------------------------------------------
	process (CLK_n, ACC, RegBusB, MULU_tmp, MULU_Fakt1, MULU_Prod32)
	begin

		MULU_tmp(31 downto 12) <= std_logic_vector((unsigned(MULU_Fakt1)*unsigned(MULU_Prod32(3 downto 0)))+unsigned("0000"&MULU_Prod32(31 downto 16)));
		MULU_tmp(11 downto 0) <= MULU_Prod32(15 downto 4);

		if rising_edge(CLK_n) then
			if ClkEn = '1' then
				if T_Res='1' then
					if I_MULUB='1' then
						MULU_Prod32(7 downto 0) <= ACC;
						MULU_Prod32(15 downto 8) <= "--------";
						MULU_Prod32(31 downto 16) <= X"0000";
						MULU_Fakt1(7 downto 0) <= "00000000";
						if Set_BusB_To(0) = '1' then
							MULU_Fakt1(15 downto 8) <= RegBusB(7 downto 0);
						else
							MULU_Fakt1(15 downto 8) <= RegBusB(15 downto 8);
						end if;
					else
						MULU_Prod32(15 downto 0) <= RegBusA;
						MULU_Prod32(31 downto 16) <= X"0000";
						MULU_Fakt1 <= RegBusB;
					end if;
				else
					MULU_Prod32 <= MULU_tmp;
				end if;
			end if;
		end if;
	end process;

---------------------------------------------------------------------------
--
-- BC('), DE('), HL('), IX and IY
--
---------------------------------------------------------------------------
	process (CLK_n)
	begin
		if rising_edge(CLK_n) then
			if ClkEn = '1' then
				-- Bus A / Write
				RegAddrA_r <= Alternate & Set_BusA_To(2 downto 1);
				if XY_Ind = '0' and XY_State /= "00" and Set_BusA_To(2 downto 1) = "10" then
					RegAddrA_r <= XY_State(1) & "11";
				end if;

				-- Bus B
				RegAddrB_r <= Alternate & Set_BusB_To(2 downto 1);
				if XY_Ind = '0' and XY_State /= "00" and Set_BusB_To(2 downto 1) = "10" then
					RegAddrB_r <= XY_State(1) & "11";
				end if;

				-- Address from register
				RegAddrC <= Alternate & Set_Addr_To(1 downto 0);
				-- Jump (HL), LD SP,HL
				if (JumpXY = '1' or LDSPHL = '1') then
					RegAddrC <= Alternate & "10";
				end if;
				if ((JumpXY = '1' or LDSPHL = '1') and XY_State /= "00") or (MCycle = "110") then
					RegAddrC <= XY_State(1) & "11";
				end if;

				if I_DJNZ = '1' and Save_ALU_r = '1' and Mode < 2 then
					IncDecZ <= F_Out(Flag_Z);
				end if;
				if (TState = 2 or (TState = 3 and MCycle = "001")) and IncDec_16(2 downto 0) = "100" then
					if ID16 = 0 then
						IncDecZ <= '0';
					else
						IncDecZ <= '1';
					end if;
				end if;

				RegBusA_r <= RegBusA;
			end if;
		end if;
	end process;

	RegAddrA <=
			-- 16 bit increment/decrement
			Alternate & IncDec_16(1 downto 0) when (TState = 2 or
				(TState = 3 and MCycle = "001" and IncDec_16(2) = '1')) and XY_State = "00" else
			XY_State(1) & "11" when (TState = 2 or
				(TState = 3 and MCycle = "001" and IncDec_16(2) = '1')) and IncDec_16(1 downto 0) = "10" else
			-- EX HL,DL
			Alternate & "10" when ExchangeDH = '1' and TState = 3 else
			Alternate & "01" when (ExchangeDH = '1' or I_MULU = '1') and TState = 4 else
			-- LDHLSP
			"010" when LDHLSP = '1' and TState = 4 else
			-- Bus A / Write
			RegAddrA_r;

	RegAddrB <=
			-- EX HL,DL
			Alternate & "01" when ExchangeDH = '1' and TState = 3 else
			-- Bus B
			RegAddrB_r;

	ID16 <= signed(RegBusA) - 1 when IncDec_16(3) = '1' else
			signed(RegBusA) + 1;

	process (Save_ALU_r, Auto_Wait_t1, ALU_OP_r, Read_To_Reg_r, I_MULU, T_Res,
			ExchangeDH, IncDec_16, MCycle, TState, Wait_n, LDHLSP)
	begin
		RegWEH <= '0';
		RegWEL <= '0';
		if (TState = 1 and Save_ALU_r = '0' and Auto_Wait_t1 = '0') or
			(Save_ALU_r = '1' and ALU_OP_r /= "0111") then
			case Read_To_Reg_r is
			when "10000" | "10001" | "10010" | "10011" | "10100" | "10101" =>
				RegWEH <= not Read_To_Reg_r(0);
				RegWEL <= Read_To_Reg_r(0);
			when others =>
			end case;
		end if;

		if I_MULU = '1' and (T_Res = '1' or TState = 4) then    -- TState = 4 DE write
			RegWEH <= '1';
			RegWEL <= '1';
		end if;

		if ExchangeDH = '1' and (TState = 3 or TState = 4) then
			RegWEH <= '1';
			RegWEL <= '1';
		end if;

		if LDHLSP = '1' and MCycle = "010" and TState = 4 then
			RegWEH <= '1';
			RegWEL <= '1';
		end if;

		if IncDec_16(2) = '1' and ((TState = 2 and Wait_n = '1' and MCycle /= "001") or (TState = 3 and MCycle = "001")) then
			case IncDec_16(1 downto 0) is
			when "00" | "01" | "10" =>
				RegWEH <= '1';
				RegWEL <= '1';
			when others =>
			end case;
		end if;
	end process;

	TmpAddr2 <= std_logic_vector(unsigned(signed(SP) + signed(Save_Mux)));

	process (Save_Mux, RegBusB, RegBusA_r, ID16, I_MULU, MULU_Prod32, MULU_tmp, T_Res,
			ExchangeDH, IncDec_16, MCycle, TState, Wait_n, LDHLSP, TmpAddr2)
	begin
		RegDIH <= Save_Mux;
		RegDIL <= Save_Mux;

		if I_MULU = '1' then
			if T_Res = '1' then
				RegDIH <= MULU_Prod32(31 downto 24);
				RegDIL <= MULU_Prod32(23 downto 16);
			else
				RegDIH <= MULU_tmp(15 downto 8);    -- TState = 4 DE write
				RegDIL <= MULU_tmp(7 downto 0);
			end if;
		end if;

		if LDHLSP = '1' and MCycle = "010" and TState = 4 then
			RegDIH <= TmpAddr2(15 downto 8);
			RegDIL <= TmpAddr2(7 downto 0);
		end if;

		if ExchangeDH = '1' and TState = 3 then
			RegDIH <= RegBusB(15 downto 8);
			RegDIL <= RegBusB(7 downto 0);
		end if;
		if ExchangeDH = '1' and TState = 4 then
			RegDIH <= RegBusA_r(15 downto 8);
			RegDIL <= RegBusA_r(7 downto 0);
		end if;

		if IncDec_16(2) = '1' and ((TState = 2 and MCycle /= "001") or (TState = 3 and MCycle = "001")) then
			RegDIH <= std_logic_vector(ID16(15 downto 8));
			RegDIL <= std_logic_vector(ID16(7 downto 0));
		end if;
	end process;

	Regs : T80_Reg
		port map(
			Clk => CLK_n,
			CEN => ClkEn,
			WEH => RegWEH,
			WEL => RegWEL,
			AddrA => RegAddrA,
			AddrB => RegAddrB,
			AddrC => RegAddrC,
			DIH => RegDIH,
			DIL => RegDIL,
			DOAH => RegBusA(15 downto 8),
			DOAL => RegBusA(7 downto 0),
			DOBH => RegBusB(15 downto 8),
			DOBL => RegBusB(7 downto 0),
			DOCH => RegBusC(15 downto 8),
			DOCL => RegBusC(7 downto 0),
			DOR  => DOR,
			DIRSet => DIRSet,
			DIR  => DIR(207 downto 80));

---------------------------------------------------------------------------
--
-- Buses
--
---------------------------------------------------------------------------
	process (CLK_n)
	begin
		if rising_edge(CLK_n) then
			if ClkEn = '1' then
				case Set_BusB_To is
				when "0111" =>
					BusB <= ACC;
				when "0000" | "0001" | "0010" | "0011" | "0100" | "0101" =>
					if Set_BusB_To(0) = '1' then
						BusB <= RegBusB(7 downto 0);
					else
						BusB <= RegBusB(15 downto 8);
					end if;
				when "0110" =>
					BusB <= DI_Reg;
				when "1000" =>
					BusB <= std_logic_vector(SP(7 downto 0));
				when "1001" =>
					BusB <= std_logic_vector(SP(15 downto 8));
				when "1010" =>
					BusB <= "00000001";
				when "1011" =>
					BusB <= F;
				when "1100" =>
					BusB <= std_logic_vector(PC(7 downto 0));
				when "1101" =>
					BusB <= std_logic_vector(PC(15 downto 8));
				when "1110" =>
					if IR = x"71" and out0 = '1' then
						BusB <= "11111111";
					else
					BusB <= "00000000";
					end if;
				when others =>
					BusB <= "--------";
				end case;

				case Set_BusA_To is
				when "0111" =>
					BusA <= ACC;
				when "0000" | "0001" | "0010" | "0011" | "0100" | "0101" =>
					if Set_BusA_To(0) = '1' then
						BusA <= RegBusA(7 downto 0);
					else
						BusA <= RegBusA(15 downto 8);
					end if;
				when "0110" =>
					BusA <= DI_Reg;
				when "1000" =>
					BusA <= std_logic_vector(SP(7 downto 0));
				when "1001" =>
					BusA <= std_logic_vector(SP(15 downto 8));
				when "1010" =>
					BusA <= "00000000";
				when others =>
					BusA <= "--------";
				end case;
				if XYbit_undoc='1' then
					BusA <= DI_Reg;
					BusB <= DI_Reg;
				end if;
			end if;
		end if;
	end process;

---------------------------------------------------------------------------
--
-- Generate external control signals
--
---------------------------------------------------------------------------
	process (RESET_n,CLK_n)
	begin
		if RESET_n = '0' then
			RFSH_n <= '1';
		elsif rising_edge(CLK_n) then
			if DIRSet = '0' and CEN = '1' then
				if MCycle = "001" and ((TState = 2  and Wait_n = '1') or TState = 3) then
					RFSH_n <= '0';
				else
					RFSH_n <= '1';
				end if;
			end if;
		end if;
	end process;

	MC <= std_logic_vector(MCycle);
	TS <= std_logic_vector(TState);
	DI_Reg <= DI;
	HALT_n <= not Halt_FF;
	BUSAK_n <= not (BusAck and RESET_n);
	IntCycle_n <= not IntCycle;
	NMICycle_n <= not NMICycle;
	IntE <= IntE_FF1;
	IORQ <= IORQ_i;
	Stop <= I_DJNZ;
-------------------------------------------------------------------------
--
-- Main state machine
--
-------------------------------------------------------------------------
	process (RESET_n, CLK_n)
		variable OldNMI_n : std_logic;
	begin
		if RESET_n = '0' then
			MCycle <= "001";
			TState <= "000";
			Pre_XY_F_M <= "000";
			Halt_FF <= '0';
			--BusAck <= '0';
			NMICycle <= '0';
			IntCycle <= '0';
			IntE_FF1 <= '0';
			IntE_FF2 <= '0';
			No_BTR <= '0';
			Auto_Wait_t1 <= '0';
			Auto_Wait_t2 <= '0';
			M1_n <= '1';
			--BusReq_s <= '0';
			NMI_s <= '0';
		elsif rising_edge(CLK_n) then
			if DIRSet = '1' then
				IntE_FF2 <= DIR(211);
				IntE_FF1 <= DIR(210);
			else
				if NMI_n = '0' and OldNMI_n = '1' then
					NMI_s <= '1';
				end if;
				OldNMI_n := NMI_n;

				if CEN = '1' then
					BusReq_s <= not BUSRQ_n;
					Auto_Wait_t2 <= Auto_Wait_t1;
					if T_Res = '1' then
						Auto_Wait_t1 <= '0';
						Auto_Wait_t2 <= '0';
					else
						Auto_Wait_t1 <= Auto_Wait or IORQ_i;
					end if;
					No_BTR <= (I_BT and (not IR(4) or not F(Flag_P))) or
							(I_BC and (not IR(4) or F(Flag_Z) or not F(Flag_P))) or
							(I_BTR and (not IR(4) or F(Flag_Z)));
					if TState = 2 then
						if SetEI = '1' then
							IntE_FF1 <= '1';
							IntE_FF2 <= '1';
						end if;
						if I_RETN = '1' then
							IntE_FF1 <= IntE_FF2;
						end if;
					end if;
					if TState = 3 then
						if SetDI = '1' then
							IntE_FF1 <= '0';
							IntE_FF2 <= '0';
						end if;
					end if;
					if IntCycle = '1' or NMICycle = '1' then
						Halt_FF <= '0';
					end if;
					if MCycle = "001" and TState = 2 and Wait_n = '1' then
						M1_n <= '1';
					end if;
					if BusReq_s = '1' and BusAck = '1' then
					else
						BusAck <= '0';
						if TState = 2 and Wait_n = '0' then
						elsif T_Res = '1' then
							if Halt = '1' and  ( not(Mode = 3 and INT_n = '0' and IntE_FF1 = '0')) then  -- halt bug when Mode = 3 , INT_n = '0' and IME=0
								Halt_FF <= '1';
							end if;
							if BusReq_s = '1' then
								BusAck <= '1';
							else
								TState <= "001";
								if (IntCycle = '1' and Mode = 3) then -- GB: read interrupt at MCycle 3
									if (MCycle = "010") then
										M1_n <= '0';
									else
										M1_n <= '1';
									end if;
								end if;
								if NextIs_XY_Fetch = '1' then
									MCycle <= "110";
									Pre_XY_F_M <= MCycle;
									if IR = "00110110" and Mode = 0 then
										Pre_XY_F_M <= "010";
									end if;
								elsif (MCycle = "111") or (MCycle = "110" and Mode = 1 and ISet /= "01") then
									MCycle <= std_logic_vector(unsigned(Pre_XY_F_M) + 1);
								elsif (MCycle = MCycles) or No_BTR = '1' or (MCycle = "010" and I_DJNZ = '1' and IncDecZ = '1') then
									M1_n <= '0';
									MCycle <= "001";
									IntCycle <= '0';
									NMICycle <= '0';
									if NMI_s = '1' and Prefix = "00" then
										NMI_s    <= '0';
										NMICycle <= '1';
										IntE_FF1 <= '0';
									elsif IntE_FF1 = '1' and INT_n='0' and Prefix = "00" and SetEI = '0' then
										IntCycle <= '1';
										IntE_FF1 <= '0';
										IntE_FF2 <= '0';
									elsif (Halt_FF = '1' and INT_n = '0' and Mode = 3) then
										Halt_FF <= '0';
									end if;
								else
									MCycle <= std_logic_vector(unsigned(MCycle) + 1);
								end if;
							end if;
						else
							if (Auto_Wait = '1' and Auto_Wait_t2 = '0') nor
								(IOWait = 1 and IORQ_i = '1' and Auto_Wait_t1 = '0') then
								TState <= TState + 1;
							end if;
						end if;
					end if;
					if TState = 0 then
						M1_n <= '0';
					end if;
				end if;
			end if;
		end if;
	end process;

	Auto_Wait <= '1' when IntCycle = '1' and MCycle = "001" else '0';
end;
