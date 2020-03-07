#!/bin/bash

run_data2mem=$false

XILINX=/opt/Xilinx/14.7
DATA2MEM=${XILINX}/ISE_DS/ISE/bin/lin64/data2mem
PAPILIO_LOADER=/opt/GadgetFactory/papilio-loader/programmer
PROG=${PAPILIO_LOADER}/linux64/papilio-prog
BSCAN=${PAPILIO_LOADER}/bscan_spi_xc6slx9.bit
IMAGE=tmp/rom_image_128K.bin

# Build a fresh ROM image
./make_rom_image_minimal.sh

# Run bitmerge to merge in the ROM images
gcc -o tmp/bitmerge bitmerge.c
./tmp/bitmerge ../xilinx/working/bbc_micro_duo/bbc_micro_duo.bit 60000:$IMAGE tmp/merged.bit
rm -f ./tmp/bitmerge

# Run data2mem to merge in the AVR Firmware
if [ $run_data2mem ]; then
BMM_FILE=../src/xilinx/CpuMon_bd.bmm
${DATA2MEM} -bm ${BMM_FILE} -bd ../AtomBusMon/firmware/avr_progmem.mem -bt tmp/merged.bit -o b tmp/merged2.bit
mv tmp/merged2.bit tmp/merged.bit
fi

# Program the Papilo Duo
sudo ${PROG} -v -f tmp/merged.bit -b ${BSCAN}  -sa -r

# Reset the Papilio Duo
sudo ${PROG} -c
