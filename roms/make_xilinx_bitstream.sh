#!/bin/bash

XILINX=/opt/Xilinx/14.7
DATA2MEM=${XILINX}/ISE_DS/ISE/bin/lin/data2mem
PAPILIO_LOADER=/opt/GadgetFactory/papilio-loader/programmer
PROG=${PAPILIO_LOADER}/linux32/papilio-prog
BSCAN=${PAPILIO_LOADER}/bscan_spi_xc6slx9.bit
IMAGE=tmp/rom_image.bin

# Build a fresh ROM image
./make_rom_image.sh

# Run bitmerge to merge in the ROM images
gcc -o tmp/bitmerge bitmerge.c 
./tmp/bitmerge ../working/bbc_micro_duo.bit 60000:$IMAGE tmp/merged1.bit
rm -f ./tmp/bitmerge

# Run data2mem to merge in the AVR Firmware
BMM_FILE=../src/CpuMon_bd.bmm
${DATA2MEM} -bm ${BMM_FILE} -bd ../../AtomBusMon/firmware/avr_progmem.mem -bt tmp/merged1.bit -o b tmp/merged2.bit

# Program the Papilo Duo
${PROG} -v -f tmp/merged2.bit -b ${BSCAN}  -sa -r

# Reset the Papilio Duo
${PROG} -c
