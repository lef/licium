#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL

[ "$#" -eq 5 ] || {
    echo "usage: oracle-bc11.sh NORMALIZED ASSERTION SCENARIO MODE OUTPUT" >&2
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
    BC11_EXPLANATION_CLOSURE:mutant-detect-explanation-member-loss)
        marker=BC11_EXPLANATION_CLOSURE_LOSS_DETECTED ;;
    BC11_FINDING_CROSS_LINK:mutant-detect-missing-cross-link-finding)
        marker=BC11_FINDING_CROSS_LINK_MISSING ;;
    BC11_FINDING_DANGLING:mutant-detect-missing-dangling-finding)
        marker=BC11_FINDING_DANGLING_MISSING ;;
    BC11_LATEST_SUBSTITUTION:mutant-detect-latest-replay-substitution)
        marker=BC11_LATEST_SUBSTITUTION_MISMATCH_DETECTED ;;
    BC11_MISSING_AS_EMPTY:mutant-detect-replay-missing-as-empty)
        marker=BC11_MISSING_AS_EMPTY_NOT_DETECTED ;;
    BC11_REPLAY_RESULT:mutant-detect-replay-result-drift)
        marker=BC11_REPLAY_RESULT_MISMATCH_DETECTED ;;
    BC11_SILENT_CROSS_LINK:mutant-detect-silent-cross-link-repair)
        marker=BC11_SILENT_CROSS_LINK_DETECTED ;;
    BC11_SILENT_DANGLING:mutant-detect-silent-dangling-repair)
        marker=BC11_SILENT_DANGLING_DETECTED ;;
    BC11_*:ordinary)
        marker=BC11_BASELINE_INVALID ;;
    *) exit 2 ;;
esac

awk -F '	' -v scenario="$scenario" '$1 == scenario' \
    "$base_dir/bc11-normalized-template.tsv" >"$tmp/expected"

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
    ' "$base_dir/bc11-oracle-contract.tsv"
) || exit 2

printf '%s\t%s\tPASS\tnorm-bc11-observation\tnormal\t-\n' \
    "$assertion" "$oracle" >"$output"
