#!/bin/bash

# Create the 512K ROM image
#
# This contains:
# 16x 16K ROMS images for the Master 128

BINIMAGE=tmp/pynqz2_rom.bin
HEXIMAGE=tmp/pynqz2_rom.hex

rm -f $BINIMAGE
rm -f $HEXIMAGE

# Master ROM Images

cat generic/blank.rom          >  $BINIMAGE
cat generic/blank.rom          >> $BINIMAGE
cat generic/blank.rom          >> $BINIMAGE
cat generic/blank.rom          >> $BINIMAGE

# Note: It's not possible to pre-load the sideways RAM banks (4-7)
cat m128/mos.rom               >> $BINIMAGE
cat generic/blank.rom          >> $BINIMAGE
cat generic/blank.rom          >> $BINIMAGE
cat generic/blank.rom          >> $BINIMAGE

cat m128/dfs.rom               >> $BINIMAGE # Retain this for SRAM Utils
cat m128/mammfsspi.rom         >> $BINIMAGE # MMFS in a higher slot
cat m128/viewsht.rom           >> $BINIMAGE
cat m128/edit.rom              >> $BINIMAGE

cat m128/basic4.rom            >> $BINIMAGE
cat m128/adfs.rom              >> $BINIMAGE
cat m128/view.rom              >> $BINIMAGE
cat m128/terminal.rom          >> $BINIMAGE

# Second 256K is all zeros

cat generic/blank.rom          >> $BINIMAGE
cat generic/blank.rom          >> $BINIMAGE
cat generic/blank.rom          >> $BINIMAGE
cat generic/blank.rom          >> $BINIMAGE

cat generic/blank.rom          >> $BINIMAGE
cat generic/blank.rom          >> $BINIMAGE
cat generic/blank.rom          >> $BINIMAGE
cat generic/blank.rom          >> $BINIMAGE

cat generic/blank.rom          >> $BINIMAGE
cat generic/blank.rom          >> $BINIMAGE
cat generic/blank.rom          >> $BINIMAGE
cat generic/blank.rom          >> $BINIMAGE

cat generic/blank.rom          >> $BINIMAGE
cat generic/blank.rom          >> $BINIMAGE
cat generic/blank.rom          >> $BINIMAGE
cat generic/blank.rom          >> $BINIMAGE

od -An -tx1 -w16 -v < $BINIMAGE > $HEXIMAGE
