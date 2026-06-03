#!/usr/bin/env bash
# MEaSUREs NSIDC-0481: TSX/TDX ~12-day high-resolution scenes.
# Builds GDAL VRTs per date, then imports into GRASS.
. "$(dirname "$0")/common.sh"

ROOT=${DATADIR}/MEaSUREs/NSIDC-0481.004
VRTROOT=./tmp/NSIDC-0481.004.vrt/
mkdir -p ${VRTROOT}

MSG_OK "MEaSUREs 0481 — building VRTs"
for date in $(cd ${ROOT}; ls -d */|tr -d '/'); do
    if [[ ! -f ${VRTROOT}/${date}_vx.vrt ]]; then
        LIST=$(find ${ROOT}/${date}/ -name "TSX*vx*.tif" | LC_ALL=C sort)
        if [[ ! -z ${LIST} ]]; then
            MSG_OK "  Building VRTs for ${date}"
            VX=$(ls $ROOT/$date/*vx* | head -n1)
            T0=$(basename ${VX} | cut -d_ -f3)
            T1=$(basename ${VX} | cut -d_ -f4)
            SEC0=$(date --utc --date="${T0}" +"%s")
            SEC1=$(date --utc --date="${T1}" +"%s")
            MID=$(echo "(${SEC0}+${SEC1})/2"|bc)
            DATE=$(date --utc --date="@${MID}" +"%Y_%m_%d")
            parallel --verbose --bar gdalbuildvrt -overwrite ${VRTROOT}/${DATE}_{}.vrt \
                $\(find ${ROOT}/${date} -name "TSX*{}*.tif" \| LC_ALL=C sort\) ::: vx vy ex ey
        fi
    fi
done

MSG_OK "MEaSUREs 0481 — importing into GRASS"
g.mapset -c MEaSUREs.0481

gdalbuildvrt -overwrite tmp/0481.vrt ./tmp/NSIDC-0481.004.vrt/*_vx.vrt
r.external source=tmp/0481.vrt output=tmp -e -r
g.region raster=tmp -pa res=250
g.remove -f type=raster name=tmp

r.mask -r
for VX in $(find ${VRTROOT} -name "*vx*.vrt" | LC_ALL=C sort); do
    VY=${VX/vx/vy}; EX=${VX/vx/ex}; EY=${EX/ex/ey}
    DATE=$(basename $VX | cut -d"_" -f1-3)
    echo $DATE
    parallel --verbose --bar r.external source={1} output={2}_${DATE} ::: ${VX} ${VY} ${EX} ${EY} :::+ VX VY EX EY
done
