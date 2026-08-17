#!/usr/bin/env bash
# Imports the PROMICE-2022 Ice Mask (Luetzenburg et al. 2025)
#   doi:10.22008/FK2/O8CLRE
#
# Provides, in mapset PROMICE_2022:
#   mask_ice   raster, 1 = ice, null = not ice (nunataks cut out)
#   margin     line vector of the ice margin, with attribute
#              Termini = 'marine' | 'land' (841 marine, 836 land segments)
#
# NOTE this is an optical (Sentinel-2, August 2022) outline of the contiguous
# ice masses, so it covers grounded AND floating ice. BedMachine mask == 2,
# which this replaces in gate_IO.sh, was grounded ice only. Shelves are still
# excluded from gate placement there via the not_ice test (mask@BedMachine==3).
#
# Not yet used: `margin` is imported here ready for the marine/land gate work.
. "$(dirname "$0")/common.sh"

ROOT=${DATADIR}/PROMICE_2022_IceMask

MSG_OK "PROMICE-2022 Ice Mask"
g.mapset -c PROMICE_2022
g.region -d

# Ice extent. File 10 is the published raster: nunataks are already cut out and
# it is gridded on BedMachine's own 150 m grid, so no rasterisation choices are
# ours to make. The pipeline region is 200 m, so GRASS resamples on read; for a
# binary mask that is subsequently grown by 2 km this is not significant.
r.in.gdal input=${ROOT}/10-PROMICE-2022-IceMask-raster-150m.gpkg \
          output=mask_ice_150m --o
r.mapcalc "mask_ice = if(mask_ice_150m > 0, 1, null())" --o
r.colors map=mask_ice color=grey

# Ice margin as lines, carrying the marine/land terminus classification.
v.in.ogr input=${ROOT}/01-PROMICE-2022-IceMask-line.gpkg output=margin --o
