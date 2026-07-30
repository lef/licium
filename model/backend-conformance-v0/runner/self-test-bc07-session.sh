#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner="$script_dir/run-bc07-session.sh"
verifier="$script_dir/verify-bc07-session.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

output=$("$runner" "$tmp/baseline")
[ "$output" = BC07_SESSION_VALID ] || {
    echo "wrong BC07 session baseline: $output" >&2
    exit 1
}
echo "ok BC07_SESSION_VALID"

cp -R "$tmp/baseline" "$tmp/copied"
cp -R "$tmp/copied/run-a/." "$tmp/copied/run-b/"
set +e
output=$("$verifier" "$tmp/copied" 2>&1)
status=$?
set -e
[ "$status" -ne 0 ] && [ "$output" = BC07_COPIED_RUN_DETECTED ] || {
    echo "copied run wrong result: $status $output" >&2
    exit 1
}
echo "ok BC07_COPIED_RUN_DETECTED"

cp -R "$tmp/baseline" "$tmp/drift"
target="$tmp/drift/run-b/bc07-effect-101/normalized-observations.tsv"
sed 's/axis-vector	101/axis-vector	100/' "$target" >"$tmp/drift.tsv"
cp "$tmp/drift.tsv" "$target"
set +e
output=$("$verifier" "$tmp/drift" 2>&1)
status=$?
set -e
[ "$status" -ne 0 ] &&
    [ "$output" = BC07_EFFECT_AXIS_MISMATCH_DETECTED ] || {
    echo "semantic drift wrong result: $status $output" >&2
    exit 1
}
echo "ok BC07_EFFECT_AXIS_MISMATCH_DETECTED"

cp -R "$tmp/baseline" "$tmp/canonical-drift"
target="$tmp/canonical-drift/run-b/bc07-effect-101/oracle-result.tsv"
sed 's/	norm-bc07-observation	/	norm-bc07-forged	/' "$target" \
    >"$tmp/canonical-drift.tsv"
cp "$tmp/canonical-drift.tsv" "$target"
set +e
output=$("$verifier" "$tmp/canonical-drift" 2>&1)
status=$?
set -e
[ "$status" -ne 0 ] &&
    [ "$output" = BC07_ORACLE_RESULT_INVALID ] || {
    echo "canonical drift wrong result: $status $output" >&2
    exit 1
}
echo "ok BC07_ORACLE_RESULT_INVALID"

set +e
output=$("$runner" "$tmp/baseline" 2>&1)
status=$?
set -e
[ "$status" -ne 0 ] && [ "$output" = BC07_SESSION_NOT_FRESH ] || exit 1
echo "ok BC07_SESSION_NOT_FRESH"

echo "4 BC07 session controls detected"
