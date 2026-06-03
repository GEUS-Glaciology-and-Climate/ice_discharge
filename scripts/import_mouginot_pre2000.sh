#!/usr/bin/env bash
# Mouginot 2018: historical ice velocities pre-2000.
. "$(dirname "$0")/common.sh"

MSG_OK "Mouginot pre-2000"
g.mapset -c Mouginot_pre2000

ROOT=${DATADIR}/Mouginot_2018/D1GW91
find ${ROOT} -name "*.nc"

for FILE in $(find ${ROOT} -name "*.nc"); do
    YYYYMMDD=$(echo ${FILE} | cut -d"_" -f4)
    YEAR=$(echo ${YYYYMMDD} | cut -d"-" -f1)
    DATE=${YEAR}_01_01
    echo $DATE
    r.external -o source="NetCDF:${FILE}:VX" output=vx_${DATE}
    r.external -o source="NetCDF:${FILE}:VY" output=vy_${DATE}
done
