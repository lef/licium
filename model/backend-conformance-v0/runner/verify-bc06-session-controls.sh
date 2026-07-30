#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
materializer="$script_dir/materialize-bc06-session-controls.sh"

[ "$#" -eq 1 ] || {
    echo "usage: verify-bc06-session-controls.sh SESSION_DIR" >&2
    exit 2
}

session_dir=$1
actual="$session_dir/control-receipts.tsv"
[ -f "$actual" ] || {
    echo BC06_SESSION_CONTROL_RECEIPT_MISSING >&2
    exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
"$materializer" "$session_dir" "$tmp/expected.tsv"
cmp -s "$actual" "$tmp/expected.tsv" || {
    echo BC06_SESSION_CONTROL_RECEIPT_INVALID >&2
    exit 1
}

echo BC06_SESSION_CONTROLS_VALID
