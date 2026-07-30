#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
provider_dir=${1:-"$script_dir/providers/flatfile-posix-provider-v1"}
vectors="$script_dir/vectors"

[ -d "$provider_dir" ] && [ -x "$provider_dir/run.sh" ] || {
    echo PROVIDER_INDEPENDENCE_SOURCE_MISSING >&2
    exit 1
}
if find "$provider_dir" -type l -print -quit | grep . >/dev/null
then
    echo NON_SQLITE_PROVIDER_USES_SQLITE >&2
    exit 1
fi
if grep -R -E -i \
    'sqlite3|[.]sqlite|sqlite-provider-v1|providers/sqlite-provider|PI_N14_SQLITE' \
    "$provider_dir" >/dev/null
then
    echo NON_SQLITE_PROVIDER_USES_SQLITE >&2
    exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
{
    cat "$vectors/expected-accepted.tsv"
    cat "$vectors/expected-projection.tsv"
} | LC_ALL=C sort >"$tmp/expected.tsv"
"$provider_dir/run.sh" valid >"$tmp/actual.tsv" 2>"$tmp/stderr"
[ ! -s "$tmp/stderr" ] || {
    echo PROVIDER_INDEPENDENCE_UNEXPECTED_STDERR >&2
    exit 1
}
cmp -s "$tmp/expected.tsv" "$tmp/actual.tsv" || {
    echo PROVIDER_INDEPENDENCE_OUTCOME_INVALID >&2
    exit 1
}

echo NON_SQLITE_PROVIDER_INDEPENDENCE_VALID
