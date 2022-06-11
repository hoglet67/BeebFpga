#!/bin/bash

# Create the minimal ROM image
#
# This contains:
# 4x 16K ROMS images for the Model B
# 4x 16K ROMS images for the Master 128

# Beeb ROM Images

MMFS=MMFS

IMAGE_B=tmp/rom_image_64K_beeb.bin
rm -f $IMAGE_B

cat bbcb/os12.rom              >> $IMAGE_B
cat bbcb/${MMFS}/M/SWMMFS.rom  >> $IMAGE_B
cat bbcb/ram_master_v6.rom     >> $IMAGE_B
cat bbcb/basic2.rom            >> $IMAGE_B

# Master ROM Images

IMAGE_M=tmp/rom_image_64K_master.bin
rm -f $IMAGE_M
cat m128/${MMFS}/M/MAMMFS.rom  >> $IMAGE_M
cat m128/mos.rom               >> $IMAGE_M
cat m128/basic4.rom            >> $IMAGE_M
cat m128/terminal.rom          >> $IMAGE_M

# Both

cat $IMAGE_B $IMAGE_M > tmp/rom_image_128K.bin
