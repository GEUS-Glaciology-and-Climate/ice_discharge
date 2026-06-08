#!/usr/bin/env bash
# Exits 0 if new Sentinel-1 files are available on the dataverse, 1 if not.
# Use as a gate before make update:  scripts/check_new_data.sh && make update

if [[ -z "${DATADIR}" ]]; then
    echo "check_new_data.sh: DATADIR is not set" >&2
    exit 2
fi

URLS="${DATADIR}/Promice200m_v5/urls.txt"
URLS_NEW=$(mktemp)

curl -sf "https://dataverse.geus.dk/api/datasets/:persistentId/dirindex?persistentId=doi:10.22008/FK2/K70OPK" \
    | grep -oP '(?<=href=")[^"]+' > "${URLS_NEW}"

if [[ ! -s "${URLS_NEW}" ]]; then
    echo "check_new_data.sh: failed to fetch URL list from dataverse" >&2
    rm "${URLS_NEW}"
    exit 2
fi

if cmp -s "${URLS_NEW}" "${URLS}"; then
    rm "${URLS_NEW}"
    exit 1  # no new data
fi

rm "${URLS_NEW}"
exit 0  # new data available
