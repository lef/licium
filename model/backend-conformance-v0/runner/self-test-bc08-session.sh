#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner="$script_dir/run-bc08-session.sh"
verifier="$script_dir/verify-bc08-session.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

output=$("$runner" "$tmp/session")
[ "$output" = BC08_SESSION_VALID ] || exit 1
echo "ok BC08_SESSION_VALID"

cp -R "$tmp/session" "$tmp/drift"
target="$tmp/drift/run-b/bc08-complete-effect/coverage.tsv"
awk -F '	' 'BEGIN { OFS=FS }
    NR==1 {$5="obs-002"}
    NR==2 {$5="obs-001"}
    {print}' \
    "$target" >"$tmp/edit"
mv "$tmp/edit" "$target"
set +e
output=$("$verifier" "$tmp/drift" 2>&1)
status=$?
set -e
[ "$status" -ne 0 ] &&
    [ "$(printf '%s\n' "$output" | tail -n 1)" = \
        BC08_SECOND_RUN_DRIFT_DETECTED ] || exit 1
echo "ok BC08_SECOND_RUN_DRIFT_DETECTED"

cp -R "$tmp/session" "$tmp/fault-drift"
target="$tmp/fault-drift/run-b/bc08-mid-boundary-failure/fault-configuration-receipts.tsv"
awk -F '	' 'BEGIN { OFS=FS }
    NR==1 {$11="0000000000000000000000000000000000000000000000000000000000000000"}
    {print}' "$target" >"$tmp/edit"
mv "$tmp/edit" "$target"
set +e
output=$("$verifier" "$tmp/fault-drift" 2>&1)
status=$?
set -e
[ "$status" -ne 0 ] &&
    [ "$(printf '%s\n' "$output" | tail -n 1)" = \
        BC08_SECOND_RUN_DRIFT_DETECTED ] || exit 1
echo "ok BC08_FAULT_RECEIPT_DRIFT_DETECTED"

set +e
output=$("$runner" "$tmp/session" 2>&1)
status=$?
set -e
[ "$status" -ne 0 ] && [ "$output" = BC08_SESSION_NOT_FRESH ] || exit 1
echo "ok BC08_SESSION_NOT_FRESH"
