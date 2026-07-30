#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
cases="$base_dir/bc06-cases.tsv"
runtime_verifier="$script_dir/verify-bc06-runtime.sh"
adapter="$base_dir/profiles/sqlite-reference/run.sh"

[ "$#" -eq 1 ] || {
    echo "usage: verify-bc06-session.sh SESSION_DIR" >&2
    exit 2
}

session_dir=$1
run_a="$session_dir/run-a"
run_b="$session_dir/run-b"

fail()
{
    echo "$1" >&2
    exit 1
}

[ -d "$run_a" ] && [ -d "$run_b" ] ||
    fail BC06_SESSION_ARTIFACT_MISSING

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

: >"$tmp/canonical-a"
: >"$tmp/canonical-b"

while IFS='	' read -r assertion kind normal_mode control_mode count disposition
do
    name=$(printf '%s' "$assertion" | tr 'A-Z_' 'a-z-')
    dir_a="$run_a/$name"
    dir_b="$run_b/$name"
    ns_a="ns-a-$name"
    ns_b="ns-b-$name"
    [ -d "$dir_a" ] && [ -d "$dir_b" ] ||
        fail BC06_SESSION_ARTIFACT_MISSING

    awk -F '	' -v assertion="$assertion" -v ns="$ns_a" '
        NF != 11 || $1 != "run-a" || $2 != ns || $3 != assertion { exit 1 }
        { count++ }
        END { if (count != 2) exit 1 }
    ' "$dir_a/action-receipts.tsv" ||
        fail BC06_COPIED_RUN_DETECTED
    awk -F '	' -v assertion="$assertion" -v ns="$ns_b" '
        NF != 11 || $1 != "run-b" || $2 != ns || $3 != assertion { exit 1 }
        { count++ }
        END { if (count != 2) exit 1 }
    ' "$dir_b/action-receipts.tsv" ||
        fail BC06_COPIED_RUN_DETECTED

    awk -F '	' '{ print $11 }' "$dir_a/action-receipts.tsv" |
        LC_ALL=C sort >"$tmp/nonces-a"
    awk -F '	' '{ print $11 }' "$dir_b/action-receipts.tsv" |
        LC_ALL=C sort >"$tmp/nonces-b"
    cmp -s "$tmp/nonces-a" "$tmp/nonces-b" &&
        fail BC06_COPIED_RUN_DETECTED

    for relation in \
        inventory-before.tsv \
        inventory-after.tsv \
        raw-observations.tsv \
        normalized-observations.tsv \
        coverage.tsv \
        oracle-result.tsv
    do
        printf 'relation\t%s\t%s\n' "$assertion" "$relation" \
            >>"$tmp/canonical-a"
        LC_ALL=C sort "$dir_a/$relation" >>"$tmp/canonical-a"
        printf 'relation\t%s\t%s\n' "$assertion" "$relation" \
            >>"$tmp/canonical-b"
        LC_ALL=C sort "$dir_b/$relation" >>"$tmp/canonical-b"
    done
done <"$cases"

cmp -s "$tmp/canonical-a" "$tmp/canonical-b" ||
    fail BC06_SECOND_RUN_DRIFT_DETECTED

lifecycle="$session_dir/lifecycle"
[ "$(cat "$session_dir/lifecycle-command-receipt.tsv")" = \
    "status	lifecycle-sentinel	put	run-a	sentinel-a" ] ||
    fail BC06_SENTINEL_LEAK_DETECTED
"$adapter" lifecycle-sentinel "$lifecycle" observe run-a sentinel-a \
    >"$tmp/sentinel-a.tsv" || fail BC06_SENTINEL_LEAK_DETECTED
"$adapter" lifecycle-sentinel "$lifecycle" observe run-b sentinel-a \
    >"$tmp/sentinel-b.tsv" || fail BC06_SENTINEL_LEAK_DETECTED
cmp -s "$tmp/sentinel-a.tsv" "$run_a/namespace-inventory.tsv" ||
    fail BC06_SENTINEL_LEAK_DETECTED
cmp -s "$tmp/sentinel-b.tsv" "$run_b/namespace-inventory.tsv" ||
    fail BC06_SENTINEL_LEAK_DETECTED
[ "$(cat "$tmp/sentinel-a.tsv")" = \
    "run-a	lifecycle-sentinel	sentinel-a	present" ] ||
    fail BC06_SENTINEL_LEAK_DETECTED
[ "$(cat "$tmp/sentinel-b.tsv")" = \
    "run-b	lifecycle-sentinel	sentinel-a	absent" ] ||
    fail BC06_SENTINEL_LEAK_DETECTED

while IFS='	' read -r assertion kind normal_mode control_mode count disposition
do
    name=$(printf '%s' "$assertion" | tr 'A-Z_' 'a-z-')
    "$runtime_verifier" "$run_a/$name" run-a "ns-a-$name" \
        "$assertion" "$run_a/$name/ns-a-$name.db" >/dev/null
    "$runtime_verifier" "$run_b/$name" run-b "ns-b-$name" \
        "$assertion" "$run_b/$name/ns-b-$name.db" >/dev/null
done <"$cases"

echo BC06_SESSION_VALID
