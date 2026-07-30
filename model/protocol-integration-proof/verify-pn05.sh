#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner="$script_dir/run-protocol-neutral.sh"
vectors="$script_dir/vectors"
expected_provenance="$script_dir/cases/pn05/expected-provenance.tsv"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

"$runner" sqlite-provider-v1 valid \
    >"$tmp/actual.tsv" 2>"$tmp/stderr"
[ ! -s "$tmp/stderr" ] || {
    echo PN05_UNEXPECTED_STDERR >&2
    exit 1
}

awk -F '	' '$1 == "value" || $1 == "relation"' \
    "$tmp/actual.tsv" >"$tmp/actual-projection.tsv"
cmp -s "$vectors/expected-projection.tsv" \
    "$tmp/actual-projection.tsv" || {
    echo PN05_PROJECTION_MISMATCH >&2
    exit 1
}

awk -F '	' \
    '$2 == "context_ref" ||
     $2 == "credential_authority_ref" ||
     $2 == "credential_store_revision" ||
     $2 == "definition_ref" ||
     $2 == "profile_ref" ||
     $2 == "root_ref"' \
    "$tmp/actual.tsv" >"$tmp/actual-provenance.tsv"
cmp -s "$expected_provenance" "$tmp/actual-provenance.tsv" || {
    echo PN05_PROVENANCE_MISMATCH >&2
    exit 1
}

cut -f2 "$vectors/forbidden-sentinels.tsv" >"$tmp/forbidden"
if grep -F -f "$tmp/forbidden" "$tmp/actual.tsv" >/dev/null
then
    echo PN05_FORBIDDEN_SENTINEL >&2
    exit 1
fi

echo 'PN05 projection-provenance sqlite-provider-v1 PASS'
