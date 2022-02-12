#!/bin/bash
. /opt/Xilinx/14.7/ISE_DS/settings64.sh

run_data2mem=$false

PAPILIO_LOADER=/opt/GadgetFactory/papilio-loader/programmer
PROG=${PAPILIO_LOADER}/linux64/papilio-prog
BSCAN=${PAPILIO_LOADER}/bscan_spi_xc6slx9.bit
IMAGE=tmp/rom_image.bin

# Build a fresh ROM image
./make_rom_image.sh

# 0x000000 - Boot Loader
# 0x054000 - BBC Micro Bitstream
# 0x0a8000 - BBC Master Bitstream
# 0x100000 - BBC Micro ROMS
# 0x140000 - BBC Master ROMS

# Strip of the bitstream header of the BBC Micro FPGA

# Run bitmerge to merge in the ROM images
gcc -o tmp/bitmerge bitmerge.c

promgen -b -u 0 ../xilinx/working/bbc_micro_duo/bbc_micro_duo.bit -o tmp/bbc_micro_duo.bin -p bin -w
promgen -b -u 0 ../xilinx/working/bbc_master_duo/bbc_micro_duo.bit -o tmp/bbc_master_duo.bin -p bin -w

cp ../xilinx/working/duo_boot_loader/duo_boot_loader.bit    tmp/merged.bit
./tmp/bitmerge tmp/merged.bit  54000:tmp/bbc_micro_duo.bin  tmp/merged.bit
./tmp/bitmerge tmp/merged.bit  A8000:tmp/bbc_master_duo.bin tmp/merged.bit
./tmp/bitmerge tmp/merged.bit 100000:$IMAGE                 tmp/merged.bit

rm -f tmp/bitmerge
rm -f tmp/bbc_micro_duo.bin
rm -f tmp/bbc_master_duo.bin

# Run data2mem to merge in the AVR Firmware
#if [ $run_data2mem ]; then
#BMM_FILE=../src/xilinx/CpuMon_bd.bmm
#${DATA2MEM} -bm ${BMM_FILE} -bd ../AtomBusMon/firmware/avr_progmem.mem -bt tmp/merged.bit -o b tmp/merged2.bit
#mv tmp/merged2.bit tmp/merged.bit
#fi

# Program the Papilo Duo
sudo ${PROG} -v -f tmp/merged.bit -b ${BSCAN}  -sa -r

# Reset the Papilio Duo
sudo ${PROG} -c
