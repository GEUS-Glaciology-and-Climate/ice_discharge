#!/usr/bin/env bash
# Effective Velocity

RED='\033[0;31m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
MSG_OK() { printf "${GREEN}${1}${NC}\n"; }
MSG_WARN() { printf "${ORANGE}WARNING: ${1}${NC}\n"; }
MSG_ERR() { echo "${RED}ERROR: ${1}${NC}\n" >&2; }
export GRASS_VERBOSE=3
# export GRASS_MESSAGE_FORMAT=silent

# vel_eff/err_eff are a function of gates_x/gates_y, so they MUST be recomputed
# whenever the gates change - which is exactly what re-running this script is
# for. None of the r.mapcalc calls below carry --o, so on a second run against a
# populated database every one of them fails with "output map <vel_eff_YYYY_MM_DD>
# exists", the previous run's rasters survive untouched, and export.sh happily
# exports them. Nothing catches it: the r.mapcalc calls run under `parallel`, the
# script has no `set -e`, and it ends with an unconditional MSG_OK precisely so
# make continues. The result is a full pipeline run reporting the OLD gates'
# discharge against the NEW gates' geometry, with no error anywhere in the log.
#
# Setting this here rather than adding --o to thirteen r.mapcalc lines also
# covers the Mouginot_pre2000 for-loop, which is written in a different style.
export GRASS_OVERWRITE=1

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

# GRASS's MASK is a per-mapset raster and it PERSISTS - nothing below used to
# remove it, so every mapset kept the previous run's mask indefinitely. That
# matters because r.mapcalc HONOURS the mask already in place while it writes
# the new one, so
#
#   r.mapcalc "MASK = <this run's gates>"
#
# actually computes  <this run's gates> INTERSECT <last run's gates>.
#
# Within one BUFFER_DIST the two are identical and the bug is invisible. Across
# a `make sweep` they are not: gates are one 200 m pixel wide and the buffer
# moves them kilometres inland, so the two gate sets are effectively disjoint
# and the intersection is EMPTY. Every vel_eff/err_eff then comes out all-null,
# r.out.xyz exports a header-only .bsv, and export.sh reports it three stages
# later as "tmp/dat is stale" - which it is not.
#
# The promice block below is the only one that never set a MASK, and it was the
# only set of rasters that survived the 5000 m leg of the sweep.
#
# r.mask -r is an ERROR, not a no-op, when there is no mask, so test first.
reset_mask() {
    [ -n "$(g.list type=raster pattern=MASK mapset=.)" ] && r.mask -r
    return 0
}

# Just one velocity cutoff & buffer distance
# :PROPERTIES:
# :ID:       20210102T152009.186822
# :END:


g.mapsets -l

r.mask -r

MAPSET=gates_vel_buf

g.mapset MEaSUREs.0478
g.region -d
reset_mask
r.mapcalc "MASK = if((gates_x@${MAPSET} == 1) | (gates_y@${MAPSET} == 1), 1, null())" --o
dates=$(g.list type=raster pattern=VX_????_??_?? | cut -d"_" -f2-)
parallel --bar "r.mapcalc \"vel_eff_{1} = if(gates_x@${MAPSET} == 1, if(VX_{1} == -2*10^9, 0, abs(VX_{1})), 0) + if(gates_y@${MAPSET} == 1, if(VY_{1} == -2*10^9, 0, abs(VY_{1})), 0)\"" ::: ${dates}
parallel --bar "r.mapcalc \"err_eff_{1} = if(gates_x@${MAPSET} == 1, if(EX_{1} == -2*10^9, 0, abs(EX_{1})), 0) + if(gates_y@${MAPSET} == 1, if(EY_{1} == -2*10^9, 0, abs(EY_{1})), 0)\"" ::: ${dates}


g.mapset MEaSUREs.0481
g.region -d
reset_mask
r.mapcalc "MASK = if((gates_x@${MAPSET} == 1) | (gates_y@${MAPSET} == 1), 1, null())" --o
dates=$(g.list type=raster pattern=VX_????_??_?? | cut -d"_" -f2-)
parallel --bar "r.mapcalc \"vel_eff_{1} = if(gates_x@${MAPSET} == 1, if(isnull(VX_{1}), 0, abs(VX_{1})), 0) + if(gates_y@${MAPSET} == 1, if(isnull(VY_{1}), 0, abs(VY_{1})), 0)\"" ::: ${dates}
parallel --bar "r.mapcalc \"err_eff_{1} = if(gates_x@${MAPSET} == 1, if(isnull(EX_{1}), 0, abs(EX_{1})), 0) + if(gates_y@${MAPSET} == 1, if(isnull(EY_{1}), 0, abs(EY_{1})), 0)\"" ::: ${dates}


g.mapset MEaSUREs.0646
g.region -d
reset_mask
r.mapcalc "MASK = if((gates_x@${MAPSET} == 1) | (gates_y@${MAPSET} == 1), 1, null())" --o
dates=$(g.list type=raster pattern=VX_????_??_?? | cut -d"_" -f2-)
parallel --bar "r.mapcalc \"vel_eff_{1} = if(gates_x@${MAPSET} == 1, if(isnull(VX_{1}), 0, abs(VX_{1})), 0) + if(gates_y@${MAPSET} == 1, if(isnull(VY_{1}), 0, abs(VY_{1})), 0)\"" ::: ${dates}
parallel --bar "r.mapcalc \"err_eff_{1} = if(gates_x@${MAPSET} == 1, if(isnull(EX_{1}), 0, abs(EX_{1})), 0) + if(gates_y@${MAPSET} == 1, if(isnull(EY_{1}), 0, abs(EY_{1})), 0)\"" ::: ${dates}


g.mapset MEaSUREs.0731
g.region -d
reset_mask
r.mapcalc "MASK = if((gates_x@${MAPSET} == 1) | (gates_y@${MAPSET} == 1), 1, null())" --o
dates=$(g.list type=raster pattern=VX_????_??_?? | cut -d"_" -f2-)
parallel --bar "r.mapcalc \"vel_eff_{1} = if(gates_x@${MAPSET} == 1, if(isnull(VX_{1}), 0, abs(VX_{1})), 0) + if(gates_y@${MAPSET} == 1, if(isnull(VY_{1}), 0, abs(VY_{1})), 0)\"" ::: ${dates}
parallel --bar "r.mapcalc \"err_eff_{1} = if(gates_x@${MAPSET} == 1, if(isnull(EX_{1}), 0, abs(EX_{1})), 0) + if(gates_y@${MAPSET} == 1, if(isnull(EY_{1}), 0, abs(EY_{1})), 0)\"" ::: ${dates}

g.mapset Mouginot_pre2000
g.region -d
reset_mask
r.mapcalc "MASK = if((gates_x@${MAPSET} == 1) | (gates_y@${MAPSET} == 1), 1, null())" --o
VX=$(g.list type=raster pattern=vx_????_??_?? | head -n1) # DEBUG
for VX in $(g.list type=raster pattern=vx_????_??_??); do
  VY=${VX/vx/vy}
  DATE=$(echo $VX | cut -d"_" -f2-)
  echo $DATE
  r.mapcalc "vel_eff_${DATE} = if(gates_x@${MAPSET} == 1, if(isnull(${VX}), 0, abs(${VX})), 0) + if(gates_y@${MAPSET} == 1, if(isnull(${VY}), 0, abs(${VY})), 0)"
done



# #+NAME: MEaSUREs_0766_effective_velocity

g.mapset MEaSUREs.0766
g.region -d
reset_mask
r.mapcalc "MASK = if((gates_x@${MAPSET} == 1) | (gates_y@${MAPSET} == 1), 1, null())" --o
dates=$(g.list type=raster pattern=VX_????_??_?? | cut -d"_" -f2-)
parallel --bar "r.mapcalc \"vel_eff_{1} = if(gates_x@${MAPSET} == 1, if(isnull(VX_{1}), 0, abs(VX_{1})), 0) + if(gates_y@${MAPSET} == 1, if(isnull(VY_{1}), 0, abs(VY_{1})), 0)\"" ::: ${dates}
parallel --bar "r.mapcalc \"err_eff_{1} = if(gates_x@${MAPSET} == 1, if(isnull(EX_{1}), 0, abs(EX_{1})), 0) + if(gates_y@${MAPSET} == 1, if(isnull(EY_{1}), 0, abs(EY_{1})), 0)\"" ::: ${dates}




# #+NAME: promice_effective_velocity

g.mapset promice
g.region -d

dates=$(g.list type=raster pattern=vx_????_??_?? | cut -d"_" -f2-)

parallel --bar "r.mapcalc \"vel_eff_{1} = 365 * (if(gates_x@${MAPSET} == 1, if(isnull(vx_{1}), 0, abs(vx_{1})), 0) + if(gates_y@${MAPSET} == 1, if(isnull(vy_{1}), 0, abs(vy_{1})), 0))\"" ::: ${dates}

parallel --bar "r.mapcalc \"err_eff_{1} = 365 * (if(gates_x@${MAPSET} == 1, if(isnull(ex_{1}), 0, abs(ex_{1})), 0) + if(gates_y@${MAPSET} == 1, if(isnull(ey_{1}), 0, abs(ey_{1})), 0))\"" ::: ${dates}

# Leave no MASK behind. reset_mask above already makes this run correct on its
# own; clearing up here means the NEXT run - or anything else that touches these
# mapsets - never inherits a mask it did not ask for either.
for M in MEaSUREs.0478 MEaSUREs.0481 MEaSUREs.0646 MEaSUREs.0731 \
         MEaSUREs.0766 Mouginot_pre2000 promice; do
    g.mapset ${M}
    reset_mask
done
g.mapset PERMANENT

# fix return code of this script so make continues
MSG_OK "vel_eff DONE"
