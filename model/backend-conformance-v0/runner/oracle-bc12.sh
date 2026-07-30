#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL

[ "$#" -eq 5 ] || {
    echo "usage: oracle-bc12.sh NORMALIZED ASSERTION SCENARIO MODE OUTPUT" >&2
    exit 2
}

normalized=$1
assertion=$2
scenario=$3
mode=$4
output=$5

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

case "$assertion:$mode" in
    BC12_ARCHIVE_BYPASS:mutant-detect-archive-state-bypass)
        marker=BC12_ARCHIVE_BYPASS_NOT_DETECTED ;;
    BC12_CANONICAL_UNCHANGED:mutant-detect-placement-inventory-change)
        marker=BC12_CANONICAL_CHANGED ;;
    BC12_DECISION_PROVENANCE:mutant-detect-decision-provenance-loss)
        marker=BC12_DECISION_PROVENANCE_LOSS ;;
    BC12_DERIVED_PROTECTION:mutant-detect-protection-derivation-loss)
        marker=BC12_DERIVED_PROTECTION_LOSS ;;
    BC12_ELIGIBILITY_DELETE:mutant-detect-eligibility-as-delete)
        marker=BC12_ELIGIBILITY_DELETE_DETECTED ;;
    BC12_FORGET_BYPASS:mutant-detect-forget-bypass)
        marker=BC12_FORGET_BYPASS_NOT_DETECTED ;;
    BC12_FORGET_CONSUMED:mutant-detect-unconsumed-forget)
        marker=BC12_FORGET_NOT_CONSUMED ;;
    BC12_NOOP_EVALUATOR:mutant-detect-noop-placement-evaluator)
        marker=BC12_NOOP_EVALUATOR_DETECTED ;;
    BC12_PLACEMENT_DECISION:mutant-detect-placement-decision-loss)
        marker=BC12_PLACEMENT_DECISION_MISMATCH ;;
    BC12_PROTECTION_BYPASS:mutant-detect-protection-bypass-witness|\
    BC12_PROTECTION_BYPASS:mutant-detect-protection-bypass-conflict|\
    BC12_PROTECTION_BYPASS:mutant-detect-protection-bypass-publication)
        marker=BC12_PROTECTION_BYPASS_NOT_DETECTED ;;
    BC12_WINDOW_BYPASS:mutant-detect-policy-window-bypass)
        marker=BC12_WINDOW_BYPASS_NOT_DETECTED ;;
    BC12_*:ordinary)
        marker=BC12_BASELINE_INVALID ;;
    *) exit 2 ;;
esac

awk -F '	' -v scenario="$scenario" '$1 == scenario' \
    "$base_dir/bc12-normalized-template.tsv" >"$tmp/expected"

awk -F '	' -v scenario="$scenario" '
    NF != 6 || $1 != scenario { exit 1 }
' "$normalized" || {
    echo "$marker" >&2
    exit 1
}

if ! cmp -s "$tmp/expected" "$normalized"; then
    echo "$marker" >&2
    exit 1
fi

oracle=$(
    awk -F '	' -v assertion="$assertion" '
        $1 == assertion && !seen[$2]++ { print $2; found++ }
        END { if (found != 1) exit 1 }
    ' "$base_dir/bc12-oracle-contract.tsv"
) || exit 2

printf '%s\t%s\tPASS\tnorm-bc12-observation\tnormal\t-\n' \
    "$assertion" "$oracle" >"$output"
