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

# [[file:ice_discharge.org::*Algorithm][Algorithm:1]]
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

VELOCITY_CUTOFF=100
BUFFER_DIST=5000
. ./gate_IO.sh
# Algorithm:1 ends here
