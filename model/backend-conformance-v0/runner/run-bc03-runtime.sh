#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
adapter="$base_dir/profiles/sqlite-reference/run.sh"
normalizer="$script_dir/normalize-bc03.sh"
oracle="$script_dir/oracle-bc03.sh"
verifier="$script_dir/verify-bc03-runtime.sh"

[ "$#" -ge 4 ] && [ "$#" -le 5 ] || {
    echo "usage: run-bc03-runtime.sh ARTIFACT_DIR RUN NS ASSERTION [MODE]" >&2
    exit 2
}

artifact_dir=$1
run=$2
namespace=$3
assertion=$4
mode=${5:-ordinary}

case "$assertion" in
    BC03_ACCEPTED_HEAD)
        case_id=case-bc03-accepted
        scenario=bc03-accepted-head--case-bc03-accepted
        action=sut-publish-root
        ;;
    BC03_PUBLICATION_SEPARATE)
        case_id=case-bc03-accepted
        scenario=bc03-publication-separate--case-bc03-accepted
        action=sut-publish-root
        ;;
    BC03_REJECTED_IS_HEAD)
        case_id=case-bc03-rejected
        scenario=bc03-rejected-is-head--case-bc03-rejected
        action=sut-publish-root
        ;;
    BC03_STORED_IS_HEAD)
        case_id=case-bc03-stored
        scenario=bc03-stored-is-head--case-bc03-stored
        action=sut-store-root
        ;;
    BC03_STORED_ROOT_SEPARATE)
        case_id=case-bc03-stored
        scenario=bc03-stored-root-separate--case-bc03-stored
        action=sut-store-root
        ;;
    BC03_WRONG_AUTHORITY_HEAD)
        case_id=case-bc03-wrong-authority
        scenario=bc03-wrong-authority-head--case-bc03-wrong-authority
        action=sut-derive-heads
        ;;
    *)
        exit 2
        ;;
esac

case "$mode" in
    ordinary|mutant-accepted-head-omission|\
mutant-publication-root-collapse|mutant-rejected-head-inclusion|\
mutant-stored-root-head-inclusion|\
mutant-stored-root-publication-collapse|\
mutant-wrong-authority-head-inclusion)
        ;;
    *)
        exit 2
        ;;
esac

[ ! -e "$artifact_dir" ] || {
    echo BC03_RUNTIME_NOT_FRESH >&2
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
        [ "$(cat "$stderr")" = "pragma	foreign-keys	1" ] || {
            echo BC03_PRAGMA_EVIDENCE_INVALID >&2
            exit 1
        }
        printf '%s\t%s\t%s\t%s\tforeign-keys\t1\n' \
            "$run" "$namespace" "$assertion" "$phase" >>"$pragma"
    elif [ -s "$stderr" ]; then
        echo BC03_COMMAND_CUSTODY_INVALID >&2
        exit 1
    fi
}

invoke create profile-create-namespace normal \
    "$tmp/create.out" "$tmp/create.err" \
    "$adapter" create-bc03 "$namespace" "$db"

invoke setup sut-setup-bc03 ordinary \
    "$tmp/setup.out" "$tmp/setup.err" \
    "$adapter" operation-bc03 "$db" "$run" "$namespace" "$assertion" \
    "$case_id" sut-setup-bc03 ordinary setup "setup-$run"

invoke inventory-before profile-inventory-bc03 ordinary \
    "$artifact_dir/inventory-before.tsv" "$tmp/inventory-before.err" \
    "$adapter" inventory-bc03 "$db" "$assertion" "$case_id" before

invoke action "$action" "$mode" \
    "$tmp/action.out" "$tmp/action.err" \
    "$adapter" operation-bc03 "$db" "$run" "$namespace" "$assertion" \
    "$case_id" "$action" "$mode" action "action-$run"

invoke observe-after profile-observe-bc03 ordinary \
    "$tmp/raw-after.tsv" "$tmp/observe-after.err" \
    "$adapter" observe-bc03 "$db" "$assertion" "$case_id" after

invoke inventory-after profile-inventory-bc03 ordinary \
    "$artifact_dir/inventory-after.tsv" "$tmp/inventory-after.err" \
    "$adapter" inventory-bc03 "$db" "$assertion" "$case_id" after

{
    cat "$tmp/setup.out"
    cat "$tmp/action.out"
} >"$artifact_dir/action-receipts.tsv"

{
    awk -F '	' -v OFS='	' -v scenario="$scenario" '
        $5 != "sut-setup-bc03" {
            result = $5 == "sut-derive-heads" ? "derived" : "recorded"
            print scenario,"raw-001","action-receipt","action",
                  "result",result
        }
    ' "$artifact_dir/action-receipts.tsv"
    cat "$tmp/raw-after.tsv"
} | LC_ALL=C sort >"$artifact_dir/raw-observations.tsv"
chmod 0644 "$artifact_dir/raw-observations.tsv"

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

invoke inventory-reopened profile-inventory-bc03 ordinary \
    "$artifact_dir/inventory-reopened.tsv" "$tmp/inventory-reopened.err" \
    "$adapter" inventory-bc03 "$db" "$assertion" "$case_id" reopened

invoke destroy profile-destroy-namespace ordinary \
    "$tmp/destroy.out" "$tmp/destroy.err" \
    "$adapter" destroy "$namespace" "$db"

"$normalizer" "$artifact_dir/raw-observations.tsv" \
    "$artifact_dir/action-receipts.tsv" "$scenario" \
    >"$artifact_dir/normalized-observations.tsv"
awk -F '	' -v scenario="$scenario" '$1 == scenario' \
    "$base_dir/bc03-coverage-template.tsv" >"$artifact_dir/coverage.tsv"
: >"$artifact_dir/exclusions.tsv"
: >"$artifact_dir/fault-markers.tsv"

"$oracle" "$artifact_dir" "$run" "$namespace" "$assertion" \
    "$case_id" "$scenario" >"$artifact_dir/oracle-result.tsv"

"$verifier" "$artifact_dir" "$run" "$namespace" "$assertion" \
    "$case_id" "$scenario" "$db"
