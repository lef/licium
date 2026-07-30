#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
scenarios="$base_dir/bc01-scenario-ids.tsv"
runtime_verifier="$script_dir/verify-bc01-runtime.sh"
control_materializer="$script_dir/materialize-bc01-run-controls.sh"
adapter="$base_dir/profiles/sqlite-reference/run.sh"

[ "$#" -eq 1 ] || exit 2
session_dir=$1
run_a="$session_dir/run-a"
run_b="$session_dir/run-b"

fail()
{
    echo "$1" >&2
    exit 1
}

[ -d "$run_a" ] && [ -d "$run_b" ] ||
    fail BC01_SESSION_ARTIFACT_MISSING
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
: >"$tmp/canonical-a"
: >"$tmp/canonical-b"

while IFS='	' read -r assertion case_id scenario
do
    dir_a="$run_a/$scenario"
    dir_b="$run_b/$scenario"
    ns_a="ns-a-$scenario"
    ns_b="ns-b-$scenario"
    [ -d "$dir_a" ] && [ -d "$dir_b" ] ||
        fail BC01_SESSION_ARTIFACT_MISSING
    awk -F '	' -v ns="$ns_a" -v scenario="$scenario" '
        NF != 13 || $1 != "run-a" || $2 != ns || $3 != scenario {
            exit 1
        }
        { count++ }
        END { if (count != 2) exit 1 }
    ' "$dir_a/action-receipts.tsv" || fail BC01_COPIED_RUN_DETECTED
    awk -F '	' -v ns="$ns_b" -v scenario="$scenario" '
        NF != 13 || $1 != "run-b" || $2 != ns || $3 != scenario {
            exit 1
        }
        { count++ }
        END { if (count != 2) exit 1 }
    ' "$dir_b/action-receipts.tsv" || fail BC01_COPIED_RUN_DETECTED
    awk -F '	' '{ print $13 }' "$dir_a/action-receipts.tsv" |
        LC_ALL=C sort >"$tmp/nonces-a"
    awk -F '	' '{ print $13 }' "$dir_b/action-receipts.tsv" |
        LC_ALL=C sort >"$tmp/nonces-b"
    cmp -s "$tmp/nonces-a" "$tmp/nonces-b" &&
        fail BC01_COPIED_RUN_DETECTED

    for relation in inventory-before.tsv inventory-after.tsv \
        inventory-reopened.tsv raw-observations.tsv \
        normalized-observations.tsv coverage.tsv oracle-result.tsv
    do
        printf 'relation\t%s\t%s\n' "$assertion" "$relation" \
            >>"$tmp/canonical-a"
        LC_ALL=C sort "$dir_a/$relation" >>"$tmp/canonical-a"
        printf 'relation\t%s\t%s\n' "$assertion" "$relation" \
            >>"$tmp/canonical-b"
        LC_ALL=C sort "$dir_b/$relation" >>"$tmp/canonical-b"
    done
done <"$scenarios"

for side in a b
do
    run="run-$side"
    awk -F '	' '
        NR == FNR {
            expected[$1] = $3
            next
        }
        NF != 3 || !($1 in expected) || $2 != expected[$1] ||
            $3 != "BC01_RUNTIME_VALID" || seen[$1]++ { exit 1 }
        { count++ }
        END {
            if (count != 5) exit 1
            for (id in expected) if (seen[id] != 1) exit 1
        }
    ' "$scenarios" "$session_dir/$run/runtime-status.tsv" ||
        fail BC01_RUNTIME_STATUS_INVALID
done

cmp -s "$tmp/canonical-a" "$tmp/canonical-b" ||
    fail BC01_SECOND_RUN_DRIFT_DETECTED

lifecycle="$session_dir/lifecycle"
[ "$(cat "$session_dir/lifecycle-command-receipt.tsv")" = \
    "status	lifecycle-sentinel	put	run-a	sentinel-a" ] ||
    fail BC01_SENTINEL_LEAK_DETECTED
"$adapter" lifecycle-sentinel "$lifecycle" observe run-a sentinel-a \
    >"$tmp/sentinel-a.tsv" || fail BC01_SENTINEL_LEAK_DETECTED
"$adapter" lifecycle-sentinel "$lifecycle" observe run-b sentinel-a \
    >"$tmp/sentinel-b.tsv" || fail BC01_SENTINEL_LEAK_DETECTED
cmp -s "$tmp/sentinel-a.tsv" "$run_a/namespace-inventory.tsv" ||
    fail BC01_SENTINEL_LEAK_DETECTED
cmp -s "$tmp/sentinel-b.tsv" "$run_b/namespace-inventory.tsv" ||
    fail BC01_SENTINEL_LEAK_DETECTED
[ "$(cat "$tmp/sentinel-a.tsv")" = \
    "run-a	lifecycle-sentinel	sentinel-a	present" ] ||
    fail BC01_SENTINEL_LEAK_DETECTED
[ "$(cat "$tmp/sentinel-b.tsv")" = \
    "run-b	lifecycle-sentinel	sentinel-a	absent" ] ||
    fail BC01_SENTINEL_LEAK_DETECTED

for side in a b
do
    run="run-$side"
    while IFS='	' read -r assertion case_id scenario
    do
        namespace="ns-$side-$scenario"
        "$runtime_verifier" "$session_dir/$run/$scenario" "$run" \
            "$namespace" "$assertion" "$case_id" "$scenario" \
            "$session_dir/$run/$scenario/nonexistent.db" >/dev/null
    done <"$scenarios"
    "$control_materializer" "$session_dir/$run" "$run" \
        "$tmp/controls-$side.tsv"
    cmp -s "$tmp/controls-$side.tsv" \
        "$session_dir/$run/control-receipts.tsv" ||
        fail BC01_RUN_CONTROL_RECEIPT_INVALID
done

echo BC01_SESSION_VALID
