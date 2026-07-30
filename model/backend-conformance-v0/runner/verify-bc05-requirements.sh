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
        fail BC05_REQUIREMENT_MISSING
    [ "$(stat -c '%a' "$file")" = 644 ] ||
        fail BC05_REQUIREMENT_MODE_INVALID
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

document="$model_dir/BC05-SQLITE-SLICE.md"
cases="$base_dir/bc05-cases.tsv"
coverage="$base_dir/bc05-coverage-template.tsv"
inventory_after="$base_dir/bc05-inventory-after.tsv"
inventory_before="$base_dir/bc05-inventory-before.tsv"
inventory_reopened="$base_dir/bc05-inventory-reopened.tsv"
mutants="$base_dir/bc05-mutants.tsv"
normalized="$base_dir/bc05-normalized-contract.tsv"
raw="$base_dir/bc05-raw-template.tsv"
artifacts="$base_dir/bc05-runtime-artifacts.tsv"
scenario_ids="$base_dir/bc05-scenario-ids.tsv"
steps="$base_dir/bc05-steps.tsv"

for file in \
    "$document" "$cases" "$coverage" "$inventory_after" \
    "$inventory_before" "$inventory_reopened" "$mutants" \
    "$normalized" "$raw" "$artifacts" "$scenario_ids" "$steps"
do
    require_file "$file"
done

require_fields "$cases" 7 BC05_CASE_REGISTRY_INVALID
require_fields "$scenario_ids" 3 BC05_SCENARIO_ID_REGISTRY_INVALID
require_fields "$steps" 5 BC05_STEP_REGISTRY_INVALID
require_fields "$mutants" 4 BC05_MUTANT_REGISTRY_INVALID
require_fields "$artifacts" 5 BC05_RUNTIME_ARTIFACT_REGISTRY_INVALID
require_fields "$raw" 6 BC05_RAW_CONTRACT_INVALID
require_fields "$normalized" 6 BC05_NORMALIZED_CONTRACT_INVALID
require_fields "$coverage" 6 BC05_COVERAGE_CONTRACT_INVALID
require_fields "$inventory_before" 6 BC05_INVENTORY_CONTRACT_INVALID
require_fields "$inventory_after" 6 BC05_INVENTORY_CONTRACT_INVALID
require_fields "$inventory_reopened" 6 BC05_INVENTORY_CONTRACT_INVALID

awk -F '	' '
    FILENAME == ARGV[1] && $1 == "BC05" {
        class[$3] = $4
        next
    }
    FILENAME == ARGV[2] && $2 == "BC05" {
        execution[$1] = $4 FS $6 FS $7 FS $10 FS $11 FS $14 FS $18
        next
    }
    FILENAME == ARGV[3] && $1 ~ /^neg-bc05-/ {
        negative[$1] = $2
        next
    }
    FILENAME == ARGV[4] {
        if (!($1 in class) || class[$1] != $2 ||
            !($1 in execution) ||
            execution[$1] != ($2 FS "sut-setup-bc05" FS $4 FS "oracle-" tolower_hyphen($1) FS "coverage-bc05" FS $7 FS $6) ||
            !($6 in negative) || negative[$6] != $1 ||
            seen_assertion[$1]++ || seen_negative[$6]++) exit 1
        count++
    }
    function tolower_hyphen(value) {
        value = tolower(value)
        gsub(/_/, "-", value)
        return value
    }
    END { if (count != 9) exit 1 }
' "$base_dir/scenarios.tsv" "$base_dir/execution-map.tsv" \
    "$base_dir/negative-identities.tsv" "$cases" ||
    fail BC05_CASE_REGISTRY_INVALID

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
    END {
        if (count != 9) exit 1
        for (key in expected)
            if (expected[key] != "" && !seen[expected[key]]) exit 1
    }
' "$cases" "$scenario_ids" ||
    fail BC05_SCENARIO_ID_REGISTRY_INVALID

cat >"$tmp/expected-steps" <<'EOF'
010	create	profile-create-namespace	normal	command-receipt
020	setup	sut-setup-bc05	ordinary	action-receipt
030	inventory-before	profile-inventory-bc05	ordinary	inventory-before
040	action	case-action	case-mode	action-receipt
050	observe-after	profile-observe-bc05	ordinary	raw-observation
060	inventory-after	profile-inventory-bc05	ordinary	inventory-after
070	reopen	profile-reopen-namespace	normal	command-receipt
080	inventory-reopened	profile-inventory-bc05	ordinary	inventory-reopened
090	destroy	profile-destroy-namespace	normal	command-receipt
100	normalize	runner-normalize-bc05	ordinary	normalized-observation
110	oracle	runner-oracle-bc05	ordinary	oracle-result
EOF
cmp -s "$tmp/expected-steps" "$steps" ||
    fail BC05_STEP_REGISTRY_INVALID

cat >"$tmp/expected-mutants" <<'EOF'
harness-bc05-noop	harness-mutant	missing-action-receipt	BC05_SUT_ACTION_MISSING
harness-bc05-observer-synthesis	observer-mutant	normalized-without-raw	BC05_COVERAGE_INVALID
harness-bc05-raw-post-seal-tamper	evidence-mutant	raw-post-seal-tamper	BC05_RAW_SEAL_INVALID
neg-bc05-ambient-advance	counterfactual	detect-ambient-closure-substitution	BC05_AMBIENT_ADVANCE_DETECTED
neg-bc05-binding-omission	counterfactual	detect-binding-omission	BC05_BINDING_OMISSION_DETECTED
neg-bc05-complete-closure	sut-mutant	detect-incomplete-closure-success	BC05_INCOMPLETE_CLOSURE_ACCEPTED
neg-bc05-definition-omission	counterfactual	detect-definition-omission	BC05_DEFINITION_OMISSION_DETECTED
neg-bc05-missing-as-empty	counterfactual	detect-missing-as-empty	BC05_MISSING_AS_EMPTY_DETECTED
neg-bc05-pinned-knowledge-cut	sut-mutant	detect-knowledge-cut-drift	BC05_KNOWLEDGE_CUT_DRIFT_DETECTED
neg-bc05-root-omission	counterfactual	detect-root-omission	BC05_ROOT_OMISSION_DETECTED
neg-bc05-semantics-omission	counterfactual	detect-semantics-omission	BC05_SEMANTICS_OMISSION_DETECTED
neg-bc05-transitive-omission	counterfactual	detect-transitive-omission	BC05_TRANSITIVE_OMISSION_DETECTED
EOF
cmp -s "$tmp/expected-mutants" "$mutants" ||
    fail BC05_MUTANT_REGISTRY_INVALID

awk -F '	' '
    FILENAME == ARGV[1] && $1 ~ /^neg-bc05-/ {
        expected[$1] = $3 FS $4
        next
    }
    FILENAME == ARGV[2] && $1 ~ /^neg-bc05-/ {
        if (!($1 in expected) || ($2 FS $3) != expected[$1] ||
            seen[$1]++) exit 1
        count++
    }
    END { if (count != 9) exit 1 }
' "$base_dir/negative-identities.tsv" "$mutants" ||
    fail BC05_MUTANT_REGISTRY_INVALID

cat >"$tmp/expected-artifacts" <<'EOF'
action-receipts.tsv	13	2	bag	direct-sut-stdout
command-receipts.tsv	12	9	bag	runner-custody
coverage.tsv	6	case-contract	set	runner-contract
exclusions.tsv	6	0	set	present-empty
fault-markers.tsv	6	0	bag	present-empty
inventory-after.tsv	6	case-contract	set	adapter-observer
inventory-before.tsv	6	case-contract	set	adapter-observer
inventory-reopened.tsv	6	case-contract	set	adapter-observer
normalized-observations.tsv	6	case-contract	set	runner-normalizer
oracle-result.tsv	6	1	set	runner-oracle
pragma.tsv	6	8	bag	adapter-stderr
raw-observations.tsv	6	case-contract	bag	adapter-and-sut
raw-seal.tsv	9	1	set	runner-custody
EOF
cmp -s "$tmp/expected-artifacts" "$artifacts" ||
    fail BC05_RUNTIME_ARTIFACT_REGISTRY_INVALID

awk -F '	' '
    FILENAME == ARGV[1] { scenario[$3] = 1; next }
    !($1 in scenario) || $2 !~ /^raw-[0-9][0-9][0-9]$/ ||
        seen[$1 FS $2]++ { exit 1 }
    { count++; per[$1]++ }
    END {
        if (count != 75) exit 1
        for (item in scenario) {
            expected = item ~ /(complete-closure|pinned-knowledge-cut|transitive-omission)/ ? 9 : 8
            if (per[item] != expected) exit 1
        }
    }
' "$scenario_ids" "$raw" || fail BC05_RAW_CONTRACT_INVALID

awk -F '	' '
    FILENAME == ARGV[1] { scenario[$3] = 1; next }
    !($1 in scenario) || $2 !~ /^obs-[0-9][0-9][0-9]$/ ||
        seen[$1 FS $2]++ { exit 1 }
    { count++; per[$1]++ }
    END {
        if (count != 75) exit 1
        for (item in scenario) {
            expected = item ~ /(complete-closure|pinned-knowledge-cut|transitive-omission)/ ? 9 : 8
            if (per[item] != expected) exit 1
        }
    }
' "$scenario_ids" "$normalized" ||
    fail BC05_NORMALIZED_CONTRACT_INVALID

awk -F '	' '
    FILENAME == ARGV[1] { raw[$1 FS $2] = 1; next }
    FILENAME == ARGV[2] { normalized[$1 FS $2] = 1; next }
    {
        raw_key = $1 FS $2
        normalized_key = $4 FS $5
        if (!(raw_key in raw) || !(normalized_key in normalized) ||
            $3 != "record" || $6 != "all" ||
            seen[raw_key FS normalized_key]++) exit 1
        raw_seen[raw_key] = 1
        normalized_seen[normalized_key] = 1
        count++
    }
    END {
        if (count != 75) exit 1
        for (key in raw) if (!(key in raw_seen)) exit 1
        for (key in normalized)
            if (!(key in normalized_seen)) exit 1
    }
' "$raw" "$normalized" "$coverage" ||
    fail BC05_COVERAGE_CONTRACT_INVALID

awk -F '	' '
    FILENAME == ARGV[1] { scenario[$3] = 1; next }
    {
        if (!($1 in scenario) ||
            $2 !~ /^(ambient-cut|binding-value|closure-request|closure-selection|cut-closure|dependency-edge|logical-object|repository|result-store)$/ ||
            seen[$1 FS $2 FS $3 FS $4 FS $5 FS $6]++) exit 1
        per[$1]++
        count++
    }
    END {
        if (count != 180) exit 1
        for (item in scenario) {
            expected = item ~ /ambient-advance/ ? 25 :
                item ~ /binding-omission/ ? 17 :
                item ~ /complete-closure/ ? 19 :
                item ~ /definition-omission/ ? 18 :
                item ~ /missing-as-empty/ ? 22 :
                item ~ /pinned-knowledge-cut/ ? 25 :
                item ~ /root-omission/ ? 18 :
                item ~ /semantics-omission/ ? 18 :
                item ~ /transitive-omission/ ? 18 : -1
            if (per[item] != expected) exit 1
        }
    }
' "$scenario_ids" "$inventory_before" ||
    fail BC05_INVENTORY_CONTRACT_INVALID
awk -F '	' '$2 != "ambient-cut"' "$inventory_before" \
    >"$tmp/inventory-before-stable"
awk -F '	' '$2 != "ambient-cut"' "$inventory_after" \
    >"$tmp/inventory-after-stable"
cmp -s "$tmp/inventory-before-stable" "$tmp/inventory-after-stable" ||
    fail BC05_INVENTORY_CONTRACT_INVALID
cmp -s "$inventory_after" "$inventory_reopened" ||
    fail BC05_INVENTORY_CONTRACT_INVALID

awk -F '	' '
    $1 ~ /ambient-advance/ && $3 == "ambient-state" &&
        $5 == "cut-after" && $6 == "cut-b" { ambient++ }
    $1 ~ /ambient-advance/ && $3 == "closure-substitution" &&
        $6 == "0" { no_substitution++ }
    $1 ~ /complete-closure/ && $3 == "execution" &&
        $6 == "complete" { complete++ }
    $1 ~ /missing-as-empty/ && $4 == "request-empty" &&
        $6 == "complete-empty" { explicit_empty++ }
    $1 ~ /missing-as-empty/ && $4 == "request-missing" &&
        $6 == "unavailable" { missing++ }
    $1 ~ /pinned-knowledge-cut/ && $3 == "pinned-result" &&
        $6 == "department:engineering" { pinned++ }
    $3 == "missing-input" && $6 ~ /^(binding|definition|root|semantics|transitive-dependency)$/ {
        missing_roles++
    }
    $3 == "persistent-effect" && $6 == "0" { unchanged++ }
    END {
        if (ambient != 1 || no_substitution != 1 || complete != 1 ||
            explicit_empty != 1 || missing != 1 || pinned != 1 ||
            missing_roles != 5 || unchanged != 9) exit 1
    }
' "$normalized" || fail BC05_NORMALIZED_CONTRACT_INVALID

awk -F '	' '
    FILENAME == ARGV[1] && $2 == "ambient-cut" {
        before[$1] = $5
        before_count++
        next
    }
    FILENAME == ARGV[2] && $2 == "ambient-cut" {
        after[$1] = $5
        after_count++
        next
    }
    END {
        if (before_count != 9 || after_count != 9) exit 1
        for (scenario in before) {
            expected = scenario ~ /(ambient-advance|pinned-knowledge-cut)/ ?
                "cut-b" : "cut-a"
            if (before[scenario] != "cut-a" ||
                after[scenario] != expected) exit 1
        }
    }
' "$inventory_before" "$inventory_after" ||
    fail BC05_INVENTORY_CONTRACT_INVALID

if ! grep -F 'complete-empty' "$document" >/dev/null ||
    ! grep -F 'unavailable' "$document" >/dev/null ||
    ! grep -F 'ambient pointer' "$document" >/dev/null ||
    ! grep -F 'BC10' "$document" >/dev/null ||
    ! grep -F '31 + 9 = 40' "$document" >/dev/null ||
    ! grep -F '83 - 36 = 47' "$document" >/dev/null
then
    fail BC05_DOCUMENT_INVALID
fi

echo BC05_REQUIREMENTS_VALID
