#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
core="$script_dir/verify-sqlite-partial-session-core.sh"
controls="$script_dir/materialize-sqlite-partial-session-controls.sh"
envelope="$script_dir/verify-sealed-run.sh"

[ "$#" -eq 2 ] || {
    echo "usage: verify-sqlite-partial-session.sh SESSION_DIR preseal|sealed" >&2
    exit 2
}

session_dir=$1
stage=$2
"$core" "$session_dir" "$stage" >/dev/null

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
"$controls" "$session_dir" "$tmp/control-receipts.tsv"
cmp -s "$tmp/control-receipts.tsv" "$session_dir/control-receipts.tsv" ||
    { echo SQLITE_PARTIAL_SESSION_CONTROL_RECEIPT_INVALID >&2; exit 1; }

[ "$stage" = preseal ] ||
    LICIUM_PARTIAL_ENVELOPE_ONLY=1 "$envelope" "$session_dir" >/dev/null

echo SQLITE_PARTIAL_SESSION_VALID
