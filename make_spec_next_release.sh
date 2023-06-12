#!/bin/bash

PATH=/opt/Xilinx/14.7/ISE_DS/ISE/bin/lin64:$PATH

# Lookup the last commit ID
GITVERSION="$(git rev-parse --short HEAD)"

# Check if any uncommitted changes in tracked files
if [ -n "$(git status --untracked-files=no --porcelain)" ]; then
  GITVERSION="${GITVERSION}?"
fi

BUILD=$(date +"%Y%m%d_%H%M")
#BUILD=dev

# ====================================================
# Compile Config Firmware
# ====================================================

function common_settings {
cat > $1 <<EOF
; =====================================
; General settings
; =====================================

; video
;     0 = RGB SCART
;     1 = HDMI/VGA (best)
;     2 = HDMI/VGA
;     3 = HDMI/VGA
;
; default is from from config.ini

; video = 1

; HDMI Audio
;     0=off
;     1=on
;
; default is from from config.ini

; hdmi_audio = 1

; HDMI Aspect Ratio
;     0=auto
;     1=4:3
;     2=16:9

hdmi_aspect = 0

; ICE Debugger (via UART on Joystick2)
;     0=off
;     1=on

debug = 0

; PS/2 Mode
;    0=keyboard
;    1=mouse
;
; default is from from config.ini

; ps2_mode = 0

; Show BeebFPGA Splash Screen
;     0=off
;    >0=on (value = duration in 100ms units)

splash = 14 ; hex!

; Whether to check the ROM crcs
;     0=no
;     1=yes
;

romcheck = 1

EOF
}

function modelb_settings {
cat >> $1 <<EOF
; =====================================
; BBC Model B specific settings
; =====================================

; Co Processor selection
;     0=disabled
;     1=internal
;     2=external

copro = 0

; Keyboard DIP settings
; See p246 of Advanced User Guide

keydip = 00

; ROM CRCs, for checking during boot

crc00 = 0000
crc01 = 0000
crc02 = 0000
crc03 = 0000
crc04 = 5cbf
crc06 = 0000
crc07 = 0000
EOF
echo "crc08 = $2" >> $1
cat >> $1 <<EOF
crc09 = 0000
crc0A = 0000
crc0B = 0000
crc0C = 0000
crc0D = 0000
crc0E = 36b8
crc0F = 4274

EOF
}

function master_settings {
cat >> $1 <<EOF
; =====================================
; BBC Master specific settings
; =====================================

; CMOS RAM Settings
; See http://beebwiki.mdfs.net/CMOS_configuration_RAM_allocation

; cmos0f bit 0 is 0:NOTUBE 1:TUBE
; cmos10 bit 2 is 0:INTUBE 1:EXTUBE

cmos05 = C9 ; Default Filing System / Language
cmos06 = FF ; ROM frugal bits (*INSERT/*UNPLUG)
cmos07 = FF ; ROM frugal bits (*INSERT/*UNPLUG)
cmos08 = 00 ; Edit startup settings
cmos09 = 00 ; reserved for telecommunications applications
cmos0A = F7 ; VDU mode and *TV settings
cmos0B = 63 ; ADFS startup options, keyboard settings, floppy params
cmos0C = 20 ; Keyboard auto-repeat delay
cmos0D = 08 ; Keyboard auto-repeat rate
cmos0E = 0A ; Printer ignore character
cmos0F = 2C ; Default printer type, serial baud rate, ignore status and TUBE select
cmos10 = 84 ; Default serial data format, auto boot option, int/ext TUBE, bell amplitude

; ROM CRCs, for checking during boot

crc00 = 0000
crc01 = 0000
crc02 = 0000
crc03 = 81db
crc04 = 9402
crc06 = 0000
crc07 = 0000
crc08 = c433
EOF
echo "crc09 = $2" >> $1
cat >> $1 <<EOF
crc0A = e7c4
crc0B = b5b6
crc0C = 61d7
crc0D = b733
crc0E = 7621
crc0F = 64af

EOF
}


function modelb_config {
cat > $1 <<EOF
name=Acorn BBC Model B

; Beeb ROM Slots 0-15 map to Spec Next Pages 0-15
resource=blank.rom,0
resource=blank.rom,1
resource=blank.rom,2
resource=blank.rom,3
resource=os12.rom,4
resource=blank.rom,5
resource=blank.rom,6
resource=blank.rom,7
resource=SWMMFS.rom,8
resource=blank.rom,9
resource=blank.rom,10
resource=blank.rom,11
resource=blank.rom,12
resource=blank.rom,13
resource=rammas6.rom,14
resource=basic2.rom,15

; Beeb Config at the start
resource=beeb.cfg,5

; Spec Next Config and the end (0x3F00)
config=5,16128
EOF
}


function master_config {
cat > $1 <<EOF
name=Acorn BBC Master

; Beeb ROM Slots 0-15 map to Spec Next Pages 0-15
resource=blank.rom,0
resource=blank.rom,1
resource=blank.rom,2
resource=owl.rom,3
resource=mos.rom,4
resource=blank.rom,5
resource=blank.rom,6
resource=blank.rom,7
resource=dfs.rom,8
resource=MAMMFS.rom,9
resource=viewsht.rom,10
resource=edit.rom,11
resource=basic4.rom,12
resource=adfs.rom,13
resource=view.rom,14
resource=terminal.rom,15

; Beeb Config at the start
resource=beeb.cfg,5

; Spec Next Config and the end (0x3F00)
config=5,16128
EOF
}

for MMFS in MMFS MMFS2
do

MMFS_BBCB_CRC=`crc16 roms/bbcb/${MMFS}/M/SWMMFS.rom`
MMFS_M128_CRC=`crc16 roms/m128/${MMFS}/M/MAMMFS.rom`

echo "CRC for $MMFS for BBC B is $MMFS_BBCB_CRC"
echo "CRC for $MMFS for Master 128 is $MMFS_M128_CRC"


NAME=beeb_fpga_spec_next_${BUILD}_${MMFS}

DIR=releases/$NAME

echo "Release name: $NAME"

rm -rf $DIR
mkdir -p $DIR

# ====================================================
# Compile Config Firmware
# ====================================================

pushd firmware

echo EQUB \"Version: $BUILD $GITVERSION\" > version.asm
beebasm -v -i config.asm -o config.rom
od -An -tx1 -w16 -v config.rom > config.mem
popd

# ====================================================
# Acorn BBC Model B
# ====================================================

MACH=bbcmodelb

mkdir -p $DIR/machines/$MACH

for i in os12 basic2 ram_master_v6 ${MMFS}/M/SWMMFS
do
    cp roms/bbcb/$i.rom $DIR/machines/${MACH}
done

# Add a blank rom
dd if=/dev/zero of=$DIR/machines/${MACH}/blank.rom bs=1024 count=16

# Rename to keep filenames sensible
mv $DIR/machines/${MACH}/ram_master_v6.rom $DIR/machines/${MACH}/rammas6.rom

common_settings $DIR/machines/${MACH}/beeb.cfg
modelb_settings $DIR/machines/${MACH}/beeb.cfg $MMFS_BBCB_CRC

modelb_config $DIR/machines/${MACH}/core.cfg

data2mem -bm xilinx/spec_next_config_modelb_bd.bmm -bd firmware/config.mem -bt xilinx/working/bbc_micro_spec_next/bbc_micro_spec_next.bit -o b $DIR/machines/${MACH}/core.bit

# ====================================================
# Acorn BBC Master
# ====================================================

MACH=bbcmaster

mkdir -p $DIR/machines/$MACH

for i in adfs basic4 dfs edit ${MMFS}/M/MAMMFS mos owl terminal view viewsht
do
    cp roms/m128/$i.rom $DIR/machines/${MACH}
done

# Add a blank rom
dd if=/dev/zero of=$DIR/machines/${MACH}/blank.rom bs=1024 count=16

common_settings $DIR/machines/${MACH}/beeb.cfg
master_settings $DIR/machines/${MACH}/beeb.cfg $MMFS_M128_CRC

master_config $DIR/machines/${MACH}/core.cfg

data2mem -bm xilinx/spec_next_config_master_bd.bmm -bd firmware/config.mem -bt xilinx/working/bbc_master_spec_next/bbc_micro_spec_next.bit -o b $DIR/machines/${MACH}/core.bit

# ====================================================
# Zip
# ====================================================

pushd $DIR

zip -qr ../$NAME.zip .

popd

unzip -l $DIR.zip

done
