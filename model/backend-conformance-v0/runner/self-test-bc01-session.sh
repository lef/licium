#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner="$script_dir/run-bc01-session.sh"
verifier="$script_dir/verify-bc01-session.sh"
controls="$script_dir/materialize-bc01-session-controls.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

session="$tmp/session"
[ "$("$runner" "$session")" = BC01_SESSION_VALID ] || exit 1
[ "$("$verifier" "$session")" = BC01_SESSION_VALID ] || exit 1
"$controls" "$session" "$tmp/control-receipts.tsv"
[ "$(wc -l <"$tmp/control-receipts.tsv" | tr -d ' ')" = 3 ] || exit 1

status_case="$tmp/runtime-status"
cp -R "$session" "$status_case"
sed '1s/BC01_RUNTIME_VALID/BC01_RUNTIME_FORGED/' \
    "$status_case/run-a/runtime-status.tsv" \
    >"$status_case/run-a/runtime-status.tsv.tmp"
mv "$status_case/run-a/runtime-status.tsv.tmp" \
    "$status_case/run-a/runtime-status.tsv"
set +e
status_output=$("$verifier" "$status_case" 2>&1)
status_result=$?
set -e
[ "$status_result" -ne 0 ] &&
    [ "$status_output" = BC01_RUNTIME_STATUS_INVALID ] || exit 1

set +e
fresh=$("$runner" "$session" 2>&1)
status=$?
set -e
[ "$status" -ne 0 ] && [ "$fresh" = BC01_SESSION_NOT_FRESH ] || exit 1

echo "1 BC01 session baseline"
echo "5 BC01 session controls detected"
