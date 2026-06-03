#!/usr/bin/env bash
# Annual DEMs: imports PRODEM (2019-2023) and Khan 2016 dh/dt (1995-2019),
# then reconstructs annual DEMs back to 1995 by subtracting elevation change.
. "$(dirname "$0")/common.sh"

mkdir -p ./tmp/

MSG_OK "PRODEM — annual DEMs 2019-2023"
g.mapset -c PRODEM
r.mask -r

for f in $(ls ${DATADIR}/PRODEM/PRODEM??.tif); do
    y=20$(echo ${f: -6:2})
    r.in.gdal -r input=${f} output=DEM_${y} band=1
done
g.region raster=DEM_2019 -pa

MSG_OK "Khan 2016 — dh/dt 1995-2010"
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
for Y in $(seq 1995 2010); do
    col=$(echo "$Y-1995+3" | bc -l)
    echo $Y $col
    if [[ "" == $(g.list type=raster pattern=dh_${Y}) ]]; then
        cat ${FILE} \
            | grep -v "^%" \
            | sed s/^\ *//g \
            | sed s/\ \ \*/,/g \
            | cut -d"," -f1,2,${col} \
            | awk -F, '{print $2 "|" $1 "|" $3}' \
            | m.proj -i input=- \
            | r.in.xyz input=- output=dh_${Y}_unfiltered
    fi
done

FILE=${DATADIR}/Khan_2016/GR_2011_2020.txt
for Y in $(seq 2011 2019); do
    col=$(echo "($Y-2011)*2 +3" | bc -l)
    echo $Y $col
    if [[ "" == $(g.list type=raster pattern=dh_${Y}) ]]; then
        cat ${FILE} \
            | grep -v "^%" \
            | sed s/^\ *//g \
            | sed s/\ \ \*/,/g \
            | cut -d"," -f1,2,${col} \
            | awk -F, '{print $2 "|" $1 "|" $3}' \
            | m.proj -i input=- \
            | r.in.xyz input=- output=dh_${Y}_unfiltered
    fi
done

parallel "r.mfilter -z input=dh_{1}_unfiltered output=dh_{1} filter=./tmp/elev_filter.txt repeat=2" ::: $(seq 1995 2019)
parallel "r.colors map=dh_{1} color=difference" ::: $(seq 1995 2019)

MSG_OK "DEM — reconstructing annual DEMs 1995-2018 from PRODEM + Khan dh/dt"
g.mapset -c DEM
g.region raster=DEM_2020@PRODEM -pa

for y in {2019..2023}; do
    if [[ -z "$(g.list type=raster pattern=DEM_${y})" ]]; then
        r.mapcalc "DEM_${y} = DEM_${y}@PRODEM"
    fi
done

for y in {2018..1995}; do
    y1=$(( ${y} + 1 ))
    if [[ -z "$(g.list type=raster pattern=DEM_${y})" ]]; then
        r.mapcalc "DEM_${y} = DEM_${y1} - dh_${y}@Khan_2016"
    fi
done
