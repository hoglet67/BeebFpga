--Copyright (C)2014-2024 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: Template file for instantiation
--Tool Version: V1.9.9.02
--Part Number: GW5A-LV25MG121NC1/I0
--Device: GW5A-25
--Device Version: B
--Created Time: Mon May 27 18:04:19 2024

--Change the instance name and port connections to the signal names
----------Copy here to design--------

component pll_27_135
    port (
        lock: out std_logic;
        clkout0: out std_logic;
        clkout1: out std_logic;
        clkin: in std_logic
    );
end component;

your_instance_name: pll_27_135
    port map (
        lock => lock_o,
        clkout0 => clkout0_o,
        clkout1 => clkout1_o,
        clkin => clkin_i
    );

----------Copy end-------------------
