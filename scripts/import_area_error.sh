#!/usr/bin/env bash
# Computes the 2D area error correction raster for EPSG:3413 (~±8% error).
# Depends on import_bedmachine having set the PERMANENT region first.
. "$(dirname "$0")/common.sh"

mkdir -p ./tmp/

MSG_OK "2D Area Error"
g.mapset PERMANENT

if [[ "" == $(g.list type=raster pattern=err_2D) ]]; then
    r.mask -r
    g.region -d

    g.region res=1000 -ap   # coarse resolution to run faster
    r.mapcalc "x = x()"
    r.mapcalc "y = y()"
    r.latlong input=x output=lat_low
    r.latlong -l input=x output=lon_low

    r.out.xyz input=lon_low,lat_low separator=space > ./tmp/llxy.txt
    PROJSTR=$(g.proj -j)
    echo $PROJSTR

    paste -d" " \
        <(cut -d" " -f1,2 ./tmp/llxy.txt) \
        <(cut -d" " -f3,4 ./tmp/llxy.txt | proj -VS ${PROJSTR} | grep Areal | column -t | sed s/\ \ /,/g | cut -d, -f4) \
        > ./tmp/xy_err.txt

    r.in.xyz input=./tmp/xy_err.txt output=err_2D_inv separator=space
    r.mapcalc "err_2D = 1/(err_2D_inv^0.5)"
    g.region -d

    r.latlong input=x output=lat   # full-res lat/lon for export
    r.latlong -l input=x output=lon
fi

g.region -d
