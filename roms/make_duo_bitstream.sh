#!/bin/bash
. /opt/Xilinx/14.7/ISE_DS/settings64.sh

# Set to true to run data2mem to merge in latest AVR firmware for ICE T65
run_data2mem=true

# Papilio Programmer settings
PAPILIO_LOADER=/opt/GadgetFactory/papilio-loader/programmer
PROG=${PAPILIO_LOADER}/linux64/papilio-prog
BSCAN=${PAPILIO_LOADER}/bscan_spi_xc6slx9.bit

# Merge in the AVR Firmware

if [ "$run_data2mem" = true ]; then

    echo "Merging AVR Firmware"

    pushd ../AtomBusMon/target/lx9_dave/ice6502
    make -B avr_progmem.mem
    popd
    data2mem -bm ../xilinx/duo_cpumon_modelb_bd.bmm \
             -bd ../AtomBusMon/target/lx9_dave/ice6502/avr_progmem.mem \
             -bt ../xilinx/working/bbc_micro_duo/bbc_micro_duo.bit \
             -o b tmp/bbc_micro_duo.bit
    data2mem -bm ../xilinx/duo_cpumon_modelb_nula_bd.bmm \
             -bd ../AtomBusMon/target/lx9_dave/ice6502/avr_progmem.mem \
             -bt ../xilinx/working/bbc_micro_duo_nula/bbc_micro_duo.bit \
             -o b tmp/bbc_micro_duo_nula.bit

    pushd ../AtomBusMon/target/lx9_dave/ice65c02
    make -B avr_progmem.mem
    popd
    data2mem -bm ../xilinx/duo_cpumon_master_bd.bmm \
             -bd ../AtomBusMon/target/lx9_dave/ice65c02/avr_progmem.mem \
             -bt ../xilinx/working/bbc_master_duo/bbc_micro_duo.bit \
             -o b tmp/bbc_master_duo.bit
    data2mem -bm ../xilinx/duo_cpumon_master_nula_bd.bmm \
             -bd ../AtomBusMon/target/lx9_dave/ice65c02/avr_progmem.mem \
             -bt ../xilinx/working/bbc_master_duo_nula/bbc_micro_duo.bit \
             -o b tmp/bbc_master_duo_nula.bit

else

    echo "Skipped Merging AVR Firmware"

    cp ../xilinx/working/bbc_micro_duo/bbc_micro_duo.bit       tmp/bbc_micro_duo.bit
    cp ../xilinx/working/bbc_micro_duo_nula/bbc_micro_duo.bit  tmp/bbc_micro_duo_nula.bit
    cp ../xilinx/working/bbc_master_duo/bbc_micro_duo.bit      tmp/bbc_master_duo.bit
    cp ../xilinx/working/bbc_master_duo_nula/bbc_micro_duo.bit tmp/bbc_master_duo_nula.bit

fi

# Build a fresh ROM image (tmp/rom_image.bin)
./make_rom_image.sh

# 0x000000 - Boot Loader
# 0x054000 - BBC Micro Bitstream
# 0x0a8000 - BBC Master Bitstream
# 0x0fc000 - BBC Micro Bitstream (NuLA)
# 0x150000 - BBC Master Bitstream (NuLA)
# 0x200000 - BBC Micro ROMS
# 0x240000 - BBC Master ROMS

# Compile the bitmerge tool, which merges addition data files into the main .bit file
gcc -o tmp/bitmerge bitmerge.c

# Strip of the bitstream header from target .bit files, so they can be treated as raw data
promgen -b -u 0 tmp/bbc_micro_duo.bit       -o tmp/bbc_micro_duo.bin       -p bin -w
promgen -b -u 0 tmp/bbc_master_duo.bit      -o tmp/bbc_master_duo.bin      -p bin -w
promgen -b -u 0 tmp/bbc_micro_duo_nula.bit  -o tmp/bbc_micro_duo_nula.bin  -p bin -w
promgen -b -u 0 tmp/bbc_master_duo_nula.bit -o tmp/bbc_master_duo_nula.bin -p bin -w

# Merge everything together into a single .bit file
cp ../xilinx/working/duo_boot_loader/duo_boot_loader.bit         tmp/merged.bit
./tmp/bitmerge tmp/merged.bit  54000:tmp/bbc_micro_duo.bin       tmp/merged.bit
./tmp/bitmerge tmp/merged.bit  A8000:tmp/bbc_master_duo.bin      tmp/merged.bit
./tmp/bitmerge tmp/merged.bit  FC000:tmp/bbc_micro_duo_nula.bin  tmp/merged.bit
./tmp/bitmerge tmp/merged.bit 150000:tmp/bbc_master_duo_nula.bin tmp/merged.bit
./tmp/bitmerge tmp/merged.bit 200000:tmp/rom_image.bin           tmp/merged.bit

# Remove working files
rm -f tmp/bitmerge
rm -f tmp/bbc_micro_duo.bin
rm -f tmp/bbc_master_duo.bin
rm -f tmp/bbc_micro_duo.bit
rm -f tmp/bbc_master_duo.bit
rm -f tmp/bbc_micro_duo_nula.bin
rm -f tmp/bbc_master_duo_nula.bin
rm -f tmp/bbc_micro_duo_nula.bit
rm -f tmp/bbc_master_duo_nula.bit

# Program the Papilo Duo
sudo ${PROG} -v -f tmp/merged.bit -b ${BSCAN}  -sa -r

# Reset the Papilio Duo
sudo ${PROG} -c
