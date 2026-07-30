#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
model_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd)
verifier="$script_dir/verify-bc07-requirements-closure.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

[ "$("$verifier")" = BC07_REQUIREMENTS_CLOSURE_VALID ] || {
    echo BC07_REQUIREMENTS_CLOSURE_BASELINE_INVALID >&2
    exit 1
}

run_control()
{
    id=$1
    expected=$2
    work="$tmp/$id"
    cp -R "$model_dir" "$work"

    case "$id" in
        manifest-digest)
            sed '1s/f65a/0000/' \
                "$work/backend-conformance-v0/requirements-closure-bc07.tsv" \
                >"$work/manifest.tmp"
            mv "$work/manifest.tmp" \
                "$work/backend-conformance-v0/requirements-closure-bc07.tsv"
            ;;
        manifest-mode)
            chmod 755 \
                "$work/backend-conformance-v0/requirements-closure-bc07.tsv"
            ;;
        included-missing)
            rm "$work/backend-conformance-v0/bc07-cases.tsv"
            ;;
        included-mode)
            chmod 755 "$work/backend-conformance-v0/bc07-cases.tsv"
            ;;
        included-digest)
            sed '1s/PASS/FAIL/' \
                "$work/backend-conformance-v0/bc07-cases.tsv" \
                >"$work/cases.tmp"
            mv "$work/cases.tmp" \
                "$work/backend-conformance-v0/bc07-cases.tsv"
            ;;
        included-symlink)
            mv "$work/backend-conformance-v0/bc07-cases.tsv" \
                "$work/backend-conformance-v0/bc07-cases-target.tsv"
            ln -s bc07-cases-target.tsv \
                "$work/backend-conformance-v0/bc07-cases.tsv"
            ;;
        *)
            echo "unknown control: $id" >&2
            exit 1
            ;;
    esac

    set +e
    output=$(
        "$work/backend-conformance-v0/runner/verify-bc07-requirements-closure.sh" \
            2>&1
    )
    status=$?
    set -e
    [ "$status" -ne 0 ] || {
        echo "BC07 closure control unexpectedly passed: $id" >&2
        exit 1
    }
    [ "$output" = "$expected" ] || {
        echo "BC07 closure control returned $output, expected $expected: $id" >&2
        exit 1
    }
    printf '%s\n' "$id"
}

run_control manifest-digest BC07_REQUIREMENTS_CLOSURE_MANIFEST_INVALID
run_control manifest-mode BC07_REQUIREMENTS_CLOSURE_MODE_INVALID
run_control included-missing BC07_REQUIREMENTS_CLOSURE_FILE_MISSING
run_control included-mode BC07_REQUIREMENTS_CLOSURE_FILE_MODE_INVALID
run_control included-digest BC07_REQUIREMENTS_CLOSURE_FILE_DIGEST_INVALID
run_control included-symlink BC07_REQUIREMENTS_CLOSURE_FILE_MISSING

echo "6 BC07 requirements closure mutations detected"
