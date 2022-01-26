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
dates=$(g.list type=raster pattern=VX_????_??_?? | cut -d"_" -f2-)
parallel --bar "r.mapcalc \"vel_eff_{1} = if(gates_x@${MAPSET} == 1, if(VX_{1} == -2*10^9, 0, abs(VX_{1})), 0) + if(gates_y@${MAPSET}, if(VY_{1} == -2*10^9, 0, abs(VY_{1})), 0)\"" ::: ${dates}
parallel --bar "r.mapcalc \"err_eff_{1} = if(gates_x@${MAPSET} == 1, if(EX_{1} == -2*10^9, 0, abs(EX_{1})), 0) + if(gates_y@${MAPSET}, if(EY_{1} == -2*10^9, 0, abs(EY_{1})), 0)\"" ::: ${dates}


g.mapset MEaSUREs.0646
g.region -d
r.mapcalc "MASK = if((gates_x@${MAPSET} == 1) | (gates_y@${MAPSET} == 1), 1, null())" --o
dates=$(g.list type=raster pattern=VX_????_??_?? | cut -d"_" -f2-)
# TODO - add gates_y@MAPSET == 1 and then ), 0) as above
parallel --bar "r.mapcalc \"vel_eff_{1} = if(gates_x@${MAPSET} == 1, if(isnull(VX_{1}), 0, abs(VX_{1}))) + if(gates_y@${MAPSET}, if(isnull(VY_{1}), 0, abs(VY_{1})))\"" ::: ${dates}
parallel --bar "r.mapcalc \"err_eff_{1} = if(gates_x@${MAPSET} == 1, if(isnull(EX_{1}), 0, abs(EX_{1}))) + if(gates_y@${MAPSET}, if(isnull(EY_{1}), 0, abs(EY_{1})))\"" ::: ${dates}


g.mapset MEaSUREs.0731
g.region -d
r.mapcalc "MASK = if((gates_x@${MAPSET} == 1) | (gates_y@${MAPSET} == 1), 1, null())" --o
dates=$(g.list type=raster pattern=VX_????_??_?? | cut -d"_" -f2-)
# TODO - add gates_y@MAPSET == 1 and then ), 0) as above
parallel --bar "r.mapcalc \"vel_eff_{1} = if(gates_x@${MAPSET} == 1, if(isnull(VX_{1}), 0, abs(VX_{1}))) + if(gates_y@${MAPSET}, if(isnull(VY_{1}), 0, abs(VY_{1})))\"" ::: ${dates}
parallel --bar "r.mapcalc \"err_eff_{1} = if(gates_x@${MAPSET} == 1, if(isnull(EX_{1}), 0, abs(EX_{1}))) + if(gates_y@${MAPSET}, if(isnull(EY_{1}), 0, abs(EY_{1})))\"" ::: ${dates}


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

dates=$(g.list type=raster pattern=vx_????_??_?? | cut -d"_" -f2-)

# TODO - add gates_y@MAPSET == 1 and then ), 0) as above
parallel --bar "r.mapcalc \"vel_eff_{1} = 365 * (if(gates_x@${MAPSET} == 1, if(isnull(vx_{1}), 0, abs(vx_{1}))) + if(gates_y@${MAPSET}, if(isnull(vy_{1}), 0, abs(vy_{1}))))\"" ::: ${dates}

parallel --bar "r.mapcalc \"err_eff_{1} = 365 * (if(gates_x@${MAPSET} == 1, if(isnull(ex_{1}), 0, abs(ex_{1}))) + if(gates_y@${MAPSET}, if(isnull(ey_{1}), 0, abs(ey_{1}))))\"" ::: ${dates}
# sentinel1_effective_velocity ends here

# [[file:ice_discharge.org::*Just one velocity cutoff & buffer distance][Just one velocity cutoff & buffer distance:3]]
# fix return code of this script so make continues
MSG_OK "vel_eff DONE"
# Just one velocity cutoff & buffer distance:3 ends here
