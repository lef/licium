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
        fail BC11_REQUIREMENT_MISSING
    [ "$(stat -c '%a' "$file")" = 644 ] ||
        fail BC11_REQUIREMENT_MODE_INVALID
}

require_fields()
{
    file=$1
    fields=$2
    rows=$3
    marker=$4
    awk -F '\t' -v fields="$fields" -v rows="$rows" '
        NF != fields { exit 1 }
        {
            for (field = 1; field <= NF; field++)
                if ($field == "") exit 1
        }
        END { if (NR != rows) exit 1 }
    ' "$file" || fail "$marker"
}

document="$model_dir/BC11-SQLITE-SLICE.md"
action_receipt="$base_dir/bc11-action-receipt-template.tsv"
cases="$base_dir/bc11-cases.tsv"
command_receipt="$base_dir/bc11-command-receipt-template.tsv"
coverage="$base_dir/bc11-coverage-template.tsv"
mutants="$base_dir/bc11-mutants.tsv"
normalized="$base_dir/bc11-normalized-template.tsv"
oracle="$base_dir/bc11-oracle-contract.tsv"
raw="$base_dir/bc11-raw-template.tsv"
raw_seal="$base_dir/bc11-raw-seal-template.tsv"
runtime_artifacts="$base_dir/bc11-runtime-artifacts.tsv"
scenario_ids="$base_dir/bc11-scenario-ids.tsv"
steps="$base_dir/bc11-steps.tsv"

for file in "$document" "$action_receipt" "$cases" "$command_receipt" \
    "$coverage" "$mutants" "$normalized" "$oracle" "$raw" "$raw_seal" \
    "$runtime_artifacts" "$scenario_ids" "$steps"
do
    require_file "$file"
done

require_fields "$action_receipt" 12 1 BC11_ACTION_RECEIPT_CONTRACT_INVALID
require_fields "$cases" 8 8 BC11_CASE_REGISTRY_INVALID
require_fields "$command_receipt" 12 1 BC11_COMMAND_RECEIPT_CONTRACT_INVALID
require_fields "$coverage" 6 92 BC11_COVERAGE_CONTRACT_INVALID
require_fields "$mutants" 5 11 BC11_MUTANT_REGISTRY_INVALID
require_fields "$normalized" 6 92 BC11_NORMALIZED_CONTRACT_INVALID
require_fields "$oracle" 7 8 BC11_ORACLE_CONTRACT_INVALID
require_fields "$raw" 6 92 BC11_RAW_CONTRACT_INVALID
require_fields "$raw_seal" 9 1 BC11_RAW_SEAL_CONTRACT_INVALID
require_fields "$runtime_artifacts" 5 10 BC11_RUNTIME_ARTIFACT_REGISTRY_INVALID
require_fields "$scenario_ids" 3 8 BC11_SCENARIO_ID_REGISTRY_INVALID
require_fields "$steps" 5 8 BC11_STEP_REGISTRY_INVALID

# Bind every local case to the accepted global scenario, execution, and
# negative registries. The local source-evidence label is descriptive only.
awk -F '\t' '
    FILENAME == ARGV[1] && $1 == "BC11" {
        class[$3] = $4
        next
    }
    FILENAME == ARGV[2] && $2 == "BC11" {
        execution[$1] = $4 FS $6 FS $7 FS $10 FS $11 FS $14 FS $17 FS $18
        next
    }
    FILENAME == ARGV[3] && $1 ~ /^neg-bc11-/ {
        negative[$1] = $2 FS $3 FS $4
        next
    }
    FILENAME == ARGV[4] {
        expected = $2 FS "sut-setup-bc11" FS $4 FS $5 FS "coverage-bc11" FS "PASS" FS negative_type($1) FS $6
        if (!($1 in class) || class[$1] != $2 ||
            !($1 in execution) ||
            execution[$1] != expected ||
            !($6 in negative) ||
            negative[$6] != ($1 FS negative_type($1) FS negative_name($1)) ||
            $3 !~ /^(explanation|replay|integrity)$/ ||
            $7 == "" ||
            $8 != 1 ||
            seen_assertion[$1]++ || seen_negative[$6]++) exit 1
        count++
    }
    function negative_type(assertion) {
        return assertion ~ /_MISSING_AS_EMPTY$/ || assertion ~ /_LATEST_SUBSTITUTION$/ ?
            "counterfactual" : "sut-mutant"
    }
    function negative_name(assertion) {
        return assertion == "BC11_EXPLANATION_CLOSURE" ?
            "detect-explanation-member-loss" :
            assertion == "BC11_FINDING_CROSS_LINK" ?
            "detect-missing-cross-link-finding" :
            assertion == "BC11_FINDING_DANGLING" ?
            "detect-missing-dangling-finding" :
            assertion == "BC11_LATEST_SUBSTITUTION" ?
            "detect-latest-replay-substitution" :
            assertion == "BC11_MISSING_AS_EMPTY" ?
            "detect-replay-missing-as-empty" :
            assertion == "BC11_REPLAY_RESULT" ?
            "detect-replay-result-drift" :
            assertion == "BC11_SILENT_CROSS_LINK" ?
            "detect-silent-cross-link-repair" :
            "detect-silent-dangling-repair"
    }
    END {
        if (count != 8 || length(seen_assertion) != 8 ||
            length(seen_negative) != 8) exit 1
    }
' "$base_dir/scenarios.tsv" "$base_dir/execution-map.tsv" \
    "$base_dir/negative-identities.tsv" "$cases" ||
    fail BC11_CASE_REGISTRY_INVALID

awk -F '\t' '
    FILENAME == ARGV[1] && $1 == "BC11" { valid[$3] = 1; next }
    FILENAME == ARGV[2] {
        expected_case = "case-" tolower_hyphen($1)
        expected_scenario = tolower_hyphen($1) "--" expected_case
        if (!($1 in valid) || $2 != expected_case ||
            $3 != expected_scenario || seen[$1]++ || seen_id[$3]++) exit 1
        count++
    }
    function tolower_hyphen(value) {
        value = tolower(value)
        gsub(/_/, "-", value)
        return value
    }
    END { if (count != 8) exit 1 }
' "$base_dir/scenarios.tsv" "$scenario_ids" ||
    fail BC11_SCENARIO_ID_REGISTRY_INVALID

cat >"$tmp/expected-steps" <<'EOF'
010	create	profile-create-namespace	normal	command-receipt
020	setup	sut-setup-bc11	ordinary	command-receipt
030	action	case-operation	case-mode	action-receipt
040	reopen	profile-reopen-namespace	normal	command-receipt
050	observe	profile-observe-bc11	ordinary	raw-observation
060	destroy	profile-destroy-namespace	normal	command-receipt
070	normalize	runner-normalize-bc11	ordinary	normalized-observation
080	oracle	runner-oracle-bc11	ordinary	oracle-result
EOF
cmp -s "$tmp/expected-steps" "$steps" ||
    fail BC11_STEP_REGISTRY_INVALID

[ "$(cat "$action_receipt")" = \
    '{run}	{namespace}	{scenario}	{assertion}	{surface}	{operation}	{mode}	{request-1}	{root-1}	{definition-1}	accepted	{nonce}' ] ||
    fail BC11_ACTION_RECEIPT_CONTRACT_INVALID
[ "$(cat "$command_receipt")" = \
    '{run}	{namespace}	{assertion}	{phase}	{operation}	{mode}	{status}	{stdout-sha256}	{stdout-bytes}	{stderr-sha256}	{stderr-bytes}	{argv-sha256}' ] ||
    fail BC11_COMMAND_RECEIPT_CONTRACT_INVALID
[ "$(cat "$raw_seal")" = \
    'raw-observations.tsv	100644	{sha256}	{bytes}	{run}	{namespace}	{scenario}	{action-receipt-sha256}	sealed-before-normalization' ] ||
    fail BC11_RAW_SEAL_CONTRACT_INVALID

# Raw and normalized contracts are non-empty.
awk -F '\t' '
    FILENAME == ARGV[1] {
        if ($2 != sprintf("raw-%03d", ++raw_count[$1]) ||
            seen_raw[$1 FS $2]++) exit 1
        raw[$1 FS substr($2, 5)] = $3 FS $4 FS $5 FS $6
        total_raw++
        next
    }
    FILENAME == ARGV[2] {
        if ($2 != sprintf("obs-%03d", ++normalized_count[$1]) ||
            seen_normalized[$1 FS $2]++) exit 1
        normalized[$1 FS substr($2, 5)] = $3 FS $4 FS $5 FS $6
        total_normalized++
        next
    }
    {
        key = $1 FS substr($2, 5)
        normalized_key = $4 FS substr($5, 5)
        if (!(key in raw) || !(normalized_key in normalized) ||
            key != normalized_key || raw[key] != normalized[normalized_key] ||
            $3 != "record" || $6 != "all" || seen_coverage[key]++) exit 1
        total_coverage++
    }
    END {
        if (total_raw != 92 || total_normalized != 92 || total_coverage != 92) exit 1
        for (key in raw)
            if (!(key in normalized) || raw[key] != normalized[key] ||
                seen_coverage[key] != 1) exit 1
        for (key in normalized) if (!(key in raw)) exit 1
        for (scenario in raw_count) {
            expected = scenario ~ /-latest-substitution--/ ? 11 :
                scenario ~ /-missing-as-empty--/ ? 35 :
                scenario ~ /-replay-result--/ ? 10 :
                scenario ~ /-silent-(cross-link|dangling)--/ ? 9 : 6
            if (raw_count[scenario] != expected ||
                normalized_count[scenario] != expected) exit 1
        }
    }
' "$raw" "$normalized" "$coverage" ||
    fail BC11_COVERAGE_CONTRACT_INVALID

awk -F '\t' '
    BEGIN {
        role[1] = "binding"
        role[2] = "definition"
        role[3] = "knowledge-cut"
        role[4] = "source-root"
        role[5] = "semantics"
    }
    {
        row_count[$1]++
    }
    $3 == "surface" && $5 == "completeness" && $6 == "complete" {
        complete[$1]++
    }
    $1 ~ /-explanation-closure--/ && $3 == "explanation" &&
        $4 == "observation" && $5 == "edge" && $6 == "observation-1" {
        exp_observation[$1]++
    }
    $1 ~ /-explanation-closure--/ && $3 == "explanation" &&
        $4 == "result" && $5 == "edge" && $6 == "result-1" {
        exp_result[$1]++
    }
    $1 ~ /-explanation-closure--/ && $3 == "explanation" &&
        $4 == "request" && $5 == "edge" && $6 == "request-1" {
        exp_request[$1]++
    }
    $1 ~ /-explanation-closure--/ && $3 == "explanation" &&
        $4 == "source-root" && $5 == "edge" && $6 == "root-1" {
        exp_root[$1]++
    }
    $1 ~ /-explanation-closure--/ && $3 == "explanation" &&
        $4 == "selected-member" && $5 == "edge" && $6 == "member-public" {
        exp_member[$1]++
    }

    $1 ~ /-(finding|silent)-cross-link--/ && $3 == "integrity" &&
        $4 == "finding" && $5 == "kind" && $6 == "cross-linked-root" {
        cross_kind[$1]++
    }
    $1 ~ /-(finding|silent)-cross-link--/ && $3 == "integrity" &&
        $4 == "finding" && $5 == "source" && $6 == "root-1" {
        cross_source[$1]++
    }
    $1 ~ /-(finding|silent)-cross-link--/ && $3 == "integrity" &&
        $4 == "finding" && $5 == "target" && $6 == "root-2" {
        cross_target[$1]++
    }
    $1 ~ /-(finding|silent)-cross-link--/ && $3 == "integrity" &&
        $4 == "selection" && $5 == "member" && $6 == "member-public" {
        cross_member[$1]++
    }
    $1 ~ /-(finding|silent)-cross-link--/ && $3 == "integrity" &&
        $4 == "summary" && $5 == "finding-count" && $6 == 1 {
        cross_count[$1]++
    }

    $1 ~ /-(finding|silent)-dangling--/ && $3 == "integrity" &&
        $4 == "finding" && $5 == "kind" && $6 == "dangling-result" {
        dangling_result[$1]++
    }
    $1 ~ /-(finding|silent)-dangling--/ && $3 == "integrity" &&
        $4 == "finding" && $5 == "kind" && $6 == "dangling-view" {
        dangling_view[$1]++
    }
    $1 ~ /-(finding|silent)-dangling--/ && $3 == "integrity" &&
        $4 == "selection" && $5 == "target" && $6 == "result-1" {
        dangling_target[$1]++
    }
    $1 ~ /-(finding|silent)-dangling--/ && $3 == "integrity" &&
        $4 == "selection" && $5 == "member" && $6 == "public-a" {
        dangling_member[$1]++
    }
    $1 ~ /-(finding|silent)-dangling--/ && $3 == "integrity" &&
        $4 == "summary" && $5 == "finding-count" && $6 == 2 {
        dangling_count[$1]++
    }

    $1 ~ /-latest-substitution--/ && $3 == "provenance" &&
        $4 == "replay" && $5 == "original-result" && $6 == "result-1" {
        latest_original[$1]++
    }
    $1 ~ /-latest-substitution--/ && $3 == "pinned-input" &&
        $4 == "replay" && $5 == "binding" && $6 == "binding-1" {
        latest_binding[$1]++
    }
    $1 ~ /-latest-substitution--/ && $3 == "pinned-input" &&
        $4 == "replay" && $5 == "definition" && $6 == "definition-1" {
        latest_definition[$1]++
    }
    $1 ~ /-latest-substitution--/ && $3 == "pinned-input" &&
        $4 == "replay" && $5 == "knowledge-cut" && $6 == "cut-1" {
        latest_cut[$1]++
    }
    $1 ~ /-latest-substitution--/ && $3 == "pinned-input" &&
        $4 == "replay" && $5 == "source-root" && $6 == "root-1" {
        latest_root[$1]++
    }
    $1 ~ /-latest-substitution--/ && $3 == "pinned-input" &&
        $4 == "replay" && $5 == "ambient-root" && $6 == "root-2" {
        latest_ambient[$1]++
    }
    $1 ~ /-latest-substitution--/ && $3 == "pinned-input" &&
        $4 == "replay" && $5 == "semantics" && $6 == "semantics-1" {
        latest_semantics[$1]++
    }
    $1 ~ /-latest-substitution--/ && $3 == "selection" &&
        $4 == "replay" && $5 == "value" && $6 == "public-a" {
        latest_public[$1]++
    }
    $1 ~ /-latest-substitution--/ && $3 == "replay" &&
        $4 == "result" && $5 == "symmetric-difference" && $6 == 0 {
        latest_diff[$1]++
    }
    $1 ~ /-latest-substitution--/ && $3 == "provenance" &&
        $4 == "replay" && $5 == "replayed-result" &&
        $6 == "replay-result-1" {
        latest_replayed[$1]++
    }

    $1 ~ /-missing-as-empty--/ && $3 == "input-status" {
        key = $1 SUBSEP $4 SUBSEP $5
        if (seen_input[key]++) exit 1
        input_value[key] = $6
        input_count[$1 SUBSEP $4]++
    }
    $1 ~ /-missing-as-empty--/ && $3 == "replay" &&
        $5 == "disposition" && $6 == "unavailable" {
        missing_disposition[$1 SUBSEP $4]++
    }
    $1 ~ /-missing-as-empty--/ && $3 == "replay" &&
        $5 == "difference-count" && $6 == 1 {
        missing_difference[$1 SUBSEP $4]++
    }

    $1 ~ /-replay-result--/ && $3 == "provenance" &&
        $4 == "replay" && $5 == "original-result" && $6 == "result-1" {
        replay_original[$1]++
    }
    $1 ~ /-replay-result--/ && $3 == "pinned-input" &&
        $4 == "replay" && $5 == "binding" && $6 == "binding-1" {
        replay_binding[$1]++
    }
    $1 ~ /-replay-result--/ && $3 == "pinned-input" &&
        $4 == "replay" && $5 == "definition" && $6 == "definition-1" {
        replay_definition[$1]++
    }
    $1 ~ /-replay-result--/ && $3 == "pinned-input" &&
        $4 == "replay" && $5 == "knowledge-cut" && $6 == "cut-1" {
        replay_cut[$1]++
    }
    $1 ~ /-replay-result--/ && $3 == "pinned-input" &&
        $4 == "replay" && $5 == "source-root" && $6 == "root-1" {
        replay_root[$1]++
    }
    $1 ~ /-replay-result--/ && $3 == "pinned-input" &&
        $4 == "replay" && $5 == "semantics" && $6 == "semantics-1" {
        replay_semantics[$1]++
    }
    $1 ~ /-replay-result--/ && $3 == "selection" &&
        $4 == "replay" && $5 == "value" && $6 == "public-a" {
        replay_public[$1]++
    }
    $1 ~ /-replay-result--/ && $3 == "replay" &&
        $4 == "result" && $5 == "symmetric-difference" && $6 == 0 {
        replay_diff[$1]++
    }
    $1 ~ /-replay-result--/ && $3 == "provenance" &&
        $4 == "replay" && $5 == "replayed-result" &&
        $6 == "replay-result-1" {
        replay_replayed[$1]++
    }

    $1 ~ /-silent-(cross-link|dangling)--/ && $3 == "inventory" &&
        $4 == "before" && $5 == "source-record-digest" {
        before_digest[$1] = $6
        before_count[$1]++
    }
    $1 ~ /-silent-(cross-link|dangling)--/ && $3 == "inventory" &&
        $4 == "after" && $5 == "source-record-digest" {
        after_digest[$1] = $6
        after_count[$1]++
    }
    $1 ~ /-silent-(cross-link|dangling)--/ && $3 == "inventory" &&
        $4 == "validation" && $5 == "repair-count" && $6 == 0 {
        repair_zero[$1]++
    }

    END {
        if (length(row_count) != 8) exit 1
        for (scenario in row_count) {
            if (scenario ~ /-explanation-closure--/) {
                if (row_count[scenario] != 6 || complete[scenario] != 1 ||
                    exp_observation[scenario] != 1 || exp_result[scenario] != 1 ||
                    exp_request[scenario] != 1 || exp_root[scenario] != 1 ||
                    exp_member[scenario] != 1) exit 1
            } else if (scenario ~ /-finding-cross-link--/) {
                if (row_count[scenario] != 6 || complete[scenario] != 1 ||
                    cross_kind[scenario] != 1 || cross_source[scenario] != 1 ||
                    cross_target[scenario] != 1 || cross_member[scenario] != 1 ||
                    cross_count[scenario] != 1) exit 1
            } else if (scenario ~ /-finding-dangling--/) {
                if (row_count[scenario] != 6 || complete[scenario] != 1 ||
                    dangling_result[scenario] != 1 ||
                    dangling_view[scenario] != 1 ||
                    dangling_target[scenario] != 1 ||
                    dangling_member[scenario] != 1 ||
                    dangling_count[scenario] != 1) exit 1
            } else if (scenario ~ /-latest-substitution--/) {
                if (row_count[scenario] != 11 || complete[scenario] != 1 ||
                    latest_original[scenario] != 1 ||
                    latest_binding[scenario] != 1 ||
                    latest_definition[scenario] != 1 ||
                    latest_cut[scenario] != 1 || latest_root[scenario] != 1 ||
                    latest_ambient[scenario] != 1 ||
                    latest_semantics[scenario] != 1 ||
                    latest_public[scenario] != 1 ||
                    latest_diff[scenario] != 1 ||
                    latest_replayed[scenario] != 1) exit 1
            } else if (scenario ~ /-missing-as-empty--/) {
                if (row_count[scenario] != 35 || complete[scenario] != 0)
                    exit 1
                for (omitted = 1; omitted <= 5; omitted++) {
                    subcase = "omission-" role[omitted]
                    if (input_count[scenario SUBSEP subcase] != 5 ||
                        missing_disposition[scenario SUBSEP subcase] != 1 ||
                        missing_difference[scenario SUBSEP subcase] != 1)
                        exit 1
                    for (candidate = 1; candidate <= 5; candidate++) {
                        expected = candidate == omitted ?
                            "unavailable" : "available"
                        if (input_value[scenario SUBSEP subcase SUBSEP role[candidate]] != expected)
                            exit 1
                    }
                }
            } else if (scenario ~ /-replay-result--/) {
                if (row_count[scenario] != 10 || complete[scenario] != 1 ||
                    replay_original[scenario] != 1 ||
                    replay_binding[scenario] != 1 ||
                    replay_definition[scenario] != 1 ||
                    replay_cut[scenario] != 1 || replay_root[scenario] != 1 ||
                    replay_semantics[scenario] != 1 ||
                    replay_public[scenario] != 1 || replay_diff[scenario] != 1 ||
                    replay_replayed[scenario] != 1) exit 1
            } else if (scenario ~ /-silent-cross-link--/) {
                if (row_count[scenario] != 9 || complete[scenario] != 1 ||
                    cross_kind[scenario] != 1 || cross_source[scenario] != 1 ||
                    cross_target[scenario] != 1 || cross_member[scenario] != 1 ||
                    cross_count[scenario] != 1 ||
                    before_count[scenario] != 1 || after_count[scenario] != 1 ||
                    before_digest[scenario] != after_digest[scenario] ||
                    repair_zero[scenario] != 1) exit 1
            } else if (scenario ~ /-silent-dangling--/) {
                if (row_count[scenario] != 9 || complete[scenario] != 1 ||
                    dangling_result[scenario] != 1 ||
                    dangling_view[scenario] != 1 ||
                    dangling_target[scenario] != 1 ||
                    dangling_member[scenario] != 1 ||
                    dangling_count[scenario] != 1 ||
                    before_count[scenario] != 1 || after_count[scenario] != 1 ||
                    before_digest[scenario] != after_digest[scenario] ||
                    repair_zero[scenario] != 1) exit 1
            } else {
                exit 1
            }
        }
    }
' "$normalized" || fail BC11_NORMALIZED_CONTRACT_INVALID

cat >"$tmp/expected-mutants" <<'EOF'
harness-bc11-missing-sut-action	-	harness-mutant	missing-action-receipt	BC11_SUT_ACTION_MISSING
harness-bc11-normalized-synthesis-without-raw-coverage	-	observer-mutant	normalized-without-raw-coverage	BC11_COVERAGE_INVALID
harness-bc11-raw-post-seal-tamper	-	evidence-mutant	raw-post-seal-tamper	BC11_RAW_SEAL_INVALID
neg-bc11-explanation-closure	neg-bc11-explanation-closure	sut-mutant	detect-explanation-member-loss	BC11_EXPLANATION_CLOSURE_LOSS_DETECTED
neg-bc11-finding-cross-link	neg-bc11-finding-cross-link	sut-mutant	detect-missing-cross-link-finding	BC11_FINDING_CROSS_LINK_MISSING
neg-bc11-finding-dangling	neg-bc11-finding-dangling	sut-mutant	detect-missing-dangling-finding	BC11_FINDING_DANGLING_MISSING
neg-bc11-latest-substitution	neg-bc11-latest-substitution	counterfactual	detect-latest-replay-substitution	BC11_LATEST_SUBSTITUTION_MISMATCH_DETECTED
neg-bc11-missing-as-empty	neg-bc11-missing-as-empty	counterfactual	detect-replay-missing-as-empty	BC11_MISSING_AS_EMPTY_NOT_DETECTED
neg-bc11-replay-result	neg-bc11-replay-result	sut-mutant	detect-replay-result-drift	BC11_REPLAY_RESULT_MISMATCH_DETECTED
neg-bc11-silent-cross-link	neg-bc11-silent-cross-link	sut-mutant	detect-silent-cross-link-repair	BC11_SILENT_CROSS_LINK_DETECTED
neg-bc11-silent-dangling	neg-bc11-silent-dangling	sut-mutant	detect-silent-dangling-repair	BC11_SILENT_DANGLING_DETECTED
EOF
cmp -s "$tmp/expected-mutants" "$mutants" ||
    fail BC11_MUTANT_REGISTRY_INVALID

cat >"$tmp/expected-oracle" <<'EOF'
BC11_EXPLANATION_CLOSURE	oracle-bc11-explanation-closure	closure	explanation-edge-count	5	neg-bc11-explanation-closure	BC11_EXPLANATION_CLOSURE_LOSS_DETECTED
BC11_FINDING_CROSS_LINK	oracle-bc11-finding-cross-link	exact	finding-count	1	neg-bc11-finding-cross-link	BC11_FINDING_CROSS_LINK_MISSING
BC11_FINDING_DANGLING	oracle-bc11-finding-dangling	exact	finding-count	2	neg-bc11-finding-dangling	BC11_FINDING_DANGLING_MISSING
BC11_LATEST_SUBSTITUTION	oracle-bc11-latest-substitution	exact	replay-result-stable	1	neg-bc11-latest-substitution	BC11_LATEST_SUBSTITUTION_MISMATCH_DETECTED
BC11_MISSING_AS_EMPTY	oracle-bc11-missing-as-empty	exact	unavailable-count	5	neg-bc11-missing-as-empty	BC11_MISSING_AS_EMPTY_NOT_DETECTED
BC11_REPLAY_RESULT	oracle-bc11-replay-result	closure	replay-result-diff	0	neg-bc11-replay-result	BC11_REPLAY_RESULT_MISMATCH_DETECTED
BC11_SILENT_CROSS_LINK	oracle-bc11-silent-cross-link	exact	inventory-unchanged	1	neg-bc11-silent-cross-link	BC11_SILENT_CROSS_LINK_DETECTED
BC11_SILENT_DANGLING	oracle-bc11-silent-dangling	exact	inventory-unchanged	1	neg-bc11-silent-dangling	BC11_SILENT_DANGLING_DETECTED
EOF
cmp -s "$tmp/expected-oracle" "$oracle" ||
    fail BC11_ORACLE_CONTRACT_INVALID

cat >"$tmp/expected-artifacts" <<'EOF'
action-receipts.tsv	12	1	bag	direct-sut-stdout
command-receipts.tsv	12	6	bag	runner-custody
coverage.tsv	6	case-contract	set	runner-contract
exclusions.tsv	6	0	set	present-empty
fault-markers.tsv	6	0	bag	present-empty
normalized-observations.tsv	6	case-contract	set	runner-normalizer
oracle-result.tsv	6	1	set	runner-oracle
pragma.tsv	6	5	bag	adapter-stderr
raw-observations.tsv	6	case-contract	bag	adapter-and-sut
raw-seal.tsv	9	1	set	runner-custody
EOF
cmp -s "$tmp/expected-artifacts" "$runtime_artifacts" ||
    fail BC11_RUNTIME_ARTIFACT_REGISTRY_INVALID

for file in "$cases" "$coverage" "$mutants" "$normalized" "$oracle" "$raw" \
    "$runtime_artifacts" "$scenario_ids" "$steps"
do
    LC_ALL=C sort -c "$file" 2>/dev/null ||
        fail BC11_REQUIREMENT_ORDER_INVALID
done

echo BC11_REQUIREMENTS_VALID
