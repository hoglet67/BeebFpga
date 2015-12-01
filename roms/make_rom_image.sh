#!/bin/bash

# Create the 512K ROM image
#
# This contains:
# 16x 16K ROMS images for the Model B
# 16x 16K ROMS images for the Master 128

IMAGE=tmp/rom_image.bin

rm -f $IMAGE

# Beeb ROM Images

cat generic/blank.rom          >> $IMAGE
cat generic/blank.rom          >> $IMAGE
cat generic/blank.rom          >> $IMAGE
cat generic/blank.rom          >> $IMAGE

cat bbcb/os12.rom              >> $IMAGE
cat generic/blank.rom          >> $IMAGE
cat generic/blank.rom          >> $IMAGE
cat generic/blank.rom          >> $IMAGE

cat generic/blank.rom          >> $IMAGE
cat generic/blank.rom          >> $IMAGE
cat generic/blank.rom          >> $IMAGE
cat generic/blank.rom          >> $IMAGE

cat generic/blank.rom          >> $IMAGE
cat bbcb/smartmmc.rom.20151002 >> $IMAGE
cat bbcb/ram_master_v6.rom     >> $IMAGE
cat bbcb/basic2.rom            >> $IMAGE

# Master ROM Images

cat generic/blank.rom          >> $IMAGE
cat generic/blank.rom          >> $IMAGE
cat generic/blank.rom          >> $IMAGE
cat m128/mmfs-m.rom            >> $IMAGE

cat m128/mos.rom               >> $IMAGE
cat generic/blank.rom          >> $IMAGE
cat generic/blank.rom          >> $IMAGE
cat generic/blank.rom          >> $IMAGE

cat generic/blank.rom          >> $IMAGE
cat m128/dfs.rom               >> $IMAGE
cat m128/viewsht.rom           >> $IMAGE
cat m128/edit.rom              >> $IMAGE

cat m128/basic4.rom            >> $IMAGE
cat m128/adfs.rom              >> $IMAGE
cat m128/view.rom              >> $IMAGE
cat m128/terminal.rom          >> $IMAGE
