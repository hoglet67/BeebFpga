#!/bin/bash

NAME=beeb_fpga_spec_next_$(date +"%Y%m%d_%H%M")

DIR=releases/$NAME

echo $DIR

mkdir -p $DIR

# ====================================================
# Acorn BBC Model B
# ====================================================

MACH=bbcmodelb

mkdir -p $DIR/machines/$MACH

cat > $DIR/machines/${MACH}/core.cfg <<EOF
name=Acorn BBC Model B

; Beeb ROM Slots 0-15 map to Spec Next Pages 16-31
; Avoid loading ROMs to Spec Next pages 16, 18, 21
resource=blank.rom,19
resource=os12.rom,20
resource=swmmfs2.rom,24
resource=blank.rom,25
resource=blank.rom,26
resource=blank.rom,27
resource=blank.rom,28
resource=blank.rom,29
resource=rammas6.rom,30
resource=basic2.rom,31

config=0,0
EOF


for i in os12 basic2 ram_master_v6 swmmfs2
do
    cp roms/bbcb/$i.rom $DIR/machines/${MACH}
done

# Add a blank rom
dd if=/dev/zero of=$DIR/machines/${MACH}/blank.rom bs=1024 count=16

# Rename to keep filenames sensible
mv $DIR/machines/${MACH}/ram_master_v6.rom $DIR/machines/${MACH}/rammas6.rom

cp -a xilinx/working/bbc_micro_spec_next/bbc_micro_spec_next.bit $DIR/machines/${MACH}/core.bit

# ====================================================
# Acorn BBC Master
# ====================================================

MACH=bbcmaster

mkdir -p $DIR/machines/$MACH

cat > $DIR/machines/${MACH}/core.cfg <<EOF
name=Acorn BBC Master

; Beeb ROM Slots 0-15 map to Spec Next Pages 16-31
; Avoid loading ROMs to Spec Next pages 16, 18, 21
resource=mammfs2.rom,19
resource=mos.rom,20
resource=owl.rom,24
resource=dfs.rom,25
resource=viewsht.rom,26
resource=edit.rom,27
resource=basic4.rom,28
resource=adfs.rom,29
resource=view.rom,30
resource=terminal.rom,31

config=0,0
EOF

for i in adfs basic4 dfs edit mammfs2 mos owl terminal view viewsht
do
    cp roms/m128/$i.rom $DIR/machines/${MACH}
done

cp -a xilinx/working/bbc_master_spec_next/bbc_micro_spec_next.bit $DIR/machines/${MACH}/core.bit

# ====================================================
# Zip
# ====================================================

cd $DIR

zip -qr ../$NAME.zip .

unzip -l ../$NAME.zip
