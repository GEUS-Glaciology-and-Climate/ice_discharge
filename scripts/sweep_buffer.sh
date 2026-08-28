#!/usr/bin/env bash
# Sweep BUFFER_DIST through the full pipeline and archive one complete result
# per distance. Fast-ice gate method (the published one) - this is the CONTROL
# for the same sweep on the `mask` branch's marine-margin method.
#
# Why it exists: the marine-margin sweep found that gates further inland report
# much less of the 1990s-to-today speed-up (+14 % at 2 km, +1 % at 7 km).
# Distance and method are confounded in that result. Running the same distance
# sweep on the unchanged fast-ice method separates them - if the trend damps
# here too, it is a property of gate distance, not of the new gate method.
#
# Run this on the HOST, in the repo root - it drives `make`, which drives the
# containers. Do not run it inside the GRASS container.
#
#   export DATADIR=/path/to/data
#   scripts/sweep_buffer.sh                      # 2000 5000 7000 10000
#   BUFFER_DISTS="5000 10000" scripts/sweep_buffer.sh
#
# Everything the pipeline writes is fixed-name - the GRASS mapset is
# `gates_vel_buf`, the pixel export is `tmp/dat_100_5000.csv`, the results are
# `out/*` - and `gates_vel_buf` is baked into COLUMN names in errors.py and
# raw2discharge.py. Renaming any of it per distance is a multi-file change with
# real breakage risk, so this script instead runs the distances one at a time
# and moves each finished result out of the way before starting the next.
#
# Only `make import` is shared between distances; gates, velocity, export,
# errors and output all depend on where the gates sit and are redone every time.

set -u -o pipefail

# `make sweep` runs this script, which runs make again. Without this the outer
# make's flags - a `-j` in particular - are inherited by every inner make, and
# the stages below are strictly ordered.
unset MAKEFLAGS MFLAGS MAKELEVEL

BUFFER_DISTS=${BUFFER_DISTS:-"2000 5000 7000 10000"}
# Held FIXED across the sweep at the published value. This sweep varies one
# thing, the gate distance; the velocity cutoff is the other axis of
# gate_IO_runner.sh's sensitivity test and mixing them would make the result
# uninterpretable.
VELOCITY_CUTOFF=${VELOCITY_CUTOFF:-100}
SWEEP_DIR=${SWEEP_DIR:-./sweep}
# The per-pixel export is ~300 MB per distance. It is the only way to ask
# pixel-level questions later (which pixels each gate set actually samples, and
# how the early velocity mosaics cover them), so it is kept by default.
KEEP_PIXEL_CSV=${KEEP_PIXEL_CSV:-1}

RED='\033[0;31m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'
MSG_OK()   { printf "${GREEN}${1}${NC}\n"; }
MSG_WARN() { printf "${ORANGE}WARNING: ${1}${NC}\n"; }
MSG_ERR()  { printf "${RED}ERROR: ${1}${NC}\n" >&2; }

if [ -z ${DATADIR+x} ]; then
    MSG_ERR "DATADIR environment variable is unset."
    echo "Fix with: \"export DATADIR=/path/to/data\"" >&2
    exit 255
fi
if [ ! -d ./G ]; then
    MSG_ERR "no GRASS database ./G here - run this from the repo root."
    exit 255
fi

COMMIT=$(git rev-parse HEAD 2>/dev/null || echo unknown)
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)
DIRTY=$(git status --porcelain 2>/dev/null | grep -v '^??' | wc -l)
[ "${DIRTY}" != "0" ] && MSG_WARN "working tree has ${DIRTY} uncommitted change(s) - the archive stamp will not describe what actually ran"

mkdir -p "${SWEEP_DIR}"
SWEEP_LOG="${SWEEP_DIR}/sweep.log"
MSG_OK "sweep: BUFFER_DISTS='${BUFFER_DISTS}' VELOCITY_CUTOFF=${VELOCITY_CUTOFF} -> ${SWEEP_DIR}"
echo "$(date --iso-8601=seconds) sweep start: '${BUFFER_DISTS}' ${BRANCH} ${COMMIT}" >> "${SWEEP_LOG}"

# Import once, up front, so a failure there costs one message rather than
# turning up inside the first distance's log.
make import || { MSG_ERR "make import failed"; exit 1; }

# `set -u` and an empty array are a bad combination on bash < 4.4, which is
# still what some server images ship; seed it so the summary below is safe.
STATUS=("--")
for DIST in ${BUFFER_DISTS}; do
    DEST="${SWEEP_DIR}/buf_${DIST}"
    if [ -e "${DEST}" ]; then
        MSG_WARN "${DEST} exists - skipping ${DIST} m. Remove it to redo."
        STATUS+=("${DIST} SKIPPED (exists)")
        continue
    fi

    MSG_OK "=== BUFFER_DIST=${DIST} ==="
    T0=$(date +%s)

    # Clean slate. Each of these is a different way for the previous distance to
    # leak into this one:
    #
    #   G/gates_vel_buf   gate_IO.sh reuses the mapset (`g.mapset -c`) and not
    #                     everything in it is written with --o. `gates_area` is
    #                     the dangerous one: r.reclass.area only emits it when
    #                     some clump is under the size threshold, and the script
    #                     explicitly tests whether it exists (gate_IO.sh line
    #                     139) - so a leftover from the previous distance would
    #                     be applied to this one. mask_GIC_Mouginot_2019_grow
    #                     (line 151) has no --o at all and would simply fail.
    #
    #   tmp/dat           export.sh caches one .bsv per raster and skips any
    #                     that already exists. Its MASK is built from
    #                     gates_final, so moving the gates changes WHICH PIXELS
    #                     are exported and every cached file is stale. There is
    #                     no row-count guard on this branch, so a stale cache
    #                     would be exported silently, mixing two gate sets into
    #                     one CSV.
    #
    #   out              gate_export.sh appends into gates.kmz with `zip`, and a
    #                     partial failure would otherwise leave last distance's
    #                     results looking like this one's.
    #
    #   G/*/MASK          GRASS's MASK is per-mapset and persistent, and
    #                     r.mapcalc applies the mask already in place while
    #                     writing a new one. A MASK left in MEaSUREs.* by the
    #                     previous distance therefore intersects this
    #                     distance's - and since the gates have moved
    #                     kilometres, that intersection is empty, so every
    #                     vel_eff/err_eff comes out all-null. vel_eff.sh now
    #                     clears these itself; this is the backstop for a run
    #                     that died before it got there.
    rm -rf ./G/gates_vel_buf ./tmp/dat ./tmp/dat_100_5000.csv ./out
    # A GRASS raster is spread over several per-element directories; remove all
    # of them, or `g.list` still reports a MASK that has no data behind it.
    rm -rf ./G/*/{cell,fcell,cellhd,cell_misc,hist,cats,colr}/MASK
    mkdir -p ./tmp ./out
    mkdir -p "${DEST}"
    LOG="${DEST}/run.log"

    OK=1
    for STAGE in gates velocity export errors output; do
        S0=$(date +%s)
        MSG_OK "--- ${DIST} m: ${STAGE} ---"
        if ! BUFFER_DIST=${DIST} VELOCITY_CUTOFF=${VELOCITY_CUTOFF} make ${STAGE} >> "${LOG}" 2>&1; then
            # Move the half-finished directory out of the way. Left as
            # `buf_<dist>` the "already exists, skipping" check above would treat
            # a crashed distance as a completed one on the next run, and the
            # sweep would quietly come out three distances wide.
            FAILED="${DEST}.failed-$(date +%Y%m%dT%H%M%S)"
            mv "${DEST}" "${FAILED}"
            MSG_ERR "BUFFER_DIST=${DIST}: stage '${STAGE}' failed - see ${FAILED}/run.log"
            STATUS+=("${DIST} FAILED at ${STAGE}")
            OK=0
            break
        fi
        echo "stage ${STAGE}: $(( $(date +%s) - S0 )) s" >> "${DEST}/timing.txt"
    done
    [ "${OK}" = "0" ] && continue

    # Archive. `mv` not `cp` - same filesystem, and out/ is ~360 MB.
    mv ./out "${DEST}/out"
    mkdir -p "${DEST}/tmp" ./out
    # The gates KML carries BOTH knobs in its name on this branch
    # (gate_IO.sh line 302), unlike the marine method where it is the distance
    # alone - so it has to be built from both here.
    for f in gates_final_${VELOCITY_CUTOFF}_${DIST}.kml err_gate.csv \
             err_sector_mouginot.csv err_region_mouginot.csv sector_cats.csv; do
        [ -e "./tmp/${f}" ] && mv "./tmp/${f}" "${DEST}/tmp/${f}"
    done
    if [ "${KEEP_PIXEL_CSV}" = "1" ]; then
        mv ./tmp/dat_100_5000.csv "${DEST}/tmp/dat_100_5000.csv"
    fi

    ELAPSED=$(( $(date +%s) - T0 ))
    NGATES=$(( $(wc -l < "${DEST}/out/gate_meta.csv") - 1 ))
    NPIXELS="not kept"
    if [ -e "${DEST}/tmp/dat_100_5000.csv" ]; then
        NPIXELS=$(( $(wc -l < "${DEST}/tmp/dat_100_5000.csv") - 1 ))
    fi

    cat > "${DEST}/MANIFEST.txt" <<EOF
BUFFER_DIST:      ${DIST}
VELOCITY_CUTOFF:  ${VELOCITY_CUTOFF}
GATE_METHOD:      fastice
finished:         $(date --iso-8601=seconds)
host:             $(hostname)
path:             $(pwd)
branch:           ${BRANCH}
commit:           ${COMMIT}
dirty_files:      ${DIRTY}
elapsed_s:        ${ELAPSED}
gates:            ${NGATES}
gate_pixels:      ${NPIXELS}
EOF
    cat "${DEST}/timing.txt" >> "${DEST}/MANIFEST.txt"

    MSG_OK "${DIST} m done in ${ELAPSED} s - ${NGATES} gates, ${NPIXELS} pixels -> ${DEST}"
    echo "$(date --iso-8601=seconds) ${DIST} OK ${ELAPSED}s ${NGATES} gates" >> "${SWEEP_LOG}"
    STATUS+=("${DIST} OK ${ELAPSED}s ${NGATES} gates")
done

echo
MSG_OK "=== sweep summary ==="
for s in "${STATUS[@]}"; do [ "${s}" = "--" ] || echo "  ${s}"; done
echo "$(date --iso-8601=seconds) sweep end" >> "${SWEEP_LOG}"

# Non-zero if anything failed, so an unattended run is detectable from $?.
printf '%s\n' "${STATUS[@]}" | grep -q FAILED && exit 1
exit 0
