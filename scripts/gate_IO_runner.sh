#!/usr/bin/env bash
# Algorithm
# + [X] Find the seaward edge of grounded ice: the PROMICE-2022 marine margin,
#       or the grounding line where a floating tongue intervenes
# + [X] Move inland by BUFFER_DIST, measured geodesically THROUGH the ice
# + [X] Discard gates if group size \in [1,2]
# + [X] Remove manually flagged areas (dat/remove_gates_manual.kml)
#
# There is no velocity condition by default, so gates exist on ice that is slow
# today but may speed up later. Gate identity is the marine-terminating glacier
# (MTG_ID), not a connected cluster.

# INSTRUCTIONS: set BUFFER_DIST and run. Repeat for a range of buffer
# distances to get a range of sensitivities.

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

# Gates are placed BUFFER_DIST upstream of the seaward edge of grounded ice,
# measured geodesically through the ice; see scripts/gate_IO.sh.
#
# VEL_FLOOR is off (0) by default, which is the point of the method: gates
# exist on ice that is slow today but may speed up later. Raising it is the
# lever if that proves too noisy or too expensive.
#
# BUFFER_DIST=2000 is what dev/2026-08-mask found best - it resolves 722 of 841
# marine-terminating glaciers against 437 at 10 km, because tributaries merge
# upstream and gates lose the ability to tell glaciers apart.
VEL_FLOOR=${VEL_FLOOR:-0}
BUFFER_DIST=${BUFFER_DIST:-2000}
export VEL_FLOOR BUFFER_DIST
MSG_OK "gates: BUFFER_DIST=${BUFFER_DIST} VEL_FLOOR=${VEL_FLOOR}"
. "$(dirname "$0")/gate_IO.sh"
