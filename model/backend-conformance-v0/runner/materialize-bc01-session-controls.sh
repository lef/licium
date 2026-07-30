#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
mutants="$base_dir/bc01-mutants.tsv"
session_verifier="$script_dir/verify-bc01-session.sh"

[ "$#" -eq 2 ] || exit 2
session_dir=$1
output=$2
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
: >"$output"

record()
{
    id=$1
    class=$2
    mutation=$3
    target=$4
    kind=$5
    case_dir="$tmp/$id"
    cp -R "$session_dir" "$case_dir"
    case "$kind" in
        copied)
            cp -R "$case_dir/run-a/." "$case_dir/run-b/"
            evidence="$case_dir/run-b/bc01-association-idempotent--case-bc01-retry/action-receipts.tsv"
            ;;
        drift)
            evidence="$case_dir/run-b/bc01-distinct-occurrence--case-bc01-distinct/normalized-observations.tsv"
            sed 's/public-a/public-b/' "$evidence" >"$tmp/mutated.tsv"
            cp "$tmp/mutated.tsv" "$evidence"
            ;;
        sentinel)
            cp "$case_dir/lifecycle/run-a/sentinel-a" \
                "$case_dir/lifecycle/run-b/sentinel-a"
            evidence="$case_dir/lifecycle/run-b/sentinel-a"
            ;;
        *)
            exit 2
            ;;
    esac
    set +e
    observed=$("$session_verifier" "$case_dir" 2>&1)
    status=$?
    set -e
    [ "$status" -ne 0 ] && [ "$observed" = "$target" ] || {
        echo BC01_SESSION_CONTROL_EXECUTION_INVALID >&2
        exit 1
    }
    evidence_sha=$(sha256sum "$evidence" | awk '{ print $1 }')
    printf '%s\t%s\t%s\tsession\t%s\t%s\t%s\t%s\n' \
        "$id" "$class" "$mutation" "$target" "$observed" "$status" \
        "$evidence_sha" >>"$output"
}

while IFS='	' read -r id class mutation target
do
    case "$id" in
        harness-bc01-copied-run)
            record "$id" "$class" "$mutation" "$target" copied
            ;;
        harness-bc01-second-run-drift)
            record "$id" "$class" "$mutation" "$target" drift
            ;;
        harness-bc01-sentinel-leak)
            record "$id" "$class" "$mutation" "$target" sentinel
            ;;
    esac
done <"$mutants"

awk -F '	' '
    NF != 8 || seen[$1]++ { exit 1 }
    { count++ }
    END { if (count != 3) exit 1 }
' "$output" || {
    echo BC01_SESSION_CONTROL_RECEIPT_INVALID >&2
    exit 1
}
