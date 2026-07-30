#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

make_case()
{
    directory=$1
    mkdir -p "$directory/runner"
    cp "$script_dir/materialize-sqlite-partial-assertions.sh" \
        "$directory/runner/"
    cp "$base_dir/scenarios.tsv" "$base_dir/execution-map.tsv" \
        "$base_dir/oracle-registry.tsv" "$directory/"
}

baseline="$tmp/baseline"
make_case "$baseline"
"$baseline/runner/materialize-sqlite-partial-assertions.sh" \
    "$baseline/assertions.tsv"

controls=0

expect_rejected()
{
    name=$1
    mutation=$2
    directory="$tmp/$name"
    make_case "$directory"
    "$mutation" "$directory"
    set +e
    output=$(
        "$directory/runner/materialize-sqlite-partial-assertions.sh" \
            "$directory/assertions.tsv" 2>&1
    )
    status=$?
    set -e
    [ "$status" -ne 0 ] &&
        [ "$output" = "SQLITE_PARTIAL_ASSERTION_REGISTRY_INVALID" ] || {
        printf '%s\n' "$output" >&2
        echo "SQLITE_PARTIAL_ASSERTION_CONTROL_INVALID: $name" >&2
        exit 1
    }
    controls=$((controls + 1))
}

mutate_oracle_drop()
{
    awk -F '	' '$1 != "oracle-bc02-complete-available"' \
        "$1/oracle-registry.tsv" >"$1/oracle-registry.new"
    mv "$1/oracle-registry.new" "$1/oracle-registry.tsv"
}

mutate_oracle_rewire()
{
    awk -F '	' -v OFS='	' '
        $1 == "BC02_COMPLETE_AVAILABLE" { $10 = "oracle-missing" }
        { print }
    ' "$1/execution-map.tsv" >"$1/execution-map.new"
    mv "$1/execution-map.new" "$1/execution-map.tsv"
}

mutate_execution_duplicate()
{
    awk -F '	' '$1 == "BC02_COMPLETE_AVAILABLE" { print; print; next }
        { print }' "$1/execution-map.tsv" >"$1/execution-map.new"
    mv "$1/execution-map.new" "$1/execution-map.tsv"
}

expect_rejected oracle-drop mutate_oracle_drop
expect_rejected oracle-rewire mutate_oracle_rewire
expect_rejected execution-duplicate mutate_execution_duplicate

printf '1 SQLite partial assertion baseline\n'
printf '%s SQLite partial assertion controls detected\n' "$controls"
