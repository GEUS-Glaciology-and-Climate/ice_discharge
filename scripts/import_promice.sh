#!/usr/bin/env bash
# PROMICE IV v5: Sentinel-1 velocity, 200 m, ~12-day cadence.
# Downloaded automatically by update.sh when new data is available.
. "$(dirname "$0")/common.sh"

MSG_OK "PROMICE IV v5"
g.mapset -c promice
ROOT=${DATADIR}/Promice200m_v5/

for FILE in $(find ${ROOT} -name "*.nc" | LC_ALL=C sort); do
    DATE_STR=$(ncdump -t -v time ${FILE} | tail -n2 | tr -dc '[0-9\-]' | tr '-' '_')
    echo $DATE_STR
    r.external -o source="NetCDF:${FILE}:land_ice_surface_easting_velocity"       output=vx_${DATE_STR}
    r.external -o source="NetCDF:${FILE}:land_ice_surface_northing_velocity"      output=vy_${DATE_STR}
    r.external -o source="NetCDF:${FILE}:land_ice_surface_easting_velocity_std"   output=ex_${DATE_STR}
    r.external -o source="NetCDF:${FILE}:land_ice_surface_easting_velocity_std"   output=ey_${DATE_STR}
done
