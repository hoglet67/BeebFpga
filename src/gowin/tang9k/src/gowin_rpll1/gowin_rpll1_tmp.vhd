--Copyright (C)2014-2023 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: Template file for instantiation
--GOWIN Version: V1.9.8.11 Education
--Part Number: GW1NR-LV9QN88PC6/I5
--Device: GW1NR-9
--Device Version: C
--Created Time: Thu May 18 15:35:21 2023

--Change the instance name and port connections to the signal names
----------Copy here to design--------

component Gowin_rPLL
    port (
        clkout: out std_logic;
        lock: out std_logic;
        clkoutp: out std_logic;
        clkoutd: out std_logic;
        clkoutd3: out std_logic;
        reset: in std_logic;
        clkin: in std_logic
    );
end component;

your_instance_name: Gowin_rPLL
    port map (
        clkout => clkout_o,
        lock => lock_o,
        clkoutp => clkoutp_o,
        clkoutd => clkoutd_o,
        clkoutd3 => clkoutd3_o,
        reset => reset_i,
        clkin => clkin_i
    );

----------Copy end-------------------
