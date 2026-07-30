#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
digests="$base_dir/bc01-contract-digests.tsv"

fail()
{
    echo "$1" >&2
    exit 1
}

[ -f "$digests" ] && [ ! -L "$digests" ] ||
    fail BC01_CONTRACT_DIGEST_MANIFEST_MISSING
[ "$(stat -c '%a' "$digests")" = 644 ] ||
    fail BC01_CONTRACT_DIGEST_MANIFEST_MODE_INVALID
[ "$(sha256sum "$digests" | awk '{ print $1 }')" = \
    "817f8fc96de992eb681ec56b675a42d88de7bb3e0f2df69ce4749d1c6ac69cc1" ] ||
    fail BC01_CONTRACT_DIGEST_MANIFEST_INVALID

awk -F '	' '
    NF != 2 || $1 !~ /^bc01-[a-z0-9-]+\.tsv$/ ||
        $2 !~ /^[0-9a-f][0-9a-f]*$/ { exit 1 }
    seen[$1]++ { exit 1 }
    { count++ }
    END { if (count != 14) exit 1 }
' "$digests" || fail BC01_CONTRACT_DIGEST_MANIFEST_SHAPE_INVALID

while IFS='	' read -r path expected
do
    file="$base_dir/$path"
    [ -f "$file" ] && [ ! -L "$file" ] ||
        fail BC01_REQUIRED_CONTRACT_MISSING
    [ "$(stat -c '%a' "$file")" = 644 ] ||
        fail BC01_REQUIRED_CONTRACT_MODE_INVALID
    [ "$(sha256sum "$file" | awk '{ print $1 }')" = "$expected" ] ||
        fail BC01_REQUIRED_CONTRACT_DIGEST_INVALID
done < "$digests"

cases="$base_dir/bc01-cases.tsv"
execution="$base_dir/execution-map.tsv"
operations="$base_dir/operation-registry.tsv"
oracles="$base_dir/oracle-registry.tsv"
negatives="$base_dir/negative-identities.tsv"
receipts="$base_dir/bc01-action-receipt-template.tsv"
before="$base_dir/bc01-inventory-before.tsv"
after="$base_dir/bc01-inventory-after.tsv"
inventory_map="$base_dir/bc01-inventory-map.tsv"
normalized="$base_dir/bc01-normalized-contract.tsv"
raw="$base_dir/bc01-raw-template.tsv"
coverage="$base_dir/bc01-coverage-template.tsv"
mutants="$base_dir/bc01-mutants.tsv"
raw_seal="$base_dir/bc01-raw-seal-template.tsv"
runtime_artifacts="$base_dir/bc01-runtime-artifacts.tsv"
aggregation="$base_dir/bc01-assertion-aggregation.tsv"
gates="$base_dir/bc01-mandatory-gates.tsv"
scenario_ids="$base_dir/bc01-scenario-ids.tsv"

awk -F '	' '
    BEGIN {
        expected["BC01_ASSOCIATION_IDEMPOTENT"] = "case-bc01-retry" SUBSEP "bc01-association-idempotent--case-bc01-retry"
        expected["BC01_DISTINCT_OCCURRENCE"] = "case-bc01-distinct" SUBSEP "bc01-distinct-occurrence--case-bc01-distinct"
        expected["BC01_OCCURRENCE_COLLAPSE"] = "case-bc01-distinct" SUBSEP "bc01-occurrence-collapse--case-bc01-distinct"
        expected["BC01_PAYLOAD_COLLISION"] = "case-bc01-payload-collision" SUBSEP "bc01-payload-collision--case-bc01-payload-collision"
        expected["BC01_RETRY_DUPLICATION"] = "case-bc01-retry" SUBSEP "bc01-retry-duplication--case-bc01-retry"
    }
    NF != 3 || $1 !~ /^BC01_/ ||
        $2 !~ /^case-bc01-(retry|distinct|payload-collision)$/ ||
        $3 !~ /^bc01-[a-z0-9-]+--case-bc01-[a-z0-9-]+$/ { exit 1 }
    {
        if (!($1 in expected) || ($2 SUBSEP $3) != expected[$1]) exit 1
        if (seen_assertion[$1]++ || seen_scenario[$3]++) exit 1
        count++
    }
    END { if (count != 5) exit 1 }
' "$scenario_ids" || fail BC01_SCENARIO_ID_REGISTRY_INVALID

awk -F '	' '
    BEGIN {
        expected["BC01_ASSOCIATION_IDEMPOTENT"] = "positive" SUBSEP "case-bc01-retry" SUBSEP "sut-retry-delivery" SUBSEP "neg-bc01-association-idempotent"
        expected["BC01_DISTINCT_OCCURRENCE"] = "positive" SUBSEP "case-bc01-distinct" SUBSEP "sut-deliver-distinct" SUBSEP "neg-bc01-distinct-occurrence"
        expected["BC01_OCCURRENCE_COLLAPSE"] = "control" SUBSEP "case-bc01-distinct" SUBSEP "sut-deliver-distinct" SUBSEP "neg-bc01-occurrence-collapse"
        expected["BC01_PAYLOAD_COLLISION"] = "control" SUBSEP "case-bc01-payload-collision" SUBSEP "sut-deliver-collision" SUBSEP "neg-bc01-payload-collision"
        expected["BC01_RETRY_DUPLICATION"] = "control" SUBSEP "case-bc01-retry" SUBSEP "sut-retry-delivery" SUBSEP "neg-bc01-retry-duplication"
    }
    NF != 7 || !($1 in expected) || $3 != "case-bc01-" substr($3, 11) ||
        $5 != "ordinary" || $7 != "PASS" { exit 1 }
    ($2 SUBSEP $3 SUBSEP $4 SUBSEP $6) != expected[$1] { exit 1 }
    seen[$1]++ { exit 1 }
    { count++ }
    END {
        if (count != 5) exit 1
        for (id in expected) if (seen[id] != 1) exit 1
    }
' "$cases" || fail BC01_CASE_CONTRACT_INVALID

awk -F '	' '
    NR == FNR {
        if ($1 ~ /^BC01_/) {
            kind[$1] = $4
            action[$1] = $7
            negative[$1] = $18
            if ($2 != "BC01" || $3 != "CC01" || $6 != "sut-setup-bc01" ||
                $8 != "raw-bc01-observation" || $9 != "norm-bc01-observation" ||
                $11 != "coverage-bc01" || $12 != "-" || $13 != "-" ||
                $14 != "PASS" || $15 != "inventory-repository" ||
                $16 != "inventory-repository") exit 1
            count++
        }
        next
    }
    kind[$1] != $2 || action[$1] != $4 || negative[$1] != $6 { exit 1 }
    { matched++ }
    END { if (count != 5 || matched != 5) exit 1 }
' "$execution" "$cases" || fail BC01_EXECUTION_MAP_INVALID

awk -F '	' '
    $1 == "sut-setup-bc01" && $2 == "sut" { setup++ }
    $1 == "sut-retry-delivery" && $2 == "sut" { retry++ }
    $1 == "sut-deliver-distinct" && $2 == "sut" { distinct++ }
    $1 == "sut-deliver-collision" && $2 == "sut" { collision++ }
    END {
        if (setup != 1 || retry != 1 || distinct != 1 || collision != 1) exit 1
    }
' "$operations" || fail BC01_OPERATION_REGISTRY_INVALID

awk -F '	' '
    BEGIN {
        expected["oracle-bc01-association-idempotent"] = "equality" SUBSEP "norm-bc01-observation"
        expected["oracle-bc01-distinct-occurrence"] = "inequality" SUBSEP "norm-bc01-observation"
        expected["oracle-bc01-occurrence-collapse"] = "integrity" SUBSEP "norm-bc01-observation"
        expected["oracle-bc01-payload-collision"] = "empty" SUBSEP "norm-bc01-observation"
        expected["oracle-bc01-retry-duplication"] = "integrity" SUBSEP "norm-bc01-observation"
    }
    $1 ~ /^oracle-bc01-/ {
        if (!($1 in expected) || ($2 SUBSEP $3) != expected[$1]) exit 1
        seen[$1]++
        count++
    }
    END {
        if (count != 5) exit 1
        for (id in expected) if (seen[id] != 1) exit 1
    }
' "$oracles" || fail BC01_ORACLE_REGISTRY_INVALID

awk -F '	' '
    NR == FNR {
        valid[$3] = $2
        next
    }
    NF != 13 || $1 != "{run}" || $2 != "{namespace}" { exit 1 }
    !($3 in valid) || $4 != valid[$3] { exit 1 }
    $5 == "sut-setup-bc01" {
        if ($6 != "accepted" || $7 != "-" || $8 != "delivery-a" ||
            $9 != "occurrence-a" || $10 != "alice" ||
            $11 != "public-a" || $12 != "inserted" ||
            $13 != "{setup-nonce}") exit 1
        setup[$3]++
        next
    }
    $13 != "{action-nonce}" { exit 1 }
    $4 == "case-bc01-retry" &&
        ($4 != "case-bc01-retry" || $5 != "sut-retry-delivery" ||
         $6 != "duplicate" || $7 != "-" || $8 != "delivery-a" ||
         $9 != "occurrence-a" || $10 != "alice" ||
         $11 != "public-a" || $12 != "unchanged") { exit 1 }
    $4 == "case-bc01-distinct" &&
        ($4 != "case-bc01-distinct" || $5 != "sut-deliver-distinct" ||
         $6 != "accepted" || $7 != "-" || $8 != "delivery-b" ||
         $9 != "occurrence-b" || $10 != "alice" ||
         $11 != "public-a" || $12 != "inserted") { exit 1 }
    $4 == "case-bc01-payload-collision" &&
        ($4 != "case-bc01-payload-collision" ||
         $5 != "sut-deliver-collision" || $6 != "collision" ||
         $7 != "payload-mismatch" || $8 != "delivery-a" ||
         $9 != "occurrence-a" || $10 != "alice" ||
         $11 != "public-x" || $12 != "unchanged") { exit 1 }
    action[$3]++
    { count++ }
    END {
        if (count != 5) exit 1
        for (id in setup)
            if (setup[id] != 1 || action[id] != 1) exit 1
    }
' "$scenario_ids" "$receipts" || fail BC01_ACTION_RECEIPT_TEMPLATE_INVALID

awk -F '	' '
    NF != 6 || $1 !~ /^bc01-[a-z0-9-]+--case-bc01-[a-z0-9-]+$/ { exit 1 }
    $2 == "delivery" && $3 == "delivery-a" &&
        $4 == "logical-value" && $5 != "public-a" { exit 1 }
    $2 == "occurrence" && $3 == "occurrence-a" &&
        $4 == "delivery-ref" && $5 != "delivery-a" { exit 1 }
    $2 == "association" && $3 == "alice" &&
        ($4 != "logical-value" || $5 != "public-a") { exit 1 }
    seen[$1 SUBSEP $2 SUBSEP $3 SUBSEP $4]++ { exit 1 }
    { per[$1]++; count++ }
    END {
        if (count != 50) exit 1
        for (id in per) if (per[id] != 10) exit 1
    }
' "$before" || fail BC01_BEFORE_INVENTORY_INVALID

awk -F '	' '
    NF != 6 || $1 !~ /^bc01-[a-z0-9-]+--case-bc01-[a-z0-9-]+$/ { exit 1 }
    $1 ~ /(distinct-occurrence|occurrence-collapse)/ &&
        $2 == "occurrence" &&
        $3 == "occurrence-b" && $4 == "delivery-ref" &&
        $5 != "delivery-b" { exit 1 }
    $1 !~ /(distinct-occurrence|occurrence-collapse)/ &&
        $2 == "delivery" && $3 == "delivery-a" &&
        $4 == "logical-value" && $5 != "public-a" { exit 1 }
    $2 == "association" && $3 == "alice" &&
        ($4 != "logical-value" || $5 != "public-a") { exit 1 }
    seen[$1 SUBSEP $2 SUBSEP $3 SUBSEP $4]++ { exit 1 }
    { per[$1]++; count++ }
    END {
        if (count != 62 ||
            per["bc01-association-idempotent--case-bc01-retry"] != 10 ||
            per["bc01-retry-duplication--case-bc01-retry"] != 10 ||
            per["bc01-payload-collision--case-bc01-payload-collision"] != 10 ||
            per["bc01-distinct-occurrence--case-bc01-distinct"] != 16 ||
            per["bc01-occurrence-collapse--case-bc01-distinct"] != 16) exit 1
    }
' "$after" || fail BC01_AFTER_INVENTORY_INVALID

awk -F '	' '
    NR == FNR {
        scenario[$1] = $3
        case_id[$1] = $2
        next
    }
    NF != 5 || !($1 in scenario) ||
        $2 !~ /^case-bc01-(retry|distinct|payload-collision)$/ ||
        $3 !~ /^(before|after|reopened)$/ ||
        $4 !~ /^bc01-inventory-(before|after)\.tsv$/ { exit 1 }
    {
        if ($2 != case_id[$1] || $5 != scenario[$1]) exit 1
        if ($3 == "before" &&
            $4 != "bc01-inventory-before.tsv") exit 1
        if ($3 != "before" &&
            $4 != "bc01-inventory-after.tsv") exit 1
    }
    seen[$1 SUBSEP $3]++ { exit 1 }
    { per[$1]++; count++ }
    END {
        if (count != 15) exit 1
        for (id in per) if (per[id] != 3) exit 1
    }
' "$scenario_ids" "$inventory_map" || fail BC01_INVENTORY_MAP_INVALID

awk -F '	' '
    NF != 6 || $1 !~ /^bc01-[a-z0-9-]+--case-bc01-[a-z0-9-]+$/ ||
        $2 !~ /^obs-00[1-9]$/ { exit 1 }
    $1 ~ /(association-idempotent|retry-duplication)/ &&
        $2 == "obs-003" &&
        ($3 != "cardinality" || $4 != "accepted-occurrence" ||
         $5 != "exact" || $6 != "1") { exit 1 }
    $1 ~ /(distinct-occurrence|occurrence-collapse)/ &&
        $2 == "obs-003" &&
        ($3 != "cardinality" || $4 != "accepted-occurrence" ||
         $5 != "exact" || $6 != "2") { exit 1 }
    $1 ~ /(distinct-occurrence|occurrence-collapse)/ &&
        $2 == "obs-006" &&
        ($3 != "provenance" || $4 != "occurrence-b" ||
         $5 != "bound" || $6 != "delivery-b") { exit 1 }
    $1 ~ /^bc01-payload-collision/ && $2 == "obs-001" &&
        ($3 != "execution" || $4 != "delivery-a" ||
         $5 != "collision" || $6 != "sut-deliver-collision") { exit 1 }
    $1 ~ /^bc01-payload-collision/ && $2 == "obs-002" &&
        ($3 != "error" || $4 != "delivery-a" ||
         $5 != "payload-mismatch" || $6 != "action") { exit 1 }
    $1 ~ /^bc01-payload-collision/ && $2 == "obs-007" &&
        ($3 != "accepted-collision" || $4 != "delivery-a" ||
         $5 != "empty" || $6 != "0") { exit 1 }
    $1 ~ /^bc01-payload-collision/ && $2 == "obs-009" &&
        ($3 != "payload" || $4 != "delivery-a" ||
         $5 != "preserved" || $6 != "public-a") { exit 1 }
    seen[$1 SUBSEP $2]++ { exit 1 }
    { per[$1]++; count++ }
    END {
        if (count != 37 ||
            per["bc01-association-idempotent--case-bc01-retry"] != 6 ||
            per["bc01-distinct-occurrence--case-bc01-distinct"] != 8 ||
            per["bc01-occurrence-collapse--case-bc01-distinct"] != 8 ||
            per["bc01-payload-collision--case-bc01-payload-collision"] != 9 ||
            per["bc01-retry-duplication--case-bc01-retry"] != 6) exit 1
    }
' "$normalized" || fail BC01_NORMALIZED_CONTRACT_INVALID

awk -F '	' '
    NF != 6 || $1 !~ /^bc01-[a-z0-9-]+--case-bc01-[a-z0-9-]+$/ ||
        $2 !~ /^raw-0(0[1-9]|1[0-6])$/ { exit 1 }
    $1 ~ /^bc01-payload-collision/ && $2 == "raw-003" &&
        ($3 != "action-receipt-error" || $4 != "action" ||
         $5 != "delivery-a" || $6 != "payload-mismatch") { exit 1 }
    $1 ~ /^bc01-payload-collision/ && $2 == "raw-004" &&
        ($3 != "collision-input" || $4 != "action" ||
         $5 != "delivery-a" || $6 != "public-x") { exit 1 }
    $1 ~ /(distinct-occurrence|occurrence-collapse)/ &&
        $2 == "raw-012" &&
        ($3 != "provenance" || $4 != "after" ||
         $5 != "occurrence-b" || $6 != "delivery-b") { exit 1 }
    $1 ~ /(distinct-occurrence|occurrence-collapse)/ &&
        $2 == "raw-013" &&
        ($3 != "occurrence-subject" || $4 != "after" ||
         $5 != "occurrence-a" || $6 != "alice") { exit 1 }
    $1 ~ /(distinct-occurrence|occurrence-collapse)/ &&
        $2 == "raw-014" &&
        ($3 != "occurrence-logical-value" || $4 != "after" ||
         $5 != "occurrence-a" || $6 != "public-a") { exit 1 }
    $1 ~ /(distinct-occurrence|occurrence-collapse)/ &&
        $2 == "raw-015" &&
        ($3 != "occurrence-subject" || $4 != "after" ||
         $5 != "occurrence-b" || $6 != "alice") { exit 1 }
    $1 ~ /(distinct-occurrence|occurrence-collapse)/ &&
        $2 == "raw-016" &&
        ($3 != "occurrence-logical-value" || $4 != "after" ||
         $5 != "occurrence-b" || $6 != "public-a") { exit 1 }
    $1 ~ /^bc01-payload-collision/ && $2 == "raw-012" &&
        ($3 != "delivery-logical-value" || $4 != "after" ||
         $5 != "delivery-a" || $6 != "public-a") { exit 1 }
    $1 ~ /(association-idempotent|retry-duplication)/ &&
        $2 == "raw-002" &&
        ($3 != "action-receipt" || $4 != "action" ||
         $5 != "delivery-a" || $6 != "duplicate") { exit 1 }
    seen[$1 SUBSEP $2]++ { exit 1 }
    { per[$1]++; count++ }
    END {
        if (count != 62 ||
            per["bc01-association-idempotent--case-bc01-retry"] != 9 ||
            per["bc01-retry-duplication--case-bc01-retry"] != 9 ||
            per["bc01-distinct-occurrence--case-bc01-distinct"] != 16 ||
            per["bc01-occurrence-collapse--case-bc01-distinct"] != 16 ||
            per["bc01-payload-collision--case-bc01-payload-collision"] != 12) exit 1
    }
' "$raw" || fail BC01_RAW_TEMPLATE_INVALID

awk -F '	' '
    NF != 6 || $1 != $4 ||
        $1 !~ /^bc01-[a-z0-9-]+--case-bc01-[a-z0-9-]+$/ ||
        $2 !~ /^raw-0(0[1-9]|1[0-6])$/ || $3 != "record" ||
        $5 !~ /^obs-00[1-9]$/ || $6 != "all" { exit 1 }
    $1 ~ /(distinct-occurrence|occurrence-collapse)/ &&
        $2 ~ /^raw-01[3-6]$/ && $5 != "obs-007" { exit 1 }
    $1 ~ /^bc01-payload-collision/ &&
        $2 == "raw-012" && $5 != "obs-009" { exit 1 }
    seen[$1 SUBSEP $2 SUBSEP $5]++ { exit 1 }
    { raw[$1 SUBSEP $2] = 1; obs[$1 SUBSEP $5] = 1; count++ }
    END {
        if (count != 64) exit 1
        scenarios[1] = "bc01-association-idempotent--case-bc01-retry"
        scenarios[2] = "bc01-retry-duplication--case-bc01-retry"
        scenarios[3] = "bc01-distinct-occurrence--case-bc01-distinct"
        scenarios[4] = "bc01-occurrence-collapse--case-bc01-distinct"
        scenarios[5] = "bc01-payload-collision--case-bc01-payload-collision"
        raw_count[1] = 9; raw_count[2] = 9
        raw_count[3] = 16; raw_count[4] = 16; raw_count[5] = 12
        obs_count[1] = 6; obs_count[2] = 6
        obs_count[3] = 8; obs_count[4] = 8; obs_count[5] = 9
        for (s = 1; s <= 5; s++) {
            for (i = 1; i <= raw_count[s]; i++)
                if (!raw[scenarios[s] SUBSEP sprintf("raw-%03d", i)]) exit 1
            for (i = 1; i <= obs_count[s]; i++)
                if (!obs[scenarios[s] SUBSEP sprintf("obs-%03d", i)]) exit 1
        }
    }
' "$coverage" || fail BC01_COVERAGE_TEMPLATE_INVALID

awk -F '	' '
    BEGIN {
        probe["neg-bc01-association-idempotent"] = "logical-association-duplication"
        probe["neg-bc01-distinct-occurrence"] = "distinct-occurrence-collapse"
        probe["neg-bc01-occurrence-collapse"] = "occurrence-collapse"
        probe["neg-bc01-payload-collision"] = "payload-collision-acceptance"
        probe["neg-bc01-retry-duplication"] = "retry-occurrence-duplication"
    }
    NR == FNR {
        if ($2 ~ /^BC01_/) {
            expected[$1] = 1
        }
        next
    }
    NF != 4 || $1 !~ /^(harness|neg)-bc01-[a-z0-9-]+$/ ||
        $4 !~ /^BC01_[A-Z0-9_]+$/ { exit 1 }
    $1 ~ /^neg-/ && !($1 in expected) { exit 1 }
    $1 ~ /^neg-/ && $3 != probe[$1] { exit 1 }
    seen[$1]++ { exit 1 }
    { count++ }
    END {
        if (count != 11) exit 1
        for (id in expected) if (seen[id] != 1) exit 1
    }
' "$negatives" "$mutants" || fail BC01_MUTANT_CONTRACT_INVALID

awk -F '	' '
    NF != 9 || $1 != "raw-observations.tsv" || $2 != "100644" ||
        $3 != "{sha256}" || $4 != "{bytes}" || $5 != "{run}" ||
        $6 != "{namespace}" || $7 != "{scenario}" ||
        $8 != "{action-receipt-sha256}" ||
        $9 != "sealed-before-normalization" { exit 1 }
    { count++ }
    END { if (count != 1) exit 1 }
' "$raw_seal" || fail BC01_RAW_SEAL_TEMPLATE_INVALID

awk -F '	' '
    BEGIN {
        expected["action-receipts.tsv"] = "13" SUBSEP "2" SUBSEP "bag" SUBSEP "direct-sut-stdout"
        expected["command-receipts.tsv"] = "12" SUBSEP "9" SUBSEP "bag" SUBSEP "runner-custody"
        expected["coverage.tsv"] = "6" SUBSEP "case-contract" SUBSEP "set" SUBSEP "runner-contract"
        expected["exclusions.tsv"] = "6" SUBSEP "0" SUBSEP "set" SUBSEP "present-empty"
        expected["fault-markers.tsv"] = "6" SUBSEP "0" SUBSEP "bag" SUBSEP "present-empty"
        expected["inventory-after.tsv"] = "6" SUBSEP "case-contract" SUBSEP "set" SUBSEP "adapter-observer"
        expected["inventory-before.tsv"] = "6" SUBSEP "10" SUBSEP "set" SUBSEP "adapter-observer"
        expected["inventory-reopened.tsv"] = "6" SUBSEP "case-contract" SUBSEP "set" SUBSEP "adapter-observer"
        expected["normalized-observations.tsv"] = "6" SUBSEP "case-contract" SUBSEP "bag" SUBSEP "runner-normalizer"
        expected["oracle-result.tsv"] = "6" SUBSEP "1" SUBSEP "set" SUBSEP "runner-oracle"
        expected["pragma.tsv"] = "6" SUBSEP "8" SUBSEP "bag" SUBSEP "adapter-stderr"
        expected["raw-observations.tsv"] = "6" SUBSEP "case-contract" SUBSEP "bag" SUBSEP "adapter-and-sut"
        expected["raw-seal.tsv"] = "9" SUBSEP "1" SUBSEP "set" SUBSEP "runner-custody"
    }
    NF != 5 || !($1 in expected) || $2 !~ /^[0-9]+$/ ||
        $3 !~ /^([0-9]+|case-contract)$/ ||
        $4 !~ /^(set|bag)$/ || $5 !~ /^[a-z0-9-]+$/ { exit 1 }
    ($2 SUBSEP $3 SUBSEP $4 SUBSEP $5) != expected[$1] { exit 1 }
    seen[$1]++ { exit 1 }
    { count++ }
    END {
        if (count != 13 || seen["action-receipts.tsv"] != 1 ||
            seen["raw-observations.tsv"] != 1 ||
            seen["normalized-observations.tsv"] != 1 ||
            seen["inventory-reopened.tsv"] != 1) exit 1
    }
' "$runtime_artifacts" || fail BC01_RUNTIME_ARTIFACT_REGISTRY_INVALID

awk -F '	' '
    BEGIN {
        expected["BC01_ASSOCIATION_IDEMPOTENT"] = "case-bc01-retry" SUBSEP "normal-oracle" SUBSEP "oracle-bc01-association-idempotent" SUBSEP "neg-bc01-association-idempotent"
        expected["BC01_DISTINCT_OCCURRENCE"] = "case-bc01-distinct" SUBSEP "normal-oracle" SUBSEP "oracle-bc01-distinct-occurrence" SUBSEP "neg-bc01-distinct-occurrence"
        expected["BC01_OCCURRENCE_COLLAPSE"] = "case-bc01-distinct" SUBSEP "normal-control" SUBSEP "oracle-bc01-occurrence-collapse" SUBSEP "neg-bc01-occurrence-collapse"
        expected["BC01_PAYLOAD_COLLISION"] = "case-bc01-payload-collision" SUBSEP "normal-control" SUBSEP "oracle-bc01-payload-collision" SUBSEP "neg-bc01-payload-collision"
        expected["BC01_RETRY_DUPLICATION"] = "case-bc01-retry" SUBSEP "normal-control" SUBSEP "oracle-bc01-retry-duplication" SUBSEP "neg-bc01-retry-duplication"
    }
    NF != 7 || !($1 in expected) ||
        $3 !~ /^normal-(oracle|control)$/ ||
        $4 !~ /^oracle-bc01-/ || $5 != "negative-control" ||
        $6 !~ /^neg-bc01-/ || $7 != "PASS" { exit 1 }
    ($2 SUBSEP $3 SUBSEP $4 SUBSEP $6) != expected[$1] { exit 1 }
    seen[$1]++ { exit 1 }
    { count++ }
    END { if (count != 5) exit 1 }
' "$aggregation" || fail BC01_ASSERTION_AGGREGATION_INVALID

awk -F '	' '
    BEGIN {
        required["action-receipt"] = 1
        required["command-custody"] = 1
        required["coverage"] = 1
        required["inventory-after"] = 1
        required["inventory-before"] = 1
        required["inventory-reopened"] = 1
        required["negative-control"] = 1
        required["normalized"] = 1
        required["oracle"] = 1
        required["raw-seal"] = 1
        negative["BC01_ASSOCIATION_IDEMPOTENT"] = "neg-bc01-association-idempotent"
        negative["BC01_DISTINCT_OCCURRENCE"] = "neg-bc01-distinct-occurrence"
        negative["BC01_OCCURRENCE_COLLAPSE"] = "neg-bc01-occurrence-collapse"
        negative["BC01_PAYLOAD_COLLISION"] = "neg-bc01-payload-collision"
        negative["BC01_RETRY_DUPLICATION"] = "neg-bc01-retry-duplication"
    }
    NF != 4 || $1 !~ /^BC01_/ || !($2 in required) { exit 1 }
    $2 == "action-receipt" &&
        ($3 != "action-receipts.tsv" || $4 != "exact") { exit 1 }
    $2 == "command-custody" &&
        ($3 != "command-receipts.tsv" || $4 != "exact") { exit 1 }
    $2 == "coverage" &&
        ($3 != "coverage.tsv" || $4 != "bidirectional") { exit 1 }
    $2 == "inventory-after" &&
        ($3 != "inventory-after.tsv" || $4 != "exact") { exit 1 }
    $2 == "inventory-before" &&
        ($3 != "inventory-before.tsv" || $4 != "exact") { exit 1 }
    $2 == "inventory-reopened" &&
        ($3 != "inventory-reopened.tsv" || $4 != "exact") { exit 1 }
    $2 == "negative-control" &&
        ($3 != negative[$1] || $4 != "triggered") { exit 1 }
    $2 == "normalized" &&
        ($3 != "normalized-observations.tsv" || $4 != "exact") { exit 1 }
    $2 == "oracle" &&
        ($3 != "oracle-result.tsv" || $4 != "PASS") { exit 1 }
    $2 == "raw-seal" &&
        ($3 != "raw-seal.tsv" || $4 != "valid") { exit 1 }
    seen[$1 SUBSEP $2]++ { exit 1 }
    { per[$1]++; count++ }
    END {
        if (count != 50) exit 1
        for (id in per) if (per[id] != 10) exit 1
    }
' "$gates" || fail BC01_MANDATORY_GATE_SET_INVALID

echo BC01_CONTRACT_VALID
