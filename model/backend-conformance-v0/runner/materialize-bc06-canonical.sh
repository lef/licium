#!/bin/sh
set -eu

[ "$#" -eq 2 ] || {
    echo "usage: materialize-bc06-canonical.sh RUN_DIR OUTPUT" >&2
    exit 2
}

run_dir=$1
output=$2

: >"$output"
for relation in \
    coverage.tsv \
    inventory-after.tsv \
    inventory-before.tsv \
    normalized-observations.tsv \
    oracle-result.tsv \
    raw-observations.tsv
do
    file="$run_dir/$relation"
    [ -f "$file" ] || exit 1
    sha=$(sha256sum "$file" | awk '{ print $1 }')
    bytes=$(wc -c <"$file" | tr -d ' ')
    printf '%s\t%s\t%s\n' "$relation" "$sha" "$bytes" >>"$output"
done
