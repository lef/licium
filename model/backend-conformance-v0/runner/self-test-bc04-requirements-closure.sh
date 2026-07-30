#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
model_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd)
verifier="$script_dir/verify-bc04-requirements-closure.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

[ "$("$verifier")" = BC04_REQUIREMENTS_CLOSURE_VALID ] || {
    echo BC04_REQUIREMENTS_CLOSURE_BASELINE_INVALID >&2
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
            ' "$work/backend-conformance-v0/requirements-closure-bc04.tsv" \
                >"$work/manifest.tmp"
            mv "$work/manifest.tmp" \
                "$work/backend-conformance-v0/requirements-closure-bc04.tsv"
            ;;
        included-digest)
            printf '\nclosure mutation\n' >>"$work/BC04-SQLITE-SLICE.md"
            ;;
        included-mode)
            chmod 755 "$work/backend-conformance-v0/bc04-cases.tsv"
            ;;
        included-symlink)
            mv "$work/backend-conformance-v0/bc04-cases.tsv" \
                "$work/backend-conformance-v0/bc04-cases-target.tsv"
            ln -s bc04-cases-target.tsv \
                "$work/backend-conformance-v0/bc04-cases.tsv"
            ;;
        *)
            echo "unknown control: $id" >&2
            exit 1
            ;;
    esac

    set +e
    output=$(
        "$work/backend-conformance-v0/runner/verify-bc04-requirements-closure.sh" \
            2>&1
    )
    status=$?
    set -e
    [ "$status" -ne 0 ] || {
        echo "BC04 closure control unexpectedly passed: $id" >&2
        exit 1
    }
    actual=$(printf '%s\n' "$output" | tail -n 1)
    [ "$actual" = "$expected" ] || {
        echo "BC04 closure control returned $actual, expected $expected: $id" >&2
        exit 1
    }
    printf '%s\n' "$id"
}

run_control manifest-tamper BC04_REQUIREMENTS_CLOSURE_MANIFEST_INVALID
run_control included-digest BC04_REQUIREMENTS_CLOSURE_FILE_DIGEST_INVALID
run_control included-mode BC04_REQUIREMENTS_CLOSURE_FILE_MODE_INVALID
run_control included-symlink BC04_REQUIREMENTS_CLOSURE_FILE_MISSING

echo "4 BC04 requirements closure mutations detected"
