#!/usr/bin/env bash
# MEaSUREs NSIDC-0478: annual velocity mosaics (200 m / 500 m).
# Also computes the 2015-2017 baseline velocity and fills spatial holes.
. "$(dirname "$0")/common.sh"

MSG_OK "MEaSUREs 0478 — 200 m mosaics"
g.mapset -c MEaSUREs.0478
r.mask -r
ROOT=${DATADIR}/MEaSUREs/NSIDC-0478.002/

for VX in $(find ${ROOT} -name "*mosaic200_*vx*.tif" | LC_ALL=C sort); do
    VY=${VX/vx/vy}; EX=${VX/vx/ex}; EY=${EX/ex/ey}
    DATE=$(dirname ${VX} | rev | cut -d"/" -f1 | rev | sed s/\\./_/g)
    parallel --verbose --bar r.in.gdal input={1} output={2}_${DATE} ::: ${VX} ${VY} ${EX} ${EY} :::+ VX VY EX EY
    parallel --verbose --bar r.null map={}_${DATE} null=0 ::: VX VY EX EY
done
g.region raster=VX_${DATE} -pa

MSG_OK "MEaSUREs 0478 — 500 m mosaics (fill gaps where no 200 m exists)"
for VX in $(find ${ROOT} -name "*mosaic500_*vx*.tif" | LC_ALL=C sort); do
    VY=${VX/vx/vy}; EX=${VX/vx/ex}; EY=${EX/ex/ey}
    DATE=$(dirname ${VX} | rev | cut -d"/" -f1 | rev | sed s/\\./_/g)
    echo $DATE
    parallel --verbose --bar r.external source={1} output={2}_${DATE}_500 ::: ${VX} ${VY} ${EX} ${EY} :::+ VX VY EX EY
    r.mapcalc "VX_${DATE} = VX_${DATE}_500"
    r.mapcalc "VY_${DATE} = VY_${DATE}_500"
    r.mapcalc "EX_${DATE} = EX_${DATE}_500"
    r.mapcalc "EY_${DATE} = EY_${DATE}_500"
    parallel --verbose --bar r.null map={}_${DATE} null=0 ::: VX VY EX EY
done

MSG_OK "MEaSUREs 0478 — 2015-2017 baseline velocity"
r.series input=VX_2015_09_01,VX_2016_09_01,VX_2017_09_01 output=vx_baseline method=average range=-1000000,1000000
r.series input=VY_2015_09_01,VY_2016_09_01,VY_2017_09_01 output=vy_baseline method=average range=-1000000,1000000
r.series input=EX_2015_09_01,EX_2016_09_01,EX_2017_09_01 output=ex_baseline method=average range=-1000000,1000000
r.series input=EY_2015_09_01,EY_2016_09_01,EY_2017_09_01 output=ey_baseline method=average range=-1000000,1000000

v.import input=./dat/remove_ice_manual.kml output=remove_ice_manual --o
r.mask -i vector=remove_ice_manual --o
r.mapcalc "vel_baseline = sqrt(vx_baseline^2 + vy_baseline^2)"
r.mapcalc "vel_err_baseline = sqrt(ex_baseline^2 + ey_baseline^2)"
r.mask -r
parallel --verbose --bar r.null map={}_baseline setnull=0 ::: vx vy vel ex ey vel_err
r.colors -e map=vel_baseline,vel_err_baseline color=viridis

MSG_OK "MEaSUREs 0478 — fill spatial holes in baseline velocity"
r.mask -r
r.mapcalc "no_vel = if(isnull(vel_baseline), 1, null())"
r.mask no_vel
r.clump input=no_vel output=no_vel_clump --o
ocean_clump=$(r.stats -c -n no_vel_clump sort=desc | head -n1 | cut -d" " -f1)
r.mask -i raster=no_vel_clump maskcats=${ocean_clump} --o
r.fillnulls input=vel_baseline out=vel_baseline_filled method=bilinear
r.mask -r
g.rename raster=vel_baseline_filled,vel_baseline --o
r.colors map=vel_baseline -e color=viridis
