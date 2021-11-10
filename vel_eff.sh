#!/usr/bin/env bash
# Effective Velocity
# :PROPERTIES:
# :header-args:bash+: :tangle vel_eff.sh
# :END:


# [[file:ice_discharge.org::*Effective Velocity][Effective Velocity:1]]
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
# Effective Velocity:1 ends here

# Just one velocity cutoff & buffer distance 
# :PROPERTIES:
# :ID:       20210102T152009.186822
# :END:


# [[file:ice_discharge.org::*Just one velocity cutoff & buffer distance][Just one velocity cutoff & buffer distance:1]]
g.mapsets -l

r.mask -r

MAPSET=gates_100_5000

g.mapset MEaSUREs.0478
g.region -d
r.mapcalc "MASK = if((gates_x@${MAPSET} == 1) | (gates_y@${MAPSET} == 1), 1, null())" --o
VX=$(g.list type=raster pattern=VX_????_??_?? | head -n1) # DEBUG
VX=$(g.list type=raster pattern=VX_????_??_?? | grep 2012_03_03) # DEBUG
for VX in $(g.list type=raster pattern=VX_????_??_??); do
  VY=${VX/VX/VY}
  EX=${VX/VX/EX}
  EY=${VX/VX/EY}
  DATE=$(echo $VX | cut -d"_" -f2-)
  echo $DATE
  # g.region raster=${VX}
  r.mapcalc "vel_eff_${DATE} = if(gates_x@${MAPSET} == 1, if(${VX} == -2*10^9, 0, abs(${VX})), 0) + if(gates_y@${MAPSET}, if(${VY} == -2*10^9, 0, abs(${VY})), 0)"
  r.mapcalc "err_eff_${DATE} = if(gates_x@${MAPSET} == 1, if(${EX} == -2*10^9, 0, abs(${EX})), 0) + if(gates_y@${MAPSET}, if(${EY} == -2*10^9, 0, abs(${EY})), 0)"
done


g.mapset MEaSUREs.0646
g.region -d
r.mapcalc "MASK = if((gates_x@${MAPSET} == 1) | (gates_y@${MAPSET} == 1), 1, null())" --o
VX=$(g.list type=raster pattern=VX_????_??_?? | head -n1) # DEBUG
for VX in $(g.list type=raster pattern=VX_????_??_??); do
  VY=${VX/VX/VY}
  EX=${VX/VX/EX}
  EY=${VX/VX/EY}
  DATE=$(echo $VX | cut -d"_" -f2-)
  echo $DATE
  r.mapcalc "vel_eff_${DATE} = if(gates_x@${MAPSET} == 1, if(isnull(${VX}), 0, abs(${VX}))) + if(gates_y@${MAPSET}, if(isnull(${VY}), 0, abs(${VY})))"
  r.mapcalc "err_eff_${DATE} = if(gates_x@${MAPSET} == 1, if(isnull(${EX}), 0, abs(${EX}))) + if(gates_y@${MAPSET}, if(isnull(${EY}), 0, abs(${EY})))"
done


g.mapset MEaSUREs.0731
g.region -d
r.mapcalc "MASK = if((gates_x@${MAPSET} == 1) | (gates_y@${MAPSET} == 1), 1, null())" --o
VX=$(g.list type=raster pattern=VX_????_??_?? | head -n1) # DEBUG
for VX in $(g.list type=raster pattern=VX_????_??_??); do
  VY=${VX/VX/VY}
  EX=${VX/VX/EX}
  EY=${VX/VX/EY}
  DATE=$(echo $VX | cut -d"_" -f2-)
  echo $DATE
  r.mapcalc "vel_eff_${DATE} = if(gates_x@${MAPSET} == 1, if(isnull(${VX}), 0, abs(${VX}))) + if(gates_y@${MAPSET}, if(isnull(${VY}), 0, abs(${VY})))"
  r.mapcalc "err_eff_${DATE} = if(gates_x@${MAPSET} == 1, if(isnull(${EX}), 0, abs(${EX}))) + if(gates_y@${MAPSET}, if(isnull(${EY}), 0, abs(${EY})))"
done


g.mapset Mouginot_pre2000
g.region -d
r.mapcalc "MASK = if((gates_x@${MAPSET} == 1) | (gates_y@${MAPSET} == 1), 1, null())" --o
VX=$(g.list type=raster pattern=vx_????_??_?? | head -n1) # DEBUG
for VX in $(g.list type=raster pattern=vx_????_??_??); do
  VY=${VX/vx/vy}
  DATE=$(echo $VX | cut -d"_" -f2-)
  echo $DATE
  r.mapcalc "vel_eff_${DATE} = (if(gates_x@${MAPSET} == 1, if(isnull(${VX}), 0, abs(${VX}))) + if(gates_y@${MAPSET}, if(isnull(${VY}), 0, abs(${VY}))))"
done
# Just one velocity cutoff & buffer distance:1 ends here



# #+NAME: sentinel1_effective_velocity

# [[file:ice_discharge.org::sentinel1_effective_velocity][sentinel1_effective_velocity]]
g.mapset Sentinel1
g.region -d
r.mapcalc "MASK = if((gates_x@${MAPSET} == 1) | (gates_y@${MAPSET} == 1), 1, null())" --o
VX=$(g.list type=raster pattern=vx_????_??_?? | head -n1) # DEBUG
for VX in $(g.list type=raster pattern=vx_????_??_??); do
  VY=${VX/vx/vy}
  EX=${VX/vx/ex}
  EY=${VX/vx/ey}
  DATE=$(echo $VX | cut -d"_" -f2-)
  echo $DATE
  r.mapcalc "vel_eff_${DATE} = 365 * (if(gates_x@${MAPSET} == 1, if(isnull(${VX}), 0, abs(${VX}))) + if(gates_y@${MAPSET}, if(isnull(${VY}), 0, abs(${VY}))))"
  r.mapcalc "err_eff_${DATE} = 365 * (if(gates_x@${MAPSET} == 1, if(isnull(${EX}), 0, abs(${EX}))) + if(gates_y@${MAPSET}, if(isnull(${EY}), 0, abs(${EY}))))"
done
# sentinel1_effective_velocity ends here

# [[file:ice_discharge.org::*Just one velocity cutoff & buffer distance][Just one velocity cutoff & buffer distance:3]]
# fix return code of this script so make continues
MSG_OK "vel_eff DONE"
# Just one velocity cutoff & buffer distance:3 ends here
