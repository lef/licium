#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner="$script_dir/run-oidc-integration.sh"
case_dir="$script_dir/cases/oi06-pn15"
mapping="$script_dir/vectors/adapter-mapping-policy.tsv"
adapter_mapping="$script_dir/adapters/oidc-provider-v1/mapping-policy.tsv"
node=${NODE:-node}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
evidence="$tmp/evidence"
mkdir "$evidence"

cmp -s "$mapping" "$adapter_mapping" || {
    echo OI06_MAPPING_POLICY_BINDING_MISMATCH >&2
    exit 1
}

OIDC_EVIDENCE_DIR="$evidence" NODE="$node" \
    "$runner" sqlite-provider-v1 \
    >"$tmp/oidc.tsv" 2>"$tmp/stderr"
[ ! -s "$tmp/stderr" ] || {
    echo OI06_PN15_UNEXPECTED_STDERR >&2
    exit 1
}

find "$evidence" -mindepth 1 -maxdepth 1 -type f -printf '%f\n' |
    LC_ALL=C sort >"$tmp/actual-inventory"
cmp -s "$case_dir/surface-inventory.txt" "$tmp/actual-inventory" || {
    echo OI06_EVIDENCE_INVENTORY_MISMATCH >&2
    exit 1
}
while IFS= read -r name
do
    cmp -s "$case_dir/$name" "$evidence/$name" || {
        echo "OI06_EVIDENCE_MISMATCH $name" >&2
        exit 1
    }
done <"$case_dir/surface-inventory.txt"

cut -f2-4 "$mapping" | tr '	' '\n' >"$tmp/raw-protocol-values"
[ "$(wc -l <"$tmp/raw-protocol-values" | tr -d ' ')" -eq 3 ] || {
    echo PN15_RAW_INPUT_PRECONDITION_INVALID >&2
    exit 1
}
if grep -R -F -f "$tmp/raw-protocol-values" "$evidence" \
    "$script_dir/providers/sqlite-provider-v1" >/dev/null
then
    echo PN15_RAW_PROTOCOL_VALUE_LEAK >&2
    exit 1
fi

echo 'OI06 inspectable-provenance-receipt PASS'
echo 'PN15 raw-protocol-backend-surfaces-zero PASS'
