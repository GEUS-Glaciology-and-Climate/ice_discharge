#!/usr/bin/env bash
# Algorithm
# + [X] Find all fast-moving ice (>X m yr^{-1})
#   + Results not very sensitive to velocity limit (10 to 100 m yr^{-1} examined)
# + [X] Find grounding line by finding edge cells where fast-moving ice borders water or ice shelf based (loosely) on BedMachine mask
# + [X] Move grounding line cells inland by X km, again limiting to regions of fast ice.
#   + Results not very sensitive to gate position (1 - 5 km range examined)

# + [X] Discard gates if group size \in [1,2]
# + [X] Manually clean a few areas (e.g. land-terminating glaciers, gates due to invalid masks, etc.) by manually selecting invalid regions in Google Earth, then remove gates in these regions

# Note that "fast ice" refers to flow velocity, not the sea ice term of "stuck to the land".

# INSTRUCTIONS: Set VELOCITY_CUTOFF and BUFFER_DIST to 50 and 2500 respectively and run the code. Then repeat for a range of other velocity cutoffs and buffer distances to get a range of sensitivities.

# OR: Tangle via ((org-babel-tangle) the code below (C-c C-v C-t or ) to [[./gate_IO.sh]] and then run this in a GRASS session:

RED='\033[0;31m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
MSG_OK() { printf "${GREEN}${1}${NC}\n"; }
MSG_WARN() { printf "${ORANGE}WARNING: ${1}${NC}\n"; }
MSG_ERR() { echo "${RED}ERROR: ${1}${NC}\n" >&2; }
export GRASS_VERBOSE=3
# export GRASS_MESSAGE_FORMAT=silent

if [ -z ${DATADIR+x} ]; then
    echo "DATADIR environment varible is unset."
    echo "Fix with: \"export DATADIR=/path/to/data\""
    exit 255
fi

set -x # print commands to STDOUT before running them

trap ctrl_c INT
function ctrl_c() {
  MSG_WARN "Caught CTRL-C"
  MSG_WARN "Killing process"
  kill -term $$ # send this program a terminate signal
}

# GATE_METHOD selects how gates are placed; see scripts/gate_IO.sh.
#   fastice  published method - BUFFER_DIST inland of the fast-ice/not-ice
#            edge, only where ice already flows > VELOCITY_CUTOFF
#   marine   BUFFER_DIST upstream of the seaward edge of grounded ice,
#            measured geodesically through the ice, with no velocity condition
#
# VELOCITY_CUTOFF applies to fastice only. VEL_FLOOR applies to marine only and
# is off (0) by default, which is the point of that method: gates exist on ice
# that is slow today but may speed up later.
#
# For marine, BUFFER_DIST=2000 is what dev/2026-08-mask found best - it resolves
# 722 of 841 marine-terminating glaciers against 437 at 10 km, because
# tributaries merge upstream and gates lose the ability to tell glaciers apart.
GATE_METHOD=${GATE_METHOD:-fastice}
VEL_FLOOR=${VEL_FLOOR:-0}
VELOCITY_CUTOFF=${VELOCITY_CUTOFF:-100}
if [ "${GATE_METHOD}" = "marine" ]; then
    BUFFER_DIST=${BUFFER_DIST:-2000}
else
    BUFFER_DIST=${BUFFER_DIST:-5000}
fi
export GATE_METHOD VEL_FLOOR VELOCITY_CUTOFF BUFFER_DIST
MSG_OK "gate method: ${GATE_METHOD} | BUFFER_DIST=${BUFFER_DIST}"
. "$(dirname "$0")/gate_IO.sh"
