#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
matrix="$base_dir/scenarios.tsv"

[ "$#" -eq 1 ] || {
    echo "usage: materialize-untested-report.sh ARTIFACT_DIR" >&2
    exit 2
}

artifact_dir=$1
mkdir -p "$artifact_dir"

LC_ALL=C awk -F '	' 'BEGIN { OFS = FS }
    { print $1, $2, $3, $4, "UNTESTED", "not-executed", "-", "-" }
' "$matrix" >"$artifact_dir/assertions.tsv"

{
    printf 'count\tglobal\tassertion-count\t83\n'
    printf 'count\tdisposition\tPASS\t0\n'
    printf 'count\tdisposition\tFAIL\t0\n'
    printf 'count\tdisposition\tUNTESTED\t83\n'
    printf 'count\tdisposition\tUNAVAILABLE\t0\n'
    printf 'count\tdisposition\tINVALID\t0\n'
    for bc in BC01 BC02 BC03 BC04 BC05 BC06 BC07 BC08 BC09 BC10 BC11 BC12
    do
        printf 'group\t%s\tdisposition\tUNTESTED\n' "$bc"
    done
    printf 'overall\tglobal\tdisposition\tUNTESTED\n'
} >"$artifact_dir/report.tsv"
