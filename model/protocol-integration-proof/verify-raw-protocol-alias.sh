#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
trace=${1:-"$script_dir/cases/request-envelope/expected-trace.tsv"}
backend_log=${2:-/dev/null}
source_dir=${3:-"$script_dir/providers/sqlite-provider-v1"}
expected="$script_dir/cases/request-envelope/expected-trace.tsv"
mapping="$script_dir/vectors/adapter-mapping-policy.tsv"

[ -f "$trace" ] && [ -e "$backend_log" ] && [ -d "$source_dir" ] || {
    echo RAW_ALIAS_INPUT_MISSING >&2
    exit 1
}
raw=$(mktemp)
trap 'rm -f "$raw"' EXIT HUP INT TERM
cut -f2-4 "$mapping" | tr '\t' '\n' >"$raw"

if grep -F -f "$raw" "$trace" >/dev/null
then
    echo RAW_PROTOCOL_VALUE_ALIAS >&2
    exit 1
fi
cmp -s "$expected" "$trace" || {
    echo RAW_ALIAS_REQUEST_SHAPE_INVALID >&2
    exit 1
}
if grep -R -F -f "$raw" "$source_dir" >/dev/null ||
    grep -F -f "$raw" "$backend_log" >/dev/null
then
    echo RAW_ALIAS_POSTCONDITION_INVALID >&2
    exit 1
fi

echo RAW_PROTOCOL_ALIAS_BOUNDARY_VALID
