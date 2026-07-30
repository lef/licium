#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner="$script_dir/run-protocol-neutral.sh"
expected="$script_dir/vectors/expected-projection.tsv"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

for run_id in a b c
do
    "$runner" sqlite-provider-v1 valid \
        >"$tmp/full-$run_id.tsv" 2>"$tmp/stderr-$run_id"
    [ ! -s "$tmp/stderr-$run_id" ] || {
        echo "PN06_UNEXPECTED_STDERR $run_id" >&2
        exit 1
    }
    awk -F '	' '$1 == "value" || $1 == "relation"' \
        "$tmp/full-$run_id.tsv" >"$tmp/semantic-$run_id.tsv"
done

if ! cmp -s "$tmp/semantic-a.tsv" "$tmp/semantic-b.tsv" ||
    ! cmp -s "$tmp/semantic-a.tsv" "$tmp/semantic-c.tsv"
then
    echo PN06_SEMANTIC_REPLAY_MISMATCH >&2
    exit 1
fi
cmp -s "$expected" "$tmp/semantic-a.tsv" || {
    echo PN06_SEMANTIC_ORACLE_MISMATCH >&2
    exit 1
}

echo 'PN06 fixed-input-semantic-replay sqlite-provider-v1 PASS'
