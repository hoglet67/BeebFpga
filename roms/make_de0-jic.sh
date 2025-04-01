#!/usr/bin/env bash

which wslpath >/dev/null
if [[ $? -eq 0 ]]; then
    WSLPATH="wslpath -w "
    QUARTUS_CPF=quartus_cpf.exe
else
    WSLPATH="echo "
    QUARTUS_CPF=quartus_cpf
fi


./make_rom_image.sh

srec_cat ./tmp/rom_image.bin -Binary -Output ./tmp/de0-all.hex -Intel

$QUARTUS_CPF -c $($WSLPATH "./de0-nano-all.cof")
