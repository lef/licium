#!/bin/sh
set -eu

[ "$#" -eq 2 ] || {
    echo "usage: normalize-bc08.sh RAW_TSV SCENARIO" >&2
    exit 2
}
raw=$1
scenario=$2

awk -F '	' -v OFS='	' -v scenario="$scenario" '
    NF != 6 || $1 != scenario || $2 !~ /^raw-[0-9][0-9][0-9]$/ ||
        seen[$2]++ { exit 1 }
    {
        id=$2
        sub(/^raw-/, "obs-", id)
        print $1,id,$3,$4,$5,$6
    }
    END { if (NR != 12) exit 1 }
' "$raw"
