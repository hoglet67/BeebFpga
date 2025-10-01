#!/bin/bash -e

OPTS="--ieee=synopsys -fexplicit"
ghdl -a ${OPTS} ../../src/gowin/src/R65Cx2.vhd
ghdl -a ${OPTS} ../../AtomBusMon/src/T6502/T65_Pack.vhd
ghdl -a ${OPTS} ../../AtomBusMon/src/T6502/T65_ALU.vhd
ghdl -a ${OPTS} ../../AtomBusMon/src/T6502/T65_MCode.vhd
ghdl -a ${OPTS} ../../AtomBusMon/src/T6502/T65.vhd
ghdl -a ${OPTS} ../../src/common/m6522.vhd
ghdl -a ${OPTS} m6522_tb.vhd
ghdl -e ${OPTS} m6522_tb
ghdl -r ${OPTS} m6522_tb --vcd=test.vcd --stop-time=2000us
