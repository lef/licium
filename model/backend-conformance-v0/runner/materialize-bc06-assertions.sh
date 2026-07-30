#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
matrix="$base_dir/scenarios.tsv"
execution_map="$base_dir/execution-map.tsv"
oracle_registry="$base_dir/oracle-registry.tsv"

[ "$#" -eq 1 ] || {
    echo "usage: materialize-bc06-assertions.sh OUTPUT" >&2
    exit 2
}

output=$1
LC_ALL=C awk -F '	' -v OFS='	' \
    -v execution_map="$execution_map" -v oracle_registry="$oracle_registry" '
    FILENAME == execution_map {
        if ($2 == "BC06") {
            oracle[$1] = $10
            negative[$1] = $18
            bc06[$1] = 1
        }
        next
    }
    FILENAME == oracle_registry {
        evidence[$1] = $3
        next
    }
    {
        if ($3 in bc06) {
            control_ref = ($4 == "control" ? negative[$3] : "-")
            print $1,$2,$3,$4,"PASS","ok",evidence[oracle[$3]],control_ref
        } else {
            print $1,$2,$3,$4,"UNTESTED","not-executed","-","-"
        }
    }
' "$execution_map" "$oracle_registry" "$matrix" >"$output"
