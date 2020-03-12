#!/bin/bash

ghdl -a -fexplicit --ieee=synopsys ../../src/xilinx/hdmi/encoder.vhd
ghdl -a -fexplicit --ieee=synopsys ../../src/xilinx/hdmi/hdmidelay.vhd
ghdl -a -fexplicit --ieee=synopsys ../../src/xilinx/hdmi/hdmi.vhd
ghdl -a -fexplicit --ieee=synopsys vhdl_tb/test_harness.vhd

ghdl -e -fexplicit --ieee=synopsys test_harness
ghdl -r -fexplicit --ieee=synopsys test_harness --vcd=dump.vcd

#--wave=dump.ghw
