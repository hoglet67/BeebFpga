#!/bin/bash

XILINX=/opt/Xilinx/14.7
DATA2MEM=${XILINX}/ISE_DS/ISE/bin/lin/data2mem
PAPILIO_LOADER=/opt/GadgetFactory/papilio-loader/programmer
PROG=${PAPILIO_LOADER}/linux32/papilio-prog
BSCAN=${PAPILIO_LOADER}/bscan_spi_xc6slx9.bit

# Create the 272K ROM image
#
# This contains 17x 16K ROMS
# 0..15 are 16K sideways ROMS
# 16 is the MOS

gcc -o bitmerge bitmerge.c 

rm -f rom_image.bin

cat blank.rom             >> rom_image.bin
cat blank.rom             >> rom_image.bin
cat blank.rom             >> rom_image.bin
cat blank.rom             >> rom_image.bin

cat blank.rom             >> rom_image.bin
cat blank.rom             >> rom_image.bin
cat blank.rom             >> rom_image.bin
cat blank.rom             >> rom_image.bin

cat blank.rom             >> rom_image.bin
cat blank.rom             >> rom_image.bin
cat blank.rom             >> rom_image.bin
cat blank.rom             >> rom_image.bin

cat blank.rom             >> rom_image.bin
cat smartmmc.rom.20151002 >> rom_image.bin
cat ram_master_v6.rom     >> rom_image.bin
cat basic2.rom            >> rom_image.bin

cat os12.rom              >> rom_image.bin

# Run bitmerge to merge in the ROM images
./bitmerge ../working/bbc_micro_duo.bit 60000:rom_image.bin merged1.bit

# Remove the old rom image
rm -f rom_image.bin bitmerge

# Run data2mem to merge in the AVR Firmware
BMM_FILE=../src/CpuMon_bd.bmm
${DATA2MEM} -bm ${BMM_FILE} -bd ../../AtomBusMon/firmware/avr_progmem.mem -bt merged1.bit -o b merged2.bit

# Program the Papilo Duo
${PROG} -v -f merged2.bit -b ${BSCAN}  -sa -r

# Reset the Papilio Duo
${PROG} -c

