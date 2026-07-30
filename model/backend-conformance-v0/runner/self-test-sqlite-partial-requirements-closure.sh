#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
model_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd)
verifier="$script_dir/verify-sqlite-partial-requirements-closure.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

[ "$("$verifier")" = SQLITE_PARTIAL_REQUIREMENTS_CLOSURE_VALID ] || {
    echo SQLITE_PARTIAL_REQUIREMENTS_CLOSURE_BASELINE_INVALID >&2
    exit 1
}

run_control()
{
    id=$1
    expected=$2
    work="$tmp/$id"
    cp -R "$model_dir" "$work"

    case "$id" in
        manifest-tamper)
            awk -F '	' 'BEGIN { OFS = "\t" }
                NR == 1 {
                    $3 = "0000000000000000000000000000000000000000000000000000000000000000"
                }
                { print }
            ' "$work/backend-conformance-v0/requirements-closure-sqlite-partial.tsv" \
                > "$work/manifest.tmp"
            mv "$work/manifest.tmp" \
                "$work/backend-conformance-v0/requirements-closure-sqlite-partial.tsv"
            ;;
        included-digest)
            printf '\nclosure mutation\n' >> \
                "$work/SQLITE-PARTIAL-SESSION.md"
            ;;
        included-mode)
            chmod 755 \
                "$work/backend-conformance-v0/sqlite-partial-scenarios.tsv"
            ;;
        included-symlink)
            mv "$work/backend-conformance-v0/sqlite-partial-scenarios.tsv" \
                "$work/backend-conformance-v0/scenarios-target.tsv"
            ln -s scenarios-target.tsv \
                "$work/backend-conformance-v0/sqlite-partial-scenarios.tsv"
            ;;
        *)
            echo "unknown control: $id" >&2
            exit 1
            ;;
    esac

    set +e
    output=$(
        "$work/backend-conformance-v0/runner/verify-sqlite-partial-requirements-closure.sh" \
            2>&1
    )
    status=$?
    set -e
    [ "$status" -ne 0 ] || {
        echo "closure control unexpectedly passed: $id" >&2
        exit 1
    }
    actual=$(printf '%s\n' "$output" | tail -n 1)
    [ "$actual" = "$expected" ] || {
        echo "closure control returned $actual, expected $expected: $id" >&2
        exit 1
    }
    printf '%s\n' "$id"
}

run_control manifest-tamper \
    SQLITE_PARTIAL_REQUIREMENTS_CLOSURE_MANIFEST_INVALID
run_control included-digest \
    SQLITE_PARTIAL_REQUIREMENTS_CLOSURE_FILE_DIGEST_INVALID
run_control included-mode \
    SQLITE_PARTIAL_REQUIREMENTS_CLOSURE_FILE_MODE_INVALID
run_control included-symlink \
    SQLITE_PARTIAL_REQUIREMENTS_CLOSURE_FILE_MISSING

echo "4 SQLite partial requirements closure mutations detected"
