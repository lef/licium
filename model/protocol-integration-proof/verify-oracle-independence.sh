#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
vectors="$script_dir/vectors"
extra_source=${1:-}

for name in expected-accepted.tsv expected-projection.tsv expected-rejected.tsv
do
    bound=$(awk -F '\t' -v name="$name" '$1 == name { print $2 }' \
        "$vectors/vector-bindings.tsv")
    actual=$(sha256sum "$vectors/$name" | cut -d' ' -f1)
    [ -n "$bound" ] && [ "$actual" = "$bound" ] || {
        echo ORACLE_BINDING_INVALID >&2
        exit 1
    }
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
find "$script_dir" -type f \( -name '*.sh' -o -name '*.mjs' \) \
    ! -name 'self-test-*' \
    ! -name 'verify-oracle-independence.sh' \
    -print >"$tmp/sources"
if [ -n "$extra_source" ]
then
    [ -f "$extra_source" ] || {
        echo ORACLE_SOURCE_MISSING >&2
        exit 1
    }
    printf '%s\n' "$extra_source" >>"$tmp/sources"
fi

while IFS= read -r source
do
    if grep -E \
        '(^|[[:space:]])(cp|mv|tee)([[:space:]].*)?(vectors/)?expected-(accepted|projection|rejected)[.]tsv|>[^#]*(vectors/)?expected-(accepted|projection|rejected)[.]tsv' \
        "$source" >/dev/null
    then
        echo ORACLE_DERIVED_FROM_SUT >&2
        exit 1
    fi
done <"$tmp/sources"

echo ORACLE_INDEPENDENCE_VALID
