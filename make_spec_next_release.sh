#!/bin/bash

NAME=beeb_fpga_spec_next_$(date +"%Y%m%d_%H%M")

DIR=releases/$NAME

echo "Release name: $NAME"

mkdir -p $DIR

# ====================================================
# Acorn BBC Model B
# ====================================================

MACH=bbcmodelb

mkdir -p $DIR/machines/$MACH

cat > $DIR/machines/${MACH}/core.cfg <<EOF
name=Acorn BBC Model B

; Beeb ROM Slots 0-15 map to Spec Next Pages 0-15
resource=blank.rom,3
resource=os12.rom,4
resource=swmmfs2.rom,8
resource=blank.rom,9
resource=blank.rom,10
resource=blank.rom,11
resource=blank.rom,12
resource=blank.rom,13
resource=rammas6.rom,14
resource=basic2.rom,15

config=31,0
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

; Beeb ROM Slots 0-15 map to Spec Next Pages 0-15
resource=mammfs2.rom,3
resource=mos.rom,4
resource=owl.rom,8
resource=dfs.rom,9
resource=viewsht.rom,10
resource=edit.rom,11
resource=basic4.rom,12
resource=adfs.rom,13
resource=view.rom,14
resource=terminal.rom,15

config=31,0
EOF

for i in adfs basic4 dfs edit mammfs2 mos owl terminal view viewsht
do
    cp roms/m128/$i.rom $DIR/machines/${MACH}
done

cp -a xilinx/working/bbc_master_spec_next/bbc_micro_spec_next.bit $DIR/machines/${MACH}/core.bit

# ====================================================
# Zip
# ====================================================

pushd $DIR

zip -qr ../$NAME.zip .

popd

unzip -l $DIR.zip
