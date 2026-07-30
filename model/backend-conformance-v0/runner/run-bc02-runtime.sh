#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
adapter="$base_dir/profiles/sqlite-reference/run.sh"
normalizer="$script_dir/normalize-bc02.sh"
oracle="$script_dir/oracle-bc02.sh"
verifier="$script_dir/verify-bc02-runtime.sh"
registry="$base_dir/bc02-runtime-artifacts.tsv"

[ "$#" -eq 6 ] || {
    echo "usage: run-bc02-runtime.sh ARTIFACT_DIR RUN NS ASSERTION CASE MODE" >&2
    exit 2
}

artifact_dir=$1
run=$2
namespace=$3
assertion=$4
case_id=$5
mode=$6
form_mode=$mode
retry_mode=ordinary
case "$assertion:$case_id" in
    BC02_PARTIAL_RESIDUE:case-bc02-after-root-header|\
    BC02_PARTIAL_RESIDUE:case-bc02-after-root-member|\
    BC02_ROLLBACK_COMPLETE:case-bc02-after-root-header|\
    BC02_ROLLBACK_COMPLETE:case-bc02-after-root-member|\
    BC02_POISONED_RETRY:case-bc02-after-root-header|\
    BC02_POISONED_RETRY:case-bc02-after-root-member)
        exec "$script_dir/run-bc02-fault-runtime.sh" \
            "$artifact_dir" "$run" "$namespace" "$assertion" "$case_id" "$mode"
        ;;
esac
case "$assertion:$case_id" in
    BC02_COMPLETE_AVAILABLE:case-bc02-complete)
        scenario=bc02-complete-available--case-bc02-complete
        after_stage=success-after
        resolution_stage=success
        after_inventory=inventory-success-after.tsv
        form_attempt=attempt-complete
        case "$mode" in
            ordinary|mutant-complete-unavailable|\
            mutant-complete-as-unavailable) ;;
            *) exit 2 ;;
        esac
        ;;
    BC02_INCOMPLETE_AS_COMPLETE:case-bc02-incomplete-missing|\
    BC02_INCOMPLETE_AS_COMPLETE:case-bc02-incomplete-substitution)
        scenario=bc02-incomplete-as-complete--"$case_id"
        after_stage=rollback-after
        resolution_stage=unavailable
        after_inventory=inventory-rollback-after.tsv
        form_attempt=attempt-initial
        case "$case_id:$mode" in
            case-bc02-incomplete-missing:ordinary|\
            case-bc02-incomplete-missing:mutant-incomplete-as-complete|\
            case-bc02-incomplete-substitution:ordinary|\
            case-bc02-incomplete-substitution:mutant-count-only-completeness)
                ;;
            *)
                exit 2
                ;;
        esac
        ;;
    BC02_HEALTHY_RETRY:case-bc02-incomplete-corrected)
        scenario=bc02-healthy-retry--case-bc02-incomplete-corrected
        after_stage=rollback-after
        resolution_stage=unavailable
        after_inventory=inventory-rollback-after.tsv
        form_attempt=attempt-initial
        healthy_retry=1
        form_mode=ordinary
        case "$mode" in
            ordinary)
                correction_mode=ordinary
                ;;
            mutant-retry-rejected)
                correction_mode=ordinary
                retry_mode=$mode
                ;;
            mutant-correction-cleans-root|mutant-correction-forbidden-write)
                correction_mode=$mode
                ;;
            *)
                exit 2
                ;;
        esac
        ;;
    *)
        exit 2
        ;;
esac

mkdir -p "$artifact_dir"
db="$artifact_dir/$namespace.db"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"; rm -f "$db"' EXIT HUP INT TERM

while IFS='	' read -r name fields cardinality kind source; do
    : > "$artifact_dir/$name"
done < "$registry"

command_receipts="$artifact_dir/command-receipts.tsv"
pragma="$artifact_dir/pragma.tsv"

invoke()
{
    phase=$1
    operation=$2
    command_mode=$3
    stdout=$4
    stderr=$5
    shift 5

    argv_sha=$(
        for argument in "$@"; do
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
    "$@" > "$stdout" 2> "$stderr"
    status=$?
    set -e

    stdout_sha=$(sha256sum "$stdout" | awk '{ print $1 }')
    stdout_bytes=$(wc -c < "$stdout" | tr -d ' ')
    stderr_sha=$(sha256sum "$stderr" | awk '{ print $1 }')
    stderr_bytes=$(wc -c < "$stderr" | tr -d ' ')

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$run" "$namespace" "$assertion" "$phase" "$operation" \
        "$command_mode" "$status" "$stdout_sha" "$stdout_bytes" \
        "$stderr_sha" "$stderr_bytes" "$argv_sha" >> "$command_receipts"

    [ "$status" -eq 0 ] || {
        if [ "$phase" = "correction" ]; then
            echo BC02_CORRECTION_WRITESET_INVALID >&2
            exit 1
        fi
        cat "$stderr" >&2
        exit "$status"
    }

    if [ "$phase" = "correction" ]; then
        {
            printf '%s\n' \
                'PRAGMA foreign_keys=ON;' \
                'BEGIN IMMEDIATE;' \
                'INSERT INTO source_object' \
                "             VALUES ('object-c','pair','value-c');" \
                '-- TRIGGER correction_guard_source_insert;' \
                'COMMIT;'
            printf 'pragma\tforeign-keys\t1\n'
        } > "$tmp/correction-trace.expected"
        cmp -s "$tmp/correction-trace.expected" "$stderr" || {
            echo BC02_CORRECTION_WRITESET_INVALID >&2
            exit 1
        }
        printf '%s\t%s\t%s\t%s\tforeign-keys\t1\n' \
            "$run" "$namespace" "$assertion" "$phase" >> "$pragma"
    elif [ "$phase" != "destroy" ]; then
        [ "$(cat "$stderr")" = "pragma	foreign-keys	1" ] || {
            echo BC02_PRAGMA_EVIDENCE_INVALID >&2
            exit 1
        }
        printf '%s\t%s\t%s\t%s\tforeign-keys\t1\n' \
            "$run" "$namespace" "$assertion" "$phase" >> "$pragma"
    elif [ -s "$stderr" ]; then
        echo BC02_COMMAND_CUSTODY_INVALID >&2
        exit 1
    fi
}

invoke create profile-create-namespace normal \
    "$tmp/create.out" "$tmp/create.err" \
    "$adapter" create-bc02 "$namespace" "$db"

invoke setup sut-setup-bc02 ordinary \
    "$tmp/setup.out" "$tmp/setup.err" \
    "$adapter" operation-bc02 "$db" "$run" "$namespace" "$assertion" \
    "$case_id" sut-setup-bc02 ordinary setup setup-nonce

invoke setup-before runner-bind-evidence ordinary \
    "$artifact_dir/inventory-setup-before.tsv" "$tmp/setup-before.err" \
    "$adapter" inventory-bc02 "$db" "$scenario"

invoke form sut-form-root "$form_mode" \
    "$artifact_dir/action-receipts.tsv" "$tmp/form.err" \
    "$adapter" operation-bc02 "$db" "$run" "$namespace" "$assertion" \
    "$case_id" sut-form-root "$form_mode" "$form_attempt" form-nonce

invoke "$after_stage" runner-bind-evidence ordinary \
    "$artifact_dir/$after_inventory" "$tmp/after-inventory.err" \
    "$adapter" inventory-bc02 "$db" "$scenario"

invoke "$resolution_stage" runner-bind-evidence ordinary \
    "$tmp/resolution-after.out" "$tmp/resolution-after.err" \
    "$adapter" resolution-bc02 "$db" "$run" "$namespace" "$assertion" \
    "$case_id" "$resolution_stage"
cat "$tmp/resolution-after.out" >> "$artifact_dir/resolution-receipts.tsv"

if [ "${healthy_retry:-0}" -eq 1 ]; then
    invoke correction sut-correct-root-input "$correction_mode" \
        "$artifact_dir/correction-receipts.tsv" "$tmp/correction.err" \
        "$adapter" operation-bc02 "$db" "$run" "$namespace" "$assertion" \
        "$case_id" sut-correct-root-input "$correction_mode" \
        correction-correction-02 correction-nonce

    guard="$base_dir/sqlite-reference/correction-guard-bc02.sql"
    guard_sha=$(sha256sum "$guard" | awk '{ print $1 }')
    printf '%s\t%s\t%s\t%s\tcorrection-correction-02\tsut-correct-root-input\tsource_object\tobject-c\tinsert-only\tguard-bc02-v1\t%s\tenforced\tcorrection-nonce\n' \
        "$run" "$namespace" "$assertion" "$case_id" "$guard_sha" \
        > "$artifact_dir/correction-write-guard-receipts.tsv"

    invoke correction-after runner-bind-evidence ordinary \
        "$artifact_dir/inventory-correction-after.tsv" \
        "$tmp/correction-after.err" \
        "$adapter" inventory-bc02 "$db" "$scenario"

    invoke retry sut-retry-root "$retry_mode" \
        "$tmp/retry-action.out" "$tmp/retry.err" \
        "$adapter" operation-bc02 "$db" "$run" "$namespace" "$assertion" \
        "$case_id" sut-retry-root "$retry_mode" attempt-retry retry-nonce
    cat "$tmp/retry-action.out" >> "$artifact_dir/action-receipts.tsv"

    invoke retry-after runner-bind-evidence ordinary \
        "$artifact_dir/inventory-retry-after.tsv" "$tmp/retry-after.err" \
        "$adapter" inventory-bc02 "$db" "$scenario"

    invoke retry-success runner-bind-evidence ordinary \
        "$tmp/resolution-retry.out" "$tmp/resolution-retry.err" \
        "$adapter" resolution-bc02 "$db" "$run" "$namespace" "$assertion" \
        "$case_id" retry-success
    cat "$tmp/resolution-retry.out" >> "$artifact_dir/resolution-receipts.tsv"
fi

invoke durability-reopen profile-reopen-namespace ordinary \
    "$tmp/reopen.out" "$tmp/reopen.err" \
    "$adapter" reopen "$db" "$run" "$namespace" "$assertion"

invoke reopened runner-bind-evidence ordinary \
    "$tmp/resolution-reopened.out" "$tmp/resolution-reopened.err" \
    "$adapter" resolution-bc02 "$db" "$run" "$namespace" "$assertion" \
    "$case_id" reopened
cat "$tmp/resolution-reopened.out" >> "$artifact_dir/resolution-receipts.tsv"

invoke destroy profile-destroy-namespace normal \
    "$tmp/destroy.out" "$tmp/destroy.err" \
    "$adapter" destroy "$namespace" "$db"

action="$artifact_dir/action-receipts.tsv"
inventory="$artifact_dir/inventory-success-after.tsv"
resolutions="$artifact_dir/resolution-receipts.tsv"
raw="$artifact_dir/raw-observations.tsv"
inventory="$artifact_dir/$after_inventory"

formation=$(awk -F '	' '{ print $5 "/" $7 "/" $9 }' "$action")
availability=$(awk -F '	' -v stage="$resolution_stage" '$5 == stage {
    print ($8 == "available" ? "available/1" : "unavailable/0")
}' "$resolutions")
if [ "$assertion" = "BC02_COMPLETE_AVAILABLE" ]; then
    membership=$(awk -F '	' -v stage="$resolution_stage" '$5 == stage {
        print ($8 == "available" ? "complete/" $9 : "incomplete/" $9)
    }' "$resolutions")
else
    membership=$(awk -F '	' '{ print "incomplete/" $11 "/" $10 }' "$action")
fi
reopened=$(awk -F '	' '$5 == "reopened" {
    print ($8 == "available" ? "available/1" : "unavailable/0")
}' "$resolutions")
ancestry=$(awk -F '	' -v stage="$resolution_stage" '$5 == stage {
    print ($8 == "available" ? "bound/" $10 : "unbound/-")
}' "$resolutions")

logical_count()
{
    relation=$1
    awk -F '	' -v relation="$relation" '
        $2 == relation && $3 != "@relation" { seen[$3] = 1 }
        END {
            for (key in seen) count++
            print count + 0
        }
    ' "$inventory"
}

if [ "$assertion" = "BC02_COMPLETE_AVAILABLE" ]; then
    {
        printf '%s\traw-ancestry-01\tresolution-receipt\tsuccess\tancestry/root-02\t%s\n' \
            "$scenario" "$ancestry"
        printf '%s\traw-ancestry-persistence-01\tinventory-repository\tsuccess-after\troot-ancestry/semantic-row-count\t%s\n' \
            "$scenario" "$(logical_count root-ancestry)"
        printf '%s\traw-availability-01\tresolution-receipt\tsuccess\tavailability/root-02\t%s\n' \
            "$scenario" "$availability"
        printf '%s\traw-formation-01\taction-receipt\taction\tattempt/outcome/root\t%s\n' \
            "$scenario" "$formation"
        printf '%s\traw-header-persistence-01\tinventory-repository\tsuccess-after\troot-header/semantic-row-count\t%s\n' \
            "$scenario" "$(logical_count root)"
        printf '%s\traw-member-persistence-01\tinventory-repository\tsuccess-after\troot-member/semantic-row-count\t%s\n' \
            "$scenario" "$(logical_count root-member)"
        printf '%s\traw-membership-01\tresolution-receipt\tsuccess\tmembership/root-02\t%s\n' \
            "$scenario" "$membership"
        printf '%s\traw-reopened-resolution-01\tresolution-receipt\treopened\tresolution/root-02\t%s\n' \
            "$scenario" "$reopened"
    } | LC_ALL=C sort > "$raw"
elif [ "${healthy_retry:-0}" -eq 1 ]; then
    setup_inventory="$artifact_dir/inventory-setup-before.tsv"
    rollback_inventory="$artifact_dir/inventory-rollback-after.tsv"
    correction_inventory="$artifact_dir/inventory-correction-after.tsv"
    setup_sha=$(sha256sum "$setup_inventory" | awk '{ print $1 }')
    rollback_sha=$(sha256sum "$rollback_inventory" | awk '{ print $1 }')
    correction_sha=$(sha256sum "$correction_inventory" | awk '{ print $1 }')
    rollback_protected_sha=$(
        awk -F '	' '$2 != "source-object"' "$rollback_inventory" |
            sha256sum | awk '{ print $1 }'
    )
    correction_protected_sha=$(
        awk -F '	' '$2 != "source-object"' "$correction_inventory" |
            sha256sum | awk '{ print $1 }'
    )
    initial_action=$(sed -n '1p' "$action")
    retry_action=$(sed -n '2p' "$action")
    initial_resolution=$(awk -F '	' '$5 == "unavailable"' "$resolutions")
    retry_resolution=$(awk -F '	' '$5 == "retry-success"' "$resolutions")
    reopened_resolution=$(awk -F '	' '$5 == "reopened"' "$resolutions")
    {
        printf '%s\traw-attempt-identity-01\taction-receipt\tinitial-form\tattempt/request/root\t%s/%s/%s\n' \
            "$scenario" \
            "$(printf '%s\n' "$initial_action" | cut -f5)" \
            "$(printf '%s\n' "$initial_action" | cut -f8)" \
            "$(printf '%s\n' "$initial_action" | cut -f9)"
        printf '%s\traw-attempt-identity-02\taction-receipt\tretry\tattempt/request/root\t%s/%s/%s\n' \
            "$scenario" \
            "$(printf '%s\n' "$retry_action" | cut -f5)" \
            "$(printf '%s\n' "$retry_action" | cut -f8)" \
            "$(printf '%s\n' "$retry_action" | cut -f9)"
        printf '%s\traw-correction-01\tcorrection-receipt\tcorrection\tobject/outcome\t%s/%s\n' \
            "$scenario" \
            "$(cut -f8 "$artifact_dir/correction-receipts.tsv")" \
            "$(cut -f7 "$artifact_dir/correction-receipts.tsv")"
        printf '%s\traw-correction-02\tinventory-repository\trollback-after\tsemantic-inventory-sha256\t%s\n' \
            "$scenario" "$rollback_sha"
        printf '%s\traw-correction-03\tinventory-repository\tcorrection-after\tsemantic-inventory-sha256\t%s\n' \
            "$scenario" "$correction_sha"
        printf '%s\traw-correction-isolation-01\tcorrection-write-guard-receipt\tcorrection\tallowed-write\tsource-object/object-c/insert-only\n' \
            "$scenario"
        printf '%s\traw-correction-isolation-02\tinventory-repository\trollback-after\tprotected-relations-sha256\t%s\n' \
            "$scenario" "$rollback_protected_sha"
        printf '%s\traw-correction-isolation-03\tinventory-repository\tcorrection-after\tprotected-relations-sha256\t%s\n' \
            "$scenario" "$correction_protected_sha"
        printf '%s\traw-error-identity-01\taction-receipt\tinitial-form\t%s/error-id/error-marker\t%s/%s\n' \
            "$scenario" \
            "$(printf '%s\n' "$initial_action" | cut -f5)" \
            "$(printf '%s\n' "$initial_action" | cut -f16)" \
            "$(printf '%s\n' "$initial_action" | cut -f17)"
        printf '%s\traw-failure-reason-01\taction-receipt\tinitial-form\t%s/error-id/error-marker\t%s/%s\n' \
            "$scenario" \
            "$(printf '%s\n' "$initial_action" | cut -f18)" \
            "$(printf '%s\n' "$initial_action" | cut -f19)" \
            "$(printf '%s\n' "$initial_action" | cut -f7)"
        printf '%s\traw-initial-availability-01\tresolution-receipt\tunavailable\tavailability/root-02\t%s/%s\n' \
            "$scenario" \
            "$(printf '%s\n' "$initial_resolution" | cut -f8 |
                sed 's/root-unavailable/unavailable/')" 0
        printf '%s\traw-initial-formation-01\taction-receipt\tinitial-form\tattempt/outcome/root\t%s/%s/%s\n' \
            "$scenario" \
            "$(printf '%s\n' "$initial_action" | cut -f5)" \
            "$(printf '%s\n' "$initial_action" | cut -f7)" \
            "$(printf '%s\n' "$initial_action" | cut -f9)"
        printf '%s\traw-initial-membership-01\taction-receipt\tinitial-form\tinput-membership/request-02\tincomplete/%s/%s\n' \
            "$scenario" \
            "$(printf '%s\n' "$initial_action" | cut -f11)" \
            "$(printf '%s\n' "$initial_action" | cut -f10)"
        printf '%s\traw-initial-rollback-01\tinventory-repository\tsetup-before\tsemantic-inventory-sha256\t%s\n' \
            "$scenario" "$setup_sha"
        printf '%s\traw-initial-rollback-02\tinventory-repository\trollback-after\tsemantic-inventory-sha256\t%s\n' \
            "$scenario" "$rollback_sha"
        printf '%s\traw-reopened-resolution-01\tresolution-receipt\treopened\tresolution/root-02\tavailable/1\n' \
            "$scenario"
        printf '%s\traw-retry-ancestry-01\tresolution-receipt\tretry-success\tancestry/root-02\tbound/%s\n' \
            "$scenario" "$(printf '%s\n' "$retry_resolution" | cut -f10)"
        printf '%s\traw-retry-availability-01\tresolution-receipt\tretry-success\tavailability/root-02\tavailable/1\n' \
            "$scenario"
        printf '%s\traw-retry-formation-01\taction-receipt\tretry\tattempt/outcome/root\t%s/%s/%s\n' \
            "$scenario" \
            "$(printf '%s\n' "$retry_action" | cut -f5)" \
            "$(printf '%s\n' "$retry_action" | cut -f7)" \
            "$(printf '%s\n' "$retry_action" | cut -f9)"
        printf '%s\traw-retry-membership-01\tresolution-receipt\tretry-success\tmembership/root-02\tcomplete/%s\n' \
            "$scenario" "$(printf '%s\n' "$retry_resolution" | cut -f9)"
    } | LC_ALL=C sort > "$raw"
else
    setup_inventory="$artifact_dir/inventory-setup-before.tsv"
    rollback_inventory="$artifact_dir/inventory-rollback-after.tsv"
    setup_sha=$(sha256sum "$setup_inventory" | awk '{ print $1 }')
    rollback_sha=$(sha256sum "$rollback_inventory" | awk '{ print $1 }')
    source_count=$(logical_count source-object)
    input_shape=$(
        if [ "$case_id" = "case-bc02-incomplete-missing" ]; then
            printf 'object-c/missing\trequired\n'
        else
            printf 'object-x/same-cardinality-substitution\tobject-c\n'
        fi
    )
    {
        printf '%s\traw-ancestry-persistence-01\tinventory-repository\trollback-after\troot-ancestry/semantic-row-count\t%s\n' \
            "$scenario" "$(logical_count root-ancestry)"
        printf '%s\traw-availability-01\tresolution-receipt\tunavailable\tavailability/root-02\t%s\n' \
            "$scenario" "$availability"
        printf '%s\traw-failure-reason-01\taction-receipt\tinitial-form\t%s/error-id/error-marker\t%s/%s\n' \
            "$scenario" "$(awk -F '	' '{ print $18 }' "$action")" \
            "$(awk -F '	' '{ print $19 }' "$action")" \
            "$(awk -F '	' '{ print $7 }' "$action")"
        printf '%s\traw-formation-01\taction-receipt\tinitial-form\tattempt/outcome/root\t%s\n' \
            "$scenario" "$formation"
        printf '%s\traw-header-persistence-01\tinventory-repository\trollback-after\troot-header/semantic-row-count\t%s\n' \
            "$scenario" "$(logical_count root)"
        printf '%s\traw-input-shape-01\tinventory-repository\tsetup-before\t%s\n' \
            "$scenario" "$input_shape"
        printf '%s\traw-member-persistence-01\tinventory-repository\trollback-after\troot-member/semantic-row-count\t%s\n' \
            "$scenario" "$(logical_count root-member)"
        printf '%s\traw-membership-01\taction-receipt\tform\tinput-membership/request-02\t%s\n' \
            "$scenario" "$membership"
        printf '%s\traw-reopened-resolution-01\tresolution-receipt\treopened\tresolution/root-02\t%s\n' \
            "$scenario" "$reopened"
        printf '%s\traw-rollback-01\tinventory-repository\tsetup-before\tsemantic-inventory-sha256\t%s\n' \
            "$scenario" "$setup_sha"
        printf '%s\traw-rollback-02\tinventory-repository\trollback-after\tsemantic-inventory-sha256\t%s\n' \
            "$scenario" "$rollback_sha"
        printf '%s\traw-source-cardinality-01\tinventory-repository\tsetup-before\tsource-object/count\t%s\n' \
            "$scenario" "$source_count"
    } | LC_ALL=C sort > "$raw"
fi

receipt_set="$tmp/receipt-set.tsv"
if [ "${healthy_retry:-0}" -eq 1 ]; then
    receipt_sources="action-receipts.tsv
command-receipts.tsv
correction-receipts.tsv
correction-write-guard-receipts.tsv
inventory-correction-after.tsv
inventory-retry-after.tsv
inventory-rollback-after.tsv
inventory-setup-before.tsv
resolution-receipts.tsv"
else
    receipt_sources="action-receipts.tsv
$after_inventory
resolution-receipts.tsv"
fi
printf '%s\n' "$receipt_sources" | LC_ALL=C sort |
while IFS= read -r source; do
    file="$artifact_dir/$source"
    printf '%s\t%s\t%s\n' "$source" \
        "$(sha256sum "$file" | awk '{ print $1 }')" \
        "$(wc -c < "$file" | tr -d ' ')"
done > "$receipt_set"

printf '%s\t100644\t%s\t%s\t%s\t%s\t%s\t%s\tsealed-before-normalization\n' \
    raw-observations.tsv \
    "$(sha256sum "$raw" | awk '{ print $1 }')" \
    "$(wc -c < "$raw" | tr -d ' ')" \
    "$run" "$namespace" "$scenario" \
    "$(sha256sum "$receipt_set" | awk '{ print $1 }')" \
    > "$artifact_dir/raw-seal.tsv"

"$normalizer" "$raw" "$scenario" > "$artifact_dir/normalized-observations.tsv"

awk -F '	' 'BEGIN { OFS = "\t" }
    {
        observation = $2
        sub(/^raw-/, "obs-", observation)
        sub(/-[0-9][0-9]$/, "", observation)
        print $1, $2, "record", $1, observation, "all"
    }
' "$raw" > "$artifact_dir/coverage.tsv"

"$oracle" "$artifact_dir" "$scenario" > "$artifact_dir/oracle-result.tsv"

while IFS='	' read -r name fields cardinality kind source; do
    chmod 644 "$artifact_dir/$name"
done < "$registry"

"$verifier" "$artifact_dir" "$run" "$namespace" "$assertion" "$case_id" >/dev/null
