#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL

[ "$#" -eq 5 ] || {
    echo "usage: oracle-bc10.sh NORMALIZED ASSERTION SCENARIO MODE OUTPUT" >&2
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
    BC10_RESULT_CLOSED:mutant-result-closure-loss)
        marker=BC10_RESULT_CLOSURE_LOSS_DETECTED ;;
    BC10_RESULT_LEAK:mutant-result-secret-leak)
        marker=BC10_RESULT_SECRET_LEAK_DETECTED ;;
    BC10_VIEW_CLOSED:mutant-view-member-loss)
        marker=BC10_VIEW_CLOSURE_LOSS_DETECTED ;;
    BC10_VIEW_LEAK:mutant-view-provenance-loss)
        marker=BC10_VIEW_PROVENANCE_LOSS_DETECTED ;;
    BC10_VIEW_LEAK:mutant-view-secret-leak)
        marker=BC10_VIEW_SECRET_LEAK_DETECTED ;;
    BC10_REPLAY_CLOSED:mutant-replay-closure-loss)
        marker=BC10_REPLAY_CLOSURE_LOSS_DETECTED ;;
    BC10_REPLAY_LEAK:mutant-replay-executor-metadata)
        marker=BC10_REPLAY_METADATA_LEAK_DETECTED ;;
    BC10_EXPLANATION_CLOSED:mutant-explanation-member-loss)
        marker=BC10_EXPLANATION_CLOSURE_LOSS_DETECTED ;;
    BC10_EXPLANATION_LEAK:mutant-explanation-secret-leak)
        marker=BC10_EXPLANATION_SECRET_LEAK_DETECTED ;;
    BC10_*:ordinary)
        marker=BC10_BASELINE_INVALID ;;
    *) exit 2 ;;
esac

awk -F '	' -v scenario="$scenario" '$1 == scenario' \
    "$base_dir/bc10-normalized-template.tsv" >"$tmp/expected"

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
    ' "$base_dir/bc10-oracle-contract.tsv"
) || exit 2

printf '%s\t%s\tPASS\tnorm-bc10-observation\tnormal\t-\n' \
    "$assertion" "$oracle" >"$output"
