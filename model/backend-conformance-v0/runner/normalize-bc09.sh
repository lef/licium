#!/bin/sh
set -eu

[ "$#" -eq 2 ] || {
    echo "usage: normalize-bc09.sh RAW OUTPUT" >&2
    exit 2
}

raw=$1
output=$2
[ -f "$raw" ] && [ ! -L "$raw" ] || exit 2

awk -F '	' 'BEGIN { OFS=FS }
    NF != 6 || $2 !~ /^raw-case-[a-z-]+-[0-9][0-9][0-9]$/ { exit 1 }
    {
        sub(/^raw-/, "obs-", $2)
        print
    }
' "$raw" >"$output"
