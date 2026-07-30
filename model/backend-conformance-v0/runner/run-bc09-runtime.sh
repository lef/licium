#!/bin/sh
set -eu

[ "$#" -eq 4 ] || [ "$#" -eq 5 ] || {
    echo "usage: run-bc09-runtime.sh ARTIFACT_DIR RUN NAMESPACE ASSERTION [MODE]" >&2
    exit 2
}

artifact_dir=$1
run=$2
namespace=$3
assertion=$4
runtime_mode=${5:-ordinary}
case "$runtime_mode" in ordinary|mutant-persistent) ;; *) exit 2 ;; esac

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
adapter="$base_dir/profiles/sqlite-reference/run.sh"
cases_registry="$base_dir/bc09-cases.tsv"
scenario_registry="$base_dir/bc09-scenario-ids.tsv"
fault_cases_registry="$base_dir/bc09-fault-cases.tsv"
schema="$base_dir/sqlite-reference/schema-bc09.sql"
normalizer="$script_dir/normalize-bc09.sh"
oracle="$script_dir/oracle-bc09.sh"
verifier="$script_dir/verify-bc09-runtime.sh"

case "$run:$namespace:$assertion" in
    *[!a-zA-Z0-9._:-]*|:*|*::*|*:) exit 2 ;;
esac

scenario=$(
    awk -F '	' -v assertion="$assertion" '
        $1 == assertion { print $3; found++ }
        END { if (found != 1) exit 1 }
    ' "$scenario_registry"
)

[ ! -e "$artifact_dir" ] || {
    echo BC09_RUNTIME_NOT_FRESH >&2
    exit 1
}
mkdir -p "$artifact_dir"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

for name in \
    action-receipts.tsv \
    command-receipts.tsv \
    coverage.tsv \
    exclusions.tsv \
    fault-activation-receipts.tsv \
    fault-configuration-receipts.tsv \
    fault-inventory-healthy.tsv \
    fault-inventory-reopened.tsv \
    fault-inventory-rollback.tsv \
    fault-inventory-setup.tsv \
    fault-markers.tsv \
    fault-trigger-receipts.tsv \
    inventory-after.tsv \
    inventory-before.tsv \
    inventory-reopened.tsv \
    normalized-observations.tsv \
    oracle-result.tsv \
    pragma.tsv \
    raw-observations.tsv \
    raw-seal.tsv
do
    : >"$artifact_dir/$name"
done

invoke_status=0
invoke()
{
    invoke_phase=$1
    invoke_operation=$2
    invoke_mode=$3
    invoke_stdout=$4
    invoke_stderr=$5
    shift 5
    argv_sha=$(
        for argument in "$@"
        do
            case "$argument" in
                "$adapter") printf '%s\n' '{adapter-entrypoint}' ;;
                "$artifact_dir/"*)
                    printf '%s\n' "{artifact-path:${argument##*/}}" ;;
                "$tmp/"*.db)
                    printf '%s\n' "{database-path:${argument##*/}}" ;;
                "$tmp/"*)
                    printf '%s\n' "{temporary-path:${argument##*/}}" ;;
                *) printf '%s\n' "$argument" ;;
            esac
        done | sha256sum | awk '{ print $1 }'
    )
    set +e
    "$@" >"$invoke_stdout" 2>"$invoke_stderr"
    invoke_status=$?
    set -e
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$run" "$namespace" "$assertion" "$invoke_phase" \
        "$invoke_operation" "$invoke_mode" "$invoke_status" \
        "$(sha256sum "$invoke_stdout" | awk '{ print $1 }')" \
        "$(wc -c <"$invoke_stdout" | tr -d ' ')" \
        "$(sha256sum "$invoke_stderr" | awk '{ print $1 }')" \
        "$(wc -c <"$invoke_stderr" | tr -d ' ')" "$argv_sha" \
        >>"$artifact_dir/command-receipts.tsv"

    if [ "$invoke_status" -eq 0 ] &&
        [ "${invoke_phase%-destroy}" = "$invoke_phase" ]; then
        [ "$(cat "$invoke_stderr")" = "pragma	foreign-keys	1" ] || {
            echo BC09_PRAGMA_EVIDENCE_INVALID >&2
            exit 1
        }
        printf '%s\t%s\t%s\t%s\tforeign-keys\t1\n' \
            "$run" "$namespace" "$assertion" "$invoke_phase" \
            >>"$artifact_dir/pragma.tsv"
    elif [ "${invoke_phase%-destroy}" != "$invoke_phase" ] &&
        [ -s "$invoke_stderr" ]; then
        echo BC09_COMMAND_CUSTODY_INVALID >&2
        exit 1
    fi
}

fault_binding()
{
    case_id=$1
    awk -F '	' -v case_id="$case_id" '
        $1 == case_id { print $2 "	" $3 "	" $4 "	" $5; found++ }
        END { if (found != 1) exit 1 }
    ' "$fault_cases_registry"
}

record_fault_configuration()
{
    case_id=$1
    hook=$2
    phase=$3
    error_id=$4
    ordinal=$5
    nonce=$6
    activation_line=$7
    stderr_file=$8

    activation_sha=$(printf '%s\n' "$activation_line" |
        sha256sum | awk '{ print $1 }')
    schema_sha=$(sha256sum "$schema" | awk '{ print $1 }')
    error_literal="LICIUM_BC09_FAULT_$(printf '%s' "$phase" |
        tr 'a-z-' 'A-Z_')"
    error_sha=$(printf '%s\n' "$error_literal" |
        sha256sum | awk '{ print $1 }')
    predicate_sha=$(printf '%s\t%s\n' "$hook" "$phase" |
        sha256sum | awk '{ print $1 }')
    raw_stderr_sha=$(sha256sum "$stderr_file" | awk '{ print $1 }')

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$run" "$namespace" "$assertion" "$case_id" "$hook" "$phase" \
        "$nonce" impl-bc09-v0 "$activation_sha" "trigger-bc09-$phase" \
        "$schema_sha" "$error_sha" "$predicate_sha" configured \
        >>"$artifact_dir/fault-configuration-receipts.tsv"

    trigger_ordinal=$(awk -v value="$ordinal" 'BEGIN { print int(value / 10) }')
    printf '%s\t%s\t%s\t%s\tattempt-bc09-%s\tsut-apply-effect\t%s\t%s\t%s\timpl-bc09-v0\t%s\ttrue\t1\t%s\t0\tok\t%s\t%s\t%s\t%s\tinjected-rollback\n' \
        "$run" "$namespace" "$assertion" "$case_id" \
        "${case_id#case-}" "$hook" "$phase" "$nonce" "$activation_sha" \
        "$trigger_ordinal" "$error_id" "$error_literal" \
        "$raw_stderr_sha" "$error_sha" \
        >>"$artifact_dir/fault-trigger-receipts.tsv"
}

process_case()
{
    case_id=$1
    case_tmp="$tmp/$case_id"
    mkdir -p "$case_tmp"
    db="$case_tmp/$case_id.db"
    case_namespace="$namespace-${case_id#case-}"
    case_actions="$case_tmp/action-receipts.tsv"
    : >"$case_actions"

    invoke "$case_id-create" profile-create-namespace normal \
        "$case_tmp/create.out" "$case_tmp/create.err" \
        "$adapter" create-bc09 "$case_namespace" "$db"
    [ "$invoke_status" -eq 0 ] || exit "$invoke_status"

    invoke "$case_id-setup" sut-setup-bc09 ordinary \
        "$case_tmp/setup.out" "$case_tmp/setup.err" \
        "$adapter" operation-bc09 "$db" "$run" "$case_namespace" \
        "$assertion" "$case_id" sut-setup-bc09 ordinary setup \
        "setup-$case_id" setup
    [ "$invoke_status" -eq 0 ] || exit "$invoke_status"

    invoke "$case_id-inventory-before" profile-inventory-bc09 ordinary \
        "$case_tmp/inventory-before.tsv" "$case_tmp/inventory-before.err" \
        "$adapter" inventory-bc09 "$db" "$case_id" before
    [ "$invoke_status" -eq 0 ] || exit "$invoke_status"
    cat "$case_tmp/inventory-before.tsv" \
        >>"$artifact_dir/inventory-before.tsv"

    fault_required=false
    [ "$assertion" = BC09_FAILPOINT_PERSISTS ] && fault_required=true
    [ "$case_id" = case-fault ] && fault_required=true
    trigger_count=0
    hook=-
    phase=-
    error_id=-
    ordinal=000
    nonce="action-$run-$case_id"
    if [ "$fault_required" = true ]; then
        binding=$(fault_binding "$case_id")
        hook=$(printf '%s\n' "$binding" | awk -F '	' '{ print $1 }')
        phase=$(printf '%s\n' "$binding" | awk -F '	' '{ print $2 }')
        error_id=$(printf '%s\n' "$binding" | awk -F '	' '{ print $3 }')
        ordinal=$(printf '%s\n' "$binding" | awk -F '	' '{ print $4 }')
        nonce="fault-$run-${case_id#case-}"
        invoke "$case_id-activate-fault" profile-activate-fault-bc09 \
            case-hook "$case_tmp/activate.out" "$case_tmp/activate.err" \
            "$adapter" fault-bc09 "$db" activate "$hook" "$phase" \
            "$nonce" impl-bc09-v0 effect-1
        [ "$invoke_status" -eq 0 ] || exit "$invoke_status"
        activation_line=$(printf '%s\t%s\t%s\t%s\tattempt-bc09-%s\tsut-apply-effect\t%s\t%s\t%s\timpl-bc09-v0' \
            "$run" "$namespace" "$assertion" "$case_id" \
            "${case_id#case-}" "$hook" "$phase" "$nonce")
        if [ "$assertion" = BC09_FAILPOINT_PERSISTS ]; then
            printf '%s\n' "$activation_line" \
                >>"$artifact_dir/fault-activation-receipts.tsv"
        fi
    fi

    if [ "$case_id" = case-duplicate ]; then
        invoke "$case_id-action-1" sut-apply-effect ordinary \
            "$case_tmp/action-1.out" "$case_tmp/action-1.err" \
            "$adapter" operation-bc09 "$db" "$run" "$case_namespace" \
            "$assertion" "$case_id" sut-apply-effect ordinary delivery-1 \
            "$nonce" attempt-1
        [ "$invoke_status" -eq 0 ] || exit "$invoke_status"
        cat "$case_tmp/action-1.out" >>"$case_actions"

        action_mode=ordinary
        [ "$fault_required" = true ] && action_mode=fault
        [ "$runtime_mode" = mutant-persistent ] &&
            action_mode=mutant-persistent
        invoke "$case_id-action-2" sut-apply-effect "$action_mode" \
            "$case_tmp/action-2.out" "$case_tmp/action-2.err" \
            "$adapter" operation-bc09 "$db" "$run" "$case_namespace" \
            "$assertion" "$case_id" sut-apply-effect "$action_mode" \
            delivery-2 "$nonce" attempt-2
        if [ "$fault_required" = true ]; then
            [ "$invoke_status" -ne 0 ] || {
                echo BC09_FAULT_UNREACHED >&2
                exit 1
            }
            trigger_count=1
        else
            [ "$invoke_status" -eq 0 ] || exit "$invoke_status"
        fi
        cat "$case_tmp/action-2.out" >>"$case_actions"
        fault_stderr="$case_tmp/action-2.err"
    else
        action_mode=ordinary
        [ "$fault_required" = true ] && action_mode=fault
        [ "$runtime_mode" = mutant-persistent ] &&
            action_mode=mutant-persistent
        invoke "$case_id-action" sut-apply-effect "$action_mode" \
            "$case_tmp/action.out" "$case_tmp/action.err" \
            "$adapter" operation-bc09 "$db" "$run" "$case_namespace" \
            "$assertion" "$case_id" sut-apply-effect "$action_mode" \
            delivery-1 "$nonce" attempt-1
        if [ "$fault_required" = true ]; then
            [ "$invoke_status" -ne 0 ] || {
                echo BC09_FAULT_UNREACHED >&2
                exit 1
            }
            trigger_count=1
        else
            [ "$invoke_status" -eq 0 ] || exit "$invoke_status"
        fi
        cat "$case_tmp/action.out" >>"$case_actions"
        fault_stderr="$case_tmp/action.err"
    fi
    cat "$case_actions" >>"$artifact_dir/action-receipts.tsv"

    invoke "$case_id-inventory-after" profile-inventory-bc09 ordinary \
        "$case_tmp/inventory-after.tsv" "$case_tmp/inventory-after.err" \
        "$adapter" inventory-bc09 "$db" "$case_id" after
    [ "$invoke_status" -eq 0 ] || exit "$invoke_status"
    cat "$case_tmp/inventory-after.tsv" \
        >>"$artifact_dir/inventory-after.tsv"

    if [ "$fault_required" = true ]; then
        if [ "$assertion" = BC09_FAILPOINT_PERSISTS ]; then
            record_fault_configuration "$case_id" "$hook" "$phase" \
                "$error_id" "$ordinal" "$nonce" "$activation_line" \
                "$fault_stderr"
            before_sha=$(sha256sum "$case_tmp/inventory-before.tsv" |
                awk '{ print $1 }')
            after_sha=$(sha256sum "$case_tmp/inventory-after.tsv" |
                awk '{ print $1 }')
            printf '%s\t%s\t%s\t%s\t%s\timpl-bc09-v0\t%s\t%s\ttrue\t%s\t%s\n' \
                "$assertion" "$run" "$case_id" "$namespace" "$nonce" \
                "$hook" "$phase" "$before_sha" "$after_sha" \
                >>"$artifact_dir/fault-markers.tsv"
            cat "$case_tmp/inventory-before.tsv" \
                >>"$artifact_dir/fault-inventory-setup.tsv"
            cat "$case_tmp/inventory-after.tsv" \
                >>"$artifact_dir/fault-inventory-rollback.tsv"
        fi
        invoke "$case_id-clear-fault" profile-clear-fault-bc09 case-hook \
            "$case_tmp/clear.out" "$case_tmp/clear.err" \
            "$adapter" fault-bc09 "$db" clear "$hook" "$phase" "$nonce" \
            impl-bc09-v0 effect-1
        [ "$invoke_status" -eq 0 ] || exit "$invoke_status"
    fi

    invoke "$case_id-reopen" profile-reopen-namespace normal \
        "$case_tmp/reopen.out" "$case_tmp/reopen.err" \
        "$adapter" reopen "$db" "$run" "$case_namespace" "$assertion"
    [ "$invoke_status" -eq 0 ] || exit "$invoke_status"
    invoke "$case_id-inventory-reopened" profile-inventory-bc09 ordinary \
        "$case_tmp/inventory-reopened.tsv" \
        "$case_tmp/inventory-reopened.err" \
        "$adapter" inventory-bc09 "$db" "$case_id" reopened
    [ "$invoke_status" -eq 0 ] || exit "$invoke_status"
    cat "$case_tmp/inventory-reopened.tsv" \
        >>"$artifact_dir/inventory-reopened.tsv"

    "$adapter" observe-bc09 "$scenario" "$case_id" "$case_actions" \
        "$case_tmp/inventory-before.tsv" "$case_tmp/inventory-after.tsv" \
        "$case_tmp/inventory-reopened.tsv" "$trigger_count" \
        "$case_tmp/raw.tsv" >/dev/null 2>"$case_tmp/observe.err"
    [ "$(cat "$case_tmp/observe.err")" = "pragma	foreign-keys	1" ] ||
        exit 1
    cat "$case_tmp/raw.tsv" >>"$artifact_dir/raw-observations.tsv"

    if [ "$assertion" = BC09_FAILPOINT_PERSISTS ]; then
        invoke "$case_id-prepare-healthy" sut-setup-bc09 healthy \
            "$case_tmp/prepare-healthy.out" \
            "$case_tmp/prepare-healthy.err" \
            "$adapter" operation-bc09 "$db" "$run" "$case_namespace" \
            "$assertion" "$case_id" sut-setup-bc09 healthy setup \
            "healthy-setup-$case_id" setup
        [ "$invoke_status" -eq 0 ] || exit "$invoke_status"
        invoke "$case_id-healthy-action" sut-apply-effect healthy \
            "$case_tmp/healthy-action.out" "$case_tmp/healthy-action.err" \
            "$adapter" operation-bc09 "$db" "$run" "$case_namespace" \
            "$assertion" "$case_id" sut-apply-effect healthy delivery-1 \
            "healthy-$case_id" healthy
        [ "$invoke_status" -eq 0 ] || exit "$invoke_status"
        cat "$case_tmp/healthy-action.out" \
            >>"$artifact_dir/action-receipts.tsv"
        invoke "$case_id-inventory-healthy" profile-inventory-bc09 ordinary \
            "$case_tmp/inventory-healthy.tsv" \
            "$case_tmp/inventory-healthy.err" \
            "$adapter" inventory-bc09 "$db" "$case_id" healthy
        [ "$invoke_status" -eq 0 ] || exit "$invoke_status"
        cat "$case_tmp/inventory-healthy.tsv" \
            >>"$artifact_dir/fault-inventory-healthy.tsv"
        invoke "$case_id-reopen-healthy" profile-reopen-namespace normal \
            "$case_tmp/reopen-healthy.out" "$case_tmp/reopen-healthy.err" \
            "$adapter" reopen "$db" "$run" "$case_namespace" "$assertion"
        [ "$invoke_status" -eq 0 ] || exit "$invoke_status"
        invoke "$case_id-inventory-healthy-reopened" \
            profile-inventory-bc09 ordinary \
            "$case_tmp/inventory-healthy-reopened.tsv" \
            "$case_tmp/inventory-healthy-reopened.err" \
            "$adapter" inventory-bc09 "$db" "$case_id" reopened
        [ "$invoke_status" -eq 0 ] || exit "$invoke_status"
        cat "$case_tmp/inventory-healthy-reopened.tsv" \
            >>"$artifact_dir/fault-inventory-reopened.tsv"
    fi

    invoke "$case_id-destroy" profile-destroy-namespace normal \
        "$case_tmp/destroy.out" "$case_tmp/destroy.err" \
        "$adapter" destroy "$case_namespace" "$db"
    [ "$invoke_status" -eq 0 ] || exit "$invoke_status"
}

awk -F '	' -v assertion="$assertion" '
    $1 == assertion && !seen[$3]++ { print $3 }
' "$cases_registry" >"$tmp/cases"
[ -s "$tmp/cases" ] || exit 2

while IFS= read -r case_id
do
    process_case "$case_id"
done <"$tmp/cases"

for name in inventory-before.tsv inventory-after.tsv inventory-reopened.tsv \
    fault-inventory-setup.tsv fault-inventory-rollback.tsv \
    fault-inventory-healthy.tsv fault-inventory-reopened.tsv
do
    LC_ALL=C sort "$artifact_dir/$name" >"$tmp/sorted"
    cp "$tmp/sorted" "$artifact_dir/$name"
done

awk -F '	' 'BEGIN { OFS=FS }
    {
        normalized=$2
        sub(/^raw-/, "obs-", normalized)
        print $1,$2,"record",$1,normalized,"all"
    }
' "$artifact_dir/raw-observations.tsv" >"$artifact_dir/coverage.tsv"

raw_sha=$(sha256sum "$artifact_dir/raw-observations.tsv" | awk '{ print $1 }')
raw_bytes=$(wc -c <"$artifact_dir/raw-observations.tsv" | tr -d ' ')
receipt_sha=$(sha256sum "$artifact_dir/action-receipts.tsv" |
    awk '{ print $1 }')
printf 'raw-observations.tsv\t100644\t%s\t%s\t%s\t%s\t%s\t%s\tsealed-before-normalization\n' \
    "$raw_sha" "$raw_bytes" "$run" "$namespace" "$scenario" \
    "$receipt_sha" >"$artifact_dir/raw-seal.tsv"

"$normalizer" "$artifact_dir/raw-observations.tsv" \
    "$artifact_dir/normalized-observations.tsv"
set +e
oracle_output=$(
    "$oracle" "$artifact_dir/normalized-observations.tsv" "$cases_registry" \
        "$assertion" "$scenario" "$artifact_dir/oracle-result.tsv" 2>&1
)
oracle_status=$?
set -e
if [ "$runtime_mode" = mutant-persistent ]; then
    [ "$oracle_status" -ne 0 ] &&
        [ "$oracle_output" = BC09_ORACLE_MISMATCH ] || {
            echo BC09_CONTROL_TARGET_INVALID >&2
            exit 1
        }
    case "$assertion" in
        BC09_DIAGNOSTIC_EPHEMERAL)
            marker=BC09_DIAGNOSTIC_PERSISTENCE_DETECTED ;;
        BC09_DUPLICATE_PERSISTS)
            marker=BC09_DUPLICATE_ARTIFACT_DETECTED ;;
        BC09_FAILPOINT_PERSISTS)
            marker=BC09_FAILPOINT_ARTIFACT_DETECTED ;;
        BC09_FAILURE_NO_PERSISTENT_ARTIFACT)
            marker=BC09_PERSISTENT_ARTIFACT_DETECTED ;;
        BC09_INCOMPLETE_PERSISTS)
            marker=BC09_INCOMPLETE_ARTIFACT_DETECTED ;;
        BC09_REJECTED_PERSISTS)
            marker=BC09_REJECTED_ARTIFACT_DETECTED ;;
        BC09_STALE_PERSISTS)
            marker=BC09_STALE_ARTIFACT_DETECTED ;;
        *)
            exit 2 ;;
    esac
    echo "$marker" >&2
    exit 1
fi
[ "$oracle_status" -eq 0 ] || {
    printf '%s\n' "$oracle_output" >&2
    exit "$oracle_status"
}

chmod 0644 "$artifact_dir"/*.tsv

[ -x "$verifier" ] || {
    echo BC09_RUNTIME_VERIFIER_MISSING >&2
    exit 1
}
"$verifier" "$artifact_dir" "$run" "$namespace" "$assertion" "$scenario"
echo BC09_RUNTIME_VALID
