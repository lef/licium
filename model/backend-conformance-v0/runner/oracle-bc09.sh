#!/bin/sh
set -eu

[ "$#" -eq 5 ] || {
    echo "usage: oracle-bc09.sh NORMALIZED CASES ASSERTION SCENARIO OUTPUT" >&2
    exit 2
}

normalized=$1
cases=$2
assertion=$3
scenario=$4
output=$5

awk -F '	' -v assertion="$assertion" -v scenario="$scenario" '
    FILENAME == ARGV[1] && $1 == assertion {
        valid[$3] = 1
        disposition[$3] = $7
        reason[$3] = $8
        deliveries[$3] = $9
        triggers[$3] = $4 == "fault" ? 1 : 0
        next
    }
    FILENAME == ARGV[2] {
        if ($1 != scenario || $2 !~ /^obs-case-/) exit 1
        id = $2
        sub(/^obs-/, "", id)
        sub(/-[0-9][0-9][0-9]$/, "", id)
        if (!(id in valid)) exit 1
        ordinal = substr($2, length($2) - 2) + 0
        if (seen[id FS ordinal]++) exit 1
        count[id]++
        if (ordinal == 1 && $6 != disposition[id]) exit 1
        if (ordinal == 2 && $6 != reason[id]) exit 1
        if (ordinal == 3 && $6 != "true") exit 1
        if (ordinal >= 4 && ordinal <= 8 && $6 != "0") exit 1
        if (ordinal == 9 && $6 != deliveries[id]) exit 1
        if (ordinal == 10 && $6 != triggers[id]) exit 1
    }
    END {
        expected = 0
        for (id in valid) {
            expected++
            if (count[id] != 10) exit 1
        }
        if (expected == 0) exit 1
    }
' "$cases" "$normalized" || {
    echo BC09_ORACLE_MISMATCH >&2
    exit 1
}

printf '%s\toracle\t%s\tdisposition\tPASS\tok\n' \
    "$scenario" "$assertion" >"$output"
