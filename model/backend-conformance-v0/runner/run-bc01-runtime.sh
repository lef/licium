#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
adapter="$base_dir/profiles/sqlite-reference/run.sh"
normalizer="$script_dir/normalize-bc01.sh"
oracle="$script_dir/oracle-bc01.sh"
verifier="$script_dir/verify-bc01-runtime.sh"

[ "$#" -ge 4 ] && [ "$#" -le 5 ] || {
    echo "usage: run-bc01-runtime.sh ARTIFACT_DIR RUN NS ASSERTION [MODE]" >&2
    exit 2
}

artifact_dir=$1
run=$2
namespace=$3
assertion=$4
mode=${5:-ordinary}

case "$assertion" in
    BC01_ASSOCIATION_IDEMPOTENT)
        case_id=case-bc01-retry
        scenario=bc01-association-idempotent--case-bc01-retry
        action=sut-retry-delivery
        ;;
    BC01_DISTINCT_OCCURRENCE)
        case_id=case-bc01-distinct
        scenario=bc01-distinct-occurrence--case-bc01-distinct
        action=sut-deliver-distinct
        ;;
    BC01_OCCURRENCE_COLLAPSE)
        case_id=case-bc01-distinct
        scenario=bc01-occurrence-collapse--case-bc01-distinct
        action=sut-deliver-distinct
        ;;
    BC01_PAYLOAD_COLLISION)
        case_id=case-bc01-payload-collision
        scenario=bc01-payload-collision--case-bc01-payload-collision
        action=sut-deliver-collision
        ;;
    BC01_RETRY_DUPLICATION)
        case_id=case-bc01-retry
        scenario=bc01-retry-duplication--case-bc01-retry
        action=sut-retry-delivery
        ;;
    *)
        exit 2
        ;;
esac

case "$mode" in
    ordinary|mutant-association-duplication|mutant-distinct-collapse|\
mutant-occurrence-collapse|mutant-payload-collision-acceptance|\
mutant-retry-duplication)
        ;;
    *)
        exit 2
        ;;
esac

[ ! -e "$artifact_dir" ] || {
    echo BC01_RUNTIME_NOT_FRESH >&2
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
            if [ "$argument" = "$adapter" ]; then
                printf '%s\n' '{adapter-entrypoint}'
            elif [ "$argument" = "$db" ]; then
                printf '%s\n' '{database-path}'
            else
                printf '%s\n' "$argument"
            fi
        done | sha256sum | awk '{ print $1 }'
    )

    set +e
    "$@" >"$stdout" 2>"$stderr"
    status=$?
    set -e

    stdout_sha=$(sha256sum "$stdout" | awk '{ print $1 }')
    stdout_bytes=$(wc -c <"$stdout" | tr -d ' ')
    stderr_sha=$(sha256sum "$stderr" | awk '{ print $1 }')
    stderr_bytes=$(wc -c <"$stderr" | tr -d ' ')
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$run" "$namespace" "$assertion" "$phase" "$operation" \
        "$command_mode" "$status" "$stdout_sha" "$stdout_bytes" \
        "$stderr_sha" "$stderr_bytes" "$argv_sha" >>"$command_receipts"

    [ "$status" -eq 0 ] || {
        cat "$stderr" >&2
        exit "$status"
    }
    if [ "$phase" != destroy ]; then
        [ "$(cat "$stderr")" = "pragma	foreign-keys	1" ] ||
            {
                echo BC01_PRAGMA_EVIDENCE_INVALID >&2
                exit 1
            }
        printf '%s\t%s\t%s\t%s\tforeign-keys\t1\n' \
            "$run" "$namespace" "$assertion" "$phase" >>"$pragma"
    elif [ -s "$stderr" ]; then
        echo BC01_COMMAND_CUSTODY_INVALID >&2
        exit 1
    fi
}

invoke create profile-create-namespace normal \
    "$tmp/create.out" "$tmp/create.err" \
    "$adapter" create-bc01 "$namespace" "$db"

invoke setup sut-setup-bc01 ordinary \
    "$tmp/setup.out" "$tmp/setup.err" \
    "$adapter" operation-bc01 "$db" "$run" "$namespace" "$assertion" \
    "$case_id" sut-setup-bc01 ordinary setup "setup-$run"

invoke inventory-before runner-bind-evidence ordinary \
    "$artifact_dir/inventory-before.tsv" "$tmp/inventory-before.err" \
    "$adapter" inventory-bc01 "$db" "$assertion" "$case_id" before

invoke action "$action" "$mode" \
    "$tmp/action.out" "$tmp/action.err" \
    "$adapter" operation-bc01 "$db" "$run" "$namespace" "$assertion" \
    "$case_id" "$action" "$mode" action "action-$run"

invoke inventory-after runner-bind-evidence ordinary \
    "$artifact_dir/inventory-after.tsv" "$tmp/inventory-after.err" \
    "$adapter" inventory-bc01 "$db" "$assertion" "$case_id" after

invoke observe-after runner-bind-evidence ordinary \
    "$tmp/raw-after.tsv" "$tmp/observe-after.err" \
    "$adapter" observe-bc01 "$db" "$assertion" "$case_id" after

{
    cat "$tmp/setup.out"
    cat "$tmp/action.out"
} >"$artifact_dir/action-receipts.tsv"

{
    LC_ALL=C awk -F '	' -v OFS='	' -v scenario="$scenario" \
        -v case_id="$case_id" '
        FILENAME == ARGV[1] {
            if ($5 == "sut-setup-bc01")
                print scenario,"raw-001","action-receipt","setup",$8,$6
            else {
                print scenario,"raw-002","action-receipt","action",$8,$6
                print scenario,"raw-003","action-receipt-error","action",$8,$7
                if (case_id == "case-bc01-payload-collision")
                    print scenario,"raw-004","collision-input","action",$8,$11
            }
            next
        }
        $2 == "delivery" && $3 == "delivery-a" &&
            $4 == "occurrence-ref" {
            id = case_id == "case-bc01-payload-collision" ?
                "raw-005" : "raw-004"
            print scenario,id,"delivery","before",$3,$5
        }
        $2 == "occurrence" && $3 == "occurrence-a" &&
            $4 == "delivery-ref" {
            id = case_id == "case-bc01-retry" ? "raw-006" : "raw-007"
            print scenario,id,"occurrence","before",$3,$5
        }
    ' "$artifact_dir/action-receipts.tsv" \
        "$artifact_dir/inventory-before.tsv"
    cat "$tmp/raw-after.tsv"
} | LC_ALL=C sort >"$artifact_dir/raw-observations.tsv"
chmod 0644 "$artifact_dir/raw-observations.tsv"

raw_sha=$(sha256sum "$artifact_dir/raw-observations.tsv" | awk '{ print $1 }')
raw_bytes=$(wc -c <"$artifact_dir/raw-observations.tsv" | tr -d ' ')
receipt_sha=$(sha256sum "$artifact_dir/action-receipts.tsv" | awk '{ print $1 }')
printf 'raw-observations.tsv\t100644\t%s\t%s\t%s\t%s\t%s\t%s\tsealed-before-normalization\n' \
    "$raw_sha" "$raw_bytes" "$run" "$namespace" "$scenario" \
    "$receipt_sha" >"$artifact_dir/raw-seal.tsv"

"$normalizer" "$artifact_dir/raw-observations.tsv" \
    "$artifact_dir/action-receipts.tsv" "$scenario" \
    >"$artifact_dir/normalized-observations.tsv"
awk -F '	' -v scenario="$scenario" '$1 == scenario' \
    "$base_dir/bc01-coverage-template.tsv" >"$artifact_dir/coverage.tsv"
: >"$artifact_dir/exclusions.tsv"
: >"$artifact_dir/fault-markers.tsv"

invoke reopen profile-reopen-namespace ordinary \
    "$tmp/reopen.out" "$tmp/reopen.err" \
    "$adapter" reopen "$db" "$run" "$namespace" "$assertion"

invoke inventory-reopened runner-bind-evidence ordinary \
    "$artifact_dir/inventory-reopened.tsv" "$tmp/inventory-reopened.err" \
    "$adapter" inventory-bc01 "$db" "$assertion" "$case_id" reopened

# This is the intentional semantic-mutant gate.  A mutant must terminate here
# with its typed BC01 marker.  Only ordinary evidence may reach the sealed
# command/receipt/template verifier below.
"$oracle" "$artifact_dir" "$run" "$namespace" "$assertion" \
    "$case_id" "$scenario" >"$artifact_dir/oracle-result.tsv"

invoke destroy profile-destroy-namespace ordinary \
    "$tmp/destroy.out" "$tmp/destroy.err" \
    "$adapter" destroy "$namespace" "$db"

"$verifier" "$artifact_dir" "$run" "$namespace" "$assertion" \
    "$case_id" "$scenario" "$db"
