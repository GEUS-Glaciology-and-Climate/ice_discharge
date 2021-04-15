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
cd ${DATADIR}/Sentinel1/Sentinel1_IV_maps/

if [[ -e urls.txt ]]; then cp urls.txt urls.txt.last; fi
curl https://dataverse01.geus.dk/api/datasets/:persistentId?persistentId=doi:10.22008/promice/data/sentinel1icevelocity/greenlandicesheet | tr ',' '\n' | grep -E '"persistentId"' | cut -d'"' -f4 > urls.txt

if cmp -s urls.txt urls.txt.last; then
  MSG_WARN "No new files..."
  exit
fi

# for PID in $(cat urls.txt); do
for PID in $(cat urls.txt | tail -n5); do
  wget --content-disposition --continue "https://dataverse01.geus.dk/api/access/datafile/:persistentId?persistentId=${PID}"
done

MSG_OK "New Sentinel velocity files found..."
cd ${workingdir}

grass ./G/PERMANENT --exec ./update_worker.sh
cp ./tmp/dat_100_5000.csv ./tmp/dat_100_5000.csv.last
grass ./G/PERMANENT --exec ./export.sh

if cmp -s ./tmp/dat_100_5000.csv ./tmp/dat_100_5000.csv.last; then 
  MSG_ERR "No change"
  exit
fi

python ./errors.py
python ./raw2discharge.py
python ./csv2nc.py
cp ./out/* ~/data/Mankoff_2020/ice/latest
python ./upload.py
# Local:1 ends here
