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
        fail BC08_REQUIREMENT_MISSING
    [ "$(stat -c '%a' "$file")" = 644 ] ||
        fail BC08_REQUIREMENT_MODE_INVALID
}

require_fields()
{
    file=$1
    fields=$2
    marker=$3
    awk -F '	' -v fields="$fields" '
        NF != fields { exit 1 }
        END { if (NR == 0) exit 1 }
    ' "$file" || fail "$marker"
}

document="$model_dir/BC08-SQLITE-SLICE.md"
action_receipt="$base_dir/bc08-action-receipt-template.tsv"
cases="$base_dir/bc08-cases.tsv"
coverage="$base_dir/bc08-coverage-template.tsv"
fault_activation="$base_dir/bc08-fault-activation-template.tsv"
fault_cases="$base_dir/bc08-fault-cases.tsv"
fault_configuration="$base_dir/bc08-fault-configuration-template.tsv"
fault_healthy="$base_dir/bc08-fault-inventory-healthy.tsv"
fault_reopened="$base_dir/bc08-fault-inventory-reopened.tsv"
fault_marker="$base_dir/bc08-fault-marker-template.tsv"
fault_rollback="$base_dir/bc08-fault-inventory-rollback.tsv"
fault_setup="$base_dir/bc08-fault-inventory-setup.tsv"
fault_steps="$base_dir/bc08-fault-steps.tsv"
fault_trigger="$base_dir/bc08-fault-trigger-template.tsv"
inventory_after="$base_dir/bc08-inventory-after.tsv"
inventory_before="$base_dir/bc08-inventory-before.tsv"
inventory_reopened="$base_dir/bc08-inventory-reopened.tsv"
mutants="$base_dir/bc08-mutants.tsv"
normalized="$base_dir/bc08-normalized-contract.tsv"
raw_seal="$base_dir/bc08-raw-seal-template.tsv"
raw="$base_dir/bc08-raw-template.tsv"
artifacts="$base_dir/bc08-runtime-artifacts.tsv"
scenario_ids="$base_dir/bc08-scenario-ids.tsv"
steps="$base_dir/bc08-steps.tsv"

for file in "$document" "$action_receipt" "$cases" "$coverage" \
    "$fault_activation" "$fault_cases" "$fault_configuration" \
    "$fault_healthy" "$fault_reopened" "$fault_marker" "$fault_rollback" "$fault_setup" \
    "$fault_steps" \
    "$fault_trigger" "$inventory_after" "$inventory_before" \
    "$inventory_reopened" "$mutants" "$normalized" "$raw_seal" "$raw" \
    "$artifacts" "$scenario_ids" "$steps"
do
    require_file "$file"
done

require_fields "$action_receipt" 15 BC08_ACTION_RECEIPT_CONTRACT_INVALID
require_fields "$cases" 7 BC08_CASE_REGISTRY_INVALID
require_fields "$coverage" 6 BC08_COVERAGE_CONTRACT_INVALID
require_fields "$fault_activation" 10 BC08_FAULT_ACTIVATION_CONTRACT_INVALID
require_fields "$fault_cases" 5 BC08_FAULT_CASE_REGISTRY_INVALID
require_fields "$fault_configuration" 14 BC08_FAULT_CONFIGURATION_CONTRACT_INVALID
require_fields "$fault_healthy" 6 BC08_FAULT_INVENTORY_CONTRACT_INVALID
require_fields "$fault_reopened" 6 BC08_FAULT_INVENTORY_CONTRACT_INVALID
require_fields "$fault_marker" 11 BC08_FAULT_MARKER_CONTRACT_INVALID
require_fields "$fault_rollback" 6 BC08_FAULT_INVENTORY_CONTRACT_INVALID
require_fields "$fault_setup" 6 BC08_FAULT_INVENTORY_CONTRACT_INVALID
require_fields "$fault_steps" 6 BC08_FAULT_STEP_REGISTRY_INVALID
require_fields "$fault_trigger" 21 BC08_FAULT_TRIGGER_CONTRACT_INVALID
require_fields "$inventory_after" 6 BC08_INVENTORY_CONTRACT_INVALID
require_fields "$inventory_before" 6 BC08_INVENTORY_CONTRACT_INVALID
require_fields "$inventory_reopened" 6 BC08_INVENTORY_CONTRACT_INVALID
require_fields "$mutants" 4 BC08_MUTANT_REGISTRY_INVALID
require_fields "$normalized" 6 BC08_NORMALIZED_CONTRACT_INVALID
require_fields "$raw_seal" 9 BC08_RAW_SEAL_CONTRACT_INVALID
require_fields "$raw" 6 BC08_RAW_CONTRACT_INVALID
require_fields "$artifacts" 5 BC08_RUNTIME_ARTIFACT_REGISTRY_INVALID
require_fields "$scenario_ids" 3 BC08_SCENARIO_ID_REGISTRY_INVALID
require_fields "$steps" 5 BC08_STEP_REGISTRY_INVALID

awk -F '	' '
    FILENAME == ARGV[1] && $1 == "BC08" {
        class[$3] = $4
        next
    }
    FILENAME == ARGV[2] && $2 == "BC08" {
        execution[$1] = $4 FS $6 FS $7 FS $10 FS $11 FS $12 FS $13 FS $14 FS $18
        next
    }
    FILENAME == ARGV[3] && $1 ~ /^neg-bc08-/ {
        negative[$1] = $2 FS $4
        next
    }
    FILENAME == ARGV[4] {
        oracle = "oracle-" tolower_hyphen($1)
        expected_set = $1 == "BC08_MID_BOUNDARY_FAILURE" ?
            "set-bc08-effect-boundaries" : "-"
        expected_requirement = $1 == "BC08_MID_BOUNDARY_FAILURE" ? "all" : "-"
        expected_execution = $2 FS "sut-setup-bc08" FS "sut-apply-effect" FS \
            oracle FS "coverage-bc08" FS expected_set FS \
            expected_requirement FS $7 FS $6
        if (!($1 in class) || class[$1] != $2 ||
            !($1 in execution) ||
            execution[$1] != expected_execution ||
            !($6 in negative) ||
            negative[$6] != ($1 FS mutant_name($1)) ||
            seen_assertion[$1]++ || seen_negative[$6]++) exit 1
        count++
    }
    function tolower_hyphen(value) {
        value = tolower(value)
        gsub(/_/, "-", value)
        return value
    }
    function mutant_name(value) {
        return value == "BC08_COMPLETE_EFFECT" ?
            "detect-incomplete-effect-set" :
            value == "BC08_MID_BOUNDARY_FAILURE" ?
            "detect-mid-boundary-partial-effect" :
            value == "BC08_MISSING_CURRENT" ?
            "detect-missing-current-pointer" :
            value == "BC08_MISSING_OBSERVATION" ?
            "detect-missing-decision-observation" :
            value == "BC08_MISSING_RESULT" ?
            "detect-missing-effect-result" :
            value == "BC08_MISSING_TRANSITION" ?
            "detect-missing-state-transition" :
            "detect-missing-complete-view"
    }
    END { if (count != 7) exit 1 }
' "$base_dir/scenarios.tsv" "$base_dir/execution-map.tsv" \
    "$base_dir/negative-identities.tsv" "$cases" ||
    fail BC08_CASE_REGISTRY_INVALID

awk -F '	' '
    FILENAME == ARGV[1] {
        expected[$1 FS $3] = tolower_hyphen($1) "--" $3
        next
    }
    {
        key = $1 FS $2
        if (!(key in expected) || $3 != expected[key] ||
            seen[$3]++) exit 1
        count++
    }
    function tolower_hyphen(value) {
        value = tolower(value)
        gsub(/_/, "-", value)
        return value
    }
    END { if (count != 7) exit 1 }
' "$cases" "$scenario_ids" ||
    fail BC08_SCENARIO_ID_REGISTRY_INVALID

cat >"$tmp/expected-steps" <<'EOF'
010	create	profile-create-namespace	normal	command-receipt
020	setup	sut-setup-bc08	ordinary	action-receipt
030	inventory-before	profile-inventory-bc08	ordinary	inventory-before
040	action	sut-apply-effect	case-mode	action-receipt
050	retry	sut-apply-effect	retry	action-receipt
060	observe-after	profile-observe-bc08	ordinary	raw-observation
070	inventory-after	profile-inventory-bc08	ordinary	inventory-after
080	reopen	profile-reopen-namespace	normal	command-receipt
090	inventory-reopened	profile-inventory-bc08	ordinary	inventory-reopened
100	destroy	profile-destroy-namespace	normal	command-receipt
110	normalize	runner-normalize-bc08	ordinary	normalized-observation
120	oracle	runner-oracle-bc08	ordinary	oracle-result
EOF
cmp -s "$tmp/expected-steps" "$steps" ||
    fail BC08_STEP_REGISTRY_INVALID

cat >"$tmp/expected-fault-cases" <<'EOF'
case-bc08-after-observation	hook-bc08-after-observation	after-observation	error-bc08-after-observation	010
case-bc08-after-transition	hook-bc08-after-transition	after-transition	error-bc08-after-transition	020
case-bc08-after-view-header	hook-bc08-after-view-header	after-view-header	error-bc08-after-view-header	030
case-bc08-after-view-row	hook-bc08-after-view-row	after-view-row	error-bc08-after-view-row	040
case-bc08-before-current-update	hook-bc08-before-current-update	before-current-update	error-bc08-before-current-update	050
EOF
cmp -s "$tmp/expected-fault-cases" "$fault_cases" ||
    fail BC08_FAULT_CASE_REGISTRY_INVALID

cat >"$tmp/expected-fault-steps" <<'EOF'
010	create	profile-create-namespace	normal	command-receipt	same
020	setup	sut-setup-bc08	fault	action-receipt	same
030	inventory-setup	profile-inventory-bc08	fault	fault-inventory-setup	same
040	activate-fault	profile-activate-fault-bc08	case-hook	fault-activation-receipt	same
050	fault-action	sut-apply-effect	fault	fault-trigger-receipt	same
060	inventory-rollback	profile-inventory-bc08	fault	fault-inventory-rollback	same
070	clear-fault	profile-clear-fault-bc08	case-hook	command-receipt	same
080	healthy-action	sut-apply-effect	ordinary	action-receipt	same
090	inventory-healthy	profile-inventory-bc08	ordinary	fault-inventory-healthy	same
100	reopen	profile-reopen-namespace	normal	command-receipt	same
110	inventory-reopened	profile-inventory-bc08	ordinary	inventory-reopened	same
120	destroy	profile-destroy-namespace	normal	command-receipt	same
EOF
cmp -s "$tmp/expected-fault-steps" "$fault_steps" ||
    fail BC08_FAULT_STEP_REGISTRY_INVALID

awk -F '	' '
    FILENAME == ARGV[1] {
        if ($2 == "BC08") hook[$1] = $3 FS $4
        next
    }
    FILENAME == ARGV[2] {
        if ($1 == "set-bc08-effect-boundaries") member[$2] = $3
        next
    }
    {
        if (!($2 in hook) || !($2 in member) ||
            hook[$2] != ($3 FS "sut-apply-effect") ||
            member[$2] != "all" || seen[$2]++) exit 1
        count++
    }
    END { if (count != 5 || length(hook) != 5 || length(member) != 5) exit 1 }
' "$base_dir/fault-hooks.tsv" "$base_dir/fault-hook-sets.tsv" "$fault_cases" ||
    fail BC08_FAULT_CASE_REGISTRY_INVALID

cat >"$tmp/expected-mutants" <<'EOF'
harness-bc08-armed-unreached	fault-harness-mutant	armed-but-not-reached	BC08_FAULT_UNREACHED
harness-bc08-db-unhealthy	fault-harness-mutant	healthy-retry-unavailable	BC08_FAULT_RECOVERY_INVALID
harness-bc08-noop	harness-mutant	missing-action-receipt	BC08_SUT_ACTION_MISSING
harness-bc08-observer-synthesis	observer-mutant	normalized-without-raw	BC08_COVERAGE_INVALID
harness-bc08-raw-post-seal-tamper	evidence-mutant	raw-post-seal-tamper	BC08_RAW_SEAL_INVALID
harness-bc08-replayed-marker	fault-harness-mutant	replayed-fault-marker	BC08_FAULT_REPLAY_DETECTED
harness-bc08-rollback-drift	fault-harness-mutant	rollback-inventory-drift	BC08_ROLLBACK_INVENTORY_INVALID
harness-bc08-wrong-hook	fault-harness-mutant	wrong-hook	BC08_FAULT_HOOK_INVALID
harness-bc08-wrong-phase	fault-harness-mutant	wrong-phase	BC08_FAULT_PHASE_INVALID
neg-bc08-complete-effect	sut-mutant	detect-incomplete-effect-set	BC08_INCOMPLETE_EFFECT_DETECTED
neg-bc08-mid-boundary-failure	fault	detect-mid-boundary-partial-effect	BC08_PARTIAL_EFFECT_DETECTED
neg-bc08-missing-current	sut-mutant	detect-missing-current-pointer	BC08_MISSING_CURRENT_DETECTED
neg-bc08-missing-observation	sut-mutant	detect-missing-decision-observation	BC08_MISSING_OBSERVATION_DETECTED
neg-bc08-missing-result	sut-mutant	detect-missing-effect-result	BC08_MISSING_RESULT_DETECTED
neg-bc08-missing-transition	sut-mutant	detect-missing-state-transition	BC08_MISSING_TRANSITION_DETECTED
neg-bc08-missing-view	sut-mutant	detect-missing-complete-view	BC08_MISSING_VIEW_DETECTED
EOF
cmp -s "$tmp/expected-mutants" "$mutants" ||
    fail BC08_MUTANT_REGISTRY_INVALID

cat >"$tmp/expected-artifacts" <<'EOF'
action-receipts.tsv	15	case-contract	bag	direct-sut-stdout
command-receipts.tsv	12	10	bag	runner-custody
coverage.tsv	6	12	set	runner-contract
exclusions.tsv	6	0	set	present-empty
fault-activation-receipts.tsv	10	fault-case-contract	bag	runner-pre-action-binding
fault-configuration-receipts.tsv	14	fault-case-contract	bag	profile-static-trigger-configuration
fault-inventory-healthy.tsv	6	fault-case-contract	set	adapter-observer
fault-inventory-reopened.tsv	6	fault-case-contract	set	adapter-observer
fault-inventory-rollback.tsv	6	fault-case-contract	set	adapter-observer
fault-inventory-setup.tsv	6	fault-case-contract	set	adapter-observer
fault-markers.tsv	11	fault-case-contract	bag	runner-materialization
fault-trigger-receipts.tsv	21	fault-case-contract	bag	direct-sut-trigger
inventory-after.tsv	6	case-contract	set	adapter-observer
inventory-before.tsv	6	case-contract	set	adapter-observer
inventory-reopened.tsv	6	case-contract	set	adapter-observer
normalized-observations.tsv	6	12	set	runner-normalizer
oracle-result.tsv	6	1	set	runner-oracle
pragma.tsv	6	8	bag	adapter-stderr
raw-observations.tsv	6	12	bag	adapter-and-sut
raw-seal.tsv	9	1	set	runner-custody
EOF
cmp -s "$tmp/expected-artifacts" "$artifacts" ||
    fail BC08_RUNTIME_ARTIFACT_REGISTRY_INVALID

[ "$(cat "$action_receipt")" = \
    '{run}	{namespace}	{scenario}	sut-apply-effect	{mode}	{effect}	{result}	{transition}	{observation}	{view}	{current-revision}	{outcome}	{set-cardinality}	{nonce}	{delivery}' ] ||
    fail BC08_ACTION_RECEIPT_CONTRACT_INVALID
[ "$(cat "$raw_seal")" = \
    'raw-observations.tsv	100644	{sha256}	{bytes}	{run}	{namespace}	{scenario}	{action-receipt-sha256}	sealed-before-normalization' ] ||
    fail BC08_RAW_SEAL_CONTRACT_INVALID

awk -F '	' '
    $1 != "{scenario}" || $2 != sprintf("raw-%03d", NR) { exit 1 }
    END { if (NR != 12) exit 1 }
' "$raw" || fail BC08_RAW_CONTRACT_INVALID

awk -F '	' '
    $1 != "{scenario}" || $2 != sprintf("raw-%03d", NR) ||
        $3 != "record" || $4 != "{scenario}" ||
        $5 != sprintf("obs-%03d", NR) || $6 != "all" { exit 1 }
    END { if (NR != 12) exit 1 }
' "$coverage" || fail BC08_COVERAGE_CONTRACT_INVALID

awk -F '	' '
    FILENAME == ARGV[1] { valid[$3] = 1; next }
    !($1 in valid) || $2 != sprintf("obs-%03d", ++per[$1]) ||
        seen[$1 FS $2]++ { exit 1 }
    { count++ }
    $2 == "obs-001" && $6 == "accepted" { accepted[$1] = 1 }
    $2 == "obs-008" && $6 == "complete" { complete[$1] = 1 }
    $2 == "obs-010" && $6 == "no-duplicate" { retry[$1] = 1 }
    $2 == "obs-011" && $1 ~ /mid-boundary-failure/ && $6 == "5" {
        hooks[$1] = 1
    }
    $2 == "obs-012" && $1 ~ /mid-boundary-failure/ && $6 == "0" {
        rollback[$1] = 1
    }
    END {
        if (count != 84) exit 1
        for (item in valid)
            if (per[item] != 12 || !accepted[item] ||
                !complete[item] || !retry[item]) exit 1
        if (length(hooks) != 1 || length(rollback) != 1) exit 1
    }
' "$scenario_ids" "$normalized" ||
    fail BC08_NORMALIZED_CONTRACT_INVALID

for inventory in "$inventory_before" "$inventory_after" "$inventory_reopened" \
    "$fault_setup" "$fault_rollback" "$fault_healthy" "$fault_reopened"
do
    LC_ALL=C sort -c "$inventory" 2>/dev/null ||
        fail BC08_INVENTORY_CONTRACT_INVALID
done
cmp -s "$inventory_after" "$inventory_reopened" ||
    fail BC08_INVENTORY_CONTRACT_INVALID
cmp -s "$fault_setup" "$fault_rollback" ||
    fail BC08_FAULT_INVENTORY_CONTRACT_INVALID
cmp -s "$fault_healthy" "$fault_reopened" ||
    fail BC08_FAULT_INVENTORY_CONTRACT_INVALID

awk -F '	' '
    FILENAME == ARGV[1] && $2 == "evaluation-result" {
        before[$1 FS $3 FS $4 FS $5 FS $6] = 1
        next
    }
    FILENAME == ARGV[2] && $2 == "evaluation-result" {
        after[$1 FS $3 FS $4 FS $5 FS $6] = 1
        next
    }
    END {
        if (length(before) != 14 || length(after) != 14) exit 1
        for (key in before) if (!(key in after)) exit 1
        for (key in after) if (!(key in before)) exit 1
    }
' "$inventory_before" "$inventory_after" ||
    fail BC08_INVENTORY_CONTRACT_INVALID

awk -F '	' '
    NR == FNR { cases[$1] = $2 FS $3; next }
    {
        if (!($4 in cases) || $1 == "" || $2 == "" ||
            $3 != "BC08_MID_BOUNDARY_FAILURE" ||
            $5 !~ /^attempt-bc08-/ || $6 != "sut-apply-effect" ||
            cases[$4] != ($7 FS $8) || $9 == "" || $10 == "" ||
            seen[$4]++) exit 1
        count++
    }
    END { if (count != 5) exit 1 }
' "$fault_cases" "$fault_activation" ||
    fail BC08_FAULT_ACTIVATION_CONTRACT_INVALID

awk -F '	' '
    NR == FNR { cases[$1] = $2 FS $3 FS $4 FS int($5 / 10); next }
    {
        if (!($4 in cases) ||
            cases[$4] != ($7 FS $8 FS $17 FS $14) ||
            $3 != "BC08_MID_BOUNDARY_FAILURE" ||
            $5 !~ /^attempt-bc08-/ || $6 != "sut-apply-effect" ||
            $9 == "" || $10 == "" || $11 == "" ||
            $12 != "true" || $13 != "1" || $15 != "0" ||
            $16 != "ok" || $18 !~ /^LICIUM_BC08_FAULT_/ ||
            $19 == "" || $20 == "" || $21 != "injected-rollback" ||
            seen[$4]++) exit 1
        count++
    }
    END { if (count != 5) exit 1 }
' "$fault_cases" "$fault_trigger" ||
    fail BC08_FAULT_TRIGGER_CONTRACT_INVALID

awk -F '	' '
    NR == FNR { cases[$1] = $2 FS $3; next }
    {
        if (!($4 in cases) || $1 == "" || $2 == "" ||
            $3 != "BC08_MID_BOUNDARY_FAILURE" ||
            cases[$4] != ($5 FS $6) ||
            $7 == "" || $8 == "" || $9 == "" ||
            $10 !~ /^trigger-bc08-/ || $11 == "" ||
            $12 == "" || $13 == "" || $14 != "configured" ||
            seen[$4]++) exit 1
        count++
    }
    END { if (count != 5) exit 1 }
' "$fault_cases" "$fault_configuration" ||
    fail BC08_FAULT_CONFIGURATION_CONTRACT_INVALID

awk -F '	' '
    NR == FNR { cases[$1] = $2 FS $3; next }
    {
        if (!($3 in cases) || cases[$3] != ($7 FS $8) ||
            $9 != "true" || $10 == "" || $11 == "" ||
            seen[$3]++) exit 1
        count++
    }
    END { if (count != 5) exit 1 }
' "$fault_cases" "$fault_marker" ||
    fail BC08_FAULT_MARKER_CONTRACT_INVALID

grep -Fq '53 scenarios、49 `PASS`／34 `UNTESTED`' "$document" &&
    grep -Fq '46 + 7 = 53' "$document" &&
    grep -Fq '83 - 49 = 34' "$document" ||
    fail BC08_DOCUMENT_INVALID

echo BC08_REQUIREMENTS_VALID
