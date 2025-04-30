-- MIT License
-- 
-- Copyright (c) 2024 dominicbeesley
-- 
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
-- 
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
-- 
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.




library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;
use ieee.math_real.all;

library work;
use work.common.all;

entity sdramctl is
	generic (
		CLOCKSPEED 	: natural;
		T_CAS_EXTRA : natural 	:= 0;	-- this needs to be 1 for > ~90 MHz

		
		-- SDRAM geometry
		LANEBITS		: natural 	:= 1;	-- number of byte lanes bits, if 0 don't connect sdram_DQM_o
		BANKBITS    : natural 	:= 2;	-- number of bits, if none set to 0 and don't connect sdram_BS_o
		ROWBITS     : positive 	:= 13;
		COLBITS		: positive 	:= 9;

		-- SDRAM speed 
		trp 			: time := 15 ns;  -- precharge
		trcd 			: time := 15 ns;	-- active to read/write
		trc 			: time := 60 ns;	-- active to active time
		trfsh			: time := 1.8 us;	-- the refresh control signal will be blocked if it occurs more frequently than this
		trfc  		: time := 63 ns 	-- refresh cycle time
		

		);
	port (
		Clk		:  in		std_logic; 

		-- sdram interface
		sdram_DQ_io			:	inout std_logic_vector((2**LANEBITS)*8-1 downto 0);
		sdram_A_o			:	out	std_logic_vector(maximum(COLBITS, ROWBITS)-1 downto 0); 
		sdram_BS_o			:  out 	std_logic_vector(maximum(BANKBITS-1, 0) downto 0); 
		sdram_CKE_o			:	out	std_logic;
		sdram_nCS_o			:	out	std_logic;
		sdram_nRAS_o		:	out	std_logic;
		sdram_nCAS_o		:	out	std_logic;
		sdram_nWE_o			:	out	std_logic;
		sdram_DQM_o			:	out	std_logic_vector(2 ** LANEBITS - 1 downto 0);

		-- cpu interface

		-- Address laid out as bank, row, column, byte lanes from high to low

		ctl_rfsh_i			:	in		std_logic	:= '0';		-- do an auto-refresh if one is pending (>trfsh since last)
		ctl_manrfsh_i		:  in    std_logic   := '0';		-- do a "manual" refresh by opening the specified bank/row and then pre-charging
		ctl_reset_i			:	in		std_logic;

		ctl_stall_o			:	out	std_logic;
		ctl_cyc_i			:	in		std_logic;
		ctl_we_i				:	in		std_logic;
		ctl_A_i				:	in		std_logic_vector(LANEBITS+BANKBITS+ROWBITS+COLBITS-1 downto 0);
		ctl_D_wr_i			:	in		std_logic_vector(7 downto 0);
		ctl_D_rd_o			:	out	std_logic_vector(7 downto 0);
		ctl_ack_o			:	out	std_logic
	);

end sdramctl;

architecture rtl of sdramctl is

	constant tck 	: time := 1 sec / CLOCKSPEED;	
	
	function CLOCKS(t:time) return integer is
	variable r:integer;
	begin
		r := (tck + t - 1 fs)/tck;
--		if r <= 1 then
--			r := 2;
--		end if;
		return r;
	end function;

	-- cycle count equivalents of generics
	constant T_RP 	: natural := CLOCKS(trp);		-- PRECHARGE cycles
	constant T_RC 	: natural := CLOCKS(trc);		-- ACTIVE to ACTIVE cycles
	constant T_RCD : natural := CLOCKS(trcd);		-- ACTIVE to READ/WRITE cycles
	constant T_RFSH: natural := CLOCKS(trfsh);
	constant T_RFC : natural := CLOCKS(trfc);

	-- other cycle counts
	constant T_RSC	: natural := 2;					-- ? TODO: change to tMRD and get rid of "after"
	constant T_CAS	: natural := 2;
	constant T_WR	: natural := 2;

	-- derived cycle indexes
	-- ---------------------
	-- wait for activate
	constant TIX_RW_CMD 	: natural := T_RCD-1;
	-- data read on bus
	constant TIX_RD_DAT	: natural := T_RCD + T_CAS + T_CAS_EXTRA - 1;
	-- read finished go back to idle state with sufficient time for auto-precharge to finish
	constant TIX_RD_FIN  : natural := maximum(TIX_RD_DAT, TIX_RD_DAT + T_RP - 2);
	-- write finished go back to idle with sufficient time for auto-precharge to finish
	constant TIX_WR_FIN	: natural := maximum(TIX_RW_CMD, T_RCD + T_WR + T_RP - 3);
	-- refresh precharge start
	constant TIX_REF_PRE : natural := T_RCD + T_CAS + 1 - 1;
	-- refresh finishing go back to idle with sufficient time for precharge to finish
	constant TIX_REF_FIN : natural := T_RCD + T_CAS + 1 + T_RP - 2;


	constant B_DQM_HI 	: integer := LANEBITS - 1;	-- maybe < 0
	constant B_COL_LO 	: natural := B_DQM_HI + 1;
	constant B_COL_HI 	: natural := B_COL_LO + COLBITS - 1;
	constant B_ROW_LO 	: natural := B_COL_HI + 1;
	constant B_ROW_HI 	: natural := B_ROW_LO + ROWBITS - 1;
	constant B_BANK_LO 	: natural := B_ROW_HI + 1;
	constant B_BANK_HI 	: natural := B_BANK_LO + BANKBITS - 1;

	-- r_powerup_ctr is 1 bit wider and wrap-around indicates finished
	constant PCTR_MAX : natural := 200 * (CLOCKSPEED / 1000000);
	signal r_powerup_ctr : unsigned(numbits(PCTR_MAX) downto 0) 
										:= "0" & to_unsigned(PCTR_MAX, numbits(PCTR_MAX));

	type t_state_main is (
		reset,
		powerup,
		config_pre,
		config_ar_before,
		config_mode,
		config_ar_after,
		run
	);

	signal r_state_main 	: 	t_state_main := powerup;

	type t_run_state is (
		start,				-- hold stall for an extra cycle while start
		idle,
		refresh_auto,
		refresh_man,
		read,
		write
	);

	signal r_run_state 	: t_run_state := idle;

	-- used for substates in init/normal operations
	constant CYC_MAX : natural := 16;
	signal r_cycle			:	std_logic_vector(CYC_MAX downto 0);
	signal r_config_ar_ct:	unsigned(3 downto 0) := (others => '0');

	type sdram_cmd is record
		nCS	: std_logic;
		nRAS	: std_logic;
		nCAS	: std_logic;
		nWE	: std_logic;
	end record sdram_cmd;

	constant cmd_nop			: sdram_cmd := (nCS => '1', nRAS => '1', nCAS => '1', nWE => '1');
	constant cmd_setmode		: sdram_cmd := (nCS => '0', nRAS => '0', nCAS => '0', nWE => '0');
	constant cmd_bankact		: sdram_cmd := (nCS => '0', nRAS => '0', nCAS => '1', nWE => '1');
	constant cmd_write		: sdram_cmd := (nCS => '0', nRAS => '1', nCAS => '0', nWE => '0');
	constant cmd_read			: sdram_cmd := (nCS => '0', nRAS => '1', nCAS => '0', nWE => '1');
	constant cmd_autorefresh: sdram_cmd := (nCS => '0', nRAS => '0', nCAS => '0', nWE => '1');
	constant cmd_precharge	: sdram_cmd := (nCS => '0', nRAS => '0', nCAS => '1', nWE => '0');

	constant MODREG			: std_logic_vector(10 downto 0) := "00000" & std_logic_vector(to_unsigned(T_CAS,2)) & "0000"; --Burst=1, Seq, Cas=T_CAS

	signal	r_cmd				: sdram_cmd;

	-- r_rfshctr is 1 bit wider than necessary, wrap around indicates ready
	signal	r_rfshctr 		: unsigned(numbits(T_RFSH-1) downto 0) := to_unsigned(T_RFSH-1, numbits(T_RFSH-1)+1);

	signal 	r_A_latched		: std_logic_vector(ctl_A_i'range);
	signal   r_D_wr_latched	: std_logic_vector(7 downto 0);

begin

	ctl_stall_o		<= '1' when r_state_main /= run else
							'1' when r_run_state /= idle else
							'0';

	sdram_CKE_o 	<= '1';
	sdram_nCS_o 	<= r_cmd.nCS;
	sdram_nRAS_o 	<= r_cmd.nRAS;
	sdram_nCAS_o 	<= r_cmd.nCAS;
	sdram_nWE_o 	<= r_cmd.nWE;

	p_state:process(clk)

		procedure RESET_CYCLE is
		begin
			r_cycle <= (0 => '1', others => '0');
		end RESET_CYCLE;
	
		procedure RESET_RFSH is
		begin
			r_rfshctr <= to_unsigned(T_RFSH-1, r_rfshctr'length);
		end RESET_RFSH;
	
		function DQM(
			A : std_logic_vector
			) return std_logic_vector is
		variable ret : std_logic_vector(sdram_DQM_o'range);
		begin
			ret := (others => '1');
			if B_DQM_HI < 0 then
				ret := (others => '0');
			else
				ret(to_integer(unsigned(A(B_DQM_HI downto 0)))) := '0';
			end if;
			return ret;
		end function;

		-- return an 8 bit slice from a wider data bus, indexed by low bits of A
		function DQSLICE(
			A : std_logic_vector;
			D : std_logic_vector
			) return std_logic_vector is
		variable I : natural;
		variable ret : std_logic_vector(7 downto 0);
		begin
			if B_DQM_HI < 0 then
				ret := D(7 downto 0);
			else
				I := to_integer(unsigned(A(B_DQM_HI downto 0))) * 8;
				ret := D(I+7 downto I);
			end if;
			return ret;
		end DQSLICE;

		-- repeat the give 8 bit data to fill the wider data bus
		function DQREP(
			D : std_logic_vector(7 downto 0)
		) return std_logic_vector is
		variable ret : std_logic_vector((2 ** LANEBITS) * 8 - 1 downto 0);
		begin

			for I in 0 to 2 ** LANEBITS - 1 loop
				ret(7 + I * 8 downto I * 8) := D;
			end loop;

			return ret;
		end DQREP;

	begin

		if rising_edge(clk) then
			r_cycle <= r_cycle(r_cycle'high-1 downto 0) & '0';

			if r_rfshctr(r_rfshctr'high) = '0' then
				r_rfshctr <= r_rfshctr - 1;
			end if;

			r_cmd <= cmd_nop;
			
			sdram_DQM_o <= (others => '1');
			sdram_DQ_io <= (others => 'Z');
			ctl_ack_o <= '0';

			case r_state_main is 
				when powerup | reset =>
					if r_powerup_ctr(r_powerup_ctr'high) = '1' then
						r_state_main <= config_pre;
						r_config_ar_ct <= (others => '0');
						RESET_CYCLE;
					end if;
				when config_pre =>
					if r_cycle(0) = '1' then
						r_cmd <= cmd_precharge;					
						sdram_A_o(10) <= '1';								-- all banks get same mode setting
						sdram_BS_o <= (others => '0');					-- don't care
					end if;
					if r_cycle(T_RP) = '1' then
						r_config_ar_ct <= (others => '0');
					r_state_main <= config_ar_before;
					RESET_CYCLE;				
					end if;
				when config_ar_before =>
					if r_cycle(0) = '1' then
						r_cmd <= cmd_autorefresh;
						sdram_A_o(10) <= '1';
						sdram_BS_o <= (others => '0');
						r_config_ar_ct <= r_config_ar_ct + 1;
					end if;
					if r_cycle(T_RC) = '1' then
						RESET_CYCLE;				
						if r_config_ar_ct(r_config_ar_ct'high) = '1' then
						r_state_main <= config_mode;
						end if;
					end if;
				when config_mode =>
					if r_cycle(0) = '1' then
						r_cmd <= cmd_setmode;
						sdram_A_o <= (others => '0');
						sdram_A_o(10 downto 0) <= MODREG;
						sdram_BS_o <= (others => '0');
					end if;
					if r_cycle(T_RSC) = '1' then
						r_config_ar_ct <= (others => '0');
						RESET_CYCLE;
						r_state_main <= config_ar_after;
					end if;
				when config_ar_after =>
					if r_cycle(0) = '1' then
						r_cmd <= cmd_autorefresh;
						sdram_A_o(10) <= '1';
						sdram_BS_o <= (others => '0');
						r_config_ar_ct <= r_config_ar_ct + 1;
					end if;
					if r_cycle(T_RC) = '1' then
						RESET_CYCLE;				
						if r_config_ar_ct(r_config_ar_ct'high) = '1' then
							r_state_main <= run;
							r_run_state <= start;
						end if;
					end if;
				when run =>

					case r_run_state is
						when start =>
							r_run_state <= idle;
						when idle =>
							RESET_CYCLE;
							if ctl_cyc_i = '1' then
								r_A_latched <= ctl_A_i;
								r_cmd <= cmd_bankact;
								sdram_BS_o <= ctl_A_i(B_BANK_HI downto B_BANK_LO);	
								sdram_A_o <= (others => '0');
								sdram_A_o(ROWBITS-1 downto 0)  <= ctl_A_i(B_ROW_HI downto B_ROW_LO);
								if ctl_manrfsh_i = '1' then
									r_run_state <= refresh_man;
								elsif ctl_we_i = '0' then
									r_run_state <= read;
								else
									r_run_state <= write;
									r_D_wr_latched <= ctl_D_wr_i;								
									ctl_ack_o <= '1';
								end if;						
							elsif r_rfshctr(r_rfshctr'high) = '1' and ctl_rfsh_i = '1' then
								r_cmd <= cmd_autorefresh;
								sdram_A_o(10) <= '1';
								sdram_BS_o <= (others => '0');
								RESET_RFSH;		
								r_run_state <= refresh_auto;					
							end if;
						when read =>
							if r_cycle(TIX_RW_CMD) = '1' then
								r_cmd <= cmd_read;
								sdram_A_o <= (others => '0');
								sdram_A_o(COLBITS-1 downto 0) <= r_A_latched(B_COL_HI downto B_COL_LO);
								sdram_A_o(10) <= '1'; -- auto precharge
								sdram_DQM_o <= (others => '0');
							end if;
							if r_cycle(TIX_RD_DAT) = '1' then
								ctl_ack_o <= '1';
								ctl_D_rd_o <= DQSLICE(r_A_latched, sdram_DQ_io);
							end if;
							if r_cycle(TIX_RD_FIN) = '1' then
								r_run_state <= idle;
							end if;
						when write =>
							if r_cycle(TIX_RW_CMD) = '1' then
								r_cmd <= cmd_write;
								sdram_A_o <= (others => '0');
								sdram_A_o(COLBITS-1 downto 0) <= r_A_latched(B_COL_HI downto B_COL_LO);
								sdram_A_o(10) <= '1'; -- auto precharge
								sdram_DQ_io <= DQREP(r_D_wr_latched);
								sdram_DQM_o <= DQM(r_A_latched);
							end if;
							if r_cycle(TIX_WR_FIN) = '1' then
								r_run_state <= idle;
							end if;
						when refresh_man =>
							if r_cycle(TIX_REF_PRE) = '1' then
								r_cmd <= cmd_precharge;
							elsif r_cycle(TIX_REF_FIN) = '1' then
								r_run_state <= idle;
							end if;
						when refresh_auto =>
							if r_cycle(T_RFC) = '1' then
								RESET_CYCLE;
								r_run_state <= idle;
							end if;
						when others => 

					end case;

				when others => null;


			end case;

			if ctl_reset_i = '1' then
				r_state_main <= reset;
				RESET_CYCLE;
				r_run_state <= start;
			end if;

		end if;

	end process;


	p_powerup:process(clk)
	begin
		if rising_edge(clk) then
			if r_powerup_ctr(r_powerup_ctr'high) = '0' then
				r_powerup_ctr <= r_powerup_ctr - 1;
			end if;
		end if;		
	end process;

end rtl;

