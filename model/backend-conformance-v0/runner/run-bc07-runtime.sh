#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
adapter="$base_dir/profiles/sqlite-reference/run.sh"
normalizer="$script_dir/normalize-bc07.sh"
oracle="$script_dir/oracle-bc07.sh"
verifier="$script_dir/verify-bc07-runtime.sh"

[ "$#" -ge 4 ] && [ "$#" -le 5 ] || exit 2
artifact_dir=$1
run=$2
namespace=$3
assertion=$4
mode=${5:-ordinary}

case "$assertion" in
    BC07_EFFECT_101)
        case_id=case-bc07-effect
        scenario=bc07-effect-101--case-bc07-effect
        action=sut-apply-effect ;;
    BC07_OBSERVATION_WITHOUT_TRANSITION)
        case_id=case-bc07-orphan
        scenario=bc07-observation-without-transition--case-bc07-orphan
        action=sut-apply-effect ;;
    BC07_ORDINARY_000)
        case_id=case-bc07-ordinary
        scenario=bc07-ordinary-000--case-bc07-ordinary
        action=sut-evaluate-pure ;;
    BC07_RECORD_IMPLIES_EFFECT)
        case_id=case-bc07-record-effect
        scenario=bc07-record-implies-effect--case-bc07-record-effect
        action=sut-record-result ;;
    BC07_RECORD_ONLY_010)
        case_id=case-bc07-record
        scenario=bc07-record-only-010--case-bc07-record
        action=sut-record-result ;;
    BC07_RESULT_REWRITE)
        case_id=case-bc07-rewrite
        scenario=bc07-result-rewrite--case-bc07-rewrite
        action=sut-apply-effect ;;
    *) exit 2 ;;
esac

case "$mode" in
    ordinary|mutant-effect-axis-mismatch|mutant-orphan-observation|\
mutant-ordinary-axis-write|mutant-record-state-effect|\
mutant-record-axis-mismatch|mutant-effect-result-rewrite)
        ;;
    *) exit 2 ;;
esac

[ ! -e "$artifact_dir" ] || {
    echo BC07_RUNTIME_NOT_FRESH >&2
    exit 1
}
mkdir -p "$artifact_dir"
db="$artifact_dir/$namespace.db"
command_receipts="$artifact_dir/command-receipts.tsv"
pragma="$artifact_dir/pragma.tsv"
: >"$command_receipts"
: >"$pragma"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"; rm -f "$db"' EXIT HUP INT TERM

invoke()
{
    phase=$1
    operation=$2
    command_mode=$3
    stdout=$4
    stderr=$5
    shift 5

    argv_sha=$(
        for argument in "$@"
        do
            case "$argument" in
                "$adapter") printf '%s\n' '{adapter-entrypoint}' ;;
                "$db") printf '%s\n' '{database-path}' ;;
                "$artifact_dir/action-receipts.tsv")
                    printf '%s\n' '{action-receipts-path}' ;;
                "$artifact_dir/inventory-before.tsv")
                    printf '%s\n' '{inventory-before-path}' ;;
                "$artifact_dir/inventory-after.tsv")
                    printf '%s\n' '{inventory-after-path}' ;;
                *) printf '%s\n' "$argument" ;;
            esac
        done | sha256sum | awk '{ print $1 }'
    )

    set +e
    "$@" >"$stdout" 2>"$stderr"
    status=$?
    set -e
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$run" "$namespace" "$assertion" "$phase" "$operation" \
        "$command_mode" "$status" \
        "$(sha256sum "$stdout" | awk '{ print $1 }')" \
        "$(wc -c <"$stdout" | tr -d ' ')" \
        "$(sha256sum "$stderr" | awk '{ print $1 }')" \
        "$(wc -c <"$stderr" | tr -d ' ')" "$argv_sha" \
        >>"$command_receipts"
    [ "$status" -eq 0 ] || {
        sed -n '1,$p' "$stderr" >&2
        exit "$status"
    }
    if [ "$phase" != destroy ]; then
        [ "$(cat "$stderr")" = "pragma	foreign-keys	1" ] || {
            echo BC07_PRAGMA_EVIDENCE_INVALID >&2
            exit 1
        }
        printf '%s\t%s\t%s\t%s\tforeign-keys\t1\n' \
            "$run" "$namespace" "$assertion" "$phase" >>"$pragma"
    elif [ -s "$stderr" ]; then
        echo BC07_COMMAND_CUSTODY_INVALID >&2
        exit 1
    fi
}

invoke create profile-create-namespace normal \
    "$tmp/create.out" "$tmp/create.err" \
    "$adapter" create-bc07 "$namespace" "$db"
invoke setup sut-setup-bc07 ordinary \
    "$tmp/setup.out" "$tmp/setup.err" \
    "$adapter" operation-bc07 "$db" "$run" "$namespace" "$assertion" \
    "$case_id" sut-setup-bc07 ordinary setup "setup-$run"
invoke inventory-before profile-inventory-bc07 ordinary \
    "$artifact_dir/inventory-before.tsv" "$tmp/inventory-before.err" \
    "$adapter" inventory-bc07 "$db" "$assertion" "$case_id" before
invoke action "$action" "$mode" \
    "$artifact_dir/action-receipts.tsv" "$tmp/action.err" \
    "$adapter" operation-bc07 "$db" "$run" "$namespace" "$assertion" \
    "$case_id" "$action" "$mode" action "action-$run"
invoke observe-after profile-observe-bc07 ordinary \
    "$artifact_dir/raw-observations.tsv" "$tmp/observe-after.err" \
    "$adapter" observe-bc07 "$db" "$assertion" "$case_id" after \
    "$artifact_dir/inventory-before.tsv" \
    "$artifact_dir/action-receipts.tsv"
chmod 0644 "$artifact_dir/raw-observations.tsv"
invoke inventory-after profile-inventory-bc07 ordinary \
    "$artifact_dir/inventory-after.tsv" "$tmp/inventory-after.err" \
    "$adapter" inventory-bc07 "$db" "$assertion" "$case_id" after

raw_sha=$(sha256sum "$artifact_dir/raw-observations.tsv" | awk '{ print $1 }')
raw_bytes=$(wc -c <"$artifact_dir/raw-observations.tsv" | tr -d ' ')
receipt_sha=$(sha256sum "$artifact_dir/action-receipts.tsv" |
    awk '{ print $1 }')
printf 'raw-observations.tsv\t100644\t%s\t%s\t%s\t%s\t%s\t%s\tsealed-before-normalization\n' \
    "$raw_sha" "$raw_bytes" "$run" "$namespace" "$scenario" \
    "$receipt_sha" >"$artifact_dir/raw-seal.tsv"

invoke reopen profile-reopen-namespace normal \
    "$tmp/reopen.out" "$tmp/reopen.err" \
    "$adapter" reopen "$db" "$run" "$namespace" "$assertion"
invoke inventory-reopened profile-inventory-bc07 ordinary \
    "$artifact_dir/inventory-reopened.tsv" "$tmp/inventory-reopened.err" \
    "$adapter" inventory-bc07 "$db" "$assertion" "$case_id" reopened
invoke destroy profile-destroy-namespace normal \
    "$tmp/destroy.out" "$tmp/destroy.err" \
    "$adapter" destroy "$namespace" "$db"

"$normalizer" "$artifact_dir/raw-observations.tsv" "$scenario" \
    >"$artifact_dir/normalized-observations.tsv"
sed "s/{scenario}/$scenario/g" "$base_dir/bc07-coverage-template.tsv" \
    >"$artifact_dir/coverage.tsv"
: >"$artifact_dir/exclusions.tsv"
: >"$artifact_dir/fault-markers.tsv"

"$oracle" "$artifact_dir" "$assertion" "$case_id" "$scenario" \
    >"$artifact_dir/oracle-result.tsv"
"$verifier" "$artifact_dir" "$run" "$namespace" "$assertion" \
    "$case_id" "$scenario" "$db" "$mode"
