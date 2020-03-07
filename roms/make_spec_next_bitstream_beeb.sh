#!/bin/bash
IMAGE=tmp/rom_image_64K_beeb.bin
OUT=tmp/bbc_micro_spec_next.bit

# Address to insert the ROM image
ADDR=$((16#70000))

# Build a fresh ROM image
./make_rom_image_minimal.sh

# Start with the bit file
cp  ../xilinx/working/bbc_micro_spec_next/bbc_micro_spec_next.bit $OUT

# Check length

LEN=$(wc -c < $OUT)

if (( $LEN  > $ADDR )); then
    echo ".bit file is too long; overlaps with address "$ADDR
    ls -l $OUT
    exit
else
    echo "Padding .bit file with $(($ADDR - $LEN)) bytes"
fi

# Extend to the start of the ROM
truncate -s $ADDR $OUT

# Append image
cat $IMAGE >> $OUT

# Report after
ls -l $OUT
