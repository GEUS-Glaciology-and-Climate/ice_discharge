#!/usr/bin/env bash

# #+RESULTS:

# Users should not need to edit anything below here.


# This code block is the top level pseudo-code description of the monitoring and update workflow. It is the only code block that is tangled out to the =monitor.sh= file. However, prior to tangling the =noweb= (<<>>) code blocks are expanded using the code blocks below.


# [[file:~/projects/ice_discharge/monitor.org::*Algorithm][Algorithm:2]]
Sentinel1_IV_DATA_DIR=${DATADIR}/Sentinel1/Sentinel1_IV_maps

RED='\033[0;31m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
MSG_OK() { printf "${GREEN}${1}${NC}\n"; }
MSG_WARN() { printf "${ORANGE}WARNING: ${1}${NC}\n"; }
MSG_ERR() { echo "${RED}ERROR: ${1}${NC}\n" >&2; }

URL=https://promice.org/PromiceDataPortal/api/download/92ce7cf4-59b8-4a3f-8f75-93d166f5a7ca/Greenland_IV
IV_web=$(curl -s ${URL} --list-only | grep \.nc | sed -e 's/<[^>]*>//g' | cut -d"." -f1)
IV_local=$(cd ${DATADIR}/Sentinel1/Sentinel1_IV_maps; ls *.nc | cut -d"." -f1)
diff <(echo $IV_web|tr ' ' '\n') <(echo $IV_local|tr ' ' '\n') &> /dev/null
if [ $? -ne 0 ]; then # difference.
  MSG_WARN "Local Sentinel1 Velocities do not match remote."
  MSG_OK "Fetching missing files..."
  missing_local=$(diff <(echo $IV_web|tr ' ' '\n') <(echo $IV_local|tr ' ' '\n') | grep "^<" | cut -c2-)
  for file in $(echo ${missing_local} | tr ' ' '\n'); do
    MSG_OK "Fetching ${file}"
    wget -np --continue ${URL}/${file}.nc -O ${Sentinel1_IV_DATA_DIR}/${file}.nc
  done
  echo make
else 
  MSG_OK "Local velocities match remote."
  MSG_OK "No action taken"
fi
# Algorithm:2 ends here
