#!/usr/bin/env bash
# Export all data to CSV

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



# #+NAME: export

MSG_OK "Exporting..."
g.mapset PERMANENT
g.region -dp

MAPSET=gates_vel_buf

VEL_baseline="vel_baseline@MEaSUREs.0478 vx_baseline@MEaSUREs.0478 vy_baseline@MEaSUREs.0478 vel_err_baseline@MEaSUREs.0478 ex_baseline@MEaSUREs.0478 ey_baseline@MEaSUREs.0478"
VEL_0478=$(g.list -m mapset=MEaSUREs.0478 type=raster pattern=vel_eff_????_??_?? separator=space)
ERR_0478=$(g.list -m mapset=MEaSUREs.0478 type=raster pattern=err_eff_????_??_?? separator=space)
VEL_0481=$(g.list -m mapset=MEaSUREs.0481 type=raster pattern=vel_eff_????_??_?? separator=space)
ERR_0481=$(g.list -m mapset=MEaSUREs.0481 type=raster pattern=err_eff_????_??_?? separator=space)
VEL_0646=$(g.list -m mapset=MEaSUREs.0646 type=raster pattern=vel_eff_????_??_?? separator=space)
ERR_0646=$(g.list -m mapset=MEaSUREs.0646 type=raster pattern=err_eff_????_??_?? separator=space)
VEL_0731=$(g.list -m mapset=MEaSUREs.0731 type=raster pattern=vel_eff_????_??_?? separator=space)
ERR_0731=$(g.list -m mapset=MEaSUREs.0731 type=raster pattern=err_eff_????_??_?? separator=space)
VEL_0766=$(g.list -m mapset=MEaSUREs.0766 type=raster pattern=vel_eff_????_??_?? separator=space)
ERR_0766=$(g.list -m mapset=MEaSUREs.0766 type=raster pattern=err_eff_????_??_?? separator=space)
VEL_SENTINEL=$(g.list -m mapset=promice type=raster pattern=vel_eff_????_??_?? separator=space)
ERR_SENTINEL=$(g.list -m mapset=promice type=raster pattern=err_eff_????_??_?? separator=space)
VEL_MOUGINOT=$(g.list -m mapset=Mouginot_pre2000 type=raster pattern=vel_eff_????_??_?? separator=space)
THICK=$(g.list -m mapset=DEM type=raster pattern=DEM_???? separator=space)

LIST="lon lat err_2D gates_x@${MAPSET} gates_y@${MAPSET} gates_gateID@${MAPSET} sectors@Mouginot_2019 regions@Mouginot_2019 bed@BedMachine thickness@BedMachine surface@BedMachine ${THICK} ${VEL_baseline} ${VEL_0478}
${VEL_0481} ${VEL_0646} ${VEL_0731} ${VEL_0766} ${VEL_SENTINEL} ${VEL_MOUGINOT} errbed@BedMachine ${ERR_0478} ${ERR_0481} ${ERR_0646} ${ERR_0731} ${ERR_0766} ${ERR_SENTINEL}"

# Mouginot catchment category table: numeric cat -> "SUBREGION1___NAME" label.
# The per-pixel export below carries only the numeric cat, so without this there
# is no way to name a catchment that contains no gate - and pixel-scale
# aggregation reaches ~95 catchments that no gate is assigned to.
r.category map=sectors@Mouginot_2019 separator=comma > ./tmp/sector_cats.csv

mkdir -p tmp/dat
# Scratch files from a previous failed export. They are diagnostics only, and
# the stacking loop at the bottom globs this directory, so they must not be
# allowed to accumulate into it.
rm -f ./tmp/dat/*.part ./tmp/dat/*.err

# The per-layer cache below exists for the hundreds of velocity rasters, which
# are expensive to export and never change once written. The three gate layers
# are the opposite: cheap, and precisely what changes whenever gate_IO.sh
# changes. Leaving them cached silently feeds the PREVIOUS run's gates into
# raw2discharge.py while the new gates sit unused in GRASS - which looks like a
# code bug rather than a stale file, because the symptom appears three stages
# downstream as a gate-count mismatch in csv2nc.py. Always refresh them.
rm -f ./tmp/dat/gates_x@${MAPSET}.bsv \
      ./tmp/dat/gates_y@${MAPSET}.bsv \
      ./tmp/dat/gates_gateID@${MAPSET}.bsv

r.mapcalc "MASK = if(gates_final@${MAPSET}) | if(mask_GIC@Mouginot_2019) | if(vel_err_baseline@MEaSUREs.0478) | if(DEM_2020@DEM)" --o
# Write to a .part file and only move it into place once r.out.xyz has both
# succeeded AND produced at least one data row.
#
# The old form redirected straight onto the final name, so the `echo` header
# landed there before r.out.xyz even ran. A failed or empty export therefore
# left a valid-looking 1-line file - and because the cache key is `-e`, that
# file was then kept forever: every later `make export` skipped the raster and
# re-reported the same mismatch, with no way to tell a genuinely stale cache
# from a job that failed in this very run.
parallel --bar "
  f=./tmp/dat/{1}.bsv
  if [[ ! -e \${f} ]]; then
    if r.out.xyz input={1} > \${f}.part 2>\${f}.err && [[ -s \${f}.part ]]; then
      (echo x\|y\|{1}; cat \${f}.part) > \${f} && rm -f \${f}.part \${f}.err
    fi
  fi" ::: ${LIST}
r.mask -r

# Two distinct failures, reported distinctly - conflating them cost a whole
# sweep leg once, because an empty raster was reported as a stale cache.
#
#   MISSING  the export above refused to write the file: r.out.xyz failed, or
#            the raster is entirely null within the MASK. Usually the raster is
#            wrong, not the cache. The commonest cause is a stale per-mapset
#            MASK during `make velocity` - see the comment in vel_eff.sh.
#
#   BAD      the file exists but has the wrong number of rows. Every .bsv is
#            transposed and stacked into one CSV purely by position, so a file
#            left over from a run with a different MASK - and MASK depends on
#            gates_final - would misalign every column without any error. This
#            one really is a stale cache.
MISSING=$(for m in ${LIST}; do
              [ -e "./tmp/dat/${m}.bsv" ] || echo "  ${m}"
          done)
if [ -n "${MISSING}" ]; then
    MSG_ERR "$(echo "${MISSING}" | wc -l) raster(s) exported no data."
    echo "${MISSING}" >&2
    echo "These rasters are empty within the MASK, or r.out.xyz failed on them." >&2
    echo "Check ./tmp/dat/*.err, then 'r.univar map=<name>' on one of them." >&2
    echo "If n=0, re-run 'make velocity' - a leftover MASK in the source" >&2
    echo "mapset is the usual cause. This is NOT a stale tmp/dat." >&2
    exit 1
fi

NROW=$(wc -l < ./tmp/dat/lat.bsv)
BAD=$(for f in ./tmp/dat/*.bsv; do
          n=$(wc -l < "$f")
          [ "$n" != "$NROW" ] && echo "  $f has $n rows"
      done)
if [ -n "${BAD}" ]; then
    MSG_ERR "row-count mismatch against lat.bsv (${NROW} rows)."
    echo "${BAD}" >&2
    echo "tmp/dat is stale - remove it and re-run 'make export'." >&2
    exit 1
fi

# combine individual files to one mega csv
cat ./tmp/dat/lat.bsv | cut -d"|" -f1,2 | datamash -t"|" transpose > ./tmp/dat_100_5000_t.bsv
for f in ./tmp/dat/*.bsv; do
  cat $f | cut -d"|" -f3 | datamash -t"|" transpose >> ./tmp/dat_100_5000_t.bsv
done
cat ./tmp/dat_100_5000_t.bsv |datamash -t"|" transpose | tr '|' ',' > ./tmp/dat_100_5000.csv
rm ./tmp/dat_100_5000_t.bsv
