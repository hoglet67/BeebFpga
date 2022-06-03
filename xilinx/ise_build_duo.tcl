#!/opt/Xilinx/14.7/ISE_DS/ISE/bin/lin64/xtclsh

project open duo_boot_loader.xise
project clean
process run "Generate Programming File"
project close

project open bbc_micro_duo.xise
project clean
process run "Generate Programming File"
project close

project open bbc_master_duo.xise
project clean
process run "Generate Programming File"
project close

project open bbc_micro_duo_nula.xise
project clean
process run "Generate Programming File"
project close

project open bbc_master_duo_nula.xise
project clean
process run "Generate Programming File"
project close
exit
