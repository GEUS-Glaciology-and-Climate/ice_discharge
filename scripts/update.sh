#!/usr/bin/env bash
# Local

# [[file:ice_discharge.org::*Local][Local:1]]
RED='\033[0;31m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
MSG_OK() { printf "${GREEN}${1}${NC}\n"; }
MSG_WARN() { printf "${ORANGE}WARNING: ${1}${NC}\n"; }
MSG_ERR() { echo "${RED}ERROR: ${1}${NC}\n" >&2; }

set -euo pipefail

MSG_OK "Updating Sentinel velocity files..."
workingdir=$(pwd)

# Warn the user that we need to manually update MEaSURES for now
MSG_WARN "MEaSUREs 0766.002 product needs to be manually updated if new data is available, see how in README.org in the datafolder"

# Update PROMICE IV 
cd ${DATADIR}/Promice200m_v5/
# The file list goes to urls.txt.new. It replaces urls.txt only as the last step
# of `make update`, so if anything fails check_new_data.sh still sees new data
# and the next cron run retries.
curl -sf "https://dataverse.geus.dk/api/datasets/:persistentId/dirindex?persistentId=doi:10.22008/FK2/K70OPK" | grep -oP '(?<=href=")[^"]+' > urls.txt.new
chmod 777 urls.txt.new
if [[ -e urls.txt ]] && cmp -s urls.txt.new urls.txt; then
  MSG_WARN "No new Sentinel1 files..."
fi

for URL in $(tail -n5 urls.txt.new); do
  wget --content-disposition --continue "https://dataverse.geus.dk${URL}"
done

MSG_OK "New Sentinel velocity files found..."
cd ${workingdir}

docker run --user $(id -u):$(id -g) --mount type=bind,src=${DATADIR},dst=/data --mount type=bind,src=$(pwd),dst=/home/user --env PARALLEL="--delay 0.1 -j -1" mankoff/ice_discharge:grass grass ./G/PERMANENT --exec ./scripts/update_worker.sh

cp ./tmp/dat_100_5000.csv ./tmp/dat_100_5000.csv.last

docker run --user $(id -u):$(id -g) --mount type=bind,src=${DATADIR},dst=/data --mount type=bind,src=$(pwd),dst=/home/user --env PARALLEL="--delay 0.1 -j -1" mankoff/ice_discharge:grass grass ./G/PERMANENT --exec ./scripts/export.sh

# export.sh's exit status is that of its last command, so check its product.
if [[ ! -s ./tmp/dat_100_5000.csv || ! ./tmp/dat_100_5000.csv -nt ./tmp/dat_100_5000.csv.last ]]; then
  MSG_ERR "export.sh did not write ./tmp/dat_100_5000.csv"
  exit 1
fi

if cmp -s ./tmp/dat_100_5000.csv ./tmp/dat_100_5000.csv.last; then
  MSG_WARN "No change in exported data"
fi
# Local:1 ends here
