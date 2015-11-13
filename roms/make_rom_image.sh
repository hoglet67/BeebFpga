#!/bin/bash

# Create the 384K ROM image
#
# This contains 24x 16K ROMS images from the Master 128 and Model B

IMAGE=tmp/rom_image.bin

rm -f $IMAGE

# 00000-1FFFF
# Master OS then ROM 9,A,B,C,D,E,F
cat m128/mos.rom               >> $IMAGE
cat m128/dfs.rom               >> $IMAGE
cat m128/viewsht.rom           >> $IMAGE
cat m128/edit.rom              >> $IMAGE
cat m128/basic4.rom            >> $IMAGE
cat m128/adfs.rom              >> $IMAGE
cat m128/view.rom              >> $IMAGE
cat m128/terminal.rom          >> $IMAGE

# 20000-3FFFF
# Beeb OS then ROM 9,A,B,C,D,E,F
cat bbcb/os12.rom              >> $IMAGE
cat generic/blank.rom          >> $IMAGE
cat generic/blank.rom          >> $IMAGE
cat generic/blank.rom          >> $IMAGE
cat generic/blank.rom          >> $IMAGE
cat bbcb/smartmmc.rom.20151002 >> $IMAGE
cat bbcb/ram_master_v6.rom     >> $IMAGE
cat bbcb/basic2.rom            >> $IMAGE

# 40000-4FFFF
# Master ROM 0,1,2,3
cat generic/blank.rom          >> $IMAGE
cat generic/blank.rom          >> $IMAGE
cat generic/blank.rom          >> $IMAGE
cat m128/mmfs-m.rom            >> $IMAGE

# 50000-5FFFF
# Beeb ROM 0,1,2,3
cat generic/blank.rom          >> $IMAGE
cat generic/blank.rom          >> $IMAGE
cat generic/blank.rom          >> $IMAGE
cat generic/blank.rom          >> $IMAGE
