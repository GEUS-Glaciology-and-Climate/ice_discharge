#!/usr/bin/env bash
# MEaSUREs NSIDC-0646: monthly velocity mosaics 1985-2018.
# Builds GDAL VRTs per month, then imports into GRASS.
. "$(dirname "$0")/common.sh"

ROOT=${DATADIR}/MEaSUREs/NSIDC-0646.003/
VRTROOT=./tmp/NSIDC-0646.003.vrt/
mkdir -p ${VRTROOT}

MSG_OK "MEaSUREs 0646 — building VRTs"
for year in $(seq 1985 2018); do
    for month in $(seq -w 1 12); do
        if [[ ! -f ${VRTROOT}/${year}_${month}_vx.vrt ]]; then
            LIST=$(find ${ROOT} -name "*${year}-${month}_vx_*.tif" | LC_ALL=C sort)
            if [[ ! -z ${LIST} ]]; then
                MSG_OK "  Building VRTs for ${year} ${month}"
                parallel --verbose --bar gdalbuildvrt -overwrite ${VRTROOT}/${year}_${month}_{}.vrt \
                    $\(find ${ROOT} -name "*${year}-${month}_{}_*.tif" \| LC_ALL=C sort\) ::: vx vy ex ey
            fi
        fi
    done
done

MSG_OK "MEaSUREs 0646 — importing into GRASS"
g.mapset -c MEaSUREs.0646
r.mask -r

for VX in $(find ${VRTROOT} -name "*vx*.vrt" | LC_ALL=C sort); do
    VY=${VX/vx/vy}; EX=${VX/vx/ex}; EY=${EX/ex/ey}
    DATE=$(basename $VX | cut -d"_" -f1-2)
    DATE=${DATE}_15   # assign mid-month day
    echo $DATE
    parallel --verbose --bar r.external source={1} output={2}_${DATE} ::: ${VX} ${VY} ${EX} ${EY} :::+ VX VY EX EY
done
g.region raster=VX_${DATE} -pa
