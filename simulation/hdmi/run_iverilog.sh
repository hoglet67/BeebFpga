#!/bin/bash

rm -f a.out

iverilog verilog_tb/test_harness.v ../../src/xilinx/hdmi/*.v

./a.out
