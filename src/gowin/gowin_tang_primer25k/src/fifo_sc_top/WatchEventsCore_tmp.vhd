--Copyright (C)2014-2024 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: Template file for instantiation
--Tool Version: V1.9.11 (64-bit)
--Part Number: GW5A-LV25MG121NC1/I0
--Device: GW5A-25
--Device Version: A
--Created Time: Sat Mar  1 18:32:38 2025

--Change the instance name and port connections to the signal names
----------Copy here to design--------

component WatchEventsCore
	port (
		Data: in std_logic_vector(71 downto 0);
		Clk: in std_logic;
		WrEn: in std_logic;
		RdEn: in std_logic;
		Reset: in std_logic;
		Q: out std_logic_vector(71 downto 0);
		Empty: out std_logic;
		Full: out std_logic
	);
end component;

your_instance_name: WatchEventsCore
	port map (
		Data => Data,
		Clk => Clk,
		WrEn => WrEn,
		RdEn => RdEn,
		Reset => Reset,
		Q => Q,
		Empty => Empty,
		Full => Full
	);

----------Copy end-------------------
