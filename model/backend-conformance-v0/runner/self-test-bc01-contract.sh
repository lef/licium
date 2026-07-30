#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
sealed_manifest=817f8fc96de992eb681ec56b675a42d88de7bb3e0f2df69ce4749d1c6ac69cc1

test_append()
{
    id=$1
    file=$2
    expected=$3
    work="$tmp/digest-$id"
    cp -R "$base_dir" "$work"
    printf '\n' >> "$work/$file"
    output=$("$work/runner/verify-bc01-contract.sh" 2>&1) && {
        echo "BC01 digest mutation unexpectedly passed: $id" >&2
        exit 1
    }
    [ "$output" = "$expected" ] || {
        echo "wrong BC01 digest marker: expected $expected, got $output" >&2
        exit 1
    }
    printf 'ok digest %s\n' "$expected"
}

refresh_seals()
{
    work=$1
    file=$2
    file_sha=$(sha256sum "$work/$file" | awk '{ print $1 }')
    awk -F '	' -v path="$file" -v digest="$file_sha" '
        BEGIN { OFS = "\t" }
        $1 == path { $2 = digest; found++ }
        { print }
        END { if (found != 1) exit 1 }
    ' "$work/bc01-contract-digests.tsv" \
        > "$work/bc01-contract-digests.tsv.tmp"
    mv "$work/bc01-contract-digests.tsv.tmp" \
        "$work/bc01-contract-digests.tsv"
    manifest_sha=$(sha256sum "$work/bc01-contract-digests.tsv" |
        awk '{ print $1 }')
    sed "s/$sealed_manifest/$manifest_sha/" \
        "$work/runner/verify-bc01-contract.sh" \
        > "$work/runner/verify-bc01-contract.sh.tmp"
    mv "$work/runner/verify-bc01-contract.sh.tmp" \
        "$work/runner/verify-bc01-contract.sh"
    chmod 755 "$work/runner/verify-bc01-contract.sh"
}

test_semantic()
{
    id=$1
    file=$2
    expected=$3
    work="$tmp/semantic-$id"
    cp -R "$base_dir" "$work"

    case "$id" in
        action-error-class)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $5 == "sut-deliver-collision" { $7 = "-" }
                { print }
            ' "$work/$file" > "$work/$file.tmp"
            ;;
        aggregation-oracle)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $1 == "BC01_PAYLOAD_COLLISION" {
                    $4 = "oracle-bc01-retry-duplication"
                }
                { print }
            ' "$work/$file" > "$work/$file.tmp"
            ;;
        case-kind)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $1 == "BC01_ASSOCIATION_IDEMPOTENT" { $2 = "control" }
                { print }
            ' "$work/$file" > "$work/$file.tmp"
            ;;
        coverage-error-source)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $1 ~ /^bc01-payload-collision/ &&
                    $2 == "raw-003" { $5 = "obs-001" }
                { print }
            ' "$work/$file" > "$work/$file.tmp"
            ;;
        coverage-multiplicity-state)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $1 ~ /^bc01-distinct-occurrence/ &&
                    $2 == "raw-016" { $5 = "obs-006" }
                { print }
            ' "$work/$file" > "$work/$file.tmp"
            ;;
        inventory-after-provenance)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $1 ~ /^bc01-occurrence-collapse/ &&
                    $2 == "occurrence" && $3 == "occurrence-b" &&
                    $4 == "delivery-ref" { $5 = "delivery-a" }
                { print }
            ' "$work/$file" > "$work/$file.tmp"
            ;;
        inventory-before-association)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $1 ~ /^bc01-association-idempotent/ &&
                    $2 == "association" && $3 == "alice" {
                    $5 = "public-x"
                }
                { print }
            ' "$work/$file" > "$work/$file.tmp"
            ;;
        inventory-map-scenario)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $1 == "BC01_PAYLOAD_COLLISION" &&
                    $3 == "reopened" {
                    $5 = "bc01-association-idempotent--case-bc01-retry"
                }
                { print }
            ' "$work/$file" > "$work/$file.tmp"
            ;;
        mandatory-reopened-source)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $1 == "BC01_PAYLOAD_COLLISION" &&
                    $2 == "inventory-reopened" {
                    $3 = "inventory-before.tsv"
                }
                { print }
            ' "$work/$file" > "$work/$file.tmp"
            ;;
        mutant-probe)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $1 == "neg-bc01-payload-collision" {
                    $3 = "retry-occurrence-duplication"
                }
                { print }
            ' "$work/$file" > "$work/$file.tmp"
            ;;
        normalized-collision-error)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $1 ~ /^bc01-payload-collision/ &&
                    $2 == "obs-002" { $5 = "wrong-error" }
                { print }
            ' "$work/$file" > "$work/$file.tmp"
            ;;
        raw-error-provenance)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $1 ~ /^bc01-payload-collision/ &&
                    $2 == "raw-003" { $6 = "-" }
                { print }
            ' "$work/$file" > "$work/$file.tmp"
            ;;
        raw-preserved-payload)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $1 ~ /^bc01-payload-collision/ &&
                    $2 == "raw-012" { $6 = "public-x" }
                { print }
            ' "$work/$file" > "$work/$file.tmp"
            ;;
        raw-seal-stage)
            awk -F '	' 'BEGIN { OFS = "\t" }
                { $9 = "sealed-after-normalization"; print }
            ' "$work/$file" > "$work/$file.tmp"
            ;;
        runtime-cardinality)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $1 == "inventory-before.tsv" { $3 = "9" }
                { print }
            ' "$work/$file" > "$work/$file.tmp"
            ;;
        scenario-identity)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $1 == "BC01_ASSOCIATION_IDEMPOTENT" {
                    $3 = "bc01-association-idempotent-wrong--case-bc01-retry"
                }
                { print }
            ' "$work/$file" > "$work/$file.tmp"
            ;;
        *)
            echo "unknown BC01 semantic mutation: $id" >&2
            exit 1
            ;;
    esac
    mv "$work/$file.tmp" "$work/$file"
    refresh_seals "$work" "$file"
    output=$("$work/runner/verify-bc01-contract.sh" 2>&1) && {
        echo "BC01 semantic mutation unexpectedly passed: $id" >&2
        exit 1
    }
    [ "$output" = "$expected" ] || {
        echo "wrong BC01 semantic marker: expected $expected, got $output" >&2
        exit 1
    }
    printf 'ok semantic %s\n' "$expected"
}

baseline=$("$script_dir/verify-bc01-contract.sh")
[ "$baseline" = BC01_CONTRACT_VALID ] || {
    echo "wrong BC01 baseline: $baseline" >&2
    exit 1
}

test_append digest-manifest bc01-contract-digests.tsv \
    BC01_CONTRACT_DIGEST_MANIFEST_INVALID
for file in \
    bc01-action-receipt-template.tsv \
    bc01-assertion-aggregation.tsv \
    bc01-cases.tsv \
    bc01-coverage-template.tsv \
    bc01-inventory-after.tsv \
    bc01-inventory-before.tsv \
    bc01-inventory-map.tsv \
    bc01-mandatory-gates.tsv \
    bc01-mutants.tsv \
    bc01-normalized-contract.tsv \
    bc01-raw-seal-template.tsv \
    bc01-raw-template.tsv \
    bc01-runtime-artifacts.tsv \
    bc01-scenario-ids.tsv
do
    test_append "$file" "$file" BC01_REQUIRED_CONTRACT_DIGEST_INVALID
done

test_semantic action-error-class bc01-action-receipt-template.tsv \
    BC01_ACTION_RECEIPT_TEMPLATE_INVALID
test_semantic aggregation-oracle bc01-assertion-aggregation.tsv \
    BC01_ASSERTION_AGGREGATION_INVALID
test_semantic case-kind bc01-cases.tsv BC01_CASE_CONTRACT_INVALID
test_semantic coverage-error-source bc01-coverage-template.tsv \
    BC01_COVERAGE_TEMPLATE_INVALID
test_semantic coverage-multiplicity-state bc01-coverage-template.tsv \
    BC01_COVERAGE_TEMPLATE_INVALID
test_semantic inventory-after-provenance bc01-inventory-after.tsv \
    BC01_AFTER_INVENTORY_INVALID
test_semantic inventory-before-association bc01-inventory-before.tsv \
    BC01_BEFORE_INVENTORY_INVALID
test_semantic inventory-map-scenario bc01-inventory-map.tsv \
    BC01_INVENTORY_MAP_INVALID
test_semantic mandatory-reopened-source bc01-mandatory-gates.tsv \
    BC01_MANDATORY_GATE_SET_INVALID
test_semantic mutant-probe bc01-mutants.tsv BC01_MUTANT_CONTRACT_INVALID
test_semantic normalized-collision-error bc01-normalized-contract.tsv \
    BC01_NORMALIZED_CONTRACT_INVALID
test_semantic raw-seal-stage bc01-raw-seal-template.tsv \
    BC01_RAW_SEAL_TEMPLATE_INVALID
test_semantic raw-error-provenance bc01-raw-template.tsv \
    BC01_RAW_TEMPLATE_INVALID
test_semantic raw-preserved-payload bc01-raw-template.tsv \
    BC01_RAW_TEMPLATE_INVALID
test_semantic runtime-cardinality bc01-runtime-artifacts.tsv \
    BC01_RUNTIME_ARTIFACT_REGISTRY_INVALID
test_semantic scenario-identity bc01-scenario-ids.tsv \
    BC01_SCENARIO_ID_REGISTRY_INVALID

work="$tmp/execution-map"
cp -R "$base_dir" "$work"
awk -F '	' 'BEGIN { OFS = "\t" }
    $1 == "BC01_ASSOCIATION_IDEMPOTENT" { $7 = "sut-deliver-distinct" }
    { print }
' "$work/execution-map.tsv" > "$work/execution-map.tsv.tmp"
mv "$work/execution-map.tsv.tmp" "$work/execution-map.tsv"
output=$("$work/runner/verify-bc01-contract.sh" 2>&1) && {
    echo "BC01 execution-map mutation unexpectedly passed" >&2
    exit 1
}
[ "$output" = BC01_EXECUTION_MAP_INVALID ] || {
    echo "wrong BC01 execution-map marker: $output" >&2
    exit 1
}
echo "ok semantic BC01_EXECUTION_MAP_INVALID"

work="$tmp/oracle-registry"
cp -R "$base_dir" "$work"
awk -F '	' 'BEGIN { OFS = "\t" }
    $1 == "oracle-bc01-payload-collision" { $2 = "exact" }
    { print }
' "$work/oracle-registry.tsv" > "$work/oracle-registry.tsv.tmp"
mv "$work/oracle-registry.tsv.tmp" "$work/oracle-registry.tsv"
output=$("$work/runner/verify-bc01-contract.sh" 2>&1) && {
    echo "BC01 oracle mutation unexpectedly passed" >&2
    exit 1
}
[ "$output" = BC01_ORACLE_REGISTRY_INVALID ] || {
    echo "wrong BC01 oracle marker: $output" >&2
    exit 1
}
echo "ok semantic BC01_ORACLE_REGISTRY_INVALID"

echo "33 BC01 contract mutations detected"
