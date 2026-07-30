#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
adapter="$base_dir/profiles/sqlite-reference/run.sh"
normalizer="$script_dir/normalize-bc05.sh"
oracle="$script_dir/oracle-bc05.sh"
verifier="$script_dir/verify-bc05-runtime.sh"

[ "$#" -ge 4 ] && [ "$#" -le 5 ] || exit 2
artifact_dir=$1
run=$2
namespace=$3
assertion=$4
mode=${5:-ordinary}

case "$assertion" in
    BC05_AMBIENT_ADVANCE)
        case_id=case-bc05-ambient
        scenario=bc05-ambient-advance--case-bc05-ambient
        action=sut-advance-and-resolve ;;
    BC05_BINDING_OMISSION)
        case_id=case-bc05-binding
        scenario=bc05-binding-omission--case-bc05-binding
        action=sut-resolve-pinned-closure ;;
    BC05_COMPLETE_CLOSURE)
        case_id=case-bc05-complete
        scenario=bc05-complete-closure--case-bc05-complete
        action=sut-resolve-pinned-closure ;;
    BC05_DEFINITION_OMISSION)
        case_id=case-bc05-definition
        scenario=bc05-definition-omission--case-bc05-definition
        action=sut-resolve-pinned-closure ;;
    BC05_MISSING_AS_EMPTY)
        case_id=case-bc05-empty
        scenario=bc05-missing-as-empty--case-bc05-empty
        action=sut-resolve-pinned-closure ;;
    BC05_PINNED_KNOWLEDGE_CUT)
        case_id=case-bc05-cut
        scenario=bc05-pinned-knowledge-cut--case-bc05-cut
        action=sut-advance-and-resolve ;;
    BC05_ROOT_OMISSION)
        case_id=case-bc05-root
        scenario=bc05-root-omission--case-bc05-root
        action=sut-resolve-pinned-closure ;;
    BC05_SEMANTICS_OMISSION)
        case_id=case-bc05-semantics
        scenario=bc05-semantics-omission--case-bc05-semantics
        action=sut-resolve-pinned-closure ;;
    BC05_TRANSITIVE_OMISSION)
        case_id=case-bc05-transitive
        scenario=bc05-transitive-omission--case-bc05-transitive
        action=sut-resolve-pinned-closure ;;
    *)
        exit 2 ;;
esac

case "$mode" in
    ordinary|mutant-ambient-closure-substitution|\
mutant-binding-omission|mutant-incomplete-closure-success|\
mutant-definition-omission|mutant-missing-as-empty|\
mutant-knowledge-cut-drift|mutant-root-omission|\
mutant-semantics-omission|mutant-transitive-omission)
        ;;
    *)
        exit 2 ;;
esac

[ ! -e "$artifact_dir" ] || {
    echo BC05_RUNTIME_NOT_FRESH >&2
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
            echo BC05_PRAGMA_EVIDENCE_INVALID >&2
            exit 1
        }
        printf '%s\t%s\t%s\t%s\tforeign-keys\t1\n' \
            "$run" "$namespace" "$assertion" "$phase" >>"$pragma"
    elif [ -s "$stderr" ]; then
        echo BC05_COMMAND_CUSTODY_INVALID >&2
        exit 1
    fi
}

invoke create profile-create-namespace normal \
    "$tmp/create.out" "$tmp/create.err" \
    "$adapter" create-bc05 "$namespace" "$db"
invoke setup sut-setup-bc05 ordinary \
    "$tmp/setup.out" "$tmp/setup.err" \
    "$adapter" operation-bc05 "$db" "$run" "$namespace" "$assertion" \
    "$case_id" sut-setup-bc05 ordinary setup "setup-$run"
invoke inventory-before profile-inventory-bc05 ordinary \
    "$artifact_dir/inventory-before.tsv" "$tmp/inventory-before.err" \
    "$adapter" inventory-bc05 "$db" "$assertion" "$case_id" before
invoke action "$action" "$mode" \
    "$tmp/action.out" "$tmp/action.err" \
    "$adapter" operation-bc05 "$db" "$run" "$namespace" "$assertion" \
    "$case_id" "$action" "$mode" action "action-$run"

{
    cat "$tmp/setup.out"
    cat "$tmp/action.out"
} >"$artifact_dir/action-receipts.tsv"

invoke observe-after profile-observe-bc05 ordinary \
    "$artifact_dir/raw-observations.tsv" "$tmp/observe-after.err" \
    "$adapter" observe-bc05 "$db" "$assertion" "$case_id" after \
    "$artifact_dir/action-receipts.tsv"
chmod 0644 "$artifact_dir/raw-observations.tsv"

invoke inventory-after profile-inventory-bc05 ordinary \
    "$artifact_dir/inventory-after.tsv" "$tmp/inventory-after.err" \
    "$adapter" inventory-bc05 "$db" "$assertion" "$case_id" after

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
invoke inventory-reopened profile-inventory-bc05 ordinary \
    "$artifact_dir/inventory-reopened.tsv" "$tmp/inventory-reopened.err" \
    "$adapter" inventory-bc05 "$db" "$assertion" "$case_id" reopened
invoke destroy profile-destroy-namespace ordinary \
    "$tmp/destroy.out" "$tmp/destroy.err" \
    "$adapter" destroy "$namespace" "$db"

"$normalizer" "$artifact_dir/raw-observations.tsv" \
    "$artifact_dir/action-receipts.tsv" "$scenario" \
    >"$artifact_dir/normalized-observations.tsv"
awk -F '	' -v scenario="$scenario" '$1 == scenario' \
    "$base_dir/bc05-coverage-template.tsv" >"$artifact_dir/coverage.tsv"
: >"$artifact_dir/exclusions.tsv"
: >"$artifact_dir/fault-markers.tsv"

"$oracle" "$artifact_dir" "$run" "$namespace" "$assertion" \
    "$case_id" "$scenario" >"$artifact_dir/oracle-result.tsv"
"$verifier" "$artifact_dir" "$run" "$namespace" "$assertion" \
    "$case_id" "$scenario" "$db" "$mode"
