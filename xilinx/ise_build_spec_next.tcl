#!/opt/Xilinx/14.7/ISE_DS/ISE/bin/lin64/xtclsh

project open bbc_master_spec_next.xise
project clean
process run "Generate Programming File"
project close

project open bbc_micro_spec_next.xise
project clean
process run "Generate Programming File"
project close

exit
