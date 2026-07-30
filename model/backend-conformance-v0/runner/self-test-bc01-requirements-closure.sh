#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
model_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

run_control()
{
    id=$1
    expected=$2
    work="$tmp/$id"
    cp -R "$model_dir" "$work"

    case "$id" in
        manifest-tamper)
            awk -F '	' 'BEGIN { OFS = "\t" }
                NR == 1 { $3 = "0000000000000000000000000000000000000000000000000000000000000000" }
                { print }
            ' "$work/backend-conformance-v0/requirements-closure-bc01.tsv" \
                > "$work/backend-conformance-v0/requirements-closure-bc01.tsv.tmp"
            mv "$work/backend-conformance-v0/requirements-closure-bc01.tsv.tmp" \
                "$work/backend-conformance-v0/requirements-closure-bc01.tsv"
            ;;
        included-digest)
            printf '\nclosure mutation\n' >> "$work/BC01-SQLITE-SLICE.md"
            ;;
        included-mode)
            chmod 755 "$work/ACCEPTANCE-BACKEND-CONFORMANCE-V0.md"
            ;;
        included-symlink)
            mv "$work/ACCEPTANCE-SQLITE-CONFORMANCE-V0.md" \
                "$work/acceptance-target.md"
            ln -s acceptance-target.md \
                "$work/ACCEPTANCE-SQLITE-CONFORMANCE-V0.md"
            ;;
        *)
            echo "unknown BC01 closure control: $id" >&2
            exit 1
            ;;
    esac

    output=$("$work/backend-conformance-v0/runner/verify-bc01-requirements-closure.sh" \
        2>&1) && {
        echo "BC01 closure control unexpectedly passed: $id" >&2
        exit 1
    }
    actual=$(printf '%s\n' "$output" | tail -n 1)
    [ "$actual" = "$expected" ] || {
        echo "BC01 closure control returned $actual, expected $expected: $id" >&2
        exit 1
    }
    printf '%s\n' "$id"
}

run_control manifest-tamper BC01_REQUIREMENTS_CLOSURE_MANIFEST_INVALID
run_control included-digest BC01_REQUIREMENTS_CLOSURE_FILE_DIGEST_INVALID
run_control included-mode BC01_REQUIREMENTS_CLOSURE_FILE_MODE_INVALID
run_control included-symlink BC01_REQUIREMENTS_CLOSURE_FILE_MISSING

echo "4 BC01 requirements closure mutations detected"
