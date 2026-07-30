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
    marker=$2
    [ -f "$file" ] && [ ! -L "$file" ] ||
        fail "$marker"
    [ "$(stat -c '%a' "$file")" = 644 ] ||
        fail SQLITE_PARTIAL_REQUIREMENT_MODE_INVALID
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

document="$model_dir/SQLITE-PARTIAL-SESSION.md"
scenarios="$base_dir/sqlite-partial-scenarios.tsv"
negative="$base_dir/sqlite-partial-bc02-negative-execution.tsv"
receipt="$base_dir/sqlite-partial-bc02-negative-receipt-template.tsv"
canonical="$base_dir/sqlite-partial-canonical.tsv"
run_layout="$base_dir/sqlite-partial-run-artifacts.tsv"
session_layout="$base_dir/sqlite-partial-session-artifacts.tsv"
mutants="$base_dir/sqlite-partial-session-mutants.tsv"

require_file "$document" SQLITE_PARTIAL_REQUIREMENT_MISSING
for file in "$scenarios" "$negative" "$receipt" "$canonical" \
    "$run_layout" "$session_layout" "$mutants"
do
    require_file "$file" SQLITE_PARTIAL_REQUIREMENT_MISSING
done

require_fields "$scenarios" 8 SQLITE_PARTIAL_SCENARIO_REGISTRY_INVALID
require_fields "$negative" 8 SQLITE_PARTIAL_NEGATIVE_REGISTRY_INVALID
require_fields "$receipt" 8 SQLITE_PARTIAL_NEGATIVE_RECEIPT_TEMPLATE_INVALID
require_fields "$canonical" 6 SQLITE_PARTIAL_CANONICAL_ALLOWLIST_INVALID
require_fields "$run_layout" 7 SQLITE_PARTIAL_RUN_LAYOUT_INVALID
require_fields "$session_layout" 7 SQLITE_PARTIAL_SESSION_LAYOUT_INVALID
require_fields "$mutants" 4 SQLITE_PARTIAL_SESSION_MUTANT_INVALID

awk -F '	' '
    function scenario(assertion, case_id, value) {
        value = tolower(assertion)
        gsub(/_/, "-", value)
        return value "--" case_id
    }
    {
        printf "%02d\tBC02\t%s\t%s\t%s\t%s\t%s\t%s\n",
            NR, $1, $2, scenario($1, $2),
            "runner/run-bc02-runtime.sh",
            "runner/verify-bc02-runtime.sh",
            "oracle-result+mandatory-gates"
    }
' "$base_dir/bc02-cases.tsv" > "$tmp/expected-scenarios"
awk -F '	' '
    {
        value = tolower($1)
        gsub(/_/, "-", value)
        printf "%02d\tBC06\t%s\t-\t%s\t%s\t%s\t%s\n",
            NR + 10, $1, value,
            "runner/run-bc06-runtime.sh",
            "runner/verify-bc06-runtime.sh",
            "oracle-result+negative-receipt"
    }
' "$base_dir/bc06-cases.tsv" >> "$tmp/expected-scenarios"
awk -F '	' '
    {
        value = tolower($1)
        gsub(/_/, "-", value)
        printf "%02d\tBC01\t%s\t%s\t%s--%s\t%s\t%s\t%s\n",
            NR + 15, $1, $3, value, $3,
            "runner/run-bc01-runtime.sh",
            "runner/verify-bc01-runtime.sh",
            "oracle-result+negative-receipt"
    }
' "$base_dir/bc01-cases.tsv" >> "$tmp/expected-scenarios"
awk -F '	' '
    {
        value = tolower($1)
        gsub(/_/, "-", value)
        printf "%02d\tBC03\t%s\t%s\t%s--%s\t%s\t%s\t%s\n",
            NR + 20, $1, $3, value, $3,
            "runner/run-bc03-runtime.sh",
            "runner/verify-bc03-runtime.sh",
            "oracle-result+negative-receipt"
    }
' "$base_dir/bc03-cases.tsv" >> "$tmp/expected-scenarios"
awk -F '	' '
    {
        value = tolower($1)
        gsub(/_/, "-", value)
        printf "%02d\tBC04\t%s\t%s\t%s--%s\t%s\t%s\t%s\n",
            NR + 26, $1, $3, value, $3,
            "runner/run-bc04-runtime.sh",
            "runner/verify-bc04-runtime.sh",
            "oracle-result+negative-receipt"
    }
' "$base_dir/bc04-cases.tsv" >> "$tmp/expected-scenarios"
awk -F '	' '
    {
        value = tolower($1)
        gsub(/_/, "-", value)
        printf "%02d\tBC05\t%s\t%s\t%s--%s\t%s\t%s\t%s\n",
            NR + 31, $1, $3, value, $3,
            "runner/run-bc05-runtime.sh",
            "runner/verify-bc05-runtime.sh",
            "oracle-result+negative-receipt"
    }
' "$base_dir/bc05-cases.tsv" >> "$tmp/expected-scenarios"
awk -F '	' '
    {
        value = tolower($1)
        gsub(/_/, "-", value)
        printf "%02d\tBC07\t%s\t%s\t%s--%s\t%s\t%s\t%s\n",
            NR + 40, $1, $3, value, $3,
            "runner/run-bc07-runtime.sh",
            "runner/verify-bc07-runtime.sh",
            "oracle-result+negative-receipt"
    }
' "$base_dir/bc07-cases.tsv" >> "$tmp/expected-scenarios"
awk -F '	' '
    {
        value = tolower($1)
        gsub(/_/, "-", value)
        printf "%02d\tBC08\t%s\t%s\t%s--%s\t%s\t%s\t%s\n",
            NR + 46, $1, $3, value, $3,
            "runner/run-bc08-runtime.sh",
            "runner/verify-bc08-runtime.sh",
            "oracle-result+negative-receipt"
    }
' "$base_dir/bc08-cases.tsv" >> "$tmp/expected-scenarios"
awk -F '	' '
    {
        printf "%02d\tBC09\t%s\t%s\t%s\t%s\t%s\t%s\n",
            NR + 53, $1, $2, $3,
            "runner/run-bc09-runtime.sh",
            "runner/verify-bc09-runtime.sh",
            "oracle-result+negative-receipt"
    }
' "$base_dir/bc09-scenario-ids.tsv" >> "$tmp/expected-scenarios"
awk -F '	' '
    {
        printf "%02d\tBC10\t%s\t%s\t%s\t%s\t%s\t%s\n",
            NR + 60, $1, $2, $3,
            "runner/run-bc10-runtime.sh",
            "runner/verify-bc10-runtime.sh",
            "oracle-result+negative-receipt"
    }
' "$base_dir/bc10-scenario-ids.tsv" >> "$tmp/expected-scenarios"
awk -F '	' '
    {
        printf "%02d\tBC11\t%s\t%s\t%s\t%s\t%s\t%s\n",
            NR + 68, $1, $2, $3,
            "runner/run-bc11-runtime.sh",
            "runner/verify-bc11-runtime.sh",
            "oracle-result+negative-receipt"
    }
' "$base_dir/bc11-scenario-ids.tsv" >> "$tmp/expected-scenarios"
awk -F '	' '
    {
        printf "%02d\tBC12\t%s\t%s\t%s\t%s\t%s\t%s\n",
            NR + 76, $1, $2, $3,
            "runner/run-bc12-runtime.sh",
            "runner/verify-bc12-runtime.sh",
            "oracle-result+negative-receipt"
    }
' "$base_dir/bc12-scenario-ids.tsv" >> "$tmp/expected-scenarios"
cmp -s "$tmp/expected-scenarios" "$scenarios" ||
    fail SQLITE_PARTIAL_SCENARIO_REGISTRY_INVALID

awk -F '	' '
    NF != 8 || $1 !~ /^[0-9][0-9]$/ ||
        $2 !~ /^BC(01|02|03|04|05|06|07|08|09|10|11|12)$/ || seen_ordinal[$1]++ ||
        seen_scenario[$5]++ { exit 1 }
    { suite[$2]++; count++ }
    END {
        if (count != 87 || suite["BC01"] != 5 ||
            suite["BC02"] != 10 || suite["BC03"] != 6 ||
            suite["BC04"] != 5 || suite["BC05"] != 9 ||
            suite["BC06"] != 5 || suite["BC07"] != 6 ||
            suite["BC08"] != 7 || suite["BC09"] != 7 ||
            suite["BC10"] != 8 || suite["BC11"] != 8 ||
            suite["BC12"] != 11)
            exit 1
    }
' "$scenarios" || fail SQLITE_PARTIAL_SCENARIO_REGISTRY_INVALID

awk -F '	' '
    BEGIN {
        source["neg-bc02-complete-available"] = "bc02-complete-available--case-bc02-complete"
        source["neg-bc02-healthy-retry"] = "bc02-healthy-retry--case-bc02-incomplete-corrected"
        source["neg-bc02-incomplete-as-complete"] = "bc02-incomplete-as-complete--case-bc02-incomplete-missing"
        source["neg-bc02-partial-residue"] = "bc02-partial-residue--case-bc02-after-root-header"
        source["neg-bc02-poisoned-retry"] = "bc02-poisoned-retry--case-bc02-after-root-header"
        source["neg-bc02-rollback-complete"] = "bc02-rollback-complete--case-bc02-after-root-header"
        evidence["neg-bc02-complete-available"] = "oracle-result.tsv"
        evidence["neg-bc02-healthy-retry"] = "oracle-result.tsv"
        evidence["neg-bc02-incomplete-as-complete"] = "oracle-result.tsv"
        evidence["neg-bc02-partial-residue"] = "inventory-rollback-after.tsv"
        evidence["neg-bc02-poisoned-retry"] = "inventory-retry-after.tsv"
        evidence["neg-bc02-rollback-complete"] = "inventory-rollback-after.tsv"
    }
    FILENAME == ARGV[1] && $1 ~ /^neg-bc02-/ {
        identity[$1] = $3 SUBSEP $2
        next
    }
    FILENAME == ARGV[2] && $1 ~ /^neg-bc02-/ {
        mutant[$1] = $2 SUBSEP $3 SUBSEP $4
        next
    }
    FILENAME == ARGV[3] {
        if (!($1 in identity) || !($1 in mutant) || !($1 in source) ||
            ($2 SUBSEP $4) != identity[$1] ||
            ($2 SUBSEP $3 SUBSEP $5) != mutant[$1] ||
            $6 != source[$1] || $7 != "execute-mutant" ||
            $8 != evidence[$1] || seen[$1]++) exit 1
        count++
    }
    END {
        if (count != 6) exit 1
        for (id in identity) if (!(id in seen)) exit 1
    }
' "$base_dir/negative-identities.tsv" "$base_dir/bc02-mutants.tsv" "$negative" ||
    fail SQLITE_PARTIAL_NEGATIVE_REGISTRY_INVALID

awk -F '	' -v registry="$negative" '
    FILENAME == registry {
        expected[$1] = $2 SUBSEP $3 SUBSEP $4 SUBSEP $5
        next
    }
    {
        if (!($1 in expected) ||
            ($2 SUBSEP $3 SUBSEP $4 SUBSEP $5) != expected[$1] ||
            $6 != "{observed-marker}" ||
            $7 != "{nonzero-status}" ||
            $8 != "{evidence-sha256}" || seen[$1]++) exit 1
        count++
    }
    END {
        if (count != 6) exit 1
        for (id in expected) if (!seen[id]) exit 1
    }
' "$negative" "$receipt" ||
    fail SQLITE_PARTIAL_NEGATIVE_RECEIPT_TEMPLATE_INVALID

cat > "$tmp/expected-canonical" <<'EOF'
BC01	scenario	coverage.tsv	exact-file	sort-c	rows
BC01	scenario	inventory-after.tsv	exact-file	sort-c	rows
BC01	scenario	inventory-before.tsv	exact-file	sort-c	rows
BC01	scenario	inventory-reopened.tsv	exact-file	sort-c	rows
BC01	scenario	normalized-observations.tsv	exact-file	sort-c	rows
BC01	scenario	oracle-result.tsv	exact-file	sort-c	rows
BC01	scenario	raw-observations.tsv	exact-file	sort-c	rows
BC02	scenario	normalized-observations.tsv	exact-file	sort-c	rows
BC02	scenario	coverage.tsv	exact-file	sort-c	rows
BC02	scenario	oracle-result.tsv	exact-file	sort-c	rows
BC02	scenario	inventory-map:scenario-applicable	exact-file	sort-c	rows
BC03	scenario	coverage.tsv	exact-file	sort-c	rows
BC03	scenario	inventory-after.tsv	exact-file	sort-c	rows
BC03	scenario	inventory-before.tsv	exact-file	sort-c	rows
BC03	scenario	inventory-reopened.tsv	exact-file	sort-c	rows
BC03	scenario	normalized-observations.tsv	exact-file	sort-c	rows
BC03	scenario	oracle-result.tsv	exact-file	sort-c	rows
BC03	scenario	raw-observations.tsv	exact-file	sort-c	rows
BC04	scenario	coverage.tsv	exact-file	sort-c	rows
BC04	scenario	inventory-after.tsv	exact-file	sort-c	rows
BC04	scenario	inventory-before.tsv	exact-file	sort-c	rows
BC04	scenario	inventory-reopened.tsv	exact-file	sort-c	rows
BC04	scenario	normalized-observations.tsv	exact-file	sort-c	rows
BC04	scenario	oracle-result.tsv	exact-file	sort-c	rows
BC04	scenario	raw-observations.tsv	exact-file	sort-c	rows
BC05	scenario	coverage.tsv	exact-file	sort-c	rows
BC05	scenario	inventory-after.tsv	exact-file	sort-c	rows
BC05	scenario	inventory-before.tsv	exact-file	sort-c	rows
BC05	scenario	inventory-reopened.tsv	exact-file	sort-c	rows
BC05	scenario	normalized-observations.tsv	exact-file	sort-c	rows
BC05	scenario	oracle-result.tsv	exact-file	sort-c	rows
BC05	scenario	raw-observations.tsv	exact-file	sort-c	rows
BC06	scenario	coverage.tsv	exact-file	sort-c	rows
BC06	scenario	inventory-after.tsv	exact-file	sort-c	rows
BC06	scenario	inventory-before.tsv	exact-file	sort-c	rows
BC06	scenario	normalized-observations.tsv	exact-file	sort-c	rows
BC06	scenario	oracle-result.tsv	exact-file	sort-c	rows
BC06	scenario	raw-observations.tsv	exact-file	sort-c	rows
BC07	scenario	coverage.tsv	exact-file	sort-c	rows
BC07	scenario	inventory-after.tsv	exact-file	sort-c	rows
BC07	scenario	inventory-before.tsv	exact-file	sort-c	rows
BC07	scenario	inventory-reopened.tsv	exact-file	sort-c	rows
BC07	scenario	normalized-observations.tsv	exact-file	sort-c	rows
BC07	scenario	oracle-result.tsv	exact-file	sort-c	rows
BC07	scenario	raw-observations.tsv	exact-file	sort-c	rows
BC08	scenario	coverage.tsv	exact-file	sort-c	rows
BC08	scenario	fault-activation-receipts.tsv	canonical-fields	sort-c	rows
BC08	scenario	fault-configuration-receipts.tsv	canonical-fields	sort-c	rows
BC08	scenario	fault-inventory-healthy.tsv	exact-file	sort-c	rows
BC08	scenario	fault-inventory-reopened.tsv	exact-file	sort-c	rows
BC08	scenario	fault-inventory-rollback.tsv	exact-file	sort-c	rows
BC08	scenario	fault-inventory-setup.tsv	exact-file	sort-c	rows
BC08	scenario	fault-markers.tsv	canonical-fields	sort-c	rows
BC08	scenario	fault-trigger-receipts.tsv	canonical-fields	sort-c	rows
BC08	scenario	inventory-after.tsv	exact-file	sort-c	rows
BC08	scenario	inventory-before.tsv	exact-file	sort-c	rows
BC08	scenario	inventory-reopened.tsv	exact-file	sort-c	rows
BC08	scenario	normalized-observations.tsv	exact-file	sort-c	rows
BC08	scenario	oracle-result.tsv	exact-file	sort-c	rows
BC08	scenario	raw-observations.tsv	exact-file	sort-c	rows
BC09	scenario	coverage.tsv	exact-file	sort-c	rows
BC09	scenario	fault-activation-receipts.tsv	canonical-fields	sort-c	rows
BC09	scenario	fault-configuration-receipts.tsv	canonical-fields	sort-c	rows
BC09	scenario	fault-inventory-healthy.tsv	exact-file	sort-c	rows
BC09	scenario	fault-inventory-reopened.tsv	exact-file	sort-c	rows
BC09	scenario	fault-inventory-rollback.tsv	exact-file	sort-c	rows
BC09	scenario	fault-inventory-setup.tsv	exact-file	sort-c	rows
BC09	scenario	fault-markers.tsv	canonical-fields	sort-c	rows
BC09	scenario	fault-trigger-receipts.tsv	canonical-fields	sort-c	rows
BC09	scenario	inventory-after.tsv	exact-file	sort-c	rows
BC09	scenario	inventory-before.tsv	exact-file	sort-c	rows
BC09	scenario	inventory-reopened.tsv	exact-file	sort-c	rows
BC09	scenario	normalized-observations.tsv	exact-file	sort-c	rows
BC09	scenario	oracle-result.tsv	exact-file	sort-c	rows
BC09	scenario	raw-observations.tsv	exact-file	sort-c	rows
BC10	scenario	coverage.tsv	exact-file	sort-c	rows
BC10	scenario	normalized-observations.tsv	exact-file	sort-c	rows
BC10	scenario	oracle-result.tsv	exact-file	sort-c	rows
BC10	scenario	raw-observations.tsv	exact-file	sort-c	rows
BC11	scenario	coverage.tsv	exact-file	sort-c	rows
BC11	scenario	normalized-observations.tsv	exact-file	sort-c	rows
BC11	scenario	oracle-result.tsv	exact-file	sort-c	rows
BC11	scenario	raw-observations.tsv	exact-file	sort-c	rows
BC12	scenario	coverage.tsv	exact-file	sort-c	rows
BC12	scenario	normalized-observations.tsv	exact-file	sort-c	rows
BC12	scenario	oracle-result.tsv	exact-file	sort-c	rows
BC12	scenario	raw-observations.tsv	exact-file	sort-c	rows
EOF
cmp -s "$tmp/expected-canonical" "$canonical" ||
    fail SQLITE_PARTIAL_CANONICAL_ALLOWLIST_INVALID
awk -F '	' '
    $1 == "BC02" && $3 ~ /^(raw-observations|raw-seal|action-receipts|command-receipts|fault-.*receipts)\.tsv$/ {
        exit 1
    }
    seen[$1 SUBSEP $2 SUBSEP $3]++ { exit 1 }
' "$canonical" || fail SQLITE_PARTIAL_CANONICAL_ALLOWLIST_INVALID

cat > "$tmp/expected-run-layout" <<'EOF'
preseal	file	root	assertions.tsv	rows=83	derived-assertions	runner
preseal	file	root	bc01-control-receipts.tsv	rows=8	bc01-mutants.tsv	runner
preseal	file	root	bc02-negative-receipts.tsv	rows=6	sqlite-partial-bc02-negative-execution.tsv	runner
preseal	file	root	bc03-control-receipts.tsv	rows=9	bc03-mutants.tsv	runner
preseal	file	root	bc04-control-receipts.tsv	rows=8	bc04-mutants.tsv	runner
preseal	file	root	bc05-control-receipts.tsv	rows=12	bc05-mutants.tsv	runner
preseal	file	root	bc06-control-receipts.tsv	rows=8	bc06-mutants.tsv	runner
preseal	file	root	bc07-control-receipts.tsv	rows=9	bc07-mutants.tsv	runner
preseal	file	root	bc08-control-receipts.tsv	rows=16	bc08-mutants.tsv	runner
preseal	file	root	bc09-control-receipts.tsv	rows=18	bc09-mutants.tsv	runner
preseal	file	root	bc10-control-receipts.tsv	rows=12	bc10-mutants.tsv	runner
preseal	file	root	bc11-control-receipts.tsv	rows=11	bc11-mutants.tsv	runner
preseal	file	root	bc12-control-receipts.tsv	rows=14	bc12-mutants.tsv	runner
preseal	file	root	namespace-inventory.tsv	rows=1	lifecycle-observation	adapter
preseal	file	root	run-metadata.tsv	rows=variable	contract-and-closure-bindings	runner
preseal	file	root	runtime-status.tsv	rows=87	sqlite-partial-scenarios.tsv	runner
preseal	registry	scenario-bc01	{scenario_id}/{bc01-runtime-artifacts}	registry-driven	bc01-runtime-artifacts.tsv	runner
preseal	registry	scenario-bc02	{scenario_id}/{bc02-runtime-artifacts}	registry-driven	bc02-runtime-artifacts.tsv	runner
preseal	registry	scenario-bc03	{scenario_id}/{bc03-runtime-artifacts}	registry-driven	bc03-runtime-artifacts.tsv	runner
preseal	registry	scenario-bc04	{scenario_id}/{bc04-runtime-artifacts}	registry-driven	bc04-runtime-artifacts.tsv	runner
preseal	registry	scenario-bc05	{scenario_id}/{bc05-runtime-artifacts}	registry-driven	bc05-runtime-artifacts.tsv	runner
preseal	registry	scenario-bc06	{scenario_id}/{bc06-runtime-artifacts}	registry-driven	bc06-runtime-artifacts.tsv	runner
preseal	registry	scenario-bc07	{scenario_id}/{bc07-runtime-artifacts}	registry-driven	bc07-runtime-artifacts.tsv	runner
preseal	registry	scenario-bc08	{scenario_id}/{bc08-runtime-artifacts}	registry-driven	bc08-runtime-artifacts.tsv	runner
preseal	registry	scenario-bc09	{scenario_id}/{bc09-runtime-artifacts}	registry-driven	bc09-runtime-artifacts.tsv	runner
preseal	registry	scenario-bc10	{scenario_id}/{bc10-runtime-artifacts}	registry-driven	bc10-runtime-artifacts.tsv	runner
preseal	registry	scenario-bc11	{scenario_id}/{bc11-runtime-artifacts}	registry-driven	bc11-runtime-artifacts.tsv	runner
preseal	registry	scenario-bc12	{scenario_id}/{bc12-runtime-artifacts}	registry-driven	bc12-runtime-artifacts.tsv	runner
sealed	file	root	outer-receipt.tsv	rows=2	payload-manifest-sha256	runner
sealed	file	root	payload-manifest.tsv	rows=variable	exact-preseal-payload	runner
sealed	file	root	report.tsv	rows=variable	assertions-plus-bindings	runner
EOF
cmp -s "$tmp/expected-run-layout" "$run_layout" ||
    fail SQLITE_PARTIAL_RUN_LAYOUT_INVALID

cat > "$tmp/expected-session-layout" <<'EOF'
preseal	file	root	aggregate-dispositions.tsv	rows=166	run-a-plus-run-b	runner
preseal	file	root	assertions.tsv	rows=83	run-a-exact	runner
preseal	file	root	canonical-comparison.tsv	rows=registry-driven	sqlite-partial-canonical.tsv	runner
preseal	file	root	control-receipts.tsv	rows=14	sqlite-partial-session-mutants.tsv	runner
preseal	file	root	lifecycle-command-receipt.tsv	rows=1	lifecycle-sentinel	adapter
preseal	file	root	run-metadata.tsv	rows=variable	run-outer-and-contract-bindings	runner
preseal	file	lifecycle	lifecycle/run-a/sentinel-a	rows=1	namespace-isolation	adapter
preseal	directory	run	run-a	sealed-run	sqlite-partial-run-artifacts.tsv	runner
preseal	directory	run	run-b	sealed-run	sqlite-partial-run-artifacts.tsv	runner
preseal	directory	lifecycle	lifecycle/run-a	exact-directory	namespace-isolation	adapter
preseal	directory	lifecycle	lifecycle/run-b	exact-directory	namespace-isolation	adapter
sealed	file	root	outer-receipt.tsv	rows=2	payload-manifest-sha256	runner
sealed	file	root	payload-manifest.tsv	rows=variable	exact-preseal-payload	runner
sealed	file	root	report.tsv	rows=variable	assertions-plus-bindings	runner
EOF
cmp -s "$tmp/expected-session-layout" "$session_layout" ||
    fail SQLITE_PARTIAL_SESSION_LAYOUT_INVALID

cat > "$tmp/expected-mutants" <<'EOF'
harness-sqlite-partial-copied-run	evidence-mutant	copied-run	SQLITE_PARTIAL_COPIED_RUN_DETECTED
harness-sqlite-partial-bc01-drift	evidence-mutant	bc01-semantic-drift	SQLITE_PARTIAL_BC01_DRIFT_DETECTED
harness-sqlite-partial-bc02-drift	evidence-mutant	bc02-semantic-drift	SQLITE_PARTIAL_BC02_DRIFT_DETECTED
harness-sqlite-partial-bc03-drift	evidence-mutant	bc03-semantic-drift	SQLITE_PARTIAL_BC03_DRIFT_DETECTED
harness-sqlite-partial-bc04-drift	evidence-mutant	bc04-semantic-drift	SQLITE_PARTIAL_BC04_DRIFT_DETECTED
harness-sqlite-partial-bc05-drift	evidence-mutant	bc05-semantic-drift	SQLITE_PARTIAL_BC05_DRIFT_DETECTED
harness-sqlite-partial-bc06-drift	evidence-mutant	bc06-semantic-drift	SQLITE_PARTIAL_BC06_DRIFT_DETECTED
harness-sqlite-partial-bc07-drift	evidence-mutant	bc07-semantic-drift	SQLITE_PARTIAL_BC07_DRIFT_DETECTED
harness-sqlite-partial-bc08-drift	evidence-mutant	bc08-semantic-drift	SQLITE_PARTIAL_BC08_DRIFT_DETECTED
harness-sqlite-partial-bc09-drift	evidence-mutant	bc09-semantic-drift	SQLITE_PARTIAL_BC09_DRIFT_DETECTED
harness-sqlite-partial-bc10-drift	evidence-mutant	bc10-semantic-drift	SQLITE_PARTIAL_BC10_DRIFT_DETECTED
harness-sqlite-partial-bc11-drift	evidence-mutant	bc11-semantic-drift	SQLITE_PARTIAL_BC11_DRIFT_DETECTED
harness-sqlite-partial-bc12-drift	evidence-mutant	bc12-semantic-drift	SQLITE_PARTIAL_BC12_DRIFT_DETECTED
harness-sqlite-partial-sentinel-leak	evidence-mutant	cross-namespace-sentinel	SQLITE_PARTIAL_SENTINEL_LEAK_DETECTED
EOF
cmp -s "$tmp/expected-mutants" "$mutants" ||
    fail SQLITE_PARTIAL_SESSION_MUTANT_INVALID

if ! grep -F '83 assertions' "$document" >/dev/null ||
    ! grep -F '11 `PASS`' "$document" >/dev/null ||
    ! grep -F '72 `UNTESTED`' "$document" >/dev/null ||
    ! grep -F 'Correction: BC01 Integration' "$document" >/dev/null ||
    ! grep -F '20 scenarios' "$document" >/dev/null ||
    ! grep -F '16 `PASS`' "$document" >/dev/null ||
    ! grep -F '67 `UNTESTED`' "$document" >/dev/null ||
    ! grep -F 'BC01 semantic drift' "$document" >/dev/null ||
    ! grep -F 'Correction: BC03 Integration' "$document" >/dev/null ||
    ! grep -F '26 scenarios' "$document" >/dev/null ||
    ! grep -F '22 `PASS`' "$document" >/dev/null ||
    ! grep -F '61 `UNTESTED`' "$document" >/dev/null ||
    ! grep -F 'BC03 semantic drift' "$document" >/dev/null ||
    ! grep -F 'Correction: BC04 Integration' "$document" >/dev/null ||
    ! grep -F '31 scenarios' "$document" >/dev/null ||
    ! grep -F '27 `PASS`' "$document" >/dev/null ||
    ! grep -F '56 `UNTESTED`' "$document" >/dev/null ||
    ! grep -F 'BC04 semantic drift' "$document" >/dev/null ||
    ! grep -F 'Correction: BC05 Integration' "$document" >/dev/null ||
    ! grep -F '40 scenarios' "$document" >/dev/null ||
    ! grep -F '36 `PASS`' "$document" >/dev/null ||
    ! grep -F '47 `UNTESTED`' "$document" >/dev/null ||
    ! grep -F 'BC05 semantic drift' "$document" >/dev/null ||
    ! grep -F 'Correction: BC07 Integration' "$document" >/dev/null ||
    ! grep -F '46 scenarios' "$document" >/dev/null ||
    ! grep -F '42 `PASS`' "$document" >/dev/null ||
    ! grep -F '41 `UNTESTED`' "$document" >/dev/null ||
    ! grep -F 'BC07 semantic drift' "$document" >/dev/null ||
    ! grep -F 'Correction: BC08 Integration Requirements' "$document" >/dev/null ||
    ! grep -F '53 scenarios' "$document" >/dev/null ||
    ! grep -F '49 `PASS`' "$document" >/dev/null ||
    ! grep -F '34 `UNTESTED`' "$document" >/dev/null ||
    ! grep -F 'BC08 semantic drift' "$document" >/dev/null ||
    ! grep -F 'Correction: BC09 Integration Requirements' "$document" >/dev/null ||
    ! grep -F '60 scenarios' "$document" >/dev/null ||
    ! grep -F '56 `PASS`' "$document" >/dev/null ||
    ! grep -F '27 `UNTESTED`' "$document" >/dev/null ||
    ! grep -F 'BC09 semantic drift' "$document" >/dev/null ||
    ! grep -F 'Correction: BC10 Integration Requirements' "$document" >/dev/null ||
    ! grep -F '68 scenarios' "$document" >/dev/null ||
    ! grep -F '64 `PASS`' "$document" >/dev/null ||
    ! grep -F '19 `UNTESTED`' "$document" >/dev/null ||
    ! grep -F 'BC10 semantic drift' "$document" >/dev/null ||
    ! grep -F 'Correction: BC11 Integration Requirements' "$document" >/dev/null ||
    ! grep -F '76 scenarios' "$document" >/dev/null ||
    ! grep -F '72 `PASS`' "$document" >/dev/null ||
    ! grep -F '11 `UNTESTED`' "$document" >/dev/null ||
    ! grep -F 'BC11 semantic drift' "$document" >/dev/null ||
    ! grep -F 'Correction: BC12 Integration Requirements' "$document" >/dev/null ||
    ! grep -F '87 scenarios' "$document" >/dev/null ||
    ! grep -F '83 `PASS`' "$document" >/dev/null ||
    ! grep -F '0 `UNTESTED`' "$document" >/dev/null ||
    ! grep -F 'BC12 semantic drift' "$document" >/dev/null ||
    ! grep -F 'FULL_GATE_VALIDATOR_UNIMPLEMENTED' "$document" >/dev/null ||
    ! grep -F 'Correction: Full Session Gate Implementation' "$document" >/dev/null ||
    ! grep -F 'FULL_GATE_SESSION_INVALID' "$document" >/dev/null ||
    ! grep -F 'SQLITE_FULL_CONFORMANCE_VALID' "$document" >/dev/null ||
    ! grep -F 'Correction: Outer Receipt Cardinality' "$document" >/dev/null ||
    ! grep -F '`rows=2`' "$document" >/dev/null ||
    ! grep -F '166 rows' "$document" >/dev/null ||
    ! grep -F 'FULL_GATE_NONPASS' "$document" >/dev/null ||
    ! grep -F 'runtime/profile promotion is outside this requirements package' \
        "$document" >/dev/null
then
    fail SQLITE_PARTIAL_DOCUMENT_INVALID
fi

echo SQLITE_PARTIAL_REQUIREMENTS_VALID
