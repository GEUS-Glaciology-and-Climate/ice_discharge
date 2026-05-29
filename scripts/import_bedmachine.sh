#!/usr/bin/env bash
. "$(dirname "$0")/common.sh"

MSG_OK "BedMachine v6"
g.mapset -c BedMachine

for var in mask surface thickness bed errbed; do
    echo $var
    r.external source=NetCDF:${DATADIR}/Morlighem_2017/BedMachineGreenland-v6.nc:${var} output=${var}
done

r.colors -a map=errbed color=haxby
r.colors map=mask color=haxby
r.mapcalc "mask_ice = if(mask == 2, 1, null())"

# Set the default region in PERMANENT from BedMachine surface at 200 m
g.mapset PERMANENT
g.region raster=surface@BedMachine res=200 -a -p
g.region -s

g.mapset BedMachine
g.region -dp
