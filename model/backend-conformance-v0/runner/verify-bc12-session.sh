#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL

[ "$#" -eq 1 ] || exit 2
session_dir=$1

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
runtime_verifier="$script_dir/verify-bc12-runtime.sh"
run_a="$session_dir/run-a"
run_b="$session_dir/run-b"

fail()
{
    echo "$1" >&2
    exit 1
}

[ -d "$run_a" ] && [ ! -L "$run_a" ] &&
    [ -d "$run_b" ] && [ ! -L "$run_b" ] ||
    fail BC12_SESSION_ARTIFACT_MISSING

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
: >"$tmp/canonical-a"
: >"$tmp/canonical-b"

while IFS='	' read -r assertion _ scenario
do
    name=$(printf '%s' "$assertion" | tr 'A-Z_' 'a-z-')
    dir_a="$run_a/$name"
    dir_b="$run_b/$name"
    ns_a="ns-a-$name"
    ns_b="ns-b-$name"
    [ -d "$dir_a" ] && [ ! -L "$dir_a" ] &&
        [ -d "$dir_b" ] && [ ! -L "$dir_b" ] ||
        fail BC12_SESSION_ARTIFACT_MISSING

    awk -F '	' -v run=run-a -v ns="$ns_a" \
        -v scenario="$scenario" -v assertion="$assertion" '
        NF != 12 || $1 != run || $2 != ns || $3 != scenario ||
            $4 != assertion || $12 != "action-" run { exit 1 }
        END { if (NR != 1) exit 1 }
    ' "$dir_a/action-receipts.tsv" || fail BC12_COPIED_RUN_DETECTED
    awk -F '	' -v run=run-b -v ns="$ns_b" \
        -v scenario="$scenario" -v assertion="$assertion" '
        NF != 12 || $1 != run || $2 != ns || $3 != scenario ||
            $4 != assertion || $12 != "action-" run { exit 1 }
        END { if (NR != 1) exit 1 }
    ' "$dir_b/action-receipts.tsv" || fail BC12_COPIED_RUN_DETECTED

    nonce_a=$(awk -F '	' '{ print $12 }' "$dir_a/action-receipts.tsv")
    nonce_b=$(awk -F '	' '{ print $12 }' "$dir_b/action-receipts.tsv")
    [ "$nonce_a" != "$nonce_b" ] || fail BC12_COPIED_RUN_DETECTED

    for relation in coverage.tsv normalized-observations.tsv \
        oracle-result.tsv raw-observations.tsv
    do
        printf 'relation\t%s\t%s\n' "$assertion" "$relation" \
            >>"$tmp/canonical-a"
        sort "$dir_a/$relation" >>"$tmp/canonical-a"
        printf 'relation\t%s\t%s\n' "$assertion" "$relation" \
            >>"$tmp/canonical-b"
        sort "$dir_b/$relation" >>"$tmp/canonical-b"
    done
done <"$base_dir/bc12-scenario-ids.tsv"

cmp -s "$tmp/canonical-a" "$tmp/canonical-b" ||
    fail BC12_SECOND_RUN_DRIFT_DETECTED

while IFS='	' read -r assertion _ scenario
do
    name=$(printf '%s' "$assertion" | tr 'A-Z_' 'a-z-')
    "$runtime_verifier" "$run_a/$name" run-a "ns-a-$name" \
        "$assertion" "$scenario" >/dev/null
    "$runtime_verifier" "$run_b/$name" run-b "ns-b-$name" \
        "$assertion" "$scenario" >/dev/null
done <"$base_dir/bc12-scenario-ids.tsv"

for run in run-a run-b
do
    expected_count=$(wc -l <"$base_dir/bc12-scenario-ids.tsv" | tr -d ' ')
    [ ! -L "$session_dir/$run/runtime-status.tsv" ] &&
        [ "$(stat -c '%a' "$session_dir/$run/runtime-status.tsv")" = 644 ] ||
        fail BC12_SESSION_ARTIFACT_INVALID
    awk -F '	' -v expected_count="$expected_count" '
        NF != 2 || $2 != "BC12_RUNTIME_VALID" || seen[$1]++ { exit 1 }
        END { if (NR != expected_count) exit 1 }
    ' "$session_dir/$run/runtime-status.tsv" ||
        fail BC12_SESSION_ARTIFACT_INVALID
done

echo BC12_SESSION_VALID
