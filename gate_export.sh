#!/usr/bin/env bash
# Gates

# [[file:ice_discharge.org::*Gates][Gates:1]]
g.mapset gates_100_5000

v.out.ogr input=gates_final output=./out/gates.kml format=KML --o
(cd out; zip gates.kmz gates.kml; rm gates.kml)
v.out.ogr input=gates_final output=./out/gates.gpkg format=GPKG --o
v.out.ogr input=gates_final output=./out/gates.geojson format=GeoJSON --o
# Gates:1 ends here
