#!/bin/bash

# Create the 64KB minimal ROM image for the Tang 9K build
#
# This contains:

# 16x 16K ROMS images for the Model B
# 16x 16K ROMS images for the Master 128

IMAGE=tmp/rom_image.bin

MMFS=MMFS

rm -f $IMAGE

cat bbcb/os12.rom              >> $IMAGE
cat bbcb/${MMFS}/M/SWMMFS.rom  >> $IMAGE
cat bbcb/ram_master_v6.rom     >> $IMAGE
cat bbcb/basic2.rom            >> $IMAGE
