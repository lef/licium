#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner=${1:-"$script_dir/run-protocol-neutral.sh"}
proof_dir=$(CDPATH= cd -- "$(dirname -- "$runner")" && pwd)
vectors="$script_dir/vectors"
schema="$proof_dir/providers/sqlite-provider-v1/schema.sql"

[ -f "$schema" ] &&
    [ "$(grep -F -c 'secret-never-project-v1' "$schema")" -eq 2 ] || {
    echo PROTOCOL_NONLEAKAGE_PRECONDITION_INVALID >&2
    exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
surfaces="$tmp/surfaces"
mkdir "$surfaces"

set +e
PROTOCOL_SURFACE_DIR="$surfaces" \
    "$runner" sqlite-provider-v1 surface-bundle \
    >"$tmp/stdout" 2>"$tmp/stderr"
run_status=$?
set -e

cut -f2 "$vectors/forbidden-sentinels.tsv" >"$tmp/forbidden"
for surface in "$tmp/stdout" "$tmp/stderr"
do
    if grep -F -f "$tmp/forbidden" "$surface" >/dev/null
    then
        echo PROTOCOL_SECRET_LEAK >&2
        exit 1
    fi
done
if find "$surfaces" -type f -exec grep -F -f "$tmp/forbidden" {} + \
    >/dev/null
then
    echo PROTOCOL_SECRET_LEAK >&2
    exit 1
fi

[ "$run_status" -eq 0 ] && [ ! -s "$tmp/stderr" ] || {
    echo PROTOCOL_NONLEAKAGE_RUN_INVALID >&2
    exit 1
}
find "$surfaces" -type f -printf '%f\n' | LC_ALL=C sort \
    >"$tmp/actual-inventory"
printf '%s\n' explanation.tsv provider.log result.tsv \
    >"$tmp/expected-inventory"
cmp -s "$tmp/expected-inventory" "$tmp/actual-inventory" || {
    echo PROTOCOL_NONLEAKAGE_INVENTORY_INVALID >&2
    exit 1
}

echo PROTOCOL_NONLEAKAGE_VALID
