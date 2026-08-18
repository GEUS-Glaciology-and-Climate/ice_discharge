#!/usr/bin/env bash


# Create a new mapset for this specific velocity cutoff and buffer distance


g.mapset -c gates_vel_buf
g.region -d



# Two methods produce the gates. Both must emit the same three concentric
# rings - gates_inside (downstream reference), gates_maybe (THE GATE) and
# gates_outside (upstream reference) - because everything below, from the
# gates_x/gates_y flow-direction logic to raw2discharge.py, depends on them.
#
#   fastice  the published method: gates sit BUFFER_DIST inland of the edge
#            where fast-flowing ice meets not-ice. A pixel is only ever a gate
#            if it already flows faster than VELOCITY_CUTOFF.
#
#   marine   gates sit BUFFER_DIST upstream of the seaward edge of GROUNDED
#            ice, measured geodesically through the ice. No velocity condition
#            by default, so gates also exist on ice that is slow today but may
#            speed up later - the reason for the method.
#
# See dev/2026-08-mask/ for the prototype these were validated against.
GATE_METHOD=${GATE_METHOD:-fastice}
VEL_FLOOR=${VEL_FLOOR:-0}

if [ "${GATE_METHOD}" = "marine" ]; then

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
# because r.clump cannot serve that role here - without a fast_ice constraint
# the gates form a continuous ribbon and one clump spans several glaciers.
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

else

# From above:

# + [X] Find grounding line by finding edge cells where fast-moving ice borders water or ice shelf based (loosely) on the ice mask

# Ice extent is the PROMICE-2022 Ice Mask (was: BedMachine mask == 2). That is
# an August 2022 Sentinel-2 outline, so it is both grounded and floating ice,
# where BedMachine mask == 2 was grounded only. Shelves are still kept out of
# gate placement by the not_ice test below (mask@BedMachine == 3).

# The 2 km grow is retained from the BedMachine version, where it existed
# because that mask "doesn't always reach into each fjord all the way". The
# PROMICE mask tracks the true 2022 margin, so the grow is now doing only its
# other job: reaching out to the edge of the velocity data.


# Grow by 2 km (10 cells @ 200 m/cell)
r.grow input=mask_ice@PROMICE_2022 output=mask_ice_grow radius=10 new=1 --o
r.mask mask_ice_grow



# The fast ice edge is where there is fast-flowing ice overlapping with not-ice.


r.mapcalc "fast_ice = if(vel_baseline@MEaSUREs.0478 > ${VELOCITY_CUTOFF}, 1, null())" --o
r.mask -r

# no velocity data, or is flagged as ice shelf or land in BedMachine
r.mapcalc "not_ice = if(isnull(vel_baseline@MEaSUREs.0478) ||| (mask@BedMachine == 0) ||| (mask@BedMachine == 3), 1, null())" --o

r.grow input=not_ice output=not_ice_grow radius=1.5 new=99 --o
r.mapcalc "fast_ice_edge = if(((not_ice_grow == 99) && (fast_ice == 1)), 1, null())" --o



# The gates are set ${BUFFER_DIST} inland from the fast ice edge. This is done by buffering the fast ice edge (which fills the space between the fast ice edge and buffer extent) and then growing the buffer by 1. This last step defines the gate locations.

# However, in order to properly estimate discharge, the gate location is not enough. Ice must flow from outside the gates, through the gates, to inside the gates, and not flow from one gate pixel to another gate pixel (or it would be counted 2x).


r.buffer input=fast_ice_edge output=fast_ice_buffer distances=${BUFFER_DIST} --o
r.grow input=fast_ice_buffer output=fast_ice_buffer_grow radius=1.5 new=99 --o
r.mask -i not_ice --o
r.mapcalc "gates_inside = if(((fast_ice_buffer_grow == 99) && (fast_ice == 1)), 1, null())" --o
r.mask -r

r.grow input=gates_inside output=gates_inside_grow radius=1.1 new=99 --o
r.mask -i not_ice --o
r.mapcalc "gates_maybe = if(((gates_inside_grow == 99) && (fast_ice == 1) && isnull(fast_ice_buffer)), 1, null())" --o
r.mask -r

r.grow input=gates_maybe output=gates_maybe_grow radius=1.1 new=99 --o
r.mask -i not_ice --o
r.mapcalc "gates_outside = if(((gates_maybe_grow == 99) && (fast_ice == 1) && isnull(fast_ice_buffer) && isnull(gates_inside)), 1, null())" --o
r.mask -r

fi

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

# Gate identity.
#
# fastice: one gate per connected cluster, which works because the fast_ice
# constraint already breaks the gates into one curtain per outlet.
#
# marine: connectivity is NOT a usable identity. Without a fast_ice constraint
# the gates form a continuous ribbon along the coast, so a single cluster spans
# several glaciers - measured at up to 8 in the Upernavik prototype. The gate
# is instead the marine-terminating glacier it belongs to, via the MTG_ID
# propagated from the margin/grounding-line source. A gate is then one glacier
# rather than one blob, which is also what makes the discharge attributable.
#
# int() is not cosmetic: MTG_ID is a double in the PROMICE margin table, so
# v.to.rast and r.patch carry it through as DCELL and gate IDs would come out
# as 242.0 rather than 242 in the per-pixel export.
if [ "${GATE_METHOD}" = "marine" ]; then
    r.mapcalc "gates_gateID = if(!isnull(gates_xy_clean0), int(src_mtg), null())" --o
else
    g.copy raster=gates_clump,gates_gateID --o
fi

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

# Gate ID

# db.droptable -f table=gates_final
# db.droptable -f table=gates_final_pts

# areas (clusters of gate pixels, but diagonals are separate)
r.to.vect input=gates_final output=gates_final type=area --o
v.db.dropcolumn map=gates_final column=label
v.db.dropcolumn map=gates_final column=value
v.db.addcolumn map=gates_final columns="gate INT"
v.what.rast map=gates_final raster=gates_gateID column=gate type=centroid

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

v.out.ogr input=gates_final output=./tmp/gates_final_${VELOCITY_CUTOFF}_${BUFFER_DIST}.kml format=KML --o
# open ./tmp/gates_final_${VELOCITY_CUTOFF}_${BUFFER_DIST}.kml
