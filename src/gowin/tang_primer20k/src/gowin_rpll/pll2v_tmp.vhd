--Copyright (C)2014-2024 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: Template file for instantiation
--Tool Version: V1.9.11 (64-bit)
--Part Number: GW2A-LV18PG256C8/I7
--Device: GW2A-18
--Device Version: C
--Created Time: Wed Mar 26 12:34:39 2025

--Change the instance name and port connections to the signal names
----------Copy here to design--------

component pll2v
    port (
        clkout: out std_logic;
        clkin: in std_logic
    );
end component;

your_instance_name: pll2v
    port map (
        clkout => clkout,
        clkin => clkin
    );

----------Copy end-------------------
