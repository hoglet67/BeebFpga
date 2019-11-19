#!/bin/bash

mkdir -p releases

name=beebfpga_$(date +"%Y%m%d_%H%M")

release=releases/${name}

echo "WARNING: Altera and Xilinx projects need manual compilation before release"

pushd roms
./make_duo_bitstream.sh
popd

mkdir -p ${release}/de1
cp -a altera/output_files/bbc_micro_de1.[ps]of ${release}/de1
cp -a roms/tmp/rom_image.bin ${release}/de1

mkdir -p ${release}/duo
cp -a roms/tmp/merged.bit  ${release}/duo/bbc_micro_duo.bit

pushd releases
zip -qr ${name}.zip ${name}
unzip -l ${name}
popd
