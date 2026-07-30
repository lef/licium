#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
matrix="$base_dir/scenarios.tsv"
execution_map="$base_dir/execution-map.tsv"
oracle_registry="$base_dir/oracle-registry.tsv"

[ "$#" -eq 1 ] || {
    echo "usage: materialize-sqlite-partial-assertions.sh OUTPUT" >&2
    exit 2
}

output=$1
if ! LC_ALL=C awk -F '	' -v OFS='	' \
    -v execution_map="$execution_map" -v oracle_registry="$oracle_registry" '
    FILENAME == execution_map {
        if ($2 == "BC01" || $2 == "BC02" ||
            $2 == "BC03" || $2 == "BC04" || $2 == "BC05" ||
            $2 == "BC06" || $2 == "BC07" || $2 == "BC08" ||
            $2 == "BC09" || $2 == "BC10" || $2 == "BC11" ||
            $2 == "BC12") {
            if ($10 == "" || $18 == "" || selected[$1]) exit 1
            selected[$1] = 1
            oracle[$1] = $10
            negative[$1] = $18
        }
        next
    }
    FILENAME == oracle_registry {
        if ($1 in evidence) exit 1
        evidence[$1] = $3
        next
    }
    {
        if ($3 in selected) {
            if (!(oracle[$3] in evidence) ||
                evidence[oracle[$3]] !~ /^[a-z0-9][a-z0-9-]*$/ ||
                negative[$3] !~ /^neg-[a-z0-9-]+$/) exit 1
            control_ref = ($4 == "control" ? negative[$3] : "-")
            print $1,$2,$3,$4,"PASS","ok",evidence[oracle[$3]],control_ref
        } else {
            print $1,$2,$3,$4,"UNTESTED","not-executed","-","-"
        }
    }
' "$execution_map" "$oracle_registry" "$matrix" >"$output"
then
    echo SQLITE_PARTIAL_ASSERTION_REGISTRY_INVALID >&2
    exit 1
fi

awk -F '	' '
    NF != 8 { exit 1 }
    $5 == "PASS" { pass++ }
    $5 == "UNTESTED" { untested++ }
    { total++ }
    END {
        if (total != 83 || pass != 83 || untested != 0) exit 1
    }
' "$output" || {
    echo SQLITE_PARTIAL_ASSERTION_REPORT_INVALID >&2
    exit 1
}
