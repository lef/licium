#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
model_dir=$(CDPATH= cd -- "$base_dir/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

fail()
{
    echo "$1" >&2
    exit 1
}

require_file()
{
    file=$1
    [ -f "$file" ] && [ ! -L "$file" ] ||
        fail BC09_REQUIREMENT_MISSING
    [ "$(stat -c '%a' "$file")" = 644 ] ||
        fail BC09_REQUIREMENT_MODE_INVALID
}

require_fields()
{
    file=$1
    fields=$2
    rows=$3
    marker=$4
    awk -F '	' -v fields="$fields" -v rows="$rows" '
        NF != fields { exit 1 }
        {
            for (field = 1; field <= NF; field++)
                if ($field == "") exit 1
        }
        END { if (NR != rows) exit 1 }
    ' "$file" || fail "$marker"
}

document="$model_dir/BC09-SQLITE-SLICE.md"
action_receipt="$base_dir/bc09-action-receipt-template.tsv"
cases="$base_dir/bc09-cases.tsv"
command_receipt="$base_dir/bc09-command-receipt-template.tsv"
coverage="$base_dir/bc09-coverage-template.tsv"
fault_activation="$base_dir/bc09-fault-activation-template.tsv"
fault_cases="$base_dir/bc09-fault-cases.tsv"
fault_configuration="$base_dir/bc09-fault-configuration-template.tsv"
fault_healthy="$base_dir/bc09-fault-inventory-healthy.tsv"
fault_marker="$base_dir/bc09-fault-marker-template.tsv"
fault_reopened="$base_dir/bc09-fault-inventory-reopened.tsv"
fault_rollback="$base_dir/bc09-fault-inventory-rollback.tsv"
fault_setup="$base_dir/bc09-fault-inventory-setup.tsv"
fault_steps="$base_dir/bc09-fault-steps.tsv"
fault_trigger="$base_dir/bc09-fault-trigger-template.tsv"
inventory_after="$base_dir/bc09-inventory-after.tsv"
inventory_before="$base_dir/bc09-inventory-before.tsv"
inventory_reopened="$base_dir/bc09-inventory-reopened.tsv"
mutants="$base_dir/bc09-mutants.tsv"
normalized="$base_dir/bc09-normalized-template.tsv"
raw="$base_dir/bc09-raw-template.tsv"
raw_seal="$base_dir/bc09-raw-seal-template.tsv"
runtime_artifacts="$base_dir/bc09-runtime-artifacts.tsv"
scenario_ids="$base_dir/bc09-scenario-ids.tsv"
steps="$base_dir/bc09-steps.tsv"

for file in "$document" "$action_receipt" "$cases" "$command_receipt" \
    "$coverage" "$fault_activation" "$fault_cases" "$fault_configuration" \
    "$fault_healthy" "$fault_marker" "$fault_reopened" "$fault_rollback" \
    "$fault_setup" "$fault_steps" "$fault_trigger" "$inventory_after" \
    "$inventory_before" "$inventory_reopened" "$mutants" "$normalized" \
    "$raw" "$raw_seal" "$runtime_artifacts" "$scenario_ids" "$steps"
do
    require_file "$file"
done

require_fields "$action_receipt" 14 1 BC09_ACTION_RECEIPT_CONTRACT_INVALID
require_fields "$cases" 11 19 BC09_CASE_REGISTRY_INVALID
require_fields "$command_receipt" 12 1 BC09_COMMAND_RECEIPT_CONTRACT_INVALID
require_fields "$coverage" 6 10 BC09_COVERAGE_CONTRACT_INVALID
require_fields "$fault_activation" 10 5 BC09_FAULT_ACTIVATION_CONTRACT_INVALID
require_fields "$fault_cases" 5 5 BC09_FAULT_CASE_REGISTRY_INVALID
require_fields "$fault_configuration" 14 5 BC09_FAULT_CONFIGURATION_CONTRACT_INVALID
require_fields "$fault_healthy" 6 45 BC09_FAULT_INVENTORY_CONTRACT_INVALID
require_fields "$fault_marker" 11 5 BC09_FAULT_MARKER_CONTRACT_INVALID
require_fields "$fault_reopened" 6 45 BC09_FAULT_INVENTORY_CONTRACT_INVALID
require_fields "$fault_rollback" 6 25 BC09_FAULT_INVENTORY_CONTRACT_INVALID
require_fields "$fault_setup" 6 25 BC09_FAULT_INVENTORY_CONTRACT_INVALID
require_fields "$fault_steps" 6 12 BC09_FAULT_STEP_REGISTRY_INVALID
require_fields "$fault_trigger" 21 5 BC09_FAULT_TRIGGER_CONTRACT_INVALID
require_fields "$inventory_after" 6 25 BC09_INVENTORY_CONTRACT_INVALID
require_fields "$inventory_before" 6 25 BC09_INVENTORY_CONTRACT_INVALID
require_fields "$inventory_reopened" 6 25 BC09_INVENTORY_CONTRACT_INVALID
require_fields "$mutants" 4 18 BC09_MUTANT_REGISTRY_INVALID
require_fields "$normalized" 6 10 BC09_NORMALIZED_CONTRACT_INVALID
require_fields "$raw" 6 10 BC09_RAW_CONTRACT_INVALID
require_fields "$raw_seal" 9 1 BC09_RAW_SEAL_CONTRACT_INVALID
require_fields "$runtime_artifacts" 5 20 BC09_RUNTIME_ARTIFACT_REGISTRY_INVALID
require_fields "$scenario_ids" 3 7 BC09_SCENARIO_ID_REGISTRY_INVALID
require_fields "$steps" 5 11 BC09_STEP_REGISTRY_INVALID

# The local case registry must be an exact, ordered enrichment of the shared
# scenario and scenario-case registries.  The enrichment fixes the SQLite
# profile's observable failure discriminator without making it a core schema.
awk -F '	' '
    FILENAME == ARGV[1] && $1 == "BC09" {
        class[$3] = $4
        scenario_count++
        next
    }
    FILENAME == ARGV[2] && $1 ~ /^BC09_/ {
        shared[$1 FS $2] = $3 FS $4
        shared_count++
        next
    }
    FILENAME == ARGV[3] {
        key = $1 FS $3
        if (!($1 in class) || class[$1] != $2 ||
            !(key in shared) || shared[key] != ($4 FS $5) ||
            $6 != "sut-apply-effect" || $11 != "PASS" ||
            seen[key]++) exit 1

        disposition = $3 == "case-duplicate" ? "duplicate" :
            $3 == "case-fault" ? "failed" : "rejected"
        reason = $3 == "case-duplicate" ? "unaccepted-redelivery" :
            $3 == "case-fault" ? "injected-rollback" :
            $3 == "case-incomplete" ? "incomplete-result" :
            $3 == "case-rejected" ? "result-rejected" : "stale-expected"
        delivery = $3 == "case-duplicate" ? 2 : 1
        if ($1 == "BC09_FAILPOINT_PERSISTS") {
            disposition = "failed"
            reason = $3 == "case-fault" ? "injected-accepted-write" :
                "injected-rejection-" substr($3, 6)
        }
        negative = "neg-" tolower_hyphen($1)
        if ($7 != disposition || $8 != reason ||
            $9 != delivery || $10 != negative) exit 1
        count++
    }
    function tolower_hyphen(value) {
        value = tolower(value)
        gsub(/_/, "-", value)
        return value
    }
    END {
        if (scenario_count != 7 || shared_count != 19 || count != 19)
            exit 1
        for (key in shared) if (!(key in seen)) exit 1
    }
' "$base_dir/scenarios.tsv" "$base_dir/scenario-cases.tsv" "$cases" ||
    fail BC09_CASE_REGISTRY_INVALID

# Bind every assertion to the shared execution and negative-identity maps.
awk -F '	' '
    FILENAME == ARGV[1] && $2 == "BC09" {
        execution[$1] = $4 FS $6 FS $7 FS $10 FS $11 FS $12 FS $13 FS \
            $14 FS $17 FS $18
        next
    }
    FILENAME == ARGV[2] && $1 ~ /^neg-bc09-/ {
        negative[$1] = $2 FS $3 FS $4
        next
    }
    FILENAME == ARGV[3] {
        negative_type = $1 == "BC09_FAILPOINT_PERSISTS" ? "fault" :
            ($1 == "BC09_DIAGNOSTIC_EPHEMERAL" ||
             $1 == "BC09_FAILURE_NO_PERSISTENT_ARTIFACT") ?
            "sut-mutant" : "counterfactual"
        expected_set = $1 == "BC09_FAILPOINT_PERSISTS" ?
            "set-bc09-failure-boundaries" : "-"
        expected_requirement = $1 == "BC09_FAILPOINT_PERSISTS" ? "all" : "-"
        expected = $2 FS "sut-setup-bc09" FS "sut-apply-effect" FS \
            "oracle-" tolower_hyphen($1) FS "coverage-bc09" FS \
            expected_set FS expected_requirement FS "PASS" FS \
            negative_type FS $10
        if (!($1 in execution) || execution[$1] != expected ||
            !($10 in negative) ||
            negative[$10] != ($1 FS negative_type FS mutant_name($1)))
            exit 1
        seen_assertion[$1] = 1
        seen_negative[$10] = 1
    }
    function tolower_hyphen(value) {
        value = tolower(value)
        gsub(/_/, "-", value)
        return value
    }
    function mutant_name(value) {
        return value == "BC09_DIAGNOSTIC_EPHEMERAL" ?
            "detect-persisted-diagnostic" :
            value == "BC09_DUPLICATE_PERSISTS" ?
            "detect-duplicate-attempt-artifact" :
            value == "BC09_FAILPOINT_PERSISTS" ?
            "detect-failpoint-artifact" :
            value == "BC09_FAILURE_NO_PERSISTENT_ARTIFACT" ?
            "detect-failure-artifact" :
            value == "BC09_INCOMPLETE_PERSISTS" ?
            "detect-incomplete-attempt-artifact" :
            value == "BC09_REJECTED_PERSISTS" ?
            "detect-rejected-attempt-artifact" :
            "detect-stale-attempt-artifact"
    }
    END {
        if (length(seen_assertion) != 7 || length(seen_negative) != 7)
            exit 1
    }
' "$base_dir/execution-map.tsv" "$base_dir/negative-identities.tsv" "$cases" ||
    fail BC09_CASE_REGISTRY_INVALID

awk -F '	' '
    FILENAME == ARGV[1] && $1 == "BC09" {
        valid[$3] = 1
        next
    }
    FILENAME == ARGV[2] {
        expected = tolower_hyphen($1) "--" $2
        if (!($1 in valid) || $3 != expected ||
            $2 !~ /^case-bc09-/ || seen[$1]++ || seen_id[$3]++) exit 1
        count++
    }
    function tolower_hyphen(value) {
        value = tolower(value)
        gsub(/_/, "-", value)
        return value
    }
    END { if (count != 7) exit 1 }
' "$base_dir/scenarios.tsv" "$scenario_ids" ||
    fail BC09_SCENARIO_ID_REGISTRY_INVALID

cat >"$tmp/expected-steps" <<'EOF'
010	create	profile-create-namespace	normal	command-receipt
020	setup	sut-setup-bc09	ordinary	action-receipt
030	inventory-before	profile-inventory-bc09	ordinary	inventory-before
040	action	sut-apply-effect	case-set	action-receipt
050	observe-after	profile-observe-bc09	ordinary	raw-observation
060	inventory-after	profile-inventory-bc09	ordinary	inventory-after
070	reopen	profile-reopen-namespace	normal	command-receipt
080	inventory-reopened	profile-inventory-bc09	ordinary	inventory-reopened
090	destroy	profile-destroy-namespace	normal	command-receipt
100	normalize	runner-normalize-bc09	ordinary	normalized-observation
110	oracle	runner-oracle-bc09	ordinary	oracle-result
EOF
cmp -s "$tmp/expected-steps" "$steps" ||
    fail BC09_STEP_REGISTRY_INVALID

cat >"$tmp/expected-fault-steps" <<'EOF'
010	create	profile-create-namespace	normal	command-receipt	same
020	setup	sut-setup-bc09	fault	action-receipt	same
030	inventory-setup	profile-inventory-bc09	fault	fault-inventory-setup	same
040	activate-fault	profile-activate-fault-bc09	case-hook	fault-activation-receipt	same
050	fault-action	sut-apply-effect	fault	fault-trigger-receipt	same
060	inventory-rollback	profile-inventory-bc09	fault	fault-inventory-rollback	same
070	clear-fault	profile-clear-fault-bc09	case-hook	command-receipt	same
080	healthy-action	sut-apply-effect	ordinary	action-receipt	same
090	inventory-healthy	profile-inventory-bc09	ordinary	fault-inventory-healthy	same
100	reopen	profile-reopen-namespace	normal	command-receipt	same
110	inventory-reopened	profile-inventory-bc09	ordinary	inventory-reopened	same
120	destroy	profile-destroy-namespace	normal	command-receipt	same
EOF
cmp -s "$tmp/expected-fault-steps" "$fault_steps" ||
    fail BC09_FAULT_STEP_REGISTRY_INVALID

awk -F '	' '
    FILENAME == ARGV[1] && $2 == "BC09" {
        hook[$1] = $3 FS $4
        next
    }
    FILENAME == ARGV[2] && $1 == "set-bc09-failure-boundaries" {
        member[$2] = $3
        next
    }
    FILENAME == ARGV[3] {
        expected_case = FNR == 1 ? "case-fault" :
            FNR == 2 ? "case-stale" :
            FNR == 3 ? "case-incomplete" :
            FNR == 4 ? "case-rejected" : "case-duplicate"
        if ($1 != expected_case || !($2 in hook) || !($2 in member) ||
            hook[$2] != ($3 FS "sut-apply-effect") ||
            member[$2] != "all" ||
            $4 != "error-bc09-" $3 || $5 != sprintf("%03d", FNR * 10) ||
            seen[$2]++) exit 1
        count++
    }
    END {
        if (count != 5 || length(hook) != 5 || length(member) != 5)
            exit 1
    }
' "$base_dir/fault-hooks.tsv" "$base_dir/fault-hook-sets.tsv" "$fault_cases" ||
    fail BC09_FAULT_CASE_REGISTRY_INVALID

[ "$(cat "$action_receipt")" = \
    '{run}	{namespace}	{assertion}	{case}	sut-apply-effect	{delivery}	{effect}	{result}	{disposition}	{reason}	{repository-delta}	{nonce}	{implementation-revision}	{attempt}' ] ||
    fail BC09_ACTION_RECEIPT_CONTRACT_INVALID
[ "$(cat "$command_receipt")" = \
    '{run}	{namespace}	{assertion}	{phase}	{operation}	{mode}	{status}	{stdout-sha256}	{stdout-bytes}	{stderr-sha256}	{stderr-bytes}	{argv-sha256}' ] ||
    fail BC09_COMMAND_RECEIPT_CONTRACT_INVALID
[ "$(cat "$raw_seal")" = \
    'raw-observations.tsv	100644	{sha256}	{bytes}	{run}	{namespace}	{scenario}	{action-receipt-sha256}	sealed-before-normalization' ] ||
    fail BC09_RAW_SEAL_CONTRACT_INVALID

awk -F '	' '
    BEGIN {
        relation[1] = "diagnostic"; attribute[1] = "disposition"
        relation[2] = "diagnostic"; attribute[2] = "reason"
        relation[3] = "repository"; attribute[3] = "inventory-equal"
        relation[4] = "state-transition"; attribute[4] = "delta"
        relation[5] = "decision-observation"; attribute[5] = "delta"
        relation[6] = "view"; attribute[6] = "delta"
        relation[7] = "current"; attribute[7] = "delta"
        relation[8] = "persistent-attempt"; attribute[8] = "delta"
        relation[9] = "delivery"; attribute[9] = "count"
        relation[10] = "fault-hook"; attribute[10] = "triggered-count"
    }
    $1 != "{scenario}" || $2 != sprintf("raw-{case}-%03d", NR) ||
        $3 != relation[NR] || $4 != attribute[NR] || $5 != "result" ||
        $6 != (NR == 1 ? "{diagnostic-disposition}" :
            NR == 2 ? "{diagnostic-reason}" :
            "{" relation[NR] "-" attribute[NR] "}") { exit 1 }
' "$raw" || fail BC09_RAW_CONTRACT_INVALID

awk -F '	' '
    BEGIN {
        relation[1] = "diagnostic"; attribute[1] = "disposition"
        relation[2] = "diagnostic"; attribute[2] = "reason"
        relation[3] = "repository"; attribute[3] = "inventory-equal"
        relation[4] = "state-transition"; attribute[4] = "delta"
        relation[5] = "decision-observation"; attribute[5] = "delta"
        relation[6] = "view"; attribute[6] = "delta"
        relation[7] = "current"; attribute[7] = "delta"
        relation[8] = "persistent-attempt"; attribute[8] = "delta"
        relation[9] = "delivery"; attribute[9] = "count"
        relation[10] = "fault-hook"; attribute[10] = "triggered-count"
    }
    $1 != "{scenario}" || $2 != sprintf("obs-{case}-%03d", NR) ||
        $3 != relation[NR] || $4 != attribute[NR] || $5 != "result" ||
        $6 != (NR == 1 ? "{diagnostic-disposition}" :
            NR == 2 ? "{diagnostic-reason}" :
            "{" relation[NR] "-" attribute[NR] "}") { exit 1 }
' "$normalized" || fail BC09_NORMALIZED_CONTRACT_INVALID

awk -F '	' '
    $1 != "{scenario}" || $2 != sprintf("raw-{case}-%03d", NR) ||
        $3 != "record" || $4 != "{scenario}" ||
        $5 != sprintf("obs-{case}-%03d", NR) || $6 != "all" { exit 1 }
' "$coverage" || fail BC09_COVERAGE_CONTRACT_INVALID

for inventory in "$inventory_before" "$inventory_after" "$inventory_reopened" \
    "$fault_setup" "$fault_rollback" "$fault_healthy" "$fault_reopened"
do
    sort -c "$inventory" 2>/dev/null ||
        fail BC09_INVENTORY_CONTRACT_INVALID
done
cmp -s "$inventory_before" "$inventory_after" &&
    cmp -s "$inventory_before" "$inventory_reopened" ||
    fail BC09_INVENTORY_CONTRACT_INVALID
cmp -s "$inventory_before" "$fault_setup" &&
    cmp -s "$fault_setup" "$fault_rollback" ||
    fail BC09_FAULT_INVENTORY_CONTRACT_INVALID
cmp -s "$fault_healthy" "$fault_reopened" ||
    fail BC09_FAULT_INVENTORY_CONTRACT_INVALID

awk -F '	' '
    {
        if ($6 != "0001") exit 1
        seen[$1 FS $2 FS $3 FS $4]++
        count[$1]++
        if ($2 == "authoritative-state" && $3 == "scope-1" &&
            $4 == "revision" && $5 == "rev-1") state[$1] = 1
        if ($2 == "effect-request" && $3 == "effect-1" &&
            $4 == "binding") binding[$1] = $5
        if ($2 == "evaluation-result" && $3 == "result-1" &&
            $4 == "completeness") complete[$1] = $5
        if ($2 == "evaluation-result" && $3 == "result-1" &&
            $4 == "disposition") disposition[$1] = $5
        if ($2 == "evaluation-result" && $3 == "result-1" &&
            $4 == "payload" && $5 == "public-a") payload[$1] = 1
    }
    END {
        split("case-duplicate case-fault case-incomplete case-rejected case-stale",
            c, " ")
        for (i in c) {
            item = c[i]
            expected_binding = item == "case-stale" ?
                "result-1,scope-1,rev-0" : "result-1,scope-1,rev-1"
            expected_complete = item == "case-incomplete" ?
                "incomplete" : "complete"
            expected_disposition = item == "case-duplicate" ||
                item == "case-rejected" ?
                "rejected" : "accepted"
            if (count[item] != 5 || !state[item] || !payload[item] ||
                binding[item] != expected_binding ||
                complete[item] != expected_complete ||
                disposition[item] != expected_disposition) exit 1
        }
    }
' "$inventory_before" || fail BC09_INVENTORY_CONTRACT_INVALID

awk -F '	' '
    {
        if ($6 != "0001") exit 1
        count[$1]++
        if ($2 == "authoritative-state" && $5 == "rev-2") state[$1] = 1
        if ($2 == "current-view" && $5 == "view-1,rev-2") current[$1] = 1
        if ($2 == "decision-observation") observation[$1] = 1
        if ($2 == "effect-request" &&
            $5 == "result-1,scope-1,rev-1") effect[$1] = 1
        if ($2 == "evaluation-result" && $4 == "completeness" &&
            $5 == "complete") complete[$1] = 1
        if ($2 == "evaluation-result" && $4 == "disposition" &&
            $5 == "accepted") accepted[$1] = 1
        if ($2 == "evaluation-result" && $4 == "payload" &&
            $5 == "public-a") payload[$1] = 1
        if ($2 == "state-transition") transition[$1] = 1
        if ($2 == "view-header") view[$1] = 1
    }
    END {
        split("case-duplicate case-fault case-incomplete case-rejected case-stale",
            c, " ")
        for (i in c) {
            item = c[i]
            if (count[item] != 9 || !state[item] || !current[item] ||
                !observation[item] || !effect[item] || !complete[item] ||
                !accepted[item] || !payload[item] || !transition[item] ||
                !view[item]) exit 1
        }
    }
' "$fault_healthy" || fail BC09_FAULT_INVENTORY_CONTRACT_INVALID

awk -F '	' '
    NR == FNR { cases[$1] = $2 FS $3; next }
    {
        if (!($4 in cases) || $1 == "" || $2 == "" ||
            $3 != "BC09_FAILPOINT_PERSISTS" ||
            $5 != "attempt-bc09-" substr($4, 6) ||
            $6 != "sut-apply-effect" ||
            cases[$4] != ($7 FS $8) || $9 == "" || $10 == "" ||
            seen[$4]++) exit 1
        count++
    }
    END { if (count != 5) exit 1 }
' "$fault_cases" "$fault_activation" ||
    fail BC09_FAULT_ACTIVATION_CONTRACT_INVALID

awk -F '	' '
    NR == FNR { cases[$1] = $2 FS $3; next }
    {
        if (!($4 in cases) || $1 == "" || $2 == "" ||
            $3 != "BC09_FAILPOINT_PERSISTS" ||
            cases[$4] != ($5 FS $6) || $7 == "" || $8 == "" || $9 == "" ||
            $10 != "trigger-bc09-" $6 ||
            $11 == "" || $12 == "" || $13 == "" || $14 != "configured" ||
            seen[$4]++) exit 1
        count++
    }
    END { if (count != 5) exit 1 }
' "$fault_cases" "$fault_configuration" ||
    fail BC09_FAULT_CONFIGURATION_CONTRACT_INVALID

awk -F '	' '
    NR == FNR { cases[$1] = $2 FS $3 FS $4 FS int($5 / 10); next }
    {
        if (!($4 in cases) ||
            cases[$4] != ($7 FS $8 FS $17 FS $14) ||
            $3 != "BC09_FAILPOINT_PERSISTS" ||
            $5 != "attempt-bc09-" substr($4, 6) ||
            $6 != "sut-apply-effect" ||
            $9 == "" || $10 == "" || $11 == "" ||
            $12 != "true" || $13 != "1" || $15 != "0" ||
            $16 != "ok" || $18 !~ /^LICIUM_BC09_FAULT_/ ||
            $19 == "" || $20 == "" || $21 != "injected-rollback" ||
            seen[$4]++) exit 1
        count++
    }
    END { if (count != 5) exit 1 }
' "$fault_cases" "$fault_trigger" ||
    fail BC09_FAULT_TRIGGER_CONTRACT_INVALID

awk -F '	' '
    NR == FNR { cases[$1] = $2 FS $3; next }
    {
        if ($1 != "BC09_FAILPOINT_PERSISTS" || !($3 in cases) ||
            cases[$3] != ($7 FS $8) || $2 == "" || $4 == "" ||
            $5 == "" || $6 == "" || $9 != "true" ||
            $10 == "" || $11 == "" || seen[$3]++) exit 1
        count++
    }
    END { if (count != 5) exit 1 }
' "$fault_cases" "$fault_marker" ||
    fail BC09_FAULT_MARKER_CONTRACT_INVALID

cat >"$tmp/expected-mutants" <<'EOF'
harness-bc09-armed-unreached	fault-harness-mutant	armed-but-not-reached	BC09_FAULT_UNREACHED
harness-bc09-command-custody	evidence-mutant	missing-command-custody	BC09_COMMAND_CUSTODY_INVALID
harness-bc09-db-unhealthy	fault-harness-mutant	healthy-retry-unavailable	BC09_FAULT_RECOVERY_INVALID
harness-bc09-duplicate-delivery	sut-mutant	missing-duplicate-delivery	BC09_DUPLICATE_DELIVERY_INVALID
harness-bc09-noop	harness-mutant	missing-action-receipt	BC09_SUT_ACTION_MISSING
harness-bc09-observer-synthesis	observer-mutant	normalized-without-raw	BC09_COVERAGE_INVALID
harness-bc09-raw-post-seal-tamper	evidence-mutant	raw-post-seal-tamper	BC09_RAW_SEAL_INVALID
harness-bc09-replayed-marker	fault-harness-mutant	replayed-fault-marker	BC09_FAULT_REPLAY_DETECTED
harness-bc09-rollback-drift	fault-harness-mutant	rollback-inventory-drift	BC09_ROLLBACK_INVENTORY_INVALID
harness-bc09-wrong-hook	fault-harness-mutant	wrong-hook	BC09_FAULT_HOOK_INVALID
harness-bc09-wrong-phase	fault-harness-mutant	wrong-phase	BC09_FAULT_PHASE_INVALID
neg-bc09-diagnostic-ephemeral	sut-mutant	detect-persisted-diagnostic	BC09_DIAGNOSTIC_PERSISTENCE_DETECTED
neg-bc09-duplicate-persists	counterfactual	detect-duplicate-attempt-artifact	BC09_DUPLICATE_ARTIFACT_DETECTED
neg-bc09-failpoint-persists	fault	detect-failpoint-artifact	BC09_FAILPOINT_ARTIFACT_DETECTED
neg-bc09-failure-no-persistent-artifact	sut-mutant	detect-failure-artifact	BC09_PERSISTENT_ARTIFACT_DETECTED
neg-bc09-incomplete-persists	counterfactual	detect-incomplete-attempt-artifact	BC09_INCOMPLETE_ARTIFACT_DETECTED
neg-bc09-rejected-persists	counterfactual	detect-rejected-attempt-artifact	BC09_REJECTED_ARTIFACT_DETECTED
neg-bc09-stale-persists	counterfactual	detect-stale-attempt-artifact	BC09_STALE_ARTIFACT_DETECTED
EOF
cmp -s "$tmp/expected-mutants" "$mutants" ||
    fail BC09_MUTANT_REGISTRY_INVALID

cat >"$tmp/expected-runtime-artifacts" <<'EOF'
action-receipts.tsv	14	case-delivery-contract	bag	direct-sut-stdout
command-receipts.tsv	12	step-contract	bag	runner-custody
coverage.tsv	6	case-observation-contract	set	runner-contract
exclusions.tsv	6	0	set	present-empty
fault-activation-receipts.tsv	10	5	bag	runner-pre-action-binding
fault-configuration-receipts.tsv	14	5	bag	profile-static-trigger-configuration
fault-inventory-healthy.tsv	6	45	set	adapter-observer
fault-inventory-reopened.tsv	6	45	set	adapter-observer
fault-inventory-rollback.tsv	6	25	set	adapter-observer
fault-inventory-setup.tsv	6	25	set	adapter-observer
fault-markers.tsv	11	5	bag	runner-materialization
fault-trigger-receipts.tsv	21	5	bag	direct-sut-trigger
inventory-after.tsv	6	case-inventory-contract	set	adapter-observer
inventory-before.tsv	6	case-inventory-contract	set	adapter-observer
inventory-reopened.tsv	6	case-inventory-contract	set	adapter-observer
normalized-observations.tsv	6	case-observation-contract	set	runner-normalizer
oracle-result.tsv	6	1	set	runner-oracle
pragma.tsv	6	step-contract	bag	adapter-stderr
raw-observations.tsv	6	case-observation-contract	bag	adapter-and-sut
raw-seal.tsv	9	1	set	runner-custody
EOF
cmp -s "$tmp/expected-runtime-artifacts" "$runtime_artifacts" ||
    fail BC09_RUNTIME_ARTIFACT_REGISTRY_INVALID

grep -Fq '60 scenarios、56 `PASS`／27 `UNTESTED`' "$document" &&
    grep -Fq '53 + 7 = 60' "$document" &&
    grep -Fq '49 + 7 = 56' "$document" &&
    grep -Fq '83 - 56 = 27' "$document" ||
    fail BC09_DOCUMENT_INVALID

echo BC09_REQUIREMENTS_VALID
