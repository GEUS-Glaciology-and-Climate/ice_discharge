#!/usr/bin/env bash
# Sourced by all GRASS import scripts — do not execute directly
RED='\033[0;31m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'
MSG_OK()   { printf "${GREEN}${1}${NC}\n"; }
MSG_WARN() { printf "${ORANGE}WARNING: ${1}${NC}\n"; }
MSG_ERR()  { echo "${RED}ERROR: ${1}${NC}\n" >&2; }
export GRASS_VERBOSE=3

if [ -z ${DATADIR+x} ]; then
    echo "DATADIR environment variable is unset."
    echo "Fix with: \"export DATADIR=/path/to/data\""
    exit 255
fi

set -x

trap ctrl_c INT
function ctrl_c() {
    MSG_WARN "Caught CTRL-C"
    MSG_WARN "Killing process"
    kill -term $$
}
