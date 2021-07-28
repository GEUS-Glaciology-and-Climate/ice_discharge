#!/usr/bin/env bash
# Import Data
# :PROPERTIES:
# :header-args:bash+: :tangle import.sh
# :END:


# [[file:ice_discharge.org::*Import Data][Import Data:1]]
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
# Import Data:1 ends here

# BedMachine v4
# + from [[textcite:Morlighem:2017BedMachine][Morlighem /et al./ (2017)]]

# [[file:ice_discharge.org::*BedMachine v4][BedMachine v4:1]]
MSG_OK "BedMachine"
g.mapset -c BedMachine

# Now provided in EPSG:3411.
# Reprojected to EPSG:3413 GeoTIFFs in [[file:~/data/Morlighem_2017/README.org]]
for var in mask surface thickness bed errbed; do
  echo $var
  r.external source=${DATADIR}/Morlighem_2017/BMv4_3413/${var}.tif output=${var}
done

r.colors -a map=errbed color=haxby

g.mapset PERMANENT
g.region raster=surface@BedMachine res=200 -a -p
g.region -s
g.mapset BedMachine
g.region -dp

r.colors map=mask color=haxby

r.mapcalc "mask_ice = if(mask == 2, 1, null())"
# BedMachine v4:1 ends here

# Bamber 2013

# [[file:ice_discharge.org::*Bamber 2013][Bamber 2013:1]]
MSG_OK "Bamber 2013"
g.mapset -c Bamber_2013
r.in.gdal input=${DATADIR}/Bamber_2013/IceThickness.tif output=thickness
r.null thickness null=0
# Bamber 2013:1 ends here

# GIMP 0715

# [[file:ice_discharge.org::*GIMP 0715][GIMP 0715:1]]
MSG_OK "GIMP 0715"
g.mapset -c GIMP.0715
ROOT=${DATADIR}/GIMP/0715

# reset
# g.remove -f type=raster name=$(g.list type=raster mapset=. separator=",")

# read in DEM, DAY, and ERR
# for f in $(ls ${ROOT}/reg/tile_?_?_reg_30m_???.tif); do
#   name=$(basename ${f})
#   r.external input=${f} output=${name}
# done
ls ${ROOT}/reg/tile_?_?_reg_30m_???.tif | parallel --verbose --bar r.external input={} output={/.}
ls ${ROOT}/fit/tile_?_?_fit_30m_???.tif | parallel --verbose --bar r.external input={} output={/.}

r.patch -s input=$(g.list type=raster pattern=tile_?_?_reg_30m_dem separator=,),$(g.list type=raster pattern=tile_?_?_fit_30m_dem separator=,) output=dem

# no fit day data to patch holes. We'll assign elevation pixels with DEM data but not DAY data to some day, TBD
r.patch -s input=$(g.list type=raster pattern=tile_?_?_reg_30m_day separator=,) output=day

r.patch -s input=$(g.list type=raster pattern=tile_?_?_reg_30m_err separator=,),$(g.list type=raster pattern=tile_?_?_fit_30m_err separator=,) output=err

r.null map=day null=0
# GIMP 0715:1 ends here

# Import & Clean

# [[file:ice_discharge.org::*Import & Clean][Import & Clean:1]]
MSG_OK "Mouginot 2019 sectors"

g.mapset -c Mouginot_2019
v.in.ogr input=${DATADIR}/Mouginot_2019 output=sectors_all
v.extract input=sectors_all where="NAME NOT LIKE '%ICE_CAP%'" output=sectors

db.select table=sectors | head
v.db.addcolumn map=sectors columns="region_name varchar(100)"
db.execute sql="UPDATE sectors SET region_name=SUBREGION1 || \"___\" || NAME"

v.to.db map=sectors option=area columns=area units=meters

mkdir -p ./tmp/
# db.select table=sectors > ./tmp/Mouginot_2019.txt

v.to.rast input=sectors output=sectors use=cat label_column=region_name
r.mapcalc "mask_GIC = if(sectors)"

# # regions map
v.to.rast input=sectors output=regions_tmp use=cat label_column=SUBREGION1
# which categories exist?
# r.category regions separator=comma | cut -d, -f2 | sort | uniq
# Convert categories to numbers
r.category regions_tmp separator=comma | sed s/NO/1/ | sed s/NE/2/ | sed s/CE/3/ | sed s/SE/4/ | sed s/SW/5/ | sed s/CW/6/ | sed s/NW/7/ > ./tmp/mouginot.cat
r.category regions_tmp separator=comma rules=./tmp/mouginot.cat
# r.category regions_tmp
r.mapcalc "regions = @regions_tmp"

# # region vector 
# r.to.vect input=regions output=regions type=area
# v.db.addcolumn map=regions column="REGION varchar(2)"
# v.what.vect map=regions column=REGION query_map=sectors query_column=SUBREGION1

# # mask
# Import & Clean:1 ends here

# Zwally 2012

# I use an "expanded boundary" version. This was created by loading the Zwally sectors into QGIS and moving the coasts outward. This is done because some gates (ice) is outside the boundaries provided by Zwally.


# [[file:ice_discharge.org::*Zwally 2012][Zwally 2012:1]]
g.mapset -c Zwally_2012
v.in.ogr input=${DATADIR}/Zwally_2012/sectors_enlarged output=Zwally_2012
# Zwally 2012:1 ends here

# 2D Area Error
# + EPSG:3413 has projection errors of \(\pm\) ~8% in Greenland
# + Method
#   + Email: [[mu4e:msgid:m2tvxmd2xr.fsf@gmail.com][Re: {GRASS-user} scale error for each pixel]]
#   + Webmail: https://www.mail-archive.com/grass-user@lists.osgeo.org/msg35005.html

# [[file:ice_discharge.org::*2D Area Error][2D Area Error:1]]
MSG_OK "2D Area Error"
g.mapset PERMANENT

if [[ "" == $(g.list type=raster pattern=err_2D) ]]; then
    r.mask -r
    g.region -d

    g.region res=1000 -ap # do things faster
    r.mapcalc "x = x()"
    r.mapcalc "y = y()"
    r.latlong input=x output=lat_low
    r.latlong -l input=x output=lon_low

    r.out.xyz input=lon_low,lat_low separator=space > ./tmp/llxy.txt
    PROJSTR=$(g.proj -j)
    echo $PROJSTR

    paste -d" " <(cut -d" " -f1,2 ./tmp/llxy.txt) <(cut -d" " -f3,4 ./tmp/llxy.txt | proj -VS ${PROJSTR} | grep Areal | column -t | sed s/\ \ /,/g | cut -d, -f4) > ./tmp/xy_err.txt

    r.in.xyz input=./tmp/xy_err.txt  output=err_2D_inv separator=space
    r.mapcalc "err_2D = 1/(err_2D_inv^0.5)" # convert area error to linear multiplier error
    g.region -d

    r.latlong input=x output=lat # for exporting at full res
    r.latlong -l input=x output=lon
fi

# sayav done
g.region -d
# 2D Area Error:1 ends here

# Import
# + First read in the 200 m files
# + Then read in the 500 m files if there were no 200 m files

# [[file:ice_discharge.org::*Import][Import:1]]
MSG_OK "MEaSURES.0478"
g.mapset -c MEaSUREs.0478

MSG_OK "  200 m..."
r.mask -r
ROOT=${DATADIR}/MEaSUREs/NSIDC-0478.002/
VX=$(find ${ROOT} -name "*mosaic200_*vx*.tif" | head -n1) # DEBUG
for VX in $(find ${ROOT} -name "*mosaic200_*vx*.tif" | LC_ALL=C sort); do
  VY=${VX/vx/vy}
  EX=${VX/vx/ex}
  EY=${EX/ex/ey}
  DATE=$(dirname ${VX} | rev | cut -d"/" -f1 | rev | sed s/\\./_/g)
  # echo $DATE
  # need to import not link to external so that we can set nulls to 0
  parallel --verbose --bar r.in.gdal input={1} output={2}_${DATE} ::: ${VX} ${VY} ${EX} ${EY} :::+ VX VY EX EY
  parallel --verbose --bar r.null map={}_${DATE} null=0 ::: VX VY EX EY
done
g.region raster=VX_${DATE} -pa

MSG_OK "  500 m..."
VX=$(find ${ROOT} -name "*mosaic500_*vx*.tif" | head -n1) # DEBUG
for VX in $(find ${ROOT} -name "*mosaic500_*vx*.tif" | LC_ALL=C sort); do
  VY=${VX/vx/vy}
  EX=${VX/vx/ex}
  EY=${EX/ex/ey}
  DATE=$(dirname ${VX} | rev | cut -d"/" -f1 | rev | sed s/\\./_/g)
  echo $DATE

  # Read in all the 500 m velocity data
  parallel --verbose --bar r.external source={1} output={2}_${DATE}_500 ::: ${VX} ${VY} ${EX} ${EY} :::+ VX VY EX EY 
  # If the 200 m data exists, will produce an error and continue
  # If the 200 m data does not exist, will resample from 500
  r.mapcalc "VX_${DATE} = VX_${DATE}_500"
  r.mapcalc "VY_${DATE} = VY_${DATE}_500"
  r.mapcalc "EX_${DATE} = EX_${DATE}_500"
  r.mapcalc "EY_${DATE} = EY_${DATE}_500"
  parallel --verbose --bar r.null map={}_${DATE} null=0 ::: VX VY EX EY
done
# Import:1 ends here

# Baseline: Average of 2015-2017

# + See [[./dat/remove_ice_manual.kml]]
# + This is due to extensive Jakobshavn retreat between baseline and present
# + The gates need to be >5 km from the baseline terminus


# [[file:ice_discharge.org::*Baseline: Average of 2015-2017][Baseline: Average of 2015-2017:1]]
MSG_OK "Baseline"
g.mapset -c MEaSUREs.0478

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
# Baseline: Average of 2015-2017:1 ends here

# Fill in holes
# + There are holes in the velocity data which will create false gates. Fill them in.
# + Clump based on yes/no velocity
#   + Largest clump is GIS
#   + 2nd largest is ocean
# + Mask by ocean (so velocity w/ holes remains)
# + Fill holes

# [[file:ice_discharge.org::*Fill in holes][Fill in holes:1]]
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
# Fill in holes:1 ends here

# Generate VRTs
# + One map per month
# + Build GDAL virtual tiles for every month (when data exists)

# [[file:ice_discharge.org::*Generate VRTs][Generate VRTs:1]]
g.mapset -c MEaSUREs.0646

ROOT=${DATADIR}/MEaSUREs/NSIDC-0646.003/
VRTROOT=./tmp/NSIDC-0646.003.vrt/
mkdir -p ${VRTROOT}
for year in $(seq 1985 2018); do
  for month in $(seq -w 1 12); do
    if [[ ! -f ${VRTROOT}/${year}_${month}_vx.vrt ]]; then # VRT file does not exist?
      LIST=$(find ${ROOT} -name "*${year}-${month}_vx_*.tif" | LC_ALL=C sort)
      if [[ ! -z ${LIST} ]]; then
        MSG_OK "Building VRTs for ${year} ${month}"
        parallel --verbose --bar gdalbuildvrt -overwrite ${VRTROOT}/${year}_${month}_{}.vrt $\(find ${ROOT} -name "*${year}-${month}_{}_*.tif" \| LC_ALL=C sort\) ::: vx vy ex ey
      fi
    fi
  done
done
# Generate VRTs:1 ends here

# Import VRTs

# [[file:ice_discharge.org::*Import VRTs][Import VRTs:1]]
MSG_OK "MEaSURES.0646"
g.mapset -c MEaSUREs.0646

r.mask -r
ROOT=./tmp/NSIDC-0646.003.vrt/
VX=$(find ${ROOT} -name "*vx*.vrt" | head -n1) # debug
for VX in $(find ${ROOT} -name "*vx*.vrt" | LC_ALL=C sort); do
    VY=${VX/vx/vy}
    EX=${VX/vx/ex}
    EY=${EX/ex/ey}
    DATE=$(basename $VX | cut -d"_" -f1-2)
    DATE=${DATE}_15
    echo $DATE
    
    parallel --verbose --bar r.external source={1} output={2}_${DATE} ::: ${VX} ${VY} ${EX} ${EY} :::+ VX VY EX EY
done
g.region raster=VX_${DATE} -pa
# g.list type=raster mapset=MEaSUREs.0646
# Import VRTs:1 ends here

# Import

# [[file:ice_discharge.org::*Import][Import:1]]
MSG_OK "MEaSURES.0731"
g.mapset -c MEaSUREs.0731
r.mask -r
ROOT=${DATADIR}/MEaSUREs/NSIDC-0731.001/
VX=$(find ${ROOT} -name "*mosaic_*vx*.tif" | head -n1) # DEBUG
for VX in $(find ${ROOT} -name "*mosaic_*vx*.tif" | LC_ALL=C sort); do
  VY=${VX/vx/vy}
  EX=${VX/vx/ex}
  EY=${EX/ex/ey}

  T0=$(dirname ${VX} | rev | cut -d"/" -f1 | rev|cut -d"_" -f4)
  T1=$(dirname ${VX} | rev | cut -d"/" -f1 | rev|cut -d"_" -f5)
  SEC0=$(date --utc --date="${T0}" +"%s")
  SEC1=$(date --utc --date="${T1}" +"%s")
  MID=$(echo "(${SEC0}+${SEC1})/2"|bc)
  DATE=$(date --utc --date="@${MID}" +"%Y_%m_%d")

  # echo $DATE
  parallel --verbose --bar r.external source={1} output={2}_${DATE} ::: ${VX} ${VY} ${EX} ${EY} :::+ VX VY EX EY
  parallel --verbose --bar r.null map={}_${DATE} null=0 ::: VX VY EX EY
done
g.region raster=VX_${DATE} -pa
# Import:1 ends here

# Import data                                                  :noexport:
# + Read in all the data
# + Conversion from [m day-1] to [m year-1] is done in section [[id:20210102T152009.186822][Just one velocity cutoff & buffer distance]]

# #+NAME: sentinel1_import  

# [[file:ice_discharge.org::sentinel1_import][sentinel1_import]]
MSG_OK "Sentinel 1"
g.mapset -c Sentinel1
ROOT=${DATADIR}/Sentinel1/Sentinel1_IV_maps

find ${ROOT} -name "*.nc"
# FILE=$(find ${ROOT} -name "*.nc"|head -n1) # testing

FILE=$(find ${ROOT} -name "*.nc" | head -n1) # DEBUG
for FILE in $(find ${ROOT} -name "*.nc" | LC_ALL=C sort); do
  T=$(ncdump -v time $FILE | tail -n2 | tr -dc '[0-9]')
  DATE=$(date --utc --date="1990-01-01 +${T} days" --iso-8601)
  DATE_STR=$(echo ${DATE} | sed s/-/_/g)
  echo $DATE

  # TT=$(ncdump -v time_bnds $FILE | tail -n2 | head -n1)
  # T0=$(echo ${TT} | cut -d, -f1)
  # T1=$(echo ${TT} | cut -d, -f2 | tr -dc [0-9])
  # D0=$(date --date="1990-01-01 +${T0} days" --iso-8601)
  # D1=$(date --date="1990-01-01 +${T1} days" --iso-8601)

  r.external -o source="NetCDF:${FILE}:land_ice_surface_easting_velocity" output=vx_${DATE_STR}
  r.external -o source="NetCDF:${FILE}:land_ice_surface_northing_velocity" output=vy_${DATE_STR}

  r.external -o source="NetCDF:${FILE}:land_ice_surface_easting_velocity_std" output=ex_${DATE_STR}
  r.external -o source="NetCDF:${FILE}:land_ice_surface_northing_velocity_std" output=ey_${DATE_STR}
done
# sentinel1_import ends here

# Mouginot 2018 (pre-2000 velocities)
# + See citet:mouginot_2018_1972to1990 and citet:mouginot_2018_1991to2000


# [[file:ice_discharge.org::*Mouginot 2018 (pre-2000 velocities)][Mouginot 2018 (pre-2000 velocities):1]]
MSG_OK "Mouginot pre 2000"
g.mapset -c Mouginot_pre2000

ROOT=${DATADIR}/Mouginot_2018/D1GW91
find ${ROOT} -name "*.nc"
FILE=$(find ${ROOT} -name "*.nc" | head -n1 | LC_ALL=C sort) # DEBUG
for FILE in $(find ${ROOT} -name "*.nc"); do
  YYYYMMDD=$(echo ${FILE} | cut -d"_" -f4)
  YEAR=$(echo ${YYYYMMDD} | cut -d"-" -f1)
  DATE=${YEAR}_01_01
  echo $DATE
  r.external -o source="NetCDF:${FILE}:VX" output=vx_${DATE}
  r.external -o source="NetCDF:${FILE}:VY" output=vy_${DATE}
done

# ROOT=${DATADIR}/Mouginot_2018/D1MM37
# find ${ROOT} -name "*.nc"
# FILE=$(find ${ROOT} -name "*.nc" | head -n1) # DEBUG
# for FILE in $(find ${ROOT} -name "*.nc"); do
#   YYYYMMDD=$(echo ${FILE} | cut -d"_" -f4)
#   YEAR=$(echo ${YYYYMMDD} | cut -d"-" -f1)
#   DATE=${YEAR}_01_01
#   echo $DATE
#   r.external -o source="NetCDF:${FILE}:VX" output=vx_${DATE}
#   r.external -o source="NetCDF:${FILE}:VY" output=vy_${DATE}
# done
# Mouginot 2018 (pre-2000 velocities):1 ends here

# Bjørk 2015
# + Write out x,y,name. Can use x,y and mean gate location to find closest name for each gate.

# [[file:ice_discharge.org::*Bjørk 2015][Bjørk 2015:1]]
MSG_OK "Bjørk 2015"
g.mapset -c Bjork_2015

ROOT=${DATADIR}/Bjørk_2015/

cat ${ROOT}/GreenlandGlacierNames_GGNv01.csv |  iconv -c -f utf-8 -t ascii | grep GrIS | awk -F';' '{print $3"|"$2"|"$7}' | sed s/,/./g | m.proj -i input=- | sed s/0.00\ //g | v.in.ascii input=- output=names columns="x double precision, y double precision, name varchar(99)"

# db.select table=names | tr '|' ',' > ./tmp/Bjork_2015_names.csv
# Bjørk 2015:1 ends here

# Mouginot 2019

# [[file:ice_discharge.org::*Mouginot 2019][Mouginot 2019:1]]
g.mapset Mouginot_2019
db.select table=sectors | head
# v.out.ascii -c input=sectors output=./tmp/Mouginot_2019_names.csv columns=NAME,SUBREGION1
# Mouginot 2019:1 ends here

# dh/dt

# [[file:ice_discharge.org::*dh/dt][dh/dt:1]]
MSG_OK "dh/dt"

g.mapset -c Khan_2016
r.mask -r

g.region -d
g.region res=2000 -pa

cat << EOF > ./tmp/elev_filter.txt
TITLE     See r.mfilter manual
    MATRIX    3
    1 1 1
    1 1 1
    1 1 1
    DIVISOR   0
    TYPE      P
EOF

FILE=${DATADIR}/Khan_2016/dhdt_1995-2015_GrIS.txt
head -n1 $FILE
Y=1995 # debug
for Y in $(seq 1995 2010); do
  col=$(echo "$Y-1995+3" | bc -l)
  if [[ "" == $(g.list type=raster pattern=dh_${Y}) ]]; then
    # remove comments, leading spaces, and convert spaces to comma, swap lat,lon, then import
    cat ${FILE} | grep -v "^%" | sed s/^\ *//g | sed s/\ \ \*/,/g | cut -d"," -f1,2,${col} | awk -F, '{print $2 "|" $1 "|" $3}' | m.proj -i input=- | r.in.xyz input=- output=dh_${Y}_unfiltered
  fi
done


FILE=${DATADIR}/Khan_2016/GR_2011_2020.txt
head -n10 $FILE
Y=2011 # debug
for Y in $(seq 2011 2019); do
  col=$(echo "($Y-2011)*2 +3" | bc -l)
  echo $Y $col

  if [[ "" == $(g.list type=raster pattern=dh_${Y}) ]]; then
    # remove comments, leading spaces, and convert spaces to comma, swap lat,lon, then import
    cat ${FILE} | grep -v "^%" | sed s/^\ *//g | sed s/\ \ \*/,/g | cut -d"," -f1,2,${col} | awk -F, '{print $2 "|" $1 "|" $3}' | m.proj -i input=- | r.in.xyz input=- output=dh_${Y}_unfiltered
  fi
done

parallel "r.mfilter -z input=dh_{1}_unfiltered output=dh_{1} filter=./tmp/elev_filter.txt repeat=2" ::: $(seq 1995 2019)
parallel "r.colors map=dh_{1} color=difference" ::: $(seq 1995 2019)
# dh/dt:1 ends here
