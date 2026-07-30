#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

mutate_drop_first() {
    file=$1
    awk 'NR > 1' "$file" > "$file.tmp"
    mv "$file.tmp" "$file"
}

run_control() {
    id=$1
    marker=$2
    work="$tmp/$id"
    cp -R "$base_dir" "$work"
    old_manifest_sha=$(sha256sum "$work/bc02-contract-digests.tsv" |
        awk '{ print $1 }')

    case "$id" in
        digest-tamper)
            awk -F '	' 'BEGIN { OFS = "\t" }
                NR == 1 { $6 = "tampered" }
                { print }
            ' "$work/bc02-normalized-contract.tsv" \
                > "$work/bc02-normalized-contract.tsv.tmp"
            mv "$work/bc02-normalized-contract.tsv.tmp" \
                "$work/bc02-normalized-contract.tsv"
            ;;
        chronology)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $1 == "BC02_PARTIAL_RESIDUE" &&
                    $2 == "case-bc02-after-root-header" &&
                    $7 == "fault-before" { $7 = "fault-after"; print; next }
                $1 == "BC02_PARTIAL_RESIDUE" &&
                    $2 == "case-bc02-after-root-header" &&
                    $7 == "fault-after" { $7 = "fault-before"; print; next }
                { print }
            ' "$work/bc02-steps.tsv" > "$work/bc02-steps.tsv.tmp"
            mv "$work/bc02-steps.tsv.tmp" "$work/bc02-steps.tsv"
            ;;
        membership-semantic)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $3 == "input-membership" && !done { $6 = "9/3"; done = 1 }
                { print }
            ' "$work/bc02-normalized-contract.tsv" \
                > "$work/bc02-normalized-contract.tsv.tmp"
            mv "$work/bc02-normalized-contract.tsv.tmp" \
                "$work/bc02-normalized-contract.tsv"
            ;;
        reason-semantic)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $2 == "obs-failure-reason" && !done { $5 = "wrong-reason"; done = 1 }
                { print }
            ' "$work/bc02-normalized-contract.tsv" \
                > "$work/bc02-normalized-contract.tsv.tmp"
            mv "$work/bc02-normalized-contract.tsv.tmp" \
                "$work/bc02-normalized-contract.tsv"
            ;;
        oracle-kind)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $1 == "oracle-bc02-complete-available" { $2 = "nonempty" }
                { print }
            ' "$work/oracle-registry.tsv" > "$work/oracle-registry.tsv.tmp"
            mv "$work/oracle-registry.tsv.tmp" "$work/oracle-registry.tsv"
            ;;
        action-cardinality)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $1 == "bc02-complete-available--case-bc02-complete" &&
                    $2 == "action-receipts.tsv" { $4 = 0 }
                { print }
            ' "$work/bc02-artifact-cardinality.tsv" \
                > "$work/bc02-artifact-cardinality.tsv.tmp"
            mv "$work/bc02-artifact-cardinality.tsv.tmp" \
                "$work/bc02-artifact-cardinality.tsv"
            ;;
        applicability-drop)
            awk -F '	' '!($1 == "set-fault" &&
                $2 == "bc02-partial-residue--case-bc02-after-root-header")' \
                "$work/bc02-mutant-applicability.tsv" \
                > "$work/bc02-mutant-applicability.tsv.tmp"
            mv "$work/bc02-mutant-applicability.tsv.tmp" \
                "$work/bc02-mutant-applicability.tsv"
            ;;
        coverage-rewire)
            awk -F '	' 'BEGIN { OFS = "\t" }
                NR == 1 { first = $5; $5 = "obs-ancestry-persistence" }
                NR == 2 { $5 = first }
                { print }
            ' "$work/bc02-coverage-template.tsv" \
                > "$work/bc02-coverage-template.tsv.tmp"
            mv "$work/bc02-coverage-template.tsv.tmp" \
                "$work/bc02-coverage-template.tsv"
            ;;
        actual-mode)
            chmod 755 "$work/bc02-cases.tsv"
            ;;
        symlink-contract)
            cp "$work/bc02-cases.tsv" "$work/cases-target.tsv"
            rm "$work/bc02-cases.tsv"
            ln -s cases-target.tsv "$work/bc02-cases.tsv"
            ;;
        trigger-false-semantic)
            awk -F '	' 'BEGIN { OFS = "\t" }
                NR == 1 { $12 = "false" }
                { print }
            ' "$work/bc02-fault-trigger-template.tsv" \
                > "$work/bc02-fault-trigger-template.tsv.tmp"
            mv "$work/bc02-fault-trigger-template.tsv.tmp" \
                "$work/bc02-fault-trigger-template.tsv"
            ;;
        observer-sequence)
            awk -F '	' 'BEGIN { OFS = "\t" }
                NR == 1 { $10 = "001" }
                { print }
            ' "$work/bc02-observer-custody-template.tsv" \
                > "$work/bc02-observer-custody-template.tsv.tmp"
            mv "$work/bc02-observer-custody-template.tsv.tmp" \
                "$work/bc02-observer-custody-template.tsv"
            ;;
        correction-guard)
            awk -F '	' 'BEGIN { OFS = "\t" }
                { $8 = "object-x"; print }
            ' "$work/bc02-correction-write-guard-template.tsv" \
                > "$work/bc02-correction-write-guard-template.tsv.tmp"
            mv "$work/bc02-correction-write-guard-template.tsv.tmp" \
                "$work/bc02-correction-write-guard-template.tsv"
            ;;
        fault-binding)
            awk -F '	' 'BEGIN { OFS = "\t" }
                NR == 1 { $8 = "{wrong-configuration-sha256}" }
                { print }
            ' "$work/bc02-fault-binding-template.tsv" \
                > "$work/bc02-fault-binding-template.tsv.tmp"
            mv "$work/bc02-fault-binding-template.tsv.tmp" \
                "$work/bc02-fault-binding-template.tsv"
            ;;
        fault-marker)
            awk -F '	' 'BEGIN { OFS = "\t" }
                NR == 1 { $9 = "false" }
                { print }
            ' "$work/bc02-fault-marker-template.tsv" \
                > "$work/bc02-fault-marker-template.tsv.tmp"
            mv "$work/bc02-fault-marker-template.tsv.tmp" \
                "$work/bc02-fault-marker-template.tsv"
            ;;
        correction-receipt)
            awk -F '	' 'BEGIN { OFS = "\t" }
                { $8 = "object-x"; print }
            ' "$work/bc02-correction-receipt-template.tsv" \
                > "$work/bc02-correction-receipt-template.tsv.tmp"
            mv "$work/bc02-correction-receipt-template.tsv.tmp" \
                "$work/bc02-correction-receipt-template.tsv"
            ;;
        data-version-sequence)
            awk -F '	' 'BEGIN { OFS = "\t" }
                NR == 1 { $9 = "002" }
                { print }
            ' "$work/bc02-data-version-receipt-template.tsv" \
                > "$work/bc02-data-version-receipt-template.tsv.tmp"
            mv "$work/bc02-data-version-receipt-template.tsv.tmp" \
                "$work/bc02-data-version-receipt-template.tsv"
            ;;
        error-identity)
            awk -F '	' 'BEGIN { OFS = "\t" }
                NR == 1 { $2 = "WRONG_MARKER" }
                { print }
            ' "$work/bc02-error-identities.tsv" \
                > "$work/bc02-error-identities.tsv.tmp"
            mv "$work/bc02-error-identities.tsv.tmp" \
                "$work/bc02-error-identities.tsv"
            ;;
        resolution-membership)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $8 == "root-unavailable" && !done { $9 = "2/3"; done = 1 }
                { print }
            ' "$work/bc02-resolution-receipt-template.tsv" \
                > "$work/bc02-resolution-receipt-template.tsv.tmp"
            mv "$work/bc02-resolution-receipt-template.tsv.tmp" \
                "$work/bc02-resolution-receipt-template.tsv"
            ;;
        normalization-rule)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $1 == "rule-inventory-equality" { $4 = "count-equality" }
                { print }
            ' "$work/bc02-normalization-rules.tsv" \
                > "$work/bc02-normalization-rules.tsv.tmp"
            mv "$work/bc02-normalization-rules.tsv.tmp" \
                "$work/bc02-normalization-rules.tsv"
            ;;
        operation-registry)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $1 == "sut-form-root" { $3 = "wrong-operation" }
                { print }
            ' "$work/operation-registry.tsv" \
                > "$work/operation-registry.tsv.tmp"
            mv "$work/operation-registry.tsv.tmp" "$work/operation-registry.tsv"
            ;;
        fault-registry-phase)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $1 == "hook-bc02-after-root-header" { $3 = "wrong-phase" }
                { print }
            ' "$work/fault-hooks.tsv" > "$work/fault-hooks.tsv.tmp"
            mv "$work/fault-hooks.tsv.tmp" "$work/fault-hooks.tsv"
            ;;
        fault-set-registry)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $1 == "set-bc02-root-boundaries" &&
                    $2 == "hook-bc02-after-root-member" { $3 = "any" }
                { print }
            ' "$work/fault-hook-sets.tsv" \
                > "$work/fault-hook-sets.tsv.tmp"
            mv "$work/fault-hook-sets.tsv.tmp" \
                "$work/fault-hook-sets.tsv"
            ;;
        aggregation-drop)
            mutate_drop_first "$work/bc02-assertion-aggregation.tsv"
            ;;
        gate-map)
            awk -F '	' 'BEGIN { OFS = "\t" }
                NR == 1 { $2 = "gate-set-poisoned" }
                { print }
            ' "$work/bc02-scenario-gates.tsv" \
                > "$work/bc02-scenario-gates.tsv.tmp"
            mv "$work/bc02-scenario-gates.tsv.tmp" \
                "$work/bc02-scenario-gates.tsv"
            ;;
        case-semantics)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $2 == "case-bc02-incomplete-missing" && !done {
                    $4 = "complete"; done = 1
                }
                { print }
            ' "$work/bc02-cases.tsv" > "$work/bc02-cases.tsv.tmp"
            mv "$work/bc02-cases.tsv.tmp" "$work/bc02-cases.tsv"
            ;;
        inventory-map-semantics)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $1 == "BC02_INCOMPLETE_AS_COMPLETE" &&
                    $2 == "case-bc02-incomplete-missing" &&
                    $3 == "setup-before" {
                    $5 = "bc02-inventory-complete-before.tsv"
                }
                { print }
            ' "$work/bc02-inventory-map.tsv" \
                > "$work/bc02-inventory-map.tsv.tmp"
            mv "$work/bc02-inventory-map.tsv.tmp" \
                "$work/bc02-inventory-map.tsv"
            ;;
        inventory-fixture-semantics)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $2 == "root-required-member" &&
                    $3 == "request-02/0003" { $5 = "object-x" }
                { print }
            ' "$work/bc02-inventory-complete-before.tsv" \
                > "$work/bc02-inventory-complete-before.tsv.tmp"
            mv "$work/bc02-inventory-complete-before.tsv.tmp" \
                "$work/bc02-inventory-complete-before.tsv"
            ;;
        normalized-semantic-seal)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $1 == "bc02-complete-available--case-bc02-complete" &&
                    $2 == "obs-availability" {
                    $5 = "unavailable"; $6 = "0"
                }
                { print }
            ' "$work/bc02-normalized-contract.tsv" \
                > "$work/bc02-normalized-contract.tsv.tmp"
            mv "$work/bc02-normalized-contract.tsv.tmp" \
                "$work/bc02-normalized-contract.tsv"
            ;;
        aggregation-swap)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $2 == "bc02-partial-residue--case-bc02-after-root-header" {
                    $1 = "BC02_ROLLBACK_COMPLETE"
                }
                $2 == "bc02-rollback-complete--case-bc02-after-root-header" {
                    $1 = "BC02_PARTIAL_RESIDUE"
                }
                { print }
            ' "$work/bc02-assertion-aggregation.tsv" \
                > "$work/bc02-assertion-aggregation.tsv.tmp"
            mv "$work/bc02-assertion-aggregation.tsv.tmp" \
                "$work/bc02-assertion-aggregation.tsv"
            awk -F '	' 'BEGIN { OFS = "\t" }
                $1 == "bc02-partial-residue--case-bc02-after-root-header" {
                    $2 = "oracle-bc02-rollback-complete"
                    $3 = "equality"
                    $4 = "inventory-repository"
                }
                $1 == "bc02-rollback-complete--case-bc02-after-root-header" {
                    $2 = "oracle-bc02-partial-residue"
                    $3 = "exact"
                    $4 = "norm-bc02-observation"
                }
                { print }
            ' "$work/bc02-oracle-result-template.tsv" \
                > "$work/bc02-oracle-result-template.tsv.tmp"
            mv "$work/bc02-oracle-result-template.tsv.tmp" \
                "$work/bc02-oracle-result-template.tsv"
            ;;
        gate-bogus-scenario)
            awk -F '	' 'BEGIN { OFS = "\t" }
                NR == 1 {
                    $1 = "bc02-partial-residue--case-bc02-bogus"
                }
                { print }
            ' "$work/bc02-scenario-gates.tsv" \
                > "$work/bc02-scenario-gates.tsv.tmp"
            mv "$work/bc02-scenario-gates.tsv.tmp" \
                "$work/bc02-scenario-gates.tsv"
            ;;
        gate-disposition)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $1 == "gate-set-partial" &&
                    $3 == "target-residue-zero" { $4 = "INVALID" }
                { print }
            ' "$work/bc02-mandatory-gate-sets.tsv" \
                > "$work/bc02-mandatory-gate-sets.tsv.tmp"
            mv "$work/bc02-mandatory-gate-sets.tsv.tmp" \
                "$work/bc02-mandatory-gate-sets.tsv"
            ;;
        gate-result-drop)
            mutate_drop_first "$work/bc02-gate-results-template.tsv"
            ;;
        normalized-field)
            awk -F '	' 'BEGIN { OFS = "\t" }
                NR == 1 { print $0, "extra"; next }
                { print }
            ' "$work/bc02-normalized-contract.tsv" \
                > "$work/bc02-normalized-contract.tsv.tmp"
            mv "$work/bc02-normalized-contract.tsv.tmp" \
                "$work/bc02-normalized-contract.tsv"
            ;;
        raw-drop)
            mutate_drop_first "$work/bc02-raw-template.tsv"
            ;;
        raw-shape)
            awk -F '	' 'BEGIN { OFS = "\t" }
                NR == 1 { $2 = "invalid-raw-id" }
                { print }
            ' "$work/bc02-raw-template.tsv" > "$work/bc02-raw-template.tsv.tmp"
            mv "$work/bc02-raw-template.tsv.tmp" "$work/bc02-raw-template.tsv"
            ;;
        coverage-drop)
            mutate_drop_first "$work/bc02-coverage-template.tsv"
            ;;
        coverage-endpoint)
            awk -F '	' 'BEGIN { OFS = "\t" }
                NR == 1 { $5 = "obs-unknown" }
                { print }
            ' "$work/bc02-coverage-template.tsv" \
                > "$work/bc02-coverage-template.tsv.tmp"
            mv "$work/bc02-coverage-template.tsv.tmp" \
                "$work/bc02-coverage-template.tsv"
            ;;
        inventory-map-drop)
            mutate_drop_first "$work/bc02-inventory-map.tsv"
            ;;
        stage-enum)
            awk -F '	' 'BEGIN { OFS = "\t" }
                NR == 1 { $1 = "unknown-stage" }
                { print }
            ' "$work/bc02-stage-enums.tsv" > "$work/bc02-stage-enums.tsv.tmp"
            mv "$work/bc02-stage-enums.tsv.tmp" "$work/bc02-stage-enums.tsv"
            ;;
        applicability)
            awk -F '	' 'BEGIN { OFS = "\t" }
                NR == 1 { $2 = "bc02-unknown--case-bc02-unknown" }
                { print }
            ' "$work/bc02-mutant-applicability.tsv" \
                > "$work/bc02-mutant-applicability.tsv.tmp"
            mv "$work/bc02-mutant-applicability.tsv.tmp" \
                "$work/bc02-mutant-applicability.tsv"
            ;;
        schema-field-count)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $1 == "bc02-root-action-receipt-template.tsv" { $2 = 18 }
                { print }
            ' "$work/bc02-tsv-schemas.tsv" > "$work/bc02-tsv-schemas.tsv.tmp"
            mv "$work/bc02-tsv-schemas.tsv.tmp" "$work/bc02-tsv-schemas.tsv"
            ;;
        schema-target-missing)
            rm "$work/bc02-correction-write-guard-template.tsv"
            ;;
        *)
            echo "unknown BC02 contract control: $id" >&2
            exit 1
            ;;
    esac

    if [ "$id" != "digest-tamper" ]; then
        manifest_tmp="$work/bc02-contract-digests.tsv.tmp"
        for file in "$work"/bc02-*.tsv "$work"/step-registry-levels.tsv; do
            [ "$(basename "$file")" = "bc02-contract-digests.tsv" ] && continue
            printf '%s\t100644\t%s\n' \
                "$(basename "$file")" \
                "$(sha256sum "$file" | awk '{ print $1 }')"
        done | LC_ALL=C sort > "$manifest_tmp"
        mv "$manifest_tmp" "$work/bc02-contract-digests.tsv"
        new_manifest_sha=$(sha256sum "$work/bc02-contract-digests.tsv" |
            awk '{ print $1 }')
        sed "s/$old_manifest_sha/$new_manifest_sha/g" \
            "$work/runner/verify-bc02-contract.sh" \
            > "$work/runner/verify-bc02-contract.sh.tmp"
        mv "$work/runner/verify-bc02-contract.sh.tmp" \
            "$work/runner/verify-bc02-contract.sh"
        chmod +x "$work/runner/verify-bc02-contract.sh"
    fi

    set +e
    output=$("$work/runner/verify-bc02-contract.sh" 2>&1)
    status=$?
    set -e
    [ "$status" -ne 0 ] || {
        echo "FAIL: $id was accepted" >&2
        exit 1
    }
    printf '%s\n' "$output" | grep -F "$marker" >/dev/null || {
        printf '%s\n' "$output" >&2
        echo "FAIL: $id missed $marker" >&2
        exit 1
    }
    echo "ok $marker"
}

pids=
launch() {
    run_control "$@" &
    pids="$pids $!"
}

launch digest-tamper BC02_CONTRACT_FILE_DIGEST_INVALID
launch chronology BC02_STEP_SEMANTICS_INVALID
launch membership-semantic BC02_NORMALIZED_SEMANTICS_INVALID
launch reason-semantic BC02_NORMALIZED_SEMANTICS_INVALID
launch oracle-kind BC02_ORACLE_CONTRACT_INVALID
launch action-cardinality BC02_ARTIFACT_CARDINALITY_SEMANTICS_INVALID
launch applicability-drop BC02_MUTANT_APPLICABILITY_INVALID
launch coverage-rewire BC02_COVERAGE_INVALID
launch actual-mode BC02_CONTRACT_FILE_MODE_INVALID
launch symlink-contract BC02_REQUIRED_CONTRACT_MISSING
launch trigger-false-semantic BC02_FAULT_TRIGGER_SEMANTICS_INVALID
launch observer-sequence BC02_OBSERVER_CUSTODY_SEMANTICS_INVALID
launch correction-guard BC02_CORRECTION_GUARD_SEMANTICS_INVALID
launch fault-binding BC02_FAULT_BINDING_SEMANTICS_INVALID
launch fault-marker BC02_FAULT_MARKER_SEMANTICS_INVALID
launch correction-receipt BC02_CORRECTION_RECEIPT_SEMANTICS_INVALID
launch data-version-sequence BC02_DATA_VERSION_SEMANTICS_INVALID
launch error-identity BC02_ERROR_IDENTITY_INVALID
launch resolution-membership BC02_RESOLUTION_SEMANTICS_INVALID
launch normalization-rule BC02_NORMALIZATION_RULE_INVALID
launch operation-registry BC02_OPERATION_REGISTRY_INVALID
launch fault-registry-phase BC02_FAULT_REGISTRY_INVALID
launch fault-set-registry BC02_FAULT_SET_REGISTRY_INVALID
launch aggregation-drop BC02_ASSERTION_AGGREGATION_INVALID
launch gate-map BC02_SCENARIO_GATE_MAP_INVALID
launch case-semantics BC02_CASE_CONTRACT_INVALID
launch inventory-map-semantics BC02_INVENTORY_MAP_SEMANTICS_INVALID
launch inventory-fixture-semantics BC02_INVENTORY_FIXTURE_SEMANTICS_INVALID
launch normalized-semantic-seal BC02_NORMALIZED_SEMANTIC_SEAL_INVALID
launch aggregation-swap BC02_ASSERTION_AGGREGATION_INVALID
launch gate-bogus-scenario BC02_SCENARIO_GATE_MAP_INVALID
launch gate-disposition BC02_MANDATORY_GATE_SET_INVALID
launch gate-result-drop BC02_GATE_RESULT_CONTRACT_INVALID
launch normalized-field BC02_NORMALIZED_CONTRACT_INVALID
launch raw-drop BC02_ARTIFACT_CARDINALITY_INVALID
launch raw-shape BC02_RAW_CONTRACT_INVALID
launch coverage-drop BC02_ARTIFACT_CARDINALITY_INVALID
launch coverage-endpoint BC02_COVERAGE_INVALID
launch inventory-map-drop BC02_INVENTORY_MAP_COVERAGE_INVALID
launch stage-enum BC02_STAGE_ENUM_INVALID
launch applicability BC02_MUTANT_APPLICABILITY_INVALID
launch schema-field-count BC02_SCHEMA_FIELD_COUNT_INVALID
launch schema-target-missing BC02_REQUIRED_CONTRACT_MISSING

failed=0
for pid in $pids; do
    wait "$pid" || failed=1
done
[ "$failed" = 0 ] || exit 1

echo "43 BC02 contract mutations detected"
