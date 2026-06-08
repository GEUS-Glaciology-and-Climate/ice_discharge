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

MSG_OK "Updating Sentinel velocity files..."
workingdir=$(pwd)

# Warn the user that we need to manually update MEaSURES for now
MSG_WARN "MEaSUREs 0766.002 product needs to be manually updated if new data is available, see how in README.org in the datafolder"

# Update PROMICE IV 
cd ${DATADIR}/Promice200m_v5/
if [[ -e urls.txt ]]; then cp urls.txt urls.txt.last; fi
curl "https://dataverse.geus.dk/api/datasets/:persistentId/dirindex?persistentId=doi:10.22008/FK2/K70OPK" | grep -oP '(?<=href=")[^"]+' > urls.txt
chmod 777 urls.txt
if cmp -s urls.txt urls.txt.last; then
  MSG_WARN "No new Sentinel1 files..."
  #exit 255
fi

for URL in $(cat urls.txt | tail -n5); do
  wget --content-disposition --continue "https://dataverse.geus.dk${URL}"
done

MSG_OK "New Sentinel velocity files found..."
cd ${workingdir}

docker run --user $(id -u):$(id -g) --mount type=bind,src=${DATADIR},dst=/data --mount type=bind,src=$(pwd),dst=/home/user --env PARALLEL="--delay 0.1 -j -1" mankoff/ice_discharge:grass grass ./G/PERMANENT --exec ./scripts/update_worker.sh

cp ./tmp/dat_100_5000.csv ./tmp/dat_100_5000.csv.last

docker run --user $(id -u):$(id -g) --mount type=bind,src=${DATADIR},dst=/data --mount type=bind,src=$(pwd),dst=/home/user --env PARALLEL="--delay 0.1 -j -1" mankoff/ice_discharge:grass grass ./G/PERMANENT --exec ./scripts/export.sh

if cmp -s ./tmp/dat_100_5000.csv ./tmp/dat_100_5000.csv.last; then
  MSG_WARN "No change in exported data"
fi

/home/shl/miniconda3/envs/TMB/bin/python upload_cli.py --url https://thredds01.geus.dk/thredds_upload --destination sid --token $(cat ~/.new_thredds_token) --file out/sector.nc --file out/region.nc
# Local:1 ends here
