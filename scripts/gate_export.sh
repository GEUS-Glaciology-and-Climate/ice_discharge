#!/usr/bin/env bash
# Gates

g.mapset gates_vel_buf

v.out.ogr input=gates_final output=./out/gates.kml format=KML --o
(cd out; zip gates.kmz gates.kml; rm gates.kml)
v.out.ogr input=gates_final output=./out/gates.gpkg format=GPKG --o
v.out.ogr input=gates_final output=./out/gates.geojson format=GeoJSON --o
