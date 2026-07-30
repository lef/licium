#!/bin/sh
set -eu

[ "$#" -eq 2 ] || {
    echo "usage: materialize-report.sh ASSERTIONS_TSV REPORT_TSV" >&2
    exit 2
}

assertions=$1
report=$2

LC_ALL=C awk -F '	' -v OFS='	' '
    BEGIN {
        rank["PASS"] = 0
        rank["UNTESTED"] = 1
        rank["UNAVAILABLE"] = 2
        rank["FAIL"] = 3
        rank["INVALID"] = 4
        disposition[1] = "PASS"
        disposition[2] = "FAIL"
        disposition[3] = "UNTESTED"
        disposition[4] = "UNAVAILABLE"
        disposition[5] = "INVALID"
    }
    {
        count[$5]++
        total++
        if (!($1 in group_rank) || rank[$5] > group_rank[$1]) {
            group_rank[$1] = rank[$5]
            group_status[$1] = $5
        }
        if (!overall_seen || rank[$5] > overall_rank) {
            overall_rank = rank[$5]
            overall_status = $5
            overall_seen = 1
        }
    }
    END {
        print "count","global","assertion-count",total
        for (i = 1; i <= 5; i++)
            print "count","disposition",disposition[i],count[disposition[i]] + 0
        for (i = 1; i <= 12; i++) {
            bc = sprintf("BC%02d", i)
            print "group",bc,"disposition",group_status[bc]
        }
        print "overall","global","disposition",overall_status
    }
' "$assertions" >"$report"
chmod 0644 "$report"
