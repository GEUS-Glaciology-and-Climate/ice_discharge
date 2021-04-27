#!/usr/bin/env bash


# Create a new mapset for this specific velocity cutoff and buffer distance


# [[file:ice_discharge.org::*Algorithm][Algorithm:2]]
g.mapset -c gates_${VELOCITY_CUTOFF}_${BUFFER_DIST}
g.region -d
# Algorithm:2 ends here



# From above:

# + [X] Find grounding line by finding edge cells where fast-moving ice borders water or ice shelf based (loosely) on BedMachine mask

# The "loosely" is because the BedMachine mask doesn't always reach into each fjord all the way. I buffer the BedMachine mask by 2 km here so that it extends to the edge of the velocity data.


# [[file:ice_discharge.org::*Algorithm][Algorithm:3]]
g.copy raster=mask_ice@BedMachine,mask_ice --o
# Grow by 2 km (10 cells @ 200 m/cell)
r.grow input=mask_ice output=mask_ice_grow radius=10 new=1 --o
r.mask mask_ice_grow
# Algorithm:3 ends here



# The fast ice edge is where there is fast-flowing ice overlapping with not-ice.


# [[file:ice_discharge.org::*Algorithm][Algorithm:4]]
r.mapcalc "fast_ice = if(vel_baseline@MEaSUREs.0478 > ${VELOCITY_CUTOFF}, 1, null())" --o
r.mask -r

# no velocity data, or is flagged as ice shelf or land in BedMachine
r.mapcalc "not_ice = if(isnull(vel_baseline@MEaSUREs.0478) ||| (mask@BedMachine == 0) ||| (mask@BedMachine == 3), 1, null())" --o

r.grow input=not_ice output=not_ice_grow radius=1.5 new=99 --o
r.mapcalc "fast_ice_edge = if(((not_ice_grow == 99) && (fast_ice == 1)), 1, null())" --o
# Algorithm:4 ends here



# The gates are set ${BUFFER_DIST} inland from the fast ice edge. This is done by buffering the fast ice edge (which fills the space between the fast ice edge and buffer extent) and then growing the buffer by 1. This last step defines the gate locations.

# However, in order to properly estimate discharge, the gate location is not enough. Ice must flow from outside the gates, through the gates, to inside the gates, and not flow from one gate pixel to another gate pixel (or it would be counted 2x). 


# [[file:ice_discharge.org::*Algorithm][Algorithm:5]]
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

r.mapcalc "gates_IO = 0" --o
r.mapcalc "gates_IO = if(isnull(gates_inside), gates_IO, 1)" --o
r.mapcalc "gates_IO = if(isnull(gates_outside), gates_IO, -1)" --o

r.colors map=gates_inside color=red
r.colors map=gates_maybe color=grey
r.colors map=gates_outside color=blue
r.colors map=gates_IO color=viridis
# Algorithm:5 ends here



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


# [[file:ice_discharge.org::*Algorithm][Algorithm:6]]
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
# Algorithm:6 ends here

# Subset to where there is known discharge

# [[file:ice_discharge.org::*Subset to where there is known discharge][Subset to where there is known discharge:1]]
r.mapcalc "gates_xy_clean0 = if((gates_x == 1) || (gates_y == 1), 1, null())" --o
# Subset to where there is known discharge:1 ends here

# Remove small areas (clusters <X cells)

# [[file:ice_discharge.org::*Remove small areas (clusters <X cells)][Remove small areas (clusters <X cells):1]]
# Remove clusters of 2 or less. How many hectares in X pixels?
# frink "(200 m)^2 * 2 -> hectares" # ans: 8.0

r.clump -d input=gates_xy_clean0 output=gates_gateID --o
r.reclass.area -d input=gates_gateID output=gates_area value=9 mode=lesser method=reclass --o

r.mapcalc "gates_xy_clean1 = if(isnull(gates_area), gates_xy_clean0, null())" --o
# Remove small areas (clusters <X cells):1 ends here

# Limit to Mouginot 2019 mask
# + Actually, limit to approximate Mouginot 2019 mask - its a bit narrow in some places

# [[file:ice_discharge.org::*Limit to Mouginot 2019 mask][Limit to Mouginot 2019 mask:1]]
# r.mask mask_GIC@Mouginot_2019 --o
r.grow input=mask_GIC@Mouginot_2019 output=mask_GIC_Mouginot_2019_grow radius=4.5 # three cells
r.mask mask_GIC_Mouginot_2019_grow --o
r.mapcalc "gates_xy_clean2 = gates_xy_clean1" --o
r.mask -r

# r.univar map=gates_xy_clean1
# r.univar map=gates_xy_clean2
# Limit to Mouginot 2019 mask:1 ends here

# Remove gates in areas from manually-drawn KML mask
# + See [[./dat/remove_gates_manual.kml]]

# [[file:ice_discharge.org::*Remove gates in areas from manually-drawn KML mask][Remove gates in areas from manually-drawn KML mask:1]]
v.import input=./dat/remove_gates_manual.kml output=remove_gates_manual --o
r.mask -i vector=remove_gates_manual --o
r.mapcalc "gates_xy_clean3 = gates_xy_clean2" --o
r.mask -r

r.univar map=gates_xy_clean2
r.univar map=gates_xy_clean3
# Remove gates in areas from manually-drawn KML mask:1 ends here

# Final Gates

# [[file:ice_discharge.org::*Final Gates][Final Gates:1]]
g.copy "gates_xy_clean3,gates_final" --o
# Final Gates:1 ends here

# Gate ID

# [[file:ice_discharge.org::*Gate ID][Gate ID:1]]
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
# Gate ID:1 ends here

# Mean x,y

# [[file:ice_discharge.org::*Mean x,y][Mean x,y:1]]
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
# Mean x,y:1 ends here

# Mean lon,lat

# [[file:ice_discharge.org::*Mean lon,lat][Mean lon,lat:1]]
v.what.rast map=gates_final_pts raster=lon@PERMANENT column=lon
v.what.rast map=gates_final_pts raster=lat@PERMANENT column=lat

v.db.addcolumn map=gates_final columns="mean_lon DOUBLE PRECISION, mean_lat DOUBLE PRECISION"
for G in $(db.select -c sql="select gate from gates_final"|sort -n|uniq); do
    db.execute sql="UPDATE gates_final SET mean_lon=(SELECT lon FROM gates_final_pts WHERE gate = ${G}) where gate = ${G}"
    db.execute sql="UPDATE gates_final SET mean_lat=(SELECT lat FROM gates_final_pts WHERE gate = ${G}) where gate = ${G}"
done
# Mean lon,lat:1 ends here

# Sector, Region, Names, etc.
# + Sector Number
# + Region Code
# + Nearest Sector or Glacier Name

# [[file:ice_discharge.org::*Sector, Region, Names, etc.][Sector, Region, Names, etc.:1]]
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

v.db.addcolumn map=gates_final columns="n_pixels INT"
v.db.addcolumn map=gates_final_pts columns="n_pixels INT"
for G in $(db.select -c sql="select gate from gates_final"|sort -n|uniq); do
    db.execute sql="UPDATE gates_final SET n_pixels=(SELECT SUM(area)/(200*200) FROM gates_final WHERE gate = ${G}) where gate = ${G}"
    # now copy that to the average gate location (point) table
    db.execute sql="UPDATE gates_final_pts SET n_pixels = (SELECT n_pixels FROM gates_final WHERE gate = ${G}) WHERE gate = ${G}"
done
# Sector, Region, Names, etc.:1 ends here

# Clean up

# [[file:ice_discharge.org::*Clean up][Clean up:1]]
db.dropcolumn -f table=gates_final column=area
# db.dropcolumn -f table=gates_final column=cat
# Clean up:1 ends here

# Export as metadata CSV

# [[file:ice_discharge.org::*Export as metadata CSV][Export as metadata CSV:1]]
mkdir -p out
db.select sql="SELECT gate,mean_x,mean_y,lon,lat,n_pixels,sector,region,Bjork_2015,Mouginot_2019,Zwally_2012 from gates_final_pts" separator=, | sort -n | uniq  > ./out/gate_meta.csv
# Export as metadata CSV:1 ends here

# Export Gates to KML                                            :noexport:

# [[file:ice_discharge.org::*Export Gates to KML][Export Gates to KML:1]]
v.out.ogr input=gates_final output=./tmp/gates_final_${VELOCITY_CUTOFF}_${BUFFER_DIST}.kml format=KML --o
# open ./tmp/gates_final_${VELOCITY_CUTOFF}_${BUFFER_DIST}.kml
# Export Gates to KML:1 ends here
