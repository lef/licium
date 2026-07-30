#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
materializer="$script_dir/materialize-bc06-run-controls.sh"

[ "$#" -eq 2 ] || {
    echo "usage: verify-bc06-run-controls.sh RUN_DIR RUN_ID" >&2
    exit 2
}

run_dir=$1
run_id=$2
actual="$run_dir/control-receipts.tsv"
[ -f "$actual" ] || {
    echo BC06_RUN_CONTROL_RECEIPT_MISSING >&2
    exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
"$materializer" "$run_dir" "$run_id" "$tmp/expected.tsv"
cmp -s "$actual" "$tmp/expected.tsv" || {
    echo BC06_RUN_CONTROL_RECEIPT_INVALID >&2
    exit 1
}

echo BC06_RUN_CONTROLS_VALID
