#!/bin/bash

# Create the ROM images for the Tang 9K and 20K builds

mkdir -p tmp

for MMFS in MMFS MMFS2
do


# Beeb ROM Images

IMAGE1=tmp/tang_image_beeb_000000.bin
rm -f $IMAGE1
cat bbcb/os12.rom              >> $IMAGE1
cat bbcb/${MMFS}/M/SWMMFS.rom  >> $IMAGE1
cat bbcb/ram_master_v6.rom     >> $IMAGE1
cat bbcb/basic2.rom            >> $IMAGE1

# Master ROM Images

IMAGE2=tmp/tang_image_master_327680.bin
rm -f $IMAGE2
cat m128/mos.rom               >> $IMAGE2

IMAGE3=tmp/tang_image_master_393216.bin
rm -f $IMAGE3
cat m128/dfs.rom               >> $IMAGE3 # Retain this for SRAM Utils
cat m128/${MMFS}/M/MAMMFS.rom  >> $IMAGE3 # MMFS in a higher slot
cat m128/viewsht.rom           >> $IMAGE3
cat m128/edit.rom              >> $IMAGE3
cat m128/basic4.rom            >> $IMAGE3
cat m128/adfs.rom              >> $IMAGE3
cat m128/view.rom              >> $IMAGE3
cat m128/terminal.rom          >> $IMAGE3

# Concatenate into a single image that can be used on the Tanh Nano 9K or 20K
#
# Tang Nano 9K
#   Beeb loads 4 ROMs from address 0x000000
#   Master loads 16 ROMs from address 0x040000
#
# Tang Nano 20K
#   Beeb loads 4 ROMs from address 0x500000
#   Master loads 16 ROMs from address 0x540000
#
# The combined ROM image contains:
#   offset 0x00000 - 0x0FFFF - Miminal 64KB Beeb Image (Beeb ROMs 4, 8, E, F)
#   offset 0x10000 - 0x3FFFF - Blank (unused Beeb ROMs)
#   offset 0x40000 - 0x4FFFF - Blank (Master ROMs 0-3)
#   offset 0x50000 - 0x53FFF - Master MOS (ROM 4)
#   offset 0x54000 - 0x5FFFF - Blank (ROMs 5-7)
#   offset 0x60000 - 0x7FFFF - Master ROMs (ROMs 8-15)
#
# NB: ROM 4 is the MOS in both Beeb and Master

IMAGE=tmp/tang_image_combined_${MMFS}.bin
rm -f $IMAGE

cat $IMAGE1 >> $IMAGE
dd if=/dev/zero bs=16384 count=16 >> $IMAGE
cat $IMAGE2 >> $IMAGE
dd if=/dev/zero bs=16384 count=3 >> $IMAGE
cat $IMAGE3 >> $IMAGE

echo $IMAGE
ls -l $IMAGE
echo "On a TANG Nano  9K program to external FLASH address 0x000000"
echo "On a TANG Nano 20K program to external FLASH address 0x500000"

done
