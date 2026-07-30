#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner="$script_dir/run-bc06-session.sh"
verifier="$script_dir/verify-bc06-session.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

output=$("$runner" "$tmp/baseline")
[ "$output" = "BC06_SESSION_VALID" ] || {
    echo "wrong BC06 session baseline: $output" >&2
    exit 1
}
echo "ok BC06_SESSION_VALID"

cp -R "$tmp/baseline" "$tmp/copied"
cp -R "$tmp/copied/run-a/." "$tmp/copied/run-b/"
set +e
output=$("$verifier" "$tmp/copied" 2>&1)
status=$?
set -e
[ "$status" -ne 0 ] && [ "$output" = "BC06_COPIED_RUN_DETECTED" ] || {
    echo "copied run wrong result: $status $output" >&2
    exit 1
}
echo "ok BC06_COPIED_RUN_DETECTED"

cp -R "$tmp/baseline" "$tmp/drift"
target="$tmp/drift/run-b/bc06-pure-zero-axes/normalized-observations.tsv"
sed 's/public-a/public-b/' "$target" >"$tmp/drift.tsv"
cp "$tmp/drift.tsv" "$target"
set +e
output=$("$verifier" "$tmp/drift" 2>&1)
status=$?
set -e
[ "$status" -ne 0 ] &&
    [ "$output" = "BC06_SECOND_RUN_DRIFT_DETECTED" ] || {
    echo "second run drift wrong result: $status $output" >&2
    exit 1
}
echo "ok BC06_SECOND_RUN_DRIFT_DETECTED"

cp -R "$tmp/baseline" "$tmp/sentinel"
cp "$tmp/sentinel/lifecycle/run-a/sentinel-a" \
    "$tmp/sentinel/lifecycle/run-b/sentinel-a"
set +e
output=$("$verifier" "$tmp/sentinel" 2>&1)
status=$?
set -e
[ "$status" -ne 0 ] &&
    [ "$output" = "BC06_SENTINEL_LEAK_DETECTED" ] || {
    echo "sentinel leak wrong result: $status $output" >&2
    exit 1
}
echo "ok BC06_SENTINEL_LEAK_DETECTED"

echo "3 BC06 session controls detected"
