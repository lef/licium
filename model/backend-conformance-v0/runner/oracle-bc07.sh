#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)

[ "$#" -eq 4 ] || exit 2
artifact_dir=$1
assertion=$2
case_id=$3
scenario=$4

case "$assertion:$case_id" in
    BC07_EFFECT_101:case-bc07-effect)
        marker=BC07_EFFECT_AXIS_MISMATCH_DETECTED ;;
    BC07_OBSERVATION_WITHOUT_TRANSITION:case-bc07-orphan)
        marker=BC07_ORPHAN_OBSERVATION_DETECTED ;;
    BC07_ORDINARY_000:case-bc07-ordinary)
        marker=BC07_ORDINARY_AXIS_WRITE_DETECTED ;;
    BC07_RECORD_IMPLIES_EFFECT:case-bc07-record-effect)
        marker=BC07_RECORD_STATE_EFFECT_DETECTED ;;
    BC07_RECORD_ONLY_010:case-bc07-record)
        marker=BC07_RECORD_AXIS_MISMATCH_DETECTED ;;
    BC07_RESULT_REWRITE:case-bc07-rewrite)
        marker=BC07_RESULT_REWRITE_DETECTED ;;
    *) exit 2 ;;
esac

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

for stage in before after reopened
do
    awk -F '	' -v scenario="$scenario" '$1 == scenario' \
        "$base_dir/bc07-inventory-$stage.tsv" >"$tmp/$stage.expected"
    LC_ALL=C sort "$artifact_dir/inventory-$stage.tsv" \
        >"$tmp/$stage.actual"
    cmp -s "$tmp/$stage.expected" "$tmp/$stage.actual" || {
        echo "$marker" >&2
        exit 1
    }
done

awk -F '	' -v scenario="$scenario" '$1 == scenario' \
    "$base_dir/bc07-normalized-contract.tsv" >"$tmp/normalized.expected"
LC_ALL=C sort "$artifact_dir/normalized-observations.tsv" \
    >"$tmp/normalized.actual"
cmp -s "$tmp/normalized.expected" "$tmp/normalized.actual" || {
    echo "$marker" >&2
    exit 1
}

printf '%s\toracle-%s\tPASS\tnorm-bc07-observation\tnormal\t-\n' \
    "$assertion" "$(printf '%s' "$assertion" |
        tr '[:upper:]_' '[:lower:]-')"
