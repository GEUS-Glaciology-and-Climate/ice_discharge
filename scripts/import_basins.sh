#!/usr/bin/env bash
# Imports all basin/sector/glacier-name reference datasets:
# Mouginot 2019, Zwally 2012, Bjørk 2015, NSIDC-0642 (Moon 2008)
. "$(dirname "$0")/common.sh"

mkdir -p ./tmp/

MSG_OK "Mouginot 2019 sectors"
g.mapset -c Mouginot_2019
v.in.ogr input=${DATADIR}/Mouginot_2019 output=sectors_all
v.extract input=sectors_all where="NAME NOT LIKE '%ICE_CAP%'" output=sectors

v.db.addcolumn map=sectors columns="region_name varchar(100)"
db.execute sql="UPDATE sectors SET region_name=SUBREGION1 || \"___\" || NAME"
v.to.db map=sectors option=area columns=area units=meters

v.to.rast input=sectors output=sectors use=cat label_column=region_name
r.mapcalc "mask_GIC = if(sectors)"

v.to.rast input=sectors output=regions_tmp use=cat label_column=SUBREGION1
r.category regions_tmp separator=comma | sed s/NO/1/ | sed s/NE/2/ | sed s/CE/3/ | sed s/SE/4/ | sed s/SW/5/ | sed s/CW/6/ | sed s/NW/7/ > ./tmp/mouginot.cat
r.category regions_tmp separator=comma rules=./tmp/mouginot.cat
r.mapcalc "regions = @regions_tmp"

MSG_OK "Zwally 2012"
g.mapset -c Zwally_2012
v.in.ogr input=${DATADIR}/Zwally_2012/sectors_enlarged output=Zwally_2012

MSG_OK "Bjørk 2015"
g.mapset -c Bjork_2015
ROOT=${DATADIR}/Bjørk_2015/
cat ${ROOT}/GreenlandGlacierNames_GGNv01.csv \
    | iconv -c -f utf-8 -t ascii \
    | grep GrIS \
    | awk -F';' '{print $3"|"$2"|"$7}' \
    | sed s/,/./g \
    | m.proj -i input=- \
    | sed s/0.00\ //g \
    | v.in.ascii input=- output=names columns="x double precision, y double precision, name varchar(99)"

MSG_OK "NSIDC-0642 (Moon 2008)"
g.mapset -c NSIDC_0642
ROOT=${DATADIR}/Moon_2008
v.in.ogr input=${ROOT}/GlacierIDs_v01.2.shp output=GlacierIDs
