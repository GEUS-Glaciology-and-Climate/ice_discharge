#!/usr/bin/env bash
# [[file:ice_discharge.org::*Local][Local:2]]
RED='\033[0;31m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
MSG_OK() { printf "${GREEN}${1}${NC}\n"; }
MSG_WARN() { printf "${ORANGE}WARNING: ${1}${NC}\n"; }
MSG_ERR() { echo "${RED}ERROR: ${1}${NC}\n" >&2; }
export GRASS_VERBOSE=3
# export GRASS_MESSAGE_FORMAT=silent

if [ -z ${DATADIR+x} ]; then
    echo "DATADIR environment varible is unset."
    echo "Fix with: \"export DATADIR=/path/to/data\""
    exit 255
fi

set -x # print commands to STDOUT before running them

trap ctrl_c INT
function ctrl_c() {
  MSG_WARN "Caught CTRL-C"
  MSG_WARN "Killing process"
  kill -term $$ # send this program a terminate signal
}
MSG_OK "Promice 200m v5"
g.mapset -c promice
ROOT=${DATADIR}/Promice200m_v5/

FILE=$(find ${ROOT} -name "*.nc" | head -n1) # DEBUG 
for FILE in $(find ${ROOT} -name "*.nc" | LC_ALL=C sort); do
  DATE_STR=$(ncdump -t -v time ${FILE} | tail -n2 | tr -dc '[0-9\-]' | tr '-' '_')
  echo $DATE_STR

  r.external -o source="NetCDF:${FILE}:land_ice_surface_easting_velocity" output=vx_${DATE_STR}
  r.external -o source="NetCDF:${FILE}:land_ice_surface_northing_velocity" output=vy_${DATE_STR}

  r.external -o source="NetCDF:${FILE}:land_ice_surface_easting_velocity_std" output=ex_${DATE_STR}
  r.external -o source="NetCDF:${FILE}:land_ice_surface_northing_velocity_std" output=ey_${DATE_STR}
done
MSG_OK "MEaSURES.0766"
g.mapset -c MEaSUREs.0766
r.mask -r
ROOT=${DATADIR}/MEaSUREs/NSIDC-0766.002
VX=$(find ${ROOT} -name "*mosaic_*vx*.tif" | tail -n1) # DEBUG
for VX in $(find ${ROOT} -name "*mosaic_*vx*.tif" | LC_ALL=C sort); do
  VY=${VX/vx/vy}
  EX=${VX/vx/ex}
  EY=${EX/ex/ey}

  T0=$(basename ${VX} | cut -d_ -f5)
  T1=$(basename ${VX} | cut -d_ -f6)
  SEC0=$(date --utc --date="${T0}" +"%s")
  SEC1=$(date --utc --date="${T1}" +"%s")
  MID=$(echo "(${SEC0}+${SEC1})/2"|bc)
  DATE=$(date --utc --date="@${MID}" +"%Y_%m_%d")

  # echo $DATE
  parallel --verbose --bar r.external source={1} output={2}_${DATE} ::: ${VX} ${VY} ${EX} ${EY} :::+ VX VY EX EY
  # Can't r.null for external maps.
  # parallel --verbose --bar r.null map={}_${DATE} null=0 ::: VX VY EX EY 
done
g.region raster=VX_${DATE} -pa

MAPSET=gates_vel_buf
g.mapset promice
g.region -d

dates=$(g.list type=raster pattern=vx_????_??_?? | cut -d"_" -f2-)

parallel --bar "r.mapcalc \"vel_eff_{1} = 365 * (if(gates_x@${MAPSET} == 1, if(isnull(vx_{1}), 0, abs(vx_{1})), 0) + if(gates_y@${MAPSET} == 1, if(isnull(vy_{1}), 0, abs(vy_{1})), 0))\"" ::: ${dates}

parallel --bar "r.mapcalc \"err_eff_{1} = 365 * (if(gates_x@${MAPSET} == 1, if(isnull(ex_{1}), 0, abs(ex_{1})), 0) + if(gates_y@${MAPSET} == 1, if(isnull(ey_{1}), 0, abs(ey_{1})), 0))\"" ::: ${dates}
g.mapset MEaSUREs.0766
g.region -d
r.mapcalc "MASK = if((gates_x@${MAPSET} == 1) | (gates_y@${MAPSET} == 1), 1, null())" --o
dates=$(g.list type=raster pattern=VX_????_??_?? | cut -d"_" -f2-)
parallel --bar "r.mapcalc \"vel_eff_{1} = if(gates_x@${MAPSET} == 1, if(isnull(VX_{1}), 0, abs(VX_{1})), 0) + if(gates_y@${MAPSET} == 1, if(isnull(VY_{1}), 0, abs(VY_{1})), 0)\"" ::: ${dates}
parallel --bar "r.mapcalc \"err_eff_{1} = if(gates_x@${MAPSET} == 1, if(isnull(EX_{1}), 0, abs(EX_{1})), 0) + if(gates_y@${MAPSET} == 1, if(isnull(EY_{1}), 0, abs(EY_{1})), 0)\"" ::: ${dates}
# Local:2 ends here
