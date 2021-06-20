connect -url tcp:127.0.0.1:3121
source /disk1/home/dmb/atom/BeebFpga/xilinx/bbc_master_pynqz2/bbc_master_pynqz2.sdk/bbc_micro_pynqz2_hw_platform_0/ps7_init.tcl
targets -set -nocase -filter {name =~"APU*" && jtag_cable_name =~ "Xilinx TUL 1234-tulA"} -index 0
loadhw -hw /disk1/home/dmb/atom/BeebFpga/xilinx/bbc_master_pynqz2/bbc_master_pynqz2.sdk/bbc_micro_pynqz2_hw_platform_0/system.hdf -mem-ranges [list {0x40000000 0xbfffffff}]
configparams force-mem-access 1
targets -set -nocase -filter {name =~"APU*" && jtag_cable_name =~ "Xilinx TUL 1234-tulA"} -index 0
stop
ps7_init
ps7_post_config
targets -set -nocase -filter {name =~ "ARM*#0" && jtag_cable_name =~ "Xilinx TUL 1234-tulA"} -index 0
rst -processor
targets -set -nocase -filter {name =~ "ARM*#0" && jtag_cable_name =~ "Xilinx TUL 1234-tulA"} -index 0
dow /disk1/home/dmb/atom/BeebFpga/xilinx/bbc_master_pynqz2/bbc_master_pynqz2.sdk/BeebFpgaLoader/Debug/BeebFpgaLoader.elf
configparams force-mem-access 0
targets -set -nocase -filter {name =~ "ARM*#0" && jtag_cable_name =~ "Xilinx TUL 1234-tulA"} -index 0
con
