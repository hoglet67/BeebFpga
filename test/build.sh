#!/bin/bash

n=0


function get_disk_num {
    printf -v num "%03d" $n
    n=$((n+1))
}


function roundup_disk_num {
    x=$1
    n=$((((n+$x-1)/$x)*$x))
}

function add_ssd {
    ssd=$1
    title=$2
    if [ -z "$title" ]
    then
        tmp1=${ssd%.*}
        title=${tmp1##*/}
    fi
    echo "  Adding SSD ${ssd} with title ${title}"
    echo ${ssd}
    get_disk_num
    cp ${ssd} ${tmp}
    beeb title ${tmp} "${title}"
    beeb dput_ssd -f ${mmb} ${num} ${tmp}
    rm -f ${tmp}
}

function get_add_ssd {
    title=$1
    url=$2
    file=${url##*/}
    wget -N -P downloads ${url}
    add_ssd downloads/${file} ${title}
}

function get_add_dsd {
    title=$1
    url=$2
    file=${url##*/}
    wget -N -P downloads ${url}
    beeb split_dsd downloads/${file} ${tmp1} ${tmp2}
    add_ssd ${tmp1} ${title}
    add_ssd ${tmp2} ${title}
    rm -f ${tmp1}
    rm -f ${tmp2}
}

function title_ssd {
    beeb blank_ssd ${tmp}
    beeb title ${tmp} "$1"
    get_disk_num
    beeb dput_ssd -f ${mmb} ${num} ${tmp}
    rm -f ${tmp}
}

function add_directory {
    dir=$1
    echo "Adding directory ${dir}"
    pwd
    ls

    for ssd in $(find ${dir} -name '*.ssd' | sort -f)
    do
        add_ssd ${ssd}
    done
}

function get_git_repo {
    url=$1
    dir=downloads/${url##*/}
    echo "-------------------------------------"
    echo $dir
    echo "-------------------------------------"

    if [ ! -d ${dir} ]
    then
        git clone ${url}.git ${dir}
    else
        pushd ${dir}
        git pull --rebase
        popd
    fi
}

mkdir -p build/downloads
cd build

# Create a fresh blank MMB file

mmb=../TEST.MMB
rm -f ${mmb}
beeb dblank_mmb -f ${mmb}
tmp=tmp.ssd
tmp1=tmp1.ssd
tmp2=tmp2.ssd

# ##########################################################################
# Bitshifters
# ##########################################################################

title_ssd "BITSHIFTERS"

# 2015
get_add_ssd NastyEffects https://bitshifters.github.io/content/crtc-somenastyeffects.ssd

# 2016
get_add_ssd BeebTracker1 https://bitshifters.github.io/content/bs-beebtrk.ssd
get_add_ssd BeebTracker2 https://bitshifters.github.io/content/bs-beebtrk2.ssd
get_add_ssd BeebTracker3 https://bitshifters.github.io/content/bs-beebtrk3.ssd

# 2017
get_add_dsd TelTxtBadApp https://bitshifters.github.io/content/bs-badappl.dsd
get_add_ssd TeleTextR    https://bitshifters.github.io/content/bs-teletextr.ssd
get_add_ssd NuLAGalVol1  https://bitshifters.github.io/content/bs-bbcnula1.ssd
get_add_ssd NuLAGalVol2  https://bitshifters.github.io/content/bs-bbcnula2.ssd

# 2018
get_add_ssd PriceOfPersi https://bitshifters.github.io/content/pop-beeb.ssd
get_add_ssd TwistedBrain https://bitshifters.github.io/content/bs-twisted.ssd

# 2019
get_add_ssd BeebStep     https://bitshifters.github.io/content/bs-beebstep.ssd
get_add_ssd StuntCarRacr https://bitshifters.github.io/content/bs-scr-beeb.ssd
get_add_ssd Patarty      https://bitshifters.github.io/content/bs-patarty.ssd
get_add_ssd WaveRunner   https://bitshifters.github.io/content/bs-wave-runner-v1-1.ssd
get_add_ssd XMAS-19      https://bitshifters.github.io/content/bs-xmas-19.ssd

# 2020
get_add_dsd BeebNICCC    https://bitshifters.github.io/content/bs-beeb-niccc.dsd
get_add_ssd NovaInvite   https://bitshifters.github.io/content/bs-nova-invite.ssd
get_add_ssd EvilInfluenc https://bitshifters.github.io/content/EvilIn11.ssd

# 2021
get_add_ssd WobbleColour https://bitshifters.github.io/content/bs-wobble-colours.ssd
get_add_ssd BarBeeb      https://bitshifters.github.io/content/bs-bar-beeb.ssd

# 2022
get_add_ssd MasterMode7  https://bitshifters.github.io/content/mmode7.ssd
get_add_ssd AlienDayDre  https://bitshifters.github.io/content/alien-daydream.ssd

# ##########################################################################
# Trickysoft (Richard Broadhurst)
# ##########################################################################

roundup_disk_num 50
title_ssd "TRICKYSOFT"
get_add_ssd Asteroids    http://bbcmicro.co.uk/gameimg/discs/3525/Disc156-Asteroids.ssd
get_add_ssd AstroBlaster http://bbcmicro.co.uk/gameimg/discs/1964/Disc110-AstroblasterRx2CB.ssd
get_add_ssd CanyonBomber http://bbcmicro.co.uk/gameimg/discs/3530/Disc158-CanyonBomber.ssd
get_add_ssd Carnival     http://bbcmicro.co.uk/gameimg/discs/1912/Disc107-CarnivalSTD.ssd
get_add_ssd Centipede    http://bbcmicro.co.uk/gameimg/discs/2850/Disc125-CentipedeCBSTD.ssd
get_add_ssd Circus       http://bbcmicro.co.uk/gameimg/discs/2629/Disc116-CircusJ.ssd
get_add_ssd Frogger      http://bbcmicro.co.uk/gameimg/discs/1934/Disc108-FroggerRSCB.ssd
get_add_ssd MissileCmd   https://stardot.org.uk/forums/download/file.php?id=82056
get_add_ssd Pacman       http://bbcmicro.co.uk/gameimg/discs/3523/Disc156-TrickysoftPacManCB.ssd
get_add_ssd Phoenix      http://bbcmicro.co.uk/gameimg/discs/2719/Disc121-Phoenix.ssd
get_add_ssd RallyX       http://bbcmicro.co.uk/gameimg/discs/3583/Disc159-TrickysoftRallyXCB.ssd
get_add_ssd RipCord      http://bbcmicro.co.uk/gameimg/discs/2649/Disc117-RipCordJ.ssd
get_add_ssd Scramble     http://bbcmicro.co.uk/gameimg/discs/2904/Disc128-ScrambleCB.ssd
get_add_ssd SpaceInvader http://bbcmicro.co.uk/gameimg/discs/2571/Disc115-SpaceInvaders.ssd
get_add_ssd Sprint1      http://bbcmicro.co.uk/gameimg/discs/3027/Disc133-Sprint1J.ssd
get_add_ssd SuperBreakou http://bbcmicro.co.uk/gameimg/discs/3535/Disc158-SuperBreakoutJ.ssd

# ##########################################################################
# Games
# ##########################################################################

roundup_disk_num 50
title_ssd "GAMES"

get_add_ssd Alien8       http://bbcmicro.co.uk/gameimg/discs/217/Disc013-Alien8.ssd
get_add_ssd Boffin       http://bbcmicro.co.uk/gameimg/discs/274/Disc016-Boffin.ssd
get_add_ssd DevilsIsland http://bbcmicro.co.uk/gameimg/discs/2631/Disc116-DevilsIslandSTD.ssd
get_add_ssd DrWho1stAdv  http://bbcmicro.co.uk/gameimg/discs/980/Disc055-DoctorWhoTheFirstAdventure.ssd
get_add_ssd Elite\(86\)  http://bbcmicro.co.uk/gameimg/discs/2088/Disc999-EliteMasterAndTubeEnhanced.ssd
get_add_ssd Exile        http://bbcmicro.co.uk/gameimg/discs/709/Disc040-ExileR.ssd
get_add_ssd FireTrack    http://bbcmicro.co.uk/gameimg/discs/2468/DiscA06-FireTrackSAM7.ssd
get_add_ssd LunarJetman  http://bbcmicro.co.uk/gameimg/discs/406/Disc023-LunarJetmanCosmicBattlezones.ssd
get_add_ssd PharaohCurse http://bbcmicro.co.uk/gameimg/discs/484/Disc027-PharaohsCurse.ssd
get_add_ssd PriceOfPersi https://bitshifters.github.io/content/pop-beeb.ssd
get_add_ssd Revs         http://bbcmicro.co.uk/gameimg/discs/267/Disc015-Revs.ssd
get_add_ssd SnapperV1    http://bbcmicro.co.uk/gameimg/discs/2345/DiscA01-SnapperV1.ssd
get_add_ssd StuntCarRacr https://bitshifters.github.io/content/bs-scr-beeb.ssd
get_add_dsd Time\&Magic  http://bbcmicro.co.uk/gameimg/discs/2343/Disc999-TimeAndMagikTrilogySTD.dsd
get_add_ssd Uridium      http://bbcmicro.co.uk/gameimg/discs/557/Disc031-UridiumCB.ssd
get_add_ssd WhiteLight   http://bbcmicro.co.uk/gameimg/discs/2712/Disc999-WhiteLight10DFS.ssd

# ##########################################################################
# Chris Evan's Test Collection
# ##########################################################################

get_git_repo https://github.com/scarybeasts/beebjit
roundup_disk_num 50
title_ssd "CHRIS EVANS"
add_directory downloads/beebjit/test/display

# ##########################################################################
# Tom Seddon's Test Collection
# ##########################################################################

get_git_repo https://github.com/tom-seddon/6845-tests
roundup_disk_num 50
title_ssd "TOM SEDDON"
for ssd in $(find downloads/6845-tests/ssds -name '*.ssd' | sort -f)
do
    title=$(echo ${ssd} | cut -c37- | cut -d. -f1)
    add_ssd ${ssd} ${title}
done

beeb dcat -f ${mmb}

# ##########################################################################
# VideoNula
# ##########################################################################

dir=downloads/VideoNuLA_pack_Feb2018
if [ ! -d ${dir} ]
then
wget -N -P downloads "https://www.dropbox.com/s/g3i5fe5napf8rwt/VideoNuLA_pack_Feb2018.zip"
mkdir -p ${dir}
unzip -d ${dir} downloads/VideoNuLA_pack_Feb2018.zip
beeb split_dsd ${dir}/cpc.dsd ${dir}/cpc0.ssd ${dir}/cpc2.ssd  
fi
roundup_disk_num 50
title_ssd "VIDEO NULA"
for ssd in $(find ${dir} -name '*.ssd' | sort -f)
do    
    title=$(echo ${ssd} | cut -c34- | cut -d. -f1)
    add_ssd ${ssd} ${title}
done
add_ssd ../local/nulatest.ssd

# ##########################################################################
# 6502 Tests
# ##########################################################################

get_git_repo https://github.com/dp111/6502Timing
get_git_repo https://github.com/hoglet67/6502_65C02_functional_tests
roundup_disk_num 50
title_ssd "6502 TESTS"
add_ssd downloads/6502_65C02_functional_tests/beeb/dormann.ssd
add_ssd ../local/BCDTEST.ssd
add_directory downloads/6502Timing


