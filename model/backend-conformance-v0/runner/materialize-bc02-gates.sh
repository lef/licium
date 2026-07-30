#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
template="$base_dir/bc02-gate-results-template.tsv"

[ "$#" -eq 3 ] || {
    echo "usage: materialize-bc02-gates.sh ARTIFACT_DIR SCENARIO REVISION" >&2
    exit 2
}

artifact_dir=$1
scenario=$2
revision=$3

case "$revision" in
    ''|*[!0-9a-f]*) exit 2 ;;
esac
[ "${#revision}" -eq 64 ] || exit 2

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

awk -F '	' -v scenario="$scenario" '$1 == scenario' "$template" |
while IFS='	' read -r scenario_id gate_set position gate_id \
    evidence_source placeholder disposition reason evaluator
do
    [ "$placeholder" = "{evidence-sha256}" ] &&
        [ "$disposition" = "PASS" ] &&
        [ "$reason" = "-" ] &&
        [ "$evaluator" = "{evaluator-revision}" ] || exit 1

    evidence_list="$tmp/evidence-list.tsv"
    : > "$evidence_list"
    printf '%s\n' "$evidence_source" | tr '+' '\n' |
    while IFS= read -r name
    do
        file="$artifact_dir/$name"
        [ -f "$file" ] && [ ! -L "$file" ] || exit 1
        printf '%s\t%s\t%s\n' "$name" \
            "$(sha256sum "$file" | awk '{ print $1 }')" \
            "$(wc -c < "$file" | tr -d ' ')" \
            >> "$evidence_list"
    done

    evidence_sha=$(LC_ALL=C sort "$evidence_list" | sha256sum |
        awk '{ print $1 }')
    printf '%s\t%s\t%s\t%s\t%s\t%s\tPASS\t-\t%s\n' \
        "$scenario_id" "$gate_set" "$position" "$gate_id" \
        "$evidence_source" "$evidence_sha" "$revision"
done
