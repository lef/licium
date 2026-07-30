#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
model_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd)
verifier="$script_dir/verify-bc11-requirements-closure.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

[ "$("$verifier")" = BC11_REQUIREMENTS_CLOSURE_VALID ] || {
    echo BC11_REQUIREMENTS_CLOSURE_BASELINE_INVALID >&2
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
            sed '1s/BC11/BCXX/' \
                "$work/backend-conformance-v0/requirements-closure-bc11.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/requirements-closure-bc11.tsv"
            ;;
        included-digest)
            sed '1s/^/# closure digest mutation\n/' \
                "$work/BC11-SQLITE-SLICE.md" >"$work/mutant.tmp"
            mv "$work/mutant.tmp" "$work/BC11-SQLITE-SLICE.md"
            ;;
        included-mode)
            chmod 755 "$work/backend-conformance-v0/bc11-cases.tsv"
            ;;
        included-symlink)
            mv "$work/backend-conformance-v0/bc11-cases.tsv" \
                "$work/backend-conformance-v0/bc11-cases-target.tsv"
            ln -s bc11-cases-target.tsv \
                "$work/backend-conformance-v0/bc11-cases.tsv"
            ;;
        *)
            echo "unknown control: $id" >&2
            exit 1
            ;;
    esac

    set +e
    output=$(
        "$work/backend-conformance-v0/runner/verify-bc11-requirements-closure.sh" \
            2>&1
    )
    status=$?
    set -e
    [ "$status" -ne 0 ] || {
        echo "BC11 requirements closure control unexpectedly passed: $id" >&2
        exit 1
    }
    [ "$output" = "$expected" ] || {
        echo "BC11 requirements closure control returned $output, expected $expected: $id" >&2
        exit 1
    }
    printf '%s\n' "$id"
}

run_control manifest-tamper BC11_REQUIREMENTS_CLOSURE_MANIFEST_INVALID
run_control included-digest BC11_REQUIREMENTS_CLOSURE_FILE_DIGEST_INVALID
run_control included-mode BC11_REQUIREMENTS_CLOSURE_FILE_MODE_INVALID
run_control included-symlink BC11_REQUIREMENTS_CLOSURE_FILE_MISSING

echo "4 BC11 requirements closure mutations detected"
