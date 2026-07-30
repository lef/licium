#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
adapter="$base_dir/profiles/sqlite-reference/run.sh"
normalizer="$script_dir/normalize-bc04.sh"
oracle="$script_dir/oracle-bc04.sh"
verifier="$script_dir/verify-bc04-runtime.sh"

[ "$#" -ge 4 ] && [ "$#" -le 5 ] || exit 2
artifact_dir=$1
run=$2
namespace=$3
assertion=$4
mode=${5:-ordinary}

case "$assertion" in
    BC04_AMBIENT_FALLBACK)
        case_id=case-bc04-ambient
        scenario=bc04-ambient-fallback--case-bc04-ambient
        action=sut-read-published ;;
    BC04_EXACT_PUBLISHED_COLLAPSE)
        case_id=case-bc04-collapse
        scenario=bc04-exact-published-collapse--case-bc04-collapse
        action=sut-read-published ;;
    BC04_EXACT_READ)
        case_id=case-bc04-exact
        scenario=bc04-exact-read--case-bc04-exact
        action=sut-read-exact ;;
    BC04_PUBLISHED_READ)
        case_id=case-bc04-published
        scenario=bc04-published-read--case-bc04-published
        action=sut-read-published ;;
    BC04_UNACCEPTED_AVAILABLE)
        case_id=case-bc04-unaccepted
        scenario=bc04-unaccepted-available--case-bc04-unaccepted
        action=sut-read-published ;;
    *)
        exit 2 ;;
esac

case "$mode" in
    ordinary|mutant-ambient-read-fallback|mutant-read-mode-collapse|\
mutant-exact-read-substitution|mutant-published-read-substitution|\
mutant-unaccepted-read-availability)
        ;;
    *)
        exit 2 ;;
esac

[ ! -e "$artifact_dir" ] || {
    echo BC04_RUNTIME_NOT_FRESH >&2
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
        cat "$stderr" >&2
        exit "$status"
    }
    if [ "$phase" != destroy ]; then
        [ "$(cat "$stderr")" = "pragma	foreign-keys	1" ] || {
            echo BC04_PRAGMA_EVIDENCE_INVALID >&2
            exit 1
        }
        printf '%s\t%s\t%s\t%s\tforeign-keys\t1\n' \
            "$run" "$namespace" "$assertion" "$phase" >>"$pragma"
    elif [ -s "$stderr" ]; then
        echo BC04_COMMAND_CUSTODY_INVALID >&2
        exit 1
    fi
}

invoke create profile-create-namespace normal \
    "$tmp/create.out" "$tmp/create.err" \
    "$adapter" create-bc04 "$namespace" "$db"
invoke setup sut-setup-bc04 ordinary \
    "$tmp/setup.out" "$tmp/setup.err" \
    "$adapter" operation-bc04 "$db" "$run" "$namespace" "$assertion" \
    "$case_id" sut-setup-bc04 ordinary setup "setup-$run"
invoke inventory-before profile-inventory-bc04 ordinary \
    "$artifact_dir/inventory-before.tsv" "$tmp/inventory-before.err" \
    "$adapter" inventory-bc04 "$db" "$assertion" "$case_id" before
invoke action "$action" "$mode" \
    "$tmp/action.out" "$tmp/action.err" \
    "$adapter" operation-bc04 "$db" "$run" "$namespace" "$assertion" \
    "$case_id" "$action" "$mode" action "action-$run"

{
    cat "$tmp/setup.out"
    cat "$tmp/action.out"
} >"$artifact_dir/action-receipts.tsv"

invoke observe-after profile-observe-bc04 ordinary \
    "$artifact_dir/raw-observations.tsv" "$tmp/observe-after.err" \
    "$adapter" observe-bc04 "$db" "$assertion" "$case_id" after \
    "$artifact_dir/action-receipts.tsv"
chmod 0644 "$artifact_dir/raw-observations.tsv"

invoke inventory-after profile-inventory-bc04 ordinary \
    "$artifact_dir/inventory-after.tsv" "$tmp/inventory-after.err" \
    "$adapter" inventory-bc04 "$db" "$assertion" "$case_id" after

raw_sha=$(sha256sum "$artifact_dir/raw-observations.tsv" | awk '{ print $1 }')
raw_bytes=$(wc -c <"$artifact_dir/raw-observations.tsv" | tr -d ' ')
receipt_sha=$(sha256sum "$artifact_dir/action-receipts.tsv" |
    awk '{ print $1 }')
printf 'raw-observations.tsv\t100644\t%s\t%s\t%s\t%s\t%s\t%s\tsealed-before-normalization\n' \
    "$raw_sha" "$raw_bytes" "$run" "$namespace" "$scenario" \
    "$receipt_sha" >"$artifact_dir/raw-seal.tsv"

invoke reopen profile-reopen-namespace ordinary \
    "$tmp/reopen.out" "$tmp/reopen.err" \
    "$adapter" reopen "$db" "$run" "$namespace" "$assertion"
invoke inventory-reopened profile-inventory-bc04 ordinary \
    "$artifact_dir/inventory-reopened.tsv" "$tmp/inventory-reopened.err" \
    "$adapter" inventory-bc04 "$db" "$assertion" "$case_id" reopened
invoke destroy profile-destroy-namespace ordinary \
    "$tmp/destroy.out" "$tmp/destroy.err" \
    "$adapter" destroy "$namespace" "$db"

"$normalizer" "$artifact_dir/raw-observations.tsv" \
    "$artifact_dir/action-receipts.tsv" "$scenario" \
    >"$artifact_dir/normalized-observations.tsv"
awk -F '	' -v scenario="$scenario" '$1 == scenario' \
    "$base_dir/bc04-coverage-template.tsv" >"$artifact_dir/coverage.tsv"
: >"$artifact_dir/exclusions.tsv"
: >"$artifact_dir/fault-markers.tsv"

"$oracle" "$artifact_dir" "$run" "$namespace" "$assertion" \
    "$case_id" "$scenario" >"$artifact_dir/oracle-result.tsv"
"$verifier" "$artifact_dir" "$run" "$namespace" "$assertion" \
    "$case_id" "$scenario" "$db" "$mode"
