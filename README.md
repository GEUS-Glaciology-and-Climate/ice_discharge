# Greenland Ice Sheet solid ice discharge from 1986 through last month

This is the source for "Greenland Ice Sheet solid ice discharge from 1986 through March 2020" and previous and subsequent versions.

- Paper: [doi:10.5194/essd-12-1367-2020](https://doi.org/10.5194/essd-12-1367-2020)
  - Paper V1: [doi:10.5194/essd-11-769-2019](https://doi.org/10.5194/essd-11-769-2019)
- Data: [doi:10.22008/promice/data/ice_discharge](https://doi.org/10.22008/promice/data/ice_discharge)
- Code (latest): https://github.com/GEUS-PROMICE/ice_discharge
  - Source V2: https://github.com/GEUS-PROMICE/ice_discharge/tree/10.5194/essd-12-1367-2020
  - Source V1: https://github.com/GEUS-PROMICE/ice_discharge/tree/10.5194/essd-11-769-2019
- [Issues](https://github.com/GEUS-PROMICE/ice_discharge/issues) are used to collect suggested improvements, problems that made it through review, and mention of similar papers published since acceptance. The work may be under active development, including updating data and tables.
  - This [diff](https://github.com/mankoff/ice_discharge/compare/10.5194/essd-12-1367-2020...main) shows changes between the latest version (V2) of the paper and the current development version.
  - Major changes post-publication are tagged [major_change](https://github.com/GEUS-PROMICE/ice_discharge/issues?q=label%3Amajor_change).

> [!WARNING]
> Before using the data you should check for any open/active issues tagged [WARNING](https://github.com/GEUS-Glaciology-and-Climate/ice_discharge/labels/WARNING).

---

## Workflow

All scripts live in `scripts/` and are controlled by `Makefile`. Run `make help` to list available targets.

### Requirements

- `$DATADIR` must be set to the path containing all raw input data (~100 GB of velocity products and ancillary datasets — not included in this repository)
- [Docker](https://www.docker.com/) must be available; the workflow uses two containers:
  - `mankoff/ice_discharge:grass` — all GRASS GIS / bash operations
  - `mankoff/ice_discharge:conda` — all Python operations
- Pull the containers with `make docker`

### Running the full pipeline

```bash
export DATADIR=/path/to/data
make docker      # pull Docker images
make import      # import all data into GRASS
make gates       # find flux gates
make velocity    # compute effective velocity at each gate
make export      # export pixel-level data from GRASS to CSV
make errors      # estimate discharge errors
make output      # compute discharge and write NetCDF
make figures     # produce figures
```

Or run everything in one go:

```bash
make all
```

### Operational update (new Sentinel-1 data)

```bash
make update
```

This checks for new PROMICE/MEaSUREs data, reprocesses, and uploads results to Thredds and GEUS Dataverse.

---

### Pipeline stages

#### Stage 1 — Import (`scripts/import.sh`)

Builds a GRASS GIS database (`G/`) in EPSG:3413 (polar stereographic) with one mapset per data source:

| Input dataset | Content | Reference |
|---|---|---|
| BedMachine | Ice mask, surface elevation, ice thickness, bed elevation, bed error | [Morlighem et al. 2017](https://doi.org/10.1002/2017GL074954) · data: [doi:10.5067/6B6B225B8V2D](https://doi.org/10.5067/6B6B225B8V2D) ([NSIDC IDBMG4](https://nsidc.org/data/idbmg4)) |
| Mouginot 2019 | Sector and region polygon boundaries (7 regions of Greenland) | [Mouginot & Rignot 2019](https://doi.org/10.7280/D1WT11) ([UCI DASH](https://dash.lib.uci.edu/stash/dataset/doi:10.7280/D1WT11)) |
| Zwally 2012 | Alternate drainage basin sectors | Zwally et al. 2012, [Antarctic and Greenland Drainage Systems](http://icesat4.gsfc.nasa.gov/cryo_data/ant_grn_drainage_systems.php) (GSFC Cryospheric Sciences Lab) |
| MEaSUREs 0478 | Annual velocity mosaics 200 m/500 m (~2000–present) | [Joughin et al. 2010](https://doi.org/10.3189/002214310792447734) · data: [doi:10.5067/OC7B04ZM9G6Q](https://doi.org/10.5067/OC7B04ZM9G6Q) ([NSIDC-0478](https://nsidc.org/data/nsidc-0478)) |
| MEaSUREs 0481 | TSX/TDX ~12-day scenes at high resolution | [NSIDC-0481](https://nsidc.org/data/nsidc-0481) — MEaSUREs Greenland Ice Velocity: Selected Glacier Site Velocity Maps from InSAR |
| MEaSUREs 0646 | Monthly mosaics 1985–2018 | Howat 2017, data: [doi:10.5067/VM5DZ20MYF5C](https://doi.org/10.5067/VM5DZ20MYF5C) ([NSIDC-0646](https://nsidc.org/data/nsidc-0646)) |
| MEaSUREs 0731 | Annual mosaics | [Joughin et al. 2018](https://doi.org/10.5194/tc-12-2211-2018) · data: [doi:10.5067/OPFQ9QDEUFFY](https://doi.org/10.5067/OPFQ9QDEUFFY) ([NSIDC-0731](https://nsidc.org/data/nsidc-0731)) |
| MEaSUREs 0766 | Most recent mosaics (manually updated) | [NSIDC-0766](https://nsidc.org/data/nsidc-0766) — MEaSUREs Greenland 6- and 12-day Ice Sheet Velocity Mosaics from SAR |
| PROMICE IV v5 | Sentinel-1, 200 m, ~12-day cadence (downloaded automatically) | [Solgaard et al. 2021](https://doi.org/10.5194/essd-13-3491-2021) · data: [doi:10.22008/FK2/K70OPK](https://doi.org/10.22008/FK2/K70OPK) ([GEUS Dataverse](https://dataverse.geus.dk/dataset.xhtml?persistentId=doi:10.22008/FK2/K70OPK)) |
| Mouginot 2018 | Historical velocities pre-2000 | Mouginot et al. 2018: [1972–1990](https://doi.org/10.7280/D1MM37) · [1991–2000](https://doi.org/10.7280/D1GW91) (UCI DASH) |
| Bjørk 2015 | Glacier names (point vector) | [Bjørk et al. 2015](https://doi.org/10.5194/tc-9-2215-2015) |
| Moon 2008 / NSIDC-0642 | Glacier IDs | [Moon & Joughin 2008](https://doi.org/10.1029/2007JF000927) · data: [doi:10.5067/DC0MLBOCL3EL](https://doi.org/10.5067/DC0MLBOCL3EL) ([NSIDC-0642](https://nsidc.org/data/nsidc-0642)) |
| PRODEM | Annual DEMs 2019–2023 | [Winstrup et al. 2024](https://doi.org/10.5194/essd-16-5405-2024) · data: [doi:10.22008/FK2/52WWHG](https://doi.org/10.22008/FK2/52WWHG) |
| Khan 2016 | dh/dt (elevation change) 1995–2019 | [Khan et al. 2016](https://doi.org/10.1126/sciadv.1600931) · data: [doi:10.22008/promice/data/DTU/surface_elevation_change/v1.0.0](https://doi.org/10.22008/promice/data/DTU/surface_elevation_change/v1.0.0) |

Also computes a 2015–2017 baseline velocity (average of three September MEaSUREs 0478 scenes), fills velocity holes via bilinear interpolation, corrects for the ±8 % 2D area error in EPSG:3413, and reconstructs annual DEMs back to 1995 by subtracting cumulative elevation change from Khan 2016.

#### Stage 2 — Gate finding (`scripts/gate_IO_runner.sh` → `scripts/gate_IO.sh`)

Locates flux gates automatically using a fixed velocity cutoff of 100 m/yr and a 5000 m inland buffer:

1. Identifies fast-moving ice (baseline velocity > 100 m/yr)
2. Finds the grounding-line edge where fast ice borders ocean or ice shelf (BedMachine mask, grown 2 km into fjords)
3. Places gates 5000 m inland from that edge
4. Labels each gate pixel as "inside" or "outside" to determine the discharge direction
5. Decomposes into x- and y-components based on flow direction
6. Removes clusters ≤ 9 pixels (< 8 ha) and manually flagged bad areas (`dat/remove_gates_manual.kml`)
7. Assigns gate IDs, computes mean positions (x, y, lon, lat), and joins four naming systems per gate: Mouginot 2019, Bjørk 2015, Zwally 2012, Moon 2008

Outputs: `out/gate_meta.csv`, `out/gates.kml`, `out/gates.gpkg`, `out/gates.geojson`

#### Stage 3 — Effective velocity (`scripts/vel_eff.sh`)

For every velocity product and every available date, extracts the component of velocity that flows through each gate:

```
vel_eff = |vx| × gates_x  +  |vy| × gates_y
err_eff = |ex| × gates_x  +  |ey| × gates_y
```

PROMICE data (in m/day) is converted to m/yr. Missing or fill values are treated as zero.

#### Stage 4 — Export from GRASS (`scripts/export.sh`, `scripts/gate_export.sh`)

Dumps all raster values at gate pixels from GRASS and merges them into one flat CSV:

**`tmp/dat_100_5000.csv`** — one row per gate pixel, with columns for position, gate ID, sector, region, thickness, bed error, annual DEMs, and effective velocity + error for every product × date combination. This is the central intermediate file consumed by all downstream Python scripts.

#### Stage 5 — Error estimation (`scripts/errors.py`)

Propagates uncertainty through the discharge formula. The dominant source is bed topography error (BedMachine `errbed`). Outputs per-sector and per-region error tables to `tmp/`.

#### Stage 6 — Discharge calculation (`scripts/raw2discharge.py`)

Aggregates pixel-level data to gate, sector, region, and whole-ice-sheet level. Applies a rolling-window outlier filter (window = 30 dates, 2σ) on velocities, merges all velocity products into a single time series, and computes discharge in Gt/yr. Also computes velocity coverage (fraction of gates with valid data at each timestep).

Outputs to `out/`: `GIS_D.csv`, `GIS_err.csv`, `GIS_coverage.csv`, and sector/region/per-gate breakdowns.

#### Stage 7 — NetCDF output (`scripts/csv2nc.py`)

Converts the discharge CSVs to CF-compliant NetCDF files (`out/GIS.nc`, `out/sector.nc`, `out/region.nc`) with standard metadata.

#### Stage 8 — Figures (`scripts/figures.py`)

Produces publication-quality figures from the output CSVs and saves them to `figs/`. Includes a whole-ice-sheet discharge time series, regional breakdowns, heatmap, and top-glacier plots.

---

### Key files

```
scripts/           # all processing scripts (edit directly)
Makefile           # pipeline entry point — run 'make help'
dat/               # small static inputs (manual gate masks, etc.)
G/                 # GRASS database (generated, not in repo)
tmp/
  dat_100_5000.csv # central intermediate: pixel-level data for all gates × dates
out/
  gate_meta.csv    # gate positions, names, sector/region assignments
  GIS_D.csv        # whole-ice-sheet discharge time series
  GIS_err.csv      # discharge uncertainty time series
  GIS_coverage.csv # velocity coverage time series
  GIS.nc           # CF-compliant NetCDF (also sector.nc, region.nc)
  gates.kml/.gpkg/.geojson  # gate geometries
figs/              # output figures
```

---

## Related work

- Companion paper: "Greenland ice sheet mass balance from 1840 through next week"
  - Publication: [doi:10.5194/essd-13-5001-2021](https://doi.org/10.5194/essd-13-5001-2021)
  - Source: https://github.com/GEUS-Glaciology-and-Climate/mass_balance
  - Data: https://doi.org/10.22008/FK2/OHI23Z

- Companion paper: "Greenland liquid water runoff from 1958 through 2019"
  - Paper: [doi:10.5194/essd-12-2811-2020](https://doi.org/10.5194/essd-12-2811-2020)
  - Source: https://github.com/GEUS-PROMICE/freshwater
  - Data: [doi:10.22008/promice/freshwater](https://doi.org/10.22008/promice/freshwater)

## Citation

### Publication

```bibtex
@article{mankoff_2020_ice,
  doi = {10.5194/essd-12-1367-2020},
  url = {https://doi.org/10.5194/essd-12-1367-2020},
  year = {2020},
  volume = 12,
  issue = 2,
  pages = {1367 -- 1383},
  publisher = {Copernicus {GmbH}},
  author = {Kenneth D. Mankoff and Anne Solgaard and William Colgan and
            Andreas P. Ahlstrøm and Shfaqat Abbas Khan and Robert S. Fausto},
  title = {{G}reenland {I}ce {S}heet solid ice discharge
           from 1986 through March 2020},
  journal = {Earth System Science Data}
}
```
### Discharge data
 
```bibtex
@data{mankoff_2020_discharge,
    author    = {Mankoff, Ken, Solgaard, Anne and Larsen, Signe Hillerup},
    publisher = {GEUS Dataverse},
    title     = {{G}reenland {I}ce {S}heet solid ice discharge from 1986 through last month: Discharge},
    year      = {2020},
    version   = {VERSION NUMBER},
    doi       = {10.22008/promice/data/ice_discharge/d/v02},
    url       = {https://doi.org/10.22008/promice/data/ice_discharge/d/v02}}
```

### Discharge gates

```bibtex
@data{porimice_sid_2020_gates,
    author    = {Mankoff, Ken and Larsen, Signe Hillerup},
    publisher = {GEUS Dataverse},
    title     = {{G}reenland {I}ce {S}heet solid ice discharge from 1986 through last month: Gates},
    UNF       = {UNF:6:/eJSVvL8Rp1NG997hIhUag==},
    year      = {2020},
    version   = {VERSION_NUMBER},
    doi       = {10.22008/promice/data/ice_discharge/gates/v02},
    url       = {https://doi.org/10.22008/promice/data/ice_discharge/gates/v02}}
```

## Funding

| Dates | Organization | Program | Effort |
|---|---|---|---|
| 2023 – | NASA GISS | Modeling Analysis and Prediction program | Maintenance |
| 2022 – | GEUS | PROMICE | Distribution (data hosting) |
| 2018 – 2022 | GEUS | PROMICE | Development; publication; distribution |

## Open science vs. reproducible science

This work is open — every line of code needed to recreate it is included in this git repository, although the ~100 GB of velocity inputs are not.  We recognise that "open" is not necessarily "reproducible".

<p align="center"><img src="https://github.com/GEUS-PROMICE/mass_balance/blob/main/open_v_reproducible.png"></p>

Source: https://github.com/karthik/rstudio2019
