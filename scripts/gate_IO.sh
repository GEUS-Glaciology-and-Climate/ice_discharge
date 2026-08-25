#!/usr/bin/env bash


# Create a new mapset for this specific buffer distance


g.mapset -c gates_vel_buf
g.region -d



# Gates sit BUFFER_DIST upstream of the seaward edge of GROUNDED ice, measured
# geodesically through the ice. There is no velocity condition by default, so
# gates also exist on ice that is slow today but may speed up later - which is
# the reason for the method.
#
# This replaces the previous "fast ice" method, which placed gates BUFFER_DIST
# inland of the edge where fast-flowing ice met not-ice and only ever made a
# pixel a gate if it already flowed faster than a velocity cutoff. That method
# conflated "no velocity data" with "not ice", which is why it needed
# dat/remove_gates_manual.kml to delete the gates it got wrong.
#
# The construction produces three concentric rings - gates_inside (downstream
# reference), gates_maybe (THE GATE) and gates_outside (upstream reference) -
# because everything below, from the gates_x/gates_y flow-direction logic to
# raw2discharge.py, depends on them.
#
# See dev/2026-08-mask/ for the prototype this was validated against.
VEL_FLOOR=${VEL_FLOOR:-0}


# The datum is the seaward edge of grounded ice: the PROMICE-2022 marine
# margin, except where a floating tongue intervenes, where it is the grounding
# line. No special-casing is needed - removing the tongues from the cost
# surface is enough. Where there is no tongue the marine margin already IS that
# edge; where there is one, the calving front leaves the cost surface and
# cannot seed anything, so the grounding line becomes the nearest source.
# Otherwise the gate would measure flux that has already crossed the grounding
# line, which is not the sea-level-relevant quantity.
v.import input=./dat/floating_ice.gpkg output=tongues --o
v.to.rast input=tongues output=tongue use=attr attribute_column=MTG_ID --o

# Grounding line = grounded cells touching a tongue. r.grow without `new`
# writes the value of the nearest input cell, so these inherit the tongue's
# MTG_ID, which is what lets a gate there be attributed to the right glacier.
r.grow input=tongue output=tongue_grow radius=1.5 --o
r.mapcalc "grounding_line = if(!isnull(tongue_grow) && isnull(tongue) \
                               && !isnull(mask_ice@PROMICE_2022), tongue_grow, null())" --o

v.extract input=margin@PROMICE_2022 where="Termini='marine'" output=margin_marine --o
v.to.rast input=margin_marine output=margin_marine use=attr attribute_column=MTG_ID --o
r.mapcalc "margin_grounded = if(isnull(tongue), margin_marine, null())" --o
r.patch input=margin_grounded,grounding_line output=gate_source --o

# Gate substrate. Tongues are excluded here as well as from the cost surface
# below - excluding them from the cost surface alone is NOT enough, because
# dist is then null over a tongue and r.grow expands the buffer into it, so
# gates would still form on floating ice.
#
# VEL_FLOOR, if used, is applied to gate SELECTION only, never to the cost
# surface: putting it there would let slow patches block propagation and
# corrupt the distance field.
if [ "${VEL_FLOOR}" = "0" ]; then
    r.mapcalc "gate_substrate = if(!isnull(mask_ice@PROMICE_2022) && isnull(tongue), 1, null())" --o
else
    r.mapcalc "gate_substrate = if(!isnull(mask_ice@PROMICE_2022) && isnull(tongue) \
                                   && vel_baseline@MEaSUREs.0478 >= ${VEL_FLOOR}, 1, null())" --o
fi

# Geodesic distance through grounded ice. Euclidean distance would cut across
# fjord mouths and put "BUFFER_DIST inland" in the wrong place; measured
# through the ice a gate 5 km upstream can be only ~3 km straight-line.
#
# The cost cell value must be the RESOLUTION, not 1: r.cost charges the cell
# value per cell step, so cost=1 accumulates a count of cells, not metres.
r.mapcalc "cost = if((!isnull(mask_ice@PROMICE_2022) ||| !isnull(margin_marine)) \
                     && isnull(tongue), nsres(), null())" --o
r.cost input=cost output=dist start_raster=gate_source --o

# Glacier identity for every cell: the MTG_ID of the nearest source, be that a
# marine margin segment or a grounding line. Used for gate IDs further down,
# because r.clump cannot serve that role here - with no velocity condition the
# gates form a continuous ribbon and one clump spans several glaciers.
r.grow.distance input=gate_source distance=src_dist value=src_mtg --o

r.mapcalc "margin_buffer = if(dist < ${BUFFER_DIST}, 1, null())" --o
r.grow input=margin_buffer output=margin_buffer_grow radius=1.5 new=99 --o

r.mask gate_substrate --o
r.mapcalc "gates_inside = if(margin_buffer_grow == 99, 1, null())" --o
r.grow input=gates_inside output=gates_inside_grow radius=1.1 new=99 --o
r.mapcalc "gates_maybe = if((gates_inside_grow == 99) && isnull(margin_buffer), 1, null())" --o
r.grow input=gates_maybe output=gates_maybe_grow radius=1.1 new=99 --o
r.mapcalc "gates_outside = if((gates_maybe_grow == 99) && isnull(margin_buffer) \
                              && isnull(gates_inside), 1, null())" --o
r.mask -r


r.mapcalc "gates_IO = 0" --o
r.mapcalc "gates_IO = if(isnull(gates_inside), gates_IO, 1)" --o
r.mapcalc "gates_IO = if(isnull(gates_outside), gates_IO, -1)" --o

r.colors map=gates_inside color=red
r.colors map=gates_maybe color=grey
r.colors map=gates_outside color=blue
r.colors map=gates_IO color=viridis



# + For each gate, split into two for the vector components of the velocity, then...
# + If flow is from gate to INSIDE, it is discharged
# + If flow is from gate to GATE, it is ignored
# + If flow is from gate to NOT(GATE || INSIDE) it is ignored
#   + If gates are a closed loop, such as the 1700 m flight-line, then
#     this scenario would be NEGATIVE discharge, not ignored. This was
#     tested with the 1700 m flight-line and compared against both the
#     vector calculations and WIC estimates.

# #+NAME: tbl_velocity
# | var            | value  | meaning           |
# |----------------+--------+-------------------|
# | vx             | > 0    | east / right      |
# | vx             | < 0    | west / left       |
# | vy             | > 0    | north / up        |
# | vy             | < 0    | south / down      |
# |----------------+--------+-------------------|
# | GRASS indexing | [0,1]  | cell to the right |
# |                | [0,-1] | left              |
# |                | [-1,0] | above             |
# |                | [1,0]  | below             |


# g.mapset -c gates_50_2500

r.mask -r

r.mapcalc "gates_x = 0" --o
r.mapcalc "gates_x = if((gates_maybe == 1) && (vx_baseline@MEaSUREs.0478 > 0), gates_IO[0,1], gates_x)" --o
r.mapcalc "gates_x = if((gates_maybe != 0) && (vx_baseline@MEaSUREs.0478 < 0), gates_IO[0,-1], gates_x)" --o

r.mapcalc "gates_y = 0" --o
r.mapcalc "gates_y = if((gates_maybe != 0) && (vy_baseline@MEaSUREs.0478 > 0), gates_IO[-1,0], gates_y)" --o
r.mapcalc "gates_y = if((gates_maybe != 0) && (vy_baseline@MEaSUREs.0478 < 0), gates_IO[1,0], gates_y)" --o

r.mapcalc "gates_x = if(gates_x == 1, 1, 0)" --o
r.mapcalc "gates_y = if(gates_y == 1, 1, 0)" --o

r.null map=gates_x null=0 # OR r.null map=gates_x setnull=0
r.null map=gates_y null=0 # OR r.null map=gates_y setnull=0

# Subset to where there is known discharge

r.mapcalc "gates_xy_clean00 = if((gates_x == 1) || (gates_y == 1), 1, null())" --o
r.mapcalc "gates_xy_clean0 = if(!isnull(gates_xy_clean00) && !isnull(DEM_2019@DEM), 1, null())" --o

# Remove small areas (clusters <X cells)

# Remove clusters of 2 or less. How many hectares in X pixels?
# frink "(200 m)^2 * 2 -> hectares" # ans: 8.0

r.clump -d input=gates_xy_clean0 output=gates_clump --o
r.reclass.area -d input=gates_clump output=gates_area value=9 mode=lesser method=reclass --o

if [ -n "$(g.list type=raster pattern=gates_area)" ]; then
    r.mapcalc "gates_xy_clean1 = if(isnull(gates_area), gates_xy_clean0, null())" --o
else
    g.copy raster=gates_xy_clean0,gates_xy_clean1 --o
fi

# Gate identity is the marine-terminating glacier, via the MTG_ID propagated
# from the margin/grounding-line source - NOT connectivity. The gates form a
# continuous ribbon along the coast, so a single r.clump cluster spans several
# glaciers (up to 8 in the Upernavik prototype). A gate is therefore one
# glacier rather than one blob, which is also what makes discharge
# attributable. r.clump is still used above, but only to size-filter.
#
# int() is not cosmetic: MTG_ID is a double in the PROMICE margin table, so
# v.to.rast and r.patch carry it through as DCELL and gate IDs would come out
# as 242.0 rather than 242 in the per-pixel export.
r.mapcalc "gates_gateID = if(!isnull(gates_xy_clean0), int(src_mtg), null())" --o

# Limit to Mouginot 2019 mask
# + Actually, limit to approximate Mouginot 2019 mask - its a bit narrow in some places

# r.mask mask_GIC@Mouginot_2019 --o
r.grow input=mask_GIC@Mouginot_2019 output=mask_GIC_Mouginot_2019_grow radius=4.5 # three cells
r.mask mask_GIC_Mouginot_2019_grow --o
r.mapcalc "gates_xy_clean2 = gates_xy_clean1" --o
r.mask -r

# r.univar map=gates_xy_clean1
# r.univar map=gates_xy_clean2

# Remove gates in areas from manually-drawn KML mask
# + See [[./dat/remove_gates_manual.kml]]

v.import input=./dat/remove_gates_manual.kml output=remove_gates_manual --o
r.mask -i vector=remove_gates_manual --o
r.mapcalc "gates_xy_clean3 = gates_xy_clean2" --o
r.mask -r

r.univar map=gates_xy_clean2
r.univar map=gates_xy_clean3

# Final Gates

g.copy "gates_xy_clean3,gates_final" --o

# Drop gates that the export will not carry any pixels for.
#
# export.sh builds its MASK as
#   if(gates_final) | if(mask_GIC) | if(vel_err_baseline) | if(DEM_2020)
# and r.mapcalc's `|` PROPAGATES NULLS - verified: with a and b non-null over
# disjoint halves of a region, `if(a) | if(b)` yields zero non-null cells,
# while `|||` and `!isnull()` yield all of them. So despite reading as an OR
# that expression is an AND: a pixel is exported only where all four are
# non-null. That is load-bearing - it is why the export is thousands of rows
# and not the whole ice sheet - so it must not be "fixed".
#
# The consequence is that a gate lying outside mask_GIC (gates are clipped to
# mask_GIC GROWN by 4.5 cells, so a gate can sit just beyond the ungrown mask),
# or where vel_err_baseline or DEM_2020 have no data, gets no exported pixels
# at all. It therefore has no discharge, yet still reached gate_meta.csv,
# leaving that file with more gates than gate_D.csv and csv2nc.py failing on
# "conflicting sizes for dimension 'gate'" (668 vs 664).
#
# A gate with no data is not a gate. Apply the same three conditions here so
# gates_final, and everything derived from it, matches what is exported.
r.mapcalc "gates_final = if(!isnull(gates_final) \
                            && !isnull(mask_GIC@Mouginot_2019) \
                            && !isnull(vel_err_baseline@MEaSUREs.0478) \
                            && !isnull(DEM_2020@DEM), gates_final, null())" --o

# gates_gateID, gates_x and gates_y are all assigned above from state that
# predates the small-cluster filter, the Mouginot clip and the manual KML.
# Every one of them has to be brought back in line with gates_final:
#
#   gates_gateID  otherwise keeps IDs for glaciers whose pixels were all
#                 removed, so the per-pixel export carries more gates than
#                 gate_meta.csv and csv2nc.py dies with "conflicting sizes for
#                 dimension 'gate'" (664 vs 652 on the first full run).
#
#   gates_x/y     otherwise still mark those removed pixels as gates, so
#                 vel_eff.sh gives them a non-zero effective velocity and they
#                 keep contributing discharge. raw2discharge.py cannot name
#                 them - their gate is not in gate_meta.csv - so it files them
#                 under the empty sector name '', producing a nameless sector
#                 column and leaving the ice-sheet total slightly larger than
#                 the sum of its sectors.
#
# Clipping a gate away has to remove its discharge, not just its label.
r.mapcalc "gates_gateID = if(!isnull(gates_final), gates_gateID, null())" --o
r.mapcalc "gates_x = if(!isnull(gates_final), gates_x, 0)" --o
r.mapcalc "gates_y = if(!isnull(gates_final), gates_y, 0)" --o

# Gate ID

# db.droptable -f table=gates_final
# db.droptable -f table=gates_final_pts

# Vectorise gates_gateID, NOT the binary gates_final.
#
# gates_final is 1-or-null, so r.to.vect on it builds areas from connected
# blobs and v.what.rast type=centroid then stamps ONE gate id per blob, taken
# at its centroid. With gates forming a continuous ribbon a blob spans several
# glaciers, so every glacier in that blob except the one under the centroid
# vanishes from the vector table - while the raster, and therefore gate_D.csv,
# still carries them. That is the 652-vs-664 mismatch csv2nc.py died on: the
# same "connectivity is not identity" problem already fixed for gates_gateID,
# surviving here in the vector path.
#
# gates_gateID is categorical, so its areas are contiguous AND single-valued:
# `value` is the gate, no centroid sampling required, and every gate in the
# raster is guaranteed at least one area.
r.to.vect input=gates_gateID output=gates_final type=area --o
v.db.dropcolumn map=gates_final column=label
v.db.addcolumn map=gates_final columns="gate INT"
v.db.update map=gates_final column=gate query_column=value
v.db.dropcolumn map=gates_final column=value

# # points (each individual gate pixel)
# r.to.vect input=gates_final output=gates_final_pts type=point --o
# v.db.dropcolumn map=gates_final_pts column=label
# v.db.dropcolumn map=gates_final_pts column=value
# v.db.addcolumn map=gates_final_pts columns="gate INT"
# v.what.rast map=gates_final_pts raster=gates_gateID column=gate type=point

# Mean x,y

# v.db.addcolumn map=gates_final columns="x DOUBLE PRECSION, y DOUBLE PRECISION, mean_x INT, mean_y INT, area INT"
v.db.addcolumn map=gates_final columns="mean_x INT, mean_y INT"
v.to.db map=gates_final option=coor columns=x,y units=meters
v.to.db map=gates_final option=area columns=area units=meters

for G in $(db.select -c sql="select gate from gates_final"|sort -n|uniq); do
  db.execute sql="UPDATE gates_final SET mean_x=(SELECT AVG(x) FROM gates_final WHERE gate == ${G}) where gate == ${G}"
  db.execute sql="UPDATE gates_final SET mean_y=(SELECT AVG(y) FROM gates_final WHERE gate == ${G}) where gate == ${G}"
done

v.out.ascii -c input=gates_final columns=gate,mean_x,mean_y | cut -d"|" -f4- | sort -n|uniq | v.in.ascii input=- output=gates_final_pts skip=1 cat=1 x=2 y=3 --o
v.db.addtable gates_final_pts
v.db.addcolumn map=gates_final_pts columns="gate INT"
v.db.update map=gates_final_pts column=gate query_column=cat

#v.db.addcolumn map=gates_final_pts columns="mean_x INT, mean_y INT"
v.to.db map=gates_final_pts option=coor columns=mean_x,mean_y units=meters

# Mean lon,lat

v.what.rast map=gates_final_pts raster=lon@PERMANENT column=lon
v.what.rast map=gates_final_pts raster=lat@PERMANENT column=lat

v.db.addcolumn map=gates_final columns="mean_lon DOUBLE PRECISION, mean_lat DOUBLE PRECISION"
for G in $(db.select -c sql="select gate from gates_final"|sort -n|uniq); do
    db.execute sql="UPDATE gates_final SET mean_lon=(SELECT lon FROM gates_final_pts WHERE gate = ${G}) where gate = ${G}"
    db.execute sql="UPDATE gates_final SET mean_lat=(SELECT lat FROM gates_final_pts WHERE gate = ${G}) where gate = ${G}"
done

# Sector, Region, Names, etc.
# + Sector Number
# + Region Code
# + Nearest Sector or Glacier Name

v.db.addcolumn map=gates_final columns="sector INT"
v.db.addcolumn map=gates_final_pts columns="sector INT"
v.distance from=gates_final to=sectors@Mouginot_2019 upload=to_attr column=sector to_column=cat
v.distance from=gates_final_pts to=sectors@Mouginot_2019 upload=to_attr column=sector to_column=cat

v.db.addcolumn map=gates_final columns="region VARCHAR(2)"
v.db.addcolumn map=gates_final_pts columns="region VARCHAR(2)"
v.distance from=gates_final to=sectors@Mouginot_2019 upload=to_attr column=region to_column=SUBREGION1
v.distance from=gates_final_pts to=sectors@Mouginot_2019 upload=to_attr column=region to_column=SUBREGION1

v.db.addcolumn map=gates_final columns="Mouginot_2019 VARCHAR(99)"
v.db.addcolumn map=gates_final_pts columns="Mouginot_2019 VARCHAR(99)"
v.distance from=gates_final to=sectors@Mouginot_2019 upload=to_attr column=Mouginot_2019 to_column=NAME
v.distance from=gates_final_pts to=sectors@Mouginot_2019 upload=to_attr column=Mouginot_2019 to_column=NAME

v.db.addcolumn map=gates_final columns="Bjork_2015 VARCHAR(99)"
v.db.addcolumn map=gates_final_pts columns="Bjork_2015 VARCHAR(99)"
v.distance from=gates_final to=names@Bjork_2015 upload=to_attr column=Bjork_2015 to_column=name
v.distance from=gates_final_pts to=names@Bjork_2015 upload=to_attr column=Bjork_2015 to_column=name

v.db.addcolumn map=gates_final columns="Zwally_2012 INT"
v.db.addcolumn map=gates_final_pts columns="Zwally_2012 INT"
v.distance from=gates_final to=Zwally_2012@Zwally_2012 upload=to_attr column=Zwally_2012 to_column=cat_
v.distance from=gates_final_pts to=Zwally_2012@Zwally_2012 upload=to_attr column=Zwally_2012 to_column=cat_

v.db.addcolumn map=gates_final columns="Moon_2008 INT"
v.db.addcolumn map=gates_final_pts columns="Moon_2008 INT"
v.distance from=gates_final to=GlacierIDs@NSIDC_0642 upload=to_attr column=Moon_2008 to_column=GlacierID
v.distance from=gates_final_pts to=GlacierIDs@NSIDC_0642 upload=to_attr column=Moon_2008 to_column=GlacierID

v.db.addcolumn map=gates_final columns="Moon_2008_dist INT"
v.db.addcolumn map=gates_final_pts columns="Moon_2008_dist INT"
v.distance from=gates_final to=GlacierIDs@NSIDC_0642 upload=dist column=Moon_2008_dist
v.distance from=gates_final_pts to=GlacierIDs@NSIDC_0642 upload=dist column=Moon_2008_dist

v.db.addcolumn map=gates_final columns="n_pixels INT"
v.db.addcolumn map=gates_final_pts columns="n_pixels INT"
for G in $(db.select -c sql="select gate from gates_final"|sort -n|uniq); do
    db.execute sql="UPDATE gates_final SET n_pixels=(SELECT SUM(area)/(200*200) FROM gates_final WHERE gate = ${G}) where gate = ${G}"
    # now copy that to the average gate location (point) table
    db.execute sql="UPDATE gates_final_pts SET n_pixels = (SELECT n_pixels FROM gates_final WHERE gate = ${G}) WHERE gate = ${G}"
done

# Clean up

[ -n "$(g.list type=vector pattern=gates_final)" ] && db.dropcolumn -f table=gates_final column=area
# db.dropcolumn -f table=gates_final column=cat

# Export as metadata CSV

mkdir -p out
db.select sql="SELECT gate,mean_x,mean_y,lon,lat,n_pixels,sector,region,Bjork_2015,Mouginot_2019,Zwally_2012,Moon_2008,Moon_2008_dist from gates_final_pts" separator=, | sort -n | uniq  > ./out/gate_meta.csv

# Export Gates to KML                                            :noexport:

v.out.ogr input=gates_final output=./tmp/gates_final_${BUFFER_DIST}.kml format=KML --o
# open ./tmp/gates_final_${BUFFER_DIST}.kml
