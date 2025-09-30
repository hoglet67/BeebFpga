#!/bin/bash -e

OPTS="--ieee=synopsys"

ghdl -a ${OPTS} ../../src/common/m6522.vhd
ghdl -a ${OPTS} m6522_tb.vhd
ghdl -e ${OPTS} m6522_tb
ghdl -r ${OPTS} m6522_tb --vcd=test.vcd --stop-time=500us
