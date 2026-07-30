#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
registry="$base_dir/sqlite-partial-bc02-negative-execution.tsv"
runtime="$script_dir/run-bc02-runtime.sh"
verifier="$script_dir/verify-bc02-negative-runtime.sh"
classifier="$script_dir/classify-bc02-negative.sh"

[ "$#" -eq 4 ] || {
    echo "usage: run-bc02-negative-runtime.sh WORK_DIR RUN NS_PREFIX RECEIPT" >&2
    exit 2
}

work_dir=$1
run=$2
namespace_prefix=$3
receipt=$4

[ ! -e "$work_dir" ] || {
    echo BC02_NEGATIVE_WORKDIR_NOT_FRESH >&2
    exit 1
}
mkdir -p "$work_dir"
: >"$receipt"

while IFS='	' read -r negative_id class mutation assertion expected_marker \
    scenario execution_mode evidence_name
do
    [ "$execution_mode" = "execute-mutant" ] || exit 1
    case "$negative_id:$scenario:$mutation" in
        neg-bc02-complete-available:bc02-complete-available--case-bc02-complete:mutant-complete-as-unavailable)
            case_id=case-bc02-complete
            ;;
        neg-bc02-healthy-retry:bc02-healthy-retry--case-bc02-incomplete-corrected:mutant-retry-rejected)
            case_id=case-bc02-incomplete-corrected
            ;;
        neg-bc02-incomplete-as-complete:bc02-incomplete-as-complete--case-bc02-incomplete-missing:mutant-incomplete-as-complete)
            case_id=case-bc02-incomplete-missing
            ;;
        neg-bc02-partial-residue:bc02-partial-residue--case-bc02-after-root-header:mutant-partial-residue)
            case_id=case-bc02-after-root-header
            ;;
        neg-bc02-poisoned-retry:bc02-poisoned-retry--case-bc02-after-root-header:mutant-poisoned-retry)
            case_id=case-bc02-after-root-header
            ;;
        neg-bc02-rollback-complete:bc02-rollback-complete--case-bc02-after-root-header:mutant-incomplete-rollback)
            case_id=case-bc02-after-root-header
            ;;
        *)
            exit 1
            ;;
    esac

    negative_dir="$work_dir/$negative_id"
    namespace="$namespace_prefix-$negative_id"
    mkdir -p "$negative_dir"
    set +e
    "$runtime" "$negative_dir" "$run" "$namespace" "$assertion" \
        "$case_id" "$mutation" >"$negative_dir/runtime.stdout" \
        2>"$negative_dir/runtime.stderr"
    status=$?
    set -e
    [ "$status" -ne 0 ] || exit 1
    observed_runtime=$(cat "$negative_dir/runtime.stderr")
    [ "$observed_runtime" = "BC02_ORACLE_MISMATCH" ] || exit 1
    observed_marker=$("$classifier" "$negative_id" "$negative_dir")
    [ "$observed_marker" = "$expected_marker" ] || exit 1
    printf '%s\t%s\t%s\n' "$status" "$observed_runtime" "$observed_marker" \
        >"$negative_dir/runtime-result.tsv"

    evidence="$negative_dir/$evidence_name"
    [ -f "$evidence" ] && [ ! -L "$evidence" ] || exit 1
    evidence_sha=$(sha256sum "$evidence" | awk '{ print $1 }')
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$negative_id" "$class" "$mutation" "$assertion" \
        "$expected_marker" "$observed_marker" "$status" "$evidence_sha" \
        >>"$receipt"
done <"$registry"

"$verifier" "$work_dir" "$receipt" "$run" "$namespace_prefix"
