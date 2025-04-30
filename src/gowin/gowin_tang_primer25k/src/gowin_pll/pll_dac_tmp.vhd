--Copyright (C)2014-2024 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: Template file for instantiation
--Tool Version: V1.9.11 (64-bit)
--Part Number: GW5A-LV25MG121NC1/I0
--Device: GW5A-25
--Device Version: A
--Created Time: Mon Mar  3 16:52:07 2025

--Change the instance name and port connections to the signal names
----------Copy here to design--------

component pll_dac
    port (
        clkout0: out std_logic;
        clkin: in std_logic
    );
end component;

your_instance_name: pll_dac
    port map (
        clkout0 => clkout0,
        clkin => clkin
    );

----------Copy end-------------------
