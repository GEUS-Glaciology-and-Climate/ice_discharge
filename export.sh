#!/usr/bin/env bash
# Export all data to CSV
# :PROPERTIES:
# :header-args:bash+: :tangle export.sh
# :END:


# [[file:ice_discharge.org::*Export all data to CSV][Export all data to CSV:1]]
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
# Export all data to CSV:1 ends here



# #+NAME: export

# [[file:ice_discharge.org::export][export]]
MSG_OK "Exporting..."
g.mapset PERMANENT
g.region -dp

MAPSET=gates_100_5000

VEL_baseline="vel_baseline@MEaSUREs.0478 vx_baseline@MEaSUREs.0478 vy_baseline@MEaSUREs.0478 vel_err_baseline@MEaSUREs.0478 ex_baseline@MEaSUREs.0478 ey_baseline@MEaSUREs.0478"
VEL_0478=$(g.list -m mapset=MEaSUREs.0478 type=raster pattern=vel_eff_????_??_?? separator=space)
ERR_0478=$(g.list -m mapset=MEaSUREs.0478 type=raster pattern=err_eff_????_??_?? separator=space)
VEL_0646=$(g.list -m mapset=MEaSUREs.0646 type=raster pattern=vel_eff_????_??_?? separator=space)
ERR_0646=$(g.list -m mapset=MEaSUREs.0646 type=raster pattern=err_eff_????_??_?? separator=space)
VEL_0731=$(g.list -m mapset=MEaSUREs.0731 type=raster pattern=vel_eff_????_??_?? separator=space)
ERR_0731=$(g.list -m mapset=MEaSUREs.0731 type=raster pattern=err_eff_????_??_?? separator=space)
VEL_SENTINEL=$(g.list -m mapset=Sentinel1 type=raster pattern=vel_eff_????_??_?? separator=space)
ERR_SENTINEL=$(g.list -m mapset=Sentinel1 type=raster pattern=err_eff_????_??_?? separator=space)
VEL_MOUGINOT=$(g.list -m mapset=Mouginot_pre2000 type=raster pattern=vel_eff_????_??_?? separator=space)
THICK=$(g.list -m mapset=Khan_2016 type=raster pattern=dh_???? separator=space)
GIMP_0715="dem@GIMP.0715 day@GIMP.0715" # ,err@GIMP.0715

LIST="lon lat err_2D gates_x@${MAPSET} gates_y@${MAPSET} gates_gateID@${MAPSET} sectors@Mouginot_2019 regions@Mouginot_2019 bed@BedMachine thickness@BedMachine surface@BedMachine thickness@Bamber_2013 bed_0@Millan_2018 thickness_0@Millan_2018 ${THICK} ${GIMP_0715} ${VEL_baseline} ${VEL_0478} ${VEL_0646} ${VEL_0731} ${VEL_SENTINEL} ${VEL_MOUGINOT} errbed@BedMachine ${ERR_0478} ${ERR_0646} ${ERR_0731} ${ERR_SENTINEL}"

mkdir tmp/dat
r.mapcalc "MASK = if(gates_final@${MAPSET}) | if(dem@GIMP.0715) | if(mask_GIC@Mouginot_2019)" --o
parallel --bar "if [[ ! -e ./tmp/dat/{1}.bsv ]]; then (echo x\|y\|{1}; r.out.xyz input={1}) > ./tmp/dat/{1}.bsv; fi" ::: ${LIST}
r.mask -r

# combine individual files to one mega csv
cat ./tmp/dat/lat.bsv | cut -d"|" -f1,2 | datamash -t"|" transpose > ./tmp/dat_100_5000_t.bsv
for f in ./tmp/dat/*; do
  cat $f | cut -d"|" -f3 | datamash -t"|" transpose >> ./tmp/dat_100_5000_t.bsv
done
cat ./tmp/dat_100_5000_t.bsv |datamash -t"|" transpose | tr '|' ',' > ./tmp/dat_100_5000.csv
rm ./tmp/dat_100_5000_t.bsv
# export ends here
