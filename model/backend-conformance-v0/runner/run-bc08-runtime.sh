#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
adapter="$base_dir/profiles/sqlite-reference/run.sh"
normalizer="$script_dir/normalize-bc08.sh"
oracle="$script_dir/oracle-bc08.sh"
verifier="$script_dir/verify-bc08-runtime.sh"
schema="$base_dir/sqlite-reference/schema-bc08.sql"

[ "$#" -ge 4 ] && [ "$#" -le 5 ] || exit 2
artifact_dir=$1
run=$2
namespace=$3
assertion=$4
mode=${5:-ordinary}

case "$assertion" in
    BC08_COMPLETE_EFFECT)
        case_id=case-bc08-complete
        scenario=bc08-complete-effect--case-bc08-complete ;;
    BC08_MID_BOUNDARY_FAILURE)
        case_id=case-bc08-boundary
        scenario=bc08-mid-boundary-failure--case-bc08-boundary ;;
    BC08_MISSING_CURRENT)
        case_id=case-bc08-current
        scenario=bc08-missing-current--case-bc08-current ;;
    BC08_MISSING_OBSERVATION)
        case_id=case-bc08-observation
        scenario=bc08-missing-observation--case-bc08-observation ;;
    BC08_MISSING_RESULT)
        case_id=case-bc08-result
        scenario=bc08-missing-result--case-bc08-result ;;
    BC08_MISSING_TRANSITION)
        case_id=case-bc08-transition
        scenario=bc08-missing-transition--case-bc08-transition ;;
    BC08_MISSING_VIEW)
        case_id=case-bc08-view
        scenario=bc08-missing-view--case-bc08-view ;;
    *) exit 2 ;;
esac

case "$mode" in
    ordinary|mutant-incomplete-effect-set|\
mutant-mid-boundary-partial-effect|mutant-missing-current|\
mutant-missing-observation|mutant-missing-result|\
mutant-missing-transition|mutant-missing-view) ;;
    *) exit 2 ;;
esac

[ ! -e "$artifact_dir" ] || {
    echo BC08_RUNTIME_NOT_FRESH >&2
    exit 1
}
mkdir -p "$artifact_dir"
db="$artifact_dir/$namespace.db"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"; rm -f "$db"' EXIT HUP INT TERM

for file in command-receipts.tsv pragma.tsv fault-activation-receipts.tsv \
    fault-configuration-receipts.tsv fault-trigger-receipts.tsv \
    fault-markers.tsv fault-inventory-setup.tsv \
    fault-inventory-rollback.tsv fault-inventory-healthy.tsv \
    fault-inventory-reopened.tsv
do
    : >"$artifact_dir/$file"
done

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
                "$artifact_dir/"*) printf '%s\n' "{artifact-path:${argument##*/}}" ;;
                "$tmp/"*) printf '%s\n' "{temporary-path:${argument##*/}}" ;;
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
        >>"$artifact_dir/command-receipts.tsv"
    [ "$status" -eq 0 ] || {
        sed -n '1,$p' "$stderr" >&2
        exit "$status"
    }
    if [ "$phase" != destroy ] && [ "$phase" != retry ]; then
        [ "$(cat "$stderr")" = "pragma	foreign-keys	1" ] ||
            { echo BC08_PRAGMA_EVIDENCE_INVALID >&2; exit 1; }
        printf '%s\t%s\t%s\t%s\tforeign-keys\t1\n' \
            "$run" "$namespace" "$assertion" "$phase" \
            >>"$artifact_dir/pragma.tsv"
    elif [ "$phase" = destroy ] && [ -s "$stderr" ]; then
        echo BC08_COMMAND_CUSTODY_INVALID >&2
        exit 1
    fi
}

invoke create profile-create-namespace normal "$tmp/create.out" \
    "$tmp/create.err" "$adapter" create-bc08 "$namespace" "$db"
invoke setup sut-setup-bc08 ordinary "$tmp/setup.out" "$tmp/setup.err" \
    "$adapter" operation-bc08 "$db" "$run" "$namespace" "$assertion" \
    "$case_id" sut-setup-bc08 ordinary setup "setup-$run"
invoke inventory-before profile-inventory-bc08 ordinary \
    "$artifact_dir/inventory-before.tsv" "$tmp/inventory-before.err" \
    "$adapter" inventory-bc08 "$db" "$scenario" before
invoke action sut-apply-effect "$mode" \
    "$artifact_dir/action-receipts.tsv" "$tmp/action.err" \
    "$adapter" operation-bc08 "$db" "$run" "$namespace" "$assertion" \
    "$case_id" sut-apply-effect "$mode" action "action-$run"
if [ "$mode" != ordinary ]; then
    set +e
    control_output=$(
        "$adapter" operation-bc08 "$db" "$run" "$namespace" "$assertion" \
            "$case_id" sut-apply-effect retry retry "retry-$run" 2>&1
    )
    control_status=$?
    set -e
    expected_guard=BC08_RETRY_INCOMPLETE_SET
    [ "$mode" = mutant-missing-transition ] &&
        expected_guard=BC08_EFFECT_PRECONDITION_FAILED
    [ "$control_status" -ne 0 ] &&
        [ "$control_output" = "$expected_guard" ] || {
            echo BC08_CONTROL_TARGET_INVALID >&2
            exit 1
        }
    case "$assertion" in
        BC08_COMPLETE_EFFECT) marker=BC08_INCOMPLETE_EFFECT_DETECTED ;;
        BC08_MID_BOUNDARY_FAILURE) marker=BC08_PARTIAL_EFFECT_DETECTED ;;
        BC08_MISSING_CURRENT) marker=BC08_MISSING_CURRENT_DETECTED ;;
        BC08_MISSING_OBSERVATION) marker=BC08_MISSING_OBSERVATION_DETECTED ;;
        BC08_MISSING_RESULT) marker=BC08_MISSING_RESULT_DETECTED ;;
        BC08_MISSING_TRANSITION) marker=BC08_MISSING_TRANSITION_DETECTED ;;
        BC08_MISSING_VIEW) marker=BC08_MISSING_VIEW_DETECTED ;;
        *) exit 2 ;;
    esac
    echo "$marker" >&2
    exit 1
fi
invoke retry sut-apply-effect retry "$tmp/retry-receipt.tsv" \
    "$tmp/retry.err" "$adapter" operation-bc08 "$db" "$run" \
    "$namespace" "$assertion" "$case_id" sut-apply-effect retry retry \
    "retry-$run"
cat "$tmp/retry-receipt.tsv" >>"$artifact_dir/action-receipts.tsv"
invoke observe-after profile-observe-bc08 ordinary \
    "$artifact_dir/raw-observations.tsv" "$tmp/observe.err" \
    "$adapter" observe-bc08 "$db" "$scenario" \
    "$artifact_dir/action-receipts.tsv" "$tmp/retry-receipt.tsv" \
    "$([ "$assertion" = BC08_MID_BOUNDARY_FAILURE ] &&
        printf 5 || printf not-applicable)" after
chmod 0644 "$artifact_dir/raw-observations.tsv"
invoke inventory-after profile-inventory-bc08 ordinary \
    "$artifact_dir/inventory-after.tsv" "$tmp/inventory-after.err" \
    "$adapter" inventory-bc08 "$db" "$scenario" after

raw_sha=$(sha256sum "$artifact_dir/raw-observations.tsv" | awk '{ print $1 }')
raw_bytes=$(wc -c <"$artifact_dir/raw-observations.tsv" | tr -d ' ')
receipt_sha=$(sha256sum "$artifact_dir/action-receipts.tsv" |
    awk '{ print $1 }')
printf 'raw-observations.tsv\t100644\t%s\t%s\t%s\t%s\t%s\t%s\tsealed-before-normalization\n' \
    "$raw_sha" "$raw_bytes" "$run" "$namespace" "$scenario" \
    "$receipt_sha" >"$artifact_dir/raw-seal.tsv"

invoke reopen profile-reopen-namespace normal "$tmp/reopen.out" \
    "$tmp/reopen.err" "$adapter" reopen "$db" "$run" "$namespace" \
    "$assertion"
invoke inventory-reopened profile-inventory-bc08 ordinary \
    "$artifact_dir/inventory-reopened.tsv" "$tmp/inventory-reopened.err" \
    "$adapter" inventory-bc08 "$db" "$scenario" reopened
invoke destroy profile-destroy-namespace normal "$tmp/destroy.out" \
    "$tmp/destroy.err" "$adapter" destroy "$namespace" "$db"

if [ "$assertion" = BC08_MID_BOUNDARY_FAILURE ]; then
    implementation_revision=impl-bc08-v0
    while IFS='	' read -r fault_case hook phase error_id ordinal
    do
        fault_ns="$namespace-$ordinal"
        fault_db="$tmp/$fault_ns.db"
        nonce="fault-$run-$ordinal"
        "$adapter" create-bc08 "$fault_ns" "$fault_db" \
            >/dev/null 2>/dev/null
        "$adapter" operation-bc08 "$fault_db" "$run" "$fault_ns" \
            "$assertion" "$case_id" sut-setup-bc08 ordinary setup \
            "setup-$nonce" >/dev/null 2>/dev/null
        "$adapter" inventory-bc08 "$fault_db" "$fault_case" setup \
            >>"$artifact_dir/fault-inventory-setup.tsv" 2>/dev/null

        activation=$(printf '%s\t%s\t%s\t%s\tattempt-bc08-%s\tsut-apply-effect\t%s\t%s\t%s\t%s' \
            "$run" "$fault_ns" "$assertion" "$fault_case" \
            "${fault_case#case-bc08-}" "$hook" "$phase" "$nonce" \
            "$implementation_revision")
        printf '%s\n' "$activation" \
            >>"$artifact_dir/fault-activation-receipts.tsv"
        activation_sha=$(printf '%s\n' "$activation" |
            sha256sum | awk '{ print $1 }')
        "$adapter" fault-bc08 "$fault_db" activate "$hook" "$phase" \
            "$nonce" "$implementation_revision" effect-1 \
            >/dev/null 2>/dev/null

        trigger="trigger-bc08-${fault_case#case-bc08-}"
        marker=$(printf 'LICIUM_BC08_FAULT_%s' \
            "$(printf '%s' "$phase" | tr 'a-z-' 'A-Z_')")
        ddl_sha=$(sed -n "/CREATE TRIGGER $trigger$/,/^END;$/p" "$schema" |
            sha256sum | awk '{ print $1 }')
        literal_sha=$(printf '%s\n' "$marker" |
            sha256sum | awk '{ print $1 }')
        predicate_sha=$(printf '%s\t%s\teffect-1\n' "$hook" "$phase" |
            sha256sum | awk '{ print $1 }')
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\tconfigured\n' \
            "$run" "$fault_ns" "$assertion" "$fault_case" "$hook" \
            "$phase" "$nonce" "$implementation_revision" "$activation_sha" \
            "$trigger" "$ddl_sha" "$literal_sha" "$predicate_sha" \
            >>"$artifact_dir/fault-configuration-receipts.tsv"

        set +e
        "$adapter" operation-bc08 "$fault_db" "$run" "$fault_ns" \
            "$assertion" "$case_id" sut-apply-effect fault fault-action \
            "$nonce" >"$tmp/$ordinal.fault.out" 2>"$tmp/$ordinal.fault.err"
        fault_status=$?
        set -e
        [ "$fault_status" -ne 0 ] &&
            grep "$marker" "$tmp/$ordinal.fault.err" >/dev/null || {
                echo BC08_FAULT_UNREACHED >&2
                exit 1
            }
        stderr_sha=$(sha256sum "$tmp/$ordinal.fault.err" |
            awk '{ print $1 }')
        parsed_sha=$(printf '%s\n' "$marker" |
            sha256sum | awk '{ print $1 }')
        ordinal_number=$(printf '%s' "$ordinal" | sed 's/^0*//')
        phase_number=$((ordinal_number / 10))
        printf '%s\t%s\t%s\t%s\tattempt-bc08-%s\tsut-apply-effect\t%s\t%s\t%s\t%s\t%s\ttrue\t1\t%s\t0\tok\t%s\t%s\t%s\t%s\tinjected-rollback\n' \
            "$run" "$fault_ns" "$assertion" "$fault_case" \
            "${fault_case#case-bc08-}" "$hook" "$phase" "$nonce" \
            "$implementation_revision" "$activation_sha" "$phase_number" \
            "$error_id" "$marker" "$stderr_sha" "$parsed_sha" \
            >>"$artifact_dir/fault-trigger-receipts.tsv"
        "$adapter" inventory-bc08 "$fault_db" "$fault_case" rollback \
            >>"$artifact_dir/fault-inventory-rollback.tsv" 2>/dev/null
        before_sha=$(awk -F '	' -v c="$fault_case" '$1 == c' \
            "$artifact_dir/fault-inventory-setup.tsv" |
            sha256sum | awk '{ print $1 }')
        after_sha=$(awk -F '	' -v c="$fault_case" '$1 == c' \
            "$artifact_dir/fault-inventory-rollback.tsv" |
            sha256sum | awk '{ print $1 }')
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\ttrue\t%s\t%s\n' \
            "$assertion" "$run" "$fault_case" "$fault_ns" "$nonce" \
            "$implementation_revision" "$hook" "$phase" "$before_sha" \
            "$after_sha" >>"$artifact_dir/fault-markers.tsv"
        "$adapter" fault-bc08 "$fault_db" clear "$hook" "$phase" "$nonce" \
            "$implementation_revision" effect-1 >/dev/null 2>/dev/null
        "$adapter" operation-bc08 "$fault_db" "$run" "$fault_ns" \
            "$assertion" "$case_id" sut-apply-effect ordinary \
            healthy-action "healthy-$nonce" >/dev/null 2>/dev/null
        "$adapter" inventory-bc08 "$fault_db" "$fault_case" healthy \
            >>"$artifact_dir/fault-inventory-healthy.tsv" 2>/dev/null
        "$adapter" reopen "$fault_db" "$run" "$fault_ns" "$assertion" \
            >/dev/null 2>/dev/null
        "$adapter" inventory-bc08 "$fault_db" "$fault_case" reopened \
            >>"$artifact_dir/fault-inventory-reopened.tsv" 2>/dev/null
        "$adapter" destroy "$fault_ns" "$fault_db" >/dev/null
    done <"$base_dir/bc08-fault-cases.tsv"
fi

"$normalizer" "$artifact_dir/raw-observations.tsv" "$scenario" \
    >"$artifact_dir/normalized-observations.tsv"
sed "s/{scenario}/$scenario/g" "$base_dir/bc08-coverage-template.tsv" \
    >"$artifact_dir/coverage.tsv"
: >"$artifact_dir/exclusions.tsv"

"$oracle" "$artifact_dir" "$run" "$namespace" "$assertion" "$case_id" \
    "$scenario" >"$artifact_dir/oracle-result.tsv"
"$verifier" "$artifact_dir" "$run" "$namespace" "$assertion" "$case_id" \
    "$scenario" "$db" "$mode"
