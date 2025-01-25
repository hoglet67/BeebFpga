
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;
use ieee.math_real.all;

library work;
use work.common.all;

entity sdramctl is
	generic (
		CLOCKSPEED : natural;
		T_CAS_EXTRA : natural := 0	-- this neads to be 1 for > ~90 MHz

		);
	port (
		Clk		:  in		std_logic;

            -- SDRAM address is structured as:
            --   bits 22..21 are the bank (4 banks)
            --   bits 20..10 are the row (2048 rows)
            --   bits 9..2 are the column (256 cols)
            --   bits 1..0 are the byte offset (selecting 8 bits out of 32)

		-- sdram interface
		sdram_DQ_io			:	inout std_logic_vector(31 downto 0);
		sdram_A_o			:	out	std_logic_vector(10 downto 0);
		sdram_BS_o			:  out 	std_logic_vector(1 downto 0);
		sdram_CKE_o			:	out	std_logic;
		sdram_nCS_o			:	out	std_logic;
		sdram_nRAS_o		:	out	std_logic;
		sdram_nCAS_o		:	out	std_logic;
		sdram_nWE_o			:	out	std_logic;
		sdram_DQM_o			:	out	std_logic_vector(3 downto 0);

		-- cpu interface

		ctl_rfsh_i			:	in		std_logic;
		ctl_reset_i			:	in		std_logic;

		ctl_stall_o			:	out	std_logic;
		ctl_cyc_i			:	in		std_logic;
		ctl_we_i				:	in		std_logic;
		ctl_A_i				:	in		std_logic_vector(22 downto 0);
		ctl_D_wr_i			:	in		std_logic_vector(7 downto 0);
		ctl_D_rd_o			:	out	std_logic_vector(7 downto 0);
		ctl_ack_o			:	out	std_logic
	);

end sdramctl;

architecture rtl of sdramctl is

	constant tck 	: time := 1 sec / CLOCKSPEED;
	constant trp 	: time := 15 ns;
	constant trcd 	: time := 15 ns;
	constant trc 	: time := 60 ns;
	--constant trfsh	: time := 7.8 us;
	constant trfsh	: time := 1.8 us;
	constant trfc  : time := 63 ns; -- refresh cycle time

	function CLOCKS(t:time) return integer is
	variable r:integer;
	begin
		r := (tck + t - 1 fs)/tck;
--		if r <= 1 then
--			r := 2;
--		end if;
		return r;
	end function;


	constant T_RP 	: natural := CLOCKS(trp);
	constant T_RC 	: natural := CLOCKS(trc);
	constant T_RCD : natural := CLOCKS(trcd);
	constant T_RSC	: natural := 2;
	constant T_CAS	: natural := 2;
	constant T_RFSH: natural := CLOCKS(trfsh);
	constant T_WR	: natural := 2;
	constant T_RFC : natural := CLOCKS(trfc);

	-- r_powerup_ctr is 1 bit wider and wrap-around indicates finished
	constant PCTR_MAX : natural := 200*(CLOCKSPEED/1000000);
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
		refresh,
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

	constant MODREG			: std_logic_vector(10 downto 0) := "00000" & std_logic_vector(to_unsigned(T_CAS,2)) & "0000"; --Burst=1, Seq, Cas=3

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
						sdram_A_o(10) <= '1';
						sdram_BS_o <= (others => '0');
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
						sdram_A_o <= (10 downto 0 => MODREG, others => '0');
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
								sdram_BS_o <= ctl_A_i(22 downto 21);
								sdram_A_o  <= ctl_A_i(20 downto 10);
								if ctl_we_i = '0' then
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
								r_run_state <= refresh;
							end if;
						when read =>
							if r_cycle(T_RCD-1) = '1' then
								r_cmd <= cmd_read;
								sdram_A_o(7 downto 0) <= r_A_latched(9 downto 2);
								sdram_A_o(10) <= '1'; -- auto precharge
								sdram_DQM_o(0) <= '0';
								sdram_DQM_o(1) <= '0';
								sdram_DQM_o(2) <= '0';
								sdram_DQM_o(3) <= '0';
							end if;
							-- need +1 below to allow for routing delays? it seems to only work at > 100MHz
							if r_cycle(T_RCD + T_CAS + T_CAS_EXTRA - 1) = '1' then
								r_run_state <= idle;
								ctl_ack_o <= '1';
                        case r_A_latched(1 downto 0) is
                            when "00" =>
                                ctl_D_rd_o <= sdram_DQ_io(7 downto 0);
                            when "01" =>
                                ctl_D_rd_o <= sdram_DQ_io(15 downto 8);
                            when "10" =>
                                ctl_D_rd_o <= sdram_DQ_io(23 downto 16);
                            when "11" =>
                                ctl_D_rd_o <= sdram_DQ_io(31 downto 24);
                            when others => null;
                       end case;
							end if;
						when write =>
							if r_cycle(T_RCD - 1) = '1' then
								r_cmd <= cmd_write;
								sdram_A_o(7 downto 0) <= r_A_latched(9 downto 2);
								sdram_A_o(10) <= '1'; -- auto precharge
								sdram_DQ_io <= r_D_wr_latched & r_D_wr_latched & r_D_wr_latched & r_D_wr_latched;
								sdram_DQM_o(0) <=     r_A_latched(1) or     r_A_latched(0);
								sdram_DQM_o(1) <=     r_A_latched(1) or not r_A_latched(0);
								sdram_DQM_o(2) <= not r_A_latched(1) or     r_A_latched(0);
								sdram_DQM_o(3) <= not r_A_latched(1) or not r_A_latched(0);
							end if;
							if r_cycle(T_RCD + T_WR + T_RP - 1) = '1' then
								r_run_state <= idle;
							end if;
						when refresh =>
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
