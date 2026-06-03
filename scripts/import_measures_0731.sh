#!/usr/bin/env bash
# MEaSUREs NSIDC-0731: annual velocity mosaics.
. "$(dirname "$0")/common.sh"

MSG_OK "MEaSUREs 0731"
g.mapset -c MEaSUREs.0731
r.mask -r
ROOT=${DATADIR}/MEaSUREs/NSIDC-0731.005/

for VX in $(find ${ROOT} -name "*mosaic_*vx*.tif" | LC_ALL=C sort); do
    VY=${VX/vx/vy}; EX=${VX/vx/ex}; EY=${EX/ex/ey}
    T0=$(dirname ${VX} | rev | cut -d"/" -f1 | rev | cut -d"_" -f4 | tr '.' '-')
    T1=$(dirname ${VX} | rev | cut -d"/" -f1 | rev | cut -d"_" -f5 | tr '.' '-')
    SEC0=$(date --utc --date="${T0}" +"%s")
    SEC1=$(date --utc --date="${T1}" +"%s")
    MID=$(echo "(${SEC0}+${SEC1})/2"|bc)
    DATE=$(date --utc --date="@${MID}" +"%Y_%m_%d")
    parallel --verbose --bar r.external source={1} output={2}_${DATE} ::: ${VX} ${VY} ${EX} ${EY} :::+ VX VY EX EY
    parallel --verbose --bar r.null map={}_${DATE} null=0 ::: VX VY EX EY
done
g.region raster=VX_${DATE} -pa
