#!/bin/bash

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

# Run bitmerge
./bitmerge ../working/bbc_micro_duo.bit 60000:rom_image.bin merged.bit

# Remove the old rom image
rm -f rom_image.bin bitmerge

# Program the Papilo Duo
/opt/GadgetFactory/papilio-loader/programmer/linux32/papilio-prog -v -b /opt/GadgetFactory/papilio-loader/programmer/bscan_spi_xc6slx9.bit -f merged.bit -sa -r

# Reset the Papilio Duo
/opt/GadgetFactory/papilio-loader/programmer/linux32/papilio-prog -c

