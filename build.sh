#!/usr/bin/env bash

set -o pipefail

TMP=/tmp/bartonks
mkdir -p $TMP

if [[ ! -e $(dirname $0)/node_modules/turf-cli/turf-point-on-surface.js ]]; then
    npm install ingalls/turf-cli
fi

if [[ ! -e $TMP/addresses_processed.txt ]]; then
    pdftotext -layout $(dirname $0)/addresses.pdf $TMP/addresses.txt
    grep -E '\s005' $TMP/addresses.txt | sed -e 's/-//g' -e 's/\.//g' > $TMP/addresses_processed.txt
fi

rm $TMP/pin2address &>/dev/null || true
rm $(dirname $0)/final.csv
IFS=' '
echo "LNG,LAT,PID,NUM,STR,CITY,ZIP" >> $(dirname $0)/final.csv
while read -r geom; do
    PIN=$(echo "$geom" | jq -r -c '.properties | .KSPID')
    ADDRESSES=$(grep "$PIN" "$TMP/addresses_processed.txt" |\
        sed -e 's/^\s*[0-9|A-Z]*\s*[0-9]*\s*[0-9]*\s*[0-9]*[A-Z]\s*//' \
            -e 's/\s\s.*//' \
            -e 's/^\s//')
    if [[ -z $ADDRESSES ]]; then continue; fi
    CENTRE=$(echo "$geom" | jq -r -c '.geometry | .coordinates' | sed -e 's/\[//' -e 's/\]//')

    while read -r ADDRESS; do
        NUM=$(echo "$ADDRESS" | grep -Eo '^[0-9]+')
        STR=$(echo "$ADDRESS" | sed -e 's/^[0-9]*\ //' -e 's/,.*//')

        if [[ -z $NUM ]] || [[ -z $STR ]]; then
            continue
        fi

        CITY=$(echo "$ADDRESS" | sed -e "s/^$NUM\ $STR,\ //" -e 's/,.*//')
        ZIP=$(echo "$ADDRESS" | grep -Eo '[0-9]{5}$')
        echo "$CENTRE,$PIN,$NUM,$STR,$CITY,$ZIP" >> $(dirname $0)/final.csv
    done <<< $ADDRESSES
done <<< $($(dirname $0)/node_modules/turf-cli/turf-point-on-surface.js $(dirname $0)/parcels.geojson | jq -r -c '.features | .[]')
