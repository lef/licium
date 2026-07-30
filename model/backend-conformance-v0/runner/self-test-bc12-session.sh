#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner="$script_dir/run-bc12-session.sh"
verifier="$script_dir/verify-bc12-session.sh"

[ -x "$runner" ] && [ -x "$verifier" ] || {
    echo BC12_SESSION_MISSING >&2
    exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

[ "$("$runner" "$tmp/session")" = BC12_SESSION_VALID ] || exit 1
echo BC12_SESSION_VALID

cp -R "$tmp/session" "$tmp/copied"
cp "$tmp/copied/run-a/bc12-placement-decision/action-receipts.tsv" \
    "$tmp/copied/run-b/bc12-placement-decision/action-receipts.tsv"
set +e
output=$("$verifier" "$tmp/copied" 2>&1)
status=$?
set -e
[ "$status" -ne 0 ] && [ "$output" = BC12_COPIED_RUN_DETECTED ] ||
    exit 1
echo BC12_COPIED_RUN_DETECTED

cp -R "$tmp/session" "$tmp/drift"
target="$tmp/drift/run-b/bc12-placement-decision/normalized-observations.tsv"
awk -F '	' 'BEGIN { OFS=FS }
    NR == 1 { $6="forged" }
    { print }
' "$target" >"$tmp/edit"
mv "$tmp/edit" "$target"
set +e
output=$("$verifier" "$tmp/drift" 2>&1)
status=$?
set -e
[ "$status" -ne 0 ] &&
    [ "$output" = BC12_SECOND_RUN_DRIFT_DETECTED ] || exit 1
echo BC12_SECOND_RUN_DRIFT_DETECTED

set +e
output=$("$runner" "$tmp/session" 2>&1)
status=$?
set -e
[ "$status" -ne 0 ] && [ "$output" = BC12_SESSION_NOT_FRESH ] ||
    exit 1
echo BC12_SESSION_NOT_FRESH
echo "3 BC12 session controls detected"
