#!/bin/sh
set -eu

[ "$#" -eq 2 ] || {
    echo "usage: normalize-bc06.sh RAW_TSV ASSERTION" >&2
    exit 2
}

raw=$1
assertion=$2

LC_ALL=C awk -F '	' -v OFS='	' -v assertion="$assertion" '
    function add(store, key) {
        if (store == "sb") sb[key]++
        else if (store == "sa") sa[key]++
        else if (store == "db") db[key]++
        else if (store == "da") da[key]++
        else if (store == "rb") rb[key]++
        else if (store == "ra") ra[key]++
    }
    function difference(left, right, key, n) {
        n = 0
        for (key in left) if (left[key] != right[key])
            n += left[key] > right[key] ? left[key] - right[key] : right[key] - left[key]
        for (key in right) if (!(key in left)) n += right[key]
        return n
    }
    {
        if ($1 != assertion || NF != 6) exit 1
        row[$2, 1] = $5
        row[$2, 2] = $6
        key = $5 SUBSEP $6
        if ($3 == "authoritative-state" && $4 == "before") add("sb", key)
        if ($3 == "authoritative-state" && $4 == "after") add("sa", key)
        if ($3 == "decision-observation" && $4 == "before") add("db", key)
        if ($3 == "decision-observation" && $4 == "after") add("da", key)
        if ($3 == "result-store" && $4 == "before") add("rb", key)
        if ($3 == "result-store" && $4 == "after") add("ra", key)
    }
    END {
        state_delta = difference(sb, sa)
        decision_delta = difference(db, da)
        result_delta = difference(rb, ra)

        print assertion,"obs-001","evaluation-outcome","occurrence-1",row["raw-013",2],row["raw-007",2]
        print assertion,"obs-005","evaluation-outcome","occurrence-2",row["raw-014",2],row["raw-010",2]
        print assertion,"obs-008","execution","occurrence-1",row["raw-013",1],row["raw-013",2]
        print assertion,"obs-009","execution","occurrence-2",row["raw-014",1],row["raw-014",2]
        print assertion,"obs-002","persistent-write","authoritative-state",state_delta ? "changed" : "unchanged",state_delta
        print assertion,"obs-003","persistent-write","decision-observation",decision_delta ? "changed" : "unchanged",decision_delta
        print assertion,"obs-004","persistent-write","result-store",result_delta ? "changed" : "unchanged",result_delta
        print assertion,"obs-007","provenance","pinned-source",row["raw-012",2],"bound"
        print assertion,"obs-010","provenance","request",row["raw-007",1],"bound"
        print assertion,"obs-006","provenance","subject",row["raw-011",2],"bound"
    }
' "$raw"
