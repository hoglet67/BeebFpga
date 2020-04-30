#!/bin/bash

#NAME=beeb_fpga_spec_next_$(date +"%Y%m%d_%H%M")
NAME=beeb_fpga_spec_next_$(date +"%Y%m%d")_dev

DIR=releases/$NAME

echo "Release name: $NAME"

mkdir -p $DIR

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

video = 1

; HDMI Audio
;     0=off
;     1=on

hdmi_audio = 1

; HDMI Aspect Ratio
;     0=auto
;     1=4:3
;     2=16:9

hdmi_aspect = 0

; Internal 6502 Co Processor
;     0=off
;     1=on

copro = 0

; ICE Debugger (via UART on Joystick2)
;     0=off
;     1=on

debug = 1

; Show BeebFPGA Splash Screen
;     0=off
;    >0=on (value = duration in 100ms units)

splash = 30

EOF
}

function modelb_settings {
cat >> $1 <<EOF
; =====================================
; BBC Model B specific settings
; =====================================

; Keyboard DIP settings
; See p246 of Advanced User Guide

keydip = 00

EOF
}

function master_settings {
cat >> $1 <<EOF
; =====================================
; BBC Master specific settings
; =====================================

; CMOS RAM Settings
; See http://beebwiki.mdfs.net/CMOS_configuration_RAM_allocation

cmos05 = C3 ; Default Filing System / Language
cmos06 = FF ; ROM frugal bits (*INSERT/*UNPLUG)
cmos07 = FF ; ROM frugal bits (*INSERT/*UNPLUG)
cmos08 = 00 ; Edit startup settings
cmos09 = 00 ; reserved for telecommunications applications
cmos0A = F7 ; VDU mode and *TV settings
cmos0B = 63 ; ADFS startup options, keyboard settings, floppy params
cmos0C = 20 ; Keyboard auto-repeat delay
cmos0D = 08 ; Keyboard auto-repeat rate
cmos0E = 0A ; Printer ignore character
cmos0F = 2D ; Default printer type, serial baud rate, ignore status and TUBE select
cmos10 = 80 ; Default serial data format, auto boot option, int/ext TUBE, bell amplitude

EOF
}

# ====================================================
# Compile Config Firmware
# ====================================================

pushd firmware
beebasm -v -i config.asm -o config.rom
popd

# ====================================================
# Acorn BBC Model B
# ====================================================

MACH=bbcmodelb

mkdir -p $DIR/machines/$MACH

cat > $DIR/machines/${MACH}/core.cfg <<EOF
name=Acorn BBC Model B

; Beeb ROM Slots 0-15 map to Spec Next Pages 16-31
resource=blank.rom,19
resource=os12.rom,20
resource=config.rom,22
resource=swmmfs2.rom,24
resource=blank.rom,25
resource=blank.rom,26
resource=blank.rom,27
resource=blank.rom,28
resource=blank.rom,29
resource=rammas6.rom,30
resource=basic2.rom,31

; Beeb Specific Config
resource=beeb.cfg,22

;config=0,0
EOF

for i in os12 basic2 ram_master_v6 swmmfs2
do
    cp roms/bbcb/$i.rom $DIR/machines/${MACH}
done
cp firmware/config.rom $DIR/machines/${MACH}

# Add a blank rom
dd if=/dev/zero of=$DIR/machines/${MACH}/blank.rom bs=1024 count=16

# Rename to keep filenames sensible
mv $DIR/machines/${MACH}/ram_master_v6.rom $DIR/machines/${MACH}/rammas6.rom

cp -a xilinx/working/bbc_micro_spec_next/bbc_micro_spec_next.bit $DIR/machines/${MACH}/core.bit

common_settings $DIR/machines/${MACH}/beeb.cfg
modelb_settings $DIR/machines/${MACH}/beeb.cfg

# ====================================================
# Acorn BBC Master
# ====================================================

MACH=bbcmaster

mkdir -p $DIR/machines/$MACH

cat > $DIR/machines/${MACH}/core.cfg <<EOF
name=Acorn BBC Master

; Beeb ROM Slots 0-15 map to Spec Next Pages 0-15
resource=mammfs2.rom,19
resource=mos.rom,20
resource=config.rom,22
resource=owl.rom,24
resource=dfs.rom,25
resource=viewsht.rom,26
resource=edit.rom,27
resource=basic4.rom,28
resource=adfs.rom,29
resource=view.rom,30
resource=terminal.rom,31

; Beeb Specific Config
resource=beeb.cfg,22

;config=0,0
EOF

for i in adfs basic4 dfs edit mammfs2 mos owl terminal view viewsht
do
    cp roms/m128/$i.rom $DIR/machines/${MACH}
done
cp firmware/config.rom $DIR/machines/${MACH}

common_settings $DIR/machines/${MACH}/beeb.cfg
master_settings $DIR/machines/${MACH}/beeb.cfg

cp -a xilinx/working/bbc_master_spec_next/bbc_micro_spec_next.bit $DIR/machines/${MACH}/core.bit

# ====================================================
# Zip
# ====================================================

pushd $DIR

zip -qr ../$NAME.zip .

popd

unzip -l $DIR.zip
