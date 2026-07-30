#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
adapter="$base_dir/profiles/sqlite-reference/run.sh"
normalizer="$script_dir/normalize-bc06.sh"
oracle="$script_dir/oracle-bc06.sh"
verifier="$script_dir/verify-bc06-runtime.sh"
coverage_template="$base_dir/bc06-coverage-template.tsv"

[ "$#" -ge 4 ] && [ "$#" -le 5 ] || {
    echo "usage: run-bc06-runtime.sh ARTIFACT_DIR RUN NS ASSERTION [MODE]" >&2
    exit 2
}

artifact_dir=$1
run=$2
namespace=$3
assertion=$4
mode=${5:-ordinary}

case "$assertion" in
    BC06_OBSERVATION_WRITE|BC06_PURE_ZERO_AXES|\
BC06_REPOSITORY_UNCHANGED|BC06_RESULT_WRITE|BC06_STATE_WRITE)
        ;;
    *)
        exit 2
        ;;
esac

case "$mode" in
    ordinary|mutant-state-write|mutant-result-write|\
mutant-observation-write|mutant-all-three-axis-write|\
mutant-repository-drift|mutant-noop)
        ;;
    *)
        exit 2
        ;;
esac

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

    if [ "$phase" != "destroy" ]; then
        [ "$(cat "$stderr")" = "pragma	foreign-keys	1" ] || {
            echo BC06_PRAGMA_EVIDENCE_INVALID >&2
            exit 1
        }
        printf '%s\t%s\t%s\t%s\tforeign-keys\t1\n' \
            "$run" "$namespace" "$assertion" "$phase" >>"$pragma"
    elif [ -s "$stderr" ]; then
        echo BC06_COMMAND_CUSTODY_INVALID >&2
        exit 1
    fi
}

invoke create profile-create-namespace normal \
    "$tmp/create.out" "$tmp/create.err" \
    "$adapter" create "$namespace" "$db"

invoke setup sut-setup-bc06 ordinary \
    "$tmp/setup.out" "$tmp/setup.err" \
    "$adapter" operation "$db" "$run" "$namespace" "$assertion" \
    sut-setup-bc06 ordinary setup setup-nonce

invoke inventory-before runner-bind-evidence ordinary \
    "$artifact_dir/inventory-before.tsv" "$tmp/inventory-before.err" \
    "$adapter" inventory "$db" "$run" "$namespace" "$assertion" before

invoke observe-before runner-bind-evidence ordinary \
    "$tmp/raw-before.tsv" "$tmp/observe-before.err" \
    "$adapter" observe "$db" "$run" "$namespace" "$assertion" \
    raw-bc06-observation before

first_mode=$mode
invoke occurrence-1 sut-evaluate-pure "$first_mode" \
    "$tmp/receipt-1.tsv" "$tmp/occurrence-1.err" \
    "$adapter" operation "$db" "$run" "$namespace" "$assertion" \
    sut-evaluate-pure "$first_mode" occurrence-1 nonce-1-"$run"

invoke occurrence-2 sut-evaluate-pure ordinary \
    "$tmp/receipt-2.tsv" "$tmp/occurrence-2.err" \
    "$adapter" operation "$db" "$run" "$namespace" "$assertion" \
    sut-evaluate-pure ordinary occurrence-2 nonce-2-"$run"

invoke inventory-after runner-bind-evidence ordinary \
    "$artifact_dir/inventory-after.tsv" "$tmp/inventory-after.err" \
    "$adapter" inventory "$db" "$run" "$namespace" "$assertion" after

invoke observe-after runner-bind-evidence ordinary \
    "$tmp/raw-after.tsv" "$tmp/observe-after.err" \
    "$adapter" observe "$db" "$run" "$namespace" "$assertion" \
    raw-bc06-observation after

{
    cat "$tmp/receipt-1.tsv"
    cat "$tmp/receipt-2.tsv"
} >"$artifact_dir/action-receipts.tsv"

{
    cat "$tmp/raw-before.tsv"
    cat "$tmp/raw-after.tsv"
    LC_ALL=C awk -F '	' -v OFS='	' '
        $4 == "occurrence-1" {
            print $3,"raw-007","evaluation-outcome",$4,$7,$10
            print $3,"raw-011","evaluation-outcome","action","subject",$8
            print $3,"raw-012","evaluation-outcome","action","pinned-source",$9
            print $3,"raw-013","action-receipt",$4,$5,$6
        }
        $4 == "occurrence-2" {
            print $3,"raw-010","evaluation-outcome",$4,$7,$10
            print $3,"raw-014","action-receipt",$4,$5,$6
        }
    ' "$artifact_dir/action-receipts.tsv"
} | LC_ALL=C sort >"$artifact_dir/raw-observations.tsv"
chmod 0644 "$artifact_dir/raw-observations.tsv"

raw_sha=$(sha256sum "$artifact_dir/raw-observations.tsv" | awk '{ print $1 }')
raw_bytes=$(wc -c <"$artifact_dir/raw-observations.tsv" | tr -d ' ')
receipt_sha=$(sha256sum "$artifact_dir/action-receipts.tsv" | awk '{ print $1 }')
printf 'raw-observations.tsv\t100644\t%s\t%s\t%s\t%s\t%s\t%s\tsealed-before-normalization\n' \
    "$raw_sha" "$raw_bytes" "$run" "$namespace" "$assertion" "$receipt_sha" \
    >"$artifact_dir/raw-seal.tsv"

"$normalizer" "$artifact_dir/raw-observations.tsv" "$assertion" \
    >"$artifact_dir/normalized-observations.tsv"
sed "s/{scenario}/$assertion/g" "$coverage_template" \
    >"$artifact_dir/coverage.tsv"
: >"$artifact_dir/exclusions.tsv"
: >"$artifact_dir/fault-markers.tsv"

"$oracle" "$artifact_dir" "$run" "$namespace" "$assertion" \
    >"$artifact_dir/oracle-result.tsv"

invoke reopen profile-reopen-namespace ordinary \
    "$tmp/reopen.out" "$tmp/reopen.err" \
    "$adapter" reopen "$db" "$run" "$namespace" "$assertion"

invoke destroy profile-destroy-namespace ordinary \
    "$tmp/destroy.out" "$tmp/destroy.err" \
    "$adapter" destroy "$namespace" "$db"

"$verifier" "$artifact_dir" "$run" "$namespace" "$assertion" "$db"
