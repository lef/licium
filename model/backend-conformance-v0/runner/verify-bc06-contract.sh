#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
cases="$base_dir/bc06-cases.tsv"
action_receipt="$base_dir/bc06-action-receipt-template.tsv"
mutants="$base_dir/bc06-mutants.tsv"
normalized="$base_dir/bc06-normalized-contract.tsv"
inventory="$base_dir/bc06-inventory-template.tsv"
raw="$base_dir/bc06-raw-template.tsv"
coverage="$base_dir/bc06-coverage-template.tsv"
raw_seal="$base_dir/bc06-raw-seal-template.tsv"
oracles="$base_dir/oracle-registry.tsv"
negatives="$base_dir/negative-identities.tsv"

fail() {
    echo "$1" >&2
    exit 1
}

require_sha() {
    file=$1
    expected=$2
    marker=$3
    actual=$(sha256sum "$file" | awk '{ print $1 }')
    [ "$actual" = "$expected" ] || fail "$marker"
}

require_sha "$cases" \
    94b611f9e154f502f92f87ca818f86cfd0151f82036c97a86e1aef76839de1f6 \
    BC06_CASE_CONTRACT_DIGEST_INVALID
require_sha "$action_receipt" \
    bf6b63139054dd1dc7a2ed45056d17299918ce77380dc04cd6f2ec202d186560 \
    BC06_ACTION_RECEIPT_TEMPLATE_DIGEST_INVALID
require_sha "$mutants" \
    a3a71b41e8d792600f882a9fdaf1e1aa0142c83521a49ed3aa97be1e47123f58 \
    BC06_MUTANT_CONTRACT_DIGEST_INVALID
require_sha "$normalized" \
    a0811be43b8da9925fec18bd1e37bea179fd191aa61150b0cf1ae075755727d6 \
    BC06_NORMALIZED_CONTRACT_DIGEST_INVALID
require_sha "$inventory" \
    eccbbf3d98d0784771bfbec85d563bc74c4876afd7da0a4bb95339620343fe4d \
    BC06_INVENTORY_TEMPLATE_DIGEST_INVALID
require_sha "$raw" \
    ec32c612f3410daddf4114e4855887a12e4b373b1ebe38cc6c09e71322ff63d5 \
    BC06_RAW_TEMPLATE_DIGEST_INVALID
require_sha "$coverage" \
    3f6536a931243ba3893e8f108ec4a58b2c5fe432c8179a88d309b00f4e8f0d73 \
    BC06_COVERAGE_TEMPLATE_DIGEST_INVALID
require_sha "$raw_seal" \
    b33710bfe21389fdc363f3f90a12ce55ed9a225c11092c367b3acc74dfc2a826 \
    BC06_RAW_SEAL_TEMPLATE_DIGEST_INVALID

awk -F '	' '
    NF != 6 { exit 1 }
    $1 !~ /^BC06_(OBSERVATION_WRITE|PURE_ZERO_AXES|REPOSITORY_UNCHANGED|RESULT_WRITE|STATE_WRITE)$/ { exit 1 }
    $2 != "positive" && $2 != "control" { exit 1 }
    $3 != "ordinary" { exit 1 }
    $4 !~ /^mutant-[a-z0-9-]+$/ { exit 1 }
    $5 != "2" { exit 1 }
    $6 != "PASS" { exit 1 }
    seen[$1]++ { exit 1 }
    { count++ }
    END {
        if (count != 5) exit 1
        if (seen["BC06_OBSERVATION_WRITE"] != 1 ||
            seen["BC06_PURE_ZERO_AXES"] != 1 ||
            seen["BC06_REPOSITORY_UNCHANGED"] != 1 ||
            seen["BC06_RESULT_WRITE"] != 1 ||
            seen["BC06_STATE_WRITE"] != 1) exit 1
    }
' "$cases" || fail "BC06_CASE_CONTRACT_INVALID"

awk -F '	' '
    NF != 11 { exit 1 }
    $1 != "{run}" || $2 != "{namespace}" || $3 != "{scenario}" { exit 1 }
    $4 !~ /^occurrence-[12]$/ || $5 != "sut-evaluate-pure" || $6 != "accepted" { exit 1 }
    $7 != "request-06" || $8 != "alice" || $9 != "pair-06" || $10 != "public-a" { exit 1 }
    $11 !~ /^\{nonce-[12]\}$/ { exit 1 }
    seen[$4]++ { exit 1 }
    { count++ }
    END { if (count != 2) exit 1 }
' "$action_receipt" || fail "BC06_ACTION_RECEIPT_TEMPLATE_INVALID"

awk -F '	' '
    NR == FNR {
        if ($2 ~ /^BC06_/) negative[$1] = 1
        next
    }
    NF != 4 { exit 1 }
    $1 ~ /^neg-/ && !($1 in negative) { exit 1 }
    $1 ~ /^harness-/ &&
        $2 != "harness-mutant" &&
        $2 != "observer-mutant" &&
        $2 != "evidence-mutant" { exit 1 }
    $1 !~ /^(neg|harness)-bc06-[a-z0-9-]+$/ { exit 1 }
    $3 !~ /^[a-z0-9][a-z0-9-]*$/ { exit 1 }
    $4 !~ /^BC06_[A-Z0-9_]+$/ { exit 1 }
    seen[$1]++ { exit 1 }
    { count++ }
    END {
        if (count != 11) exit 1
        for (id in negative) if (seen[id] != 1) exit 1
    }
' "$negatives" "$mutants" || fail "BC06_MUTANT_CONTRACT_INVALID"

awk -F '	' '
    NF != 6 { exit 1 }
    $1 !~ /^BC06_/ { exit 1 }
    $2 !~ /^obs-(00[1-9]|010)$/ { exit 1 }
    {
        if (seen[$1 SUBSEP $2]++) exit 1
        per_assertion[$1]++
        count++
    }
    END {
        if (count != 50) exit 1
        for (id in per_assertion) if (per_assertion[id] != 10) exit 1
    }
' "$normalized" || fail "BC06_NORMALIZED_CONTRACT_INVALID"

awk -F '	' '
    NF != 6 { exit 1 }
    $1 != "{scenario}" { exit 1 }
    seen[$2 SUBSEP $3 SUBSEP $4]++ { exit 1 }
    { count++ }
    END { if (count != 10) exit 1 }
' "$inventory" || fail "BC06_INVENTORY_TEMPLATE_INVALID"

awk -F '	' '
    NF != 6 { exit 1 }
    $1 != "{scenario}" { exit 1 }
    $2 !~ /^raw-(00[1-9]|01[0-4])$/ { exit 1 }
    seen[$2]++ { exit 1 }
    { count++ }
    END { if (count != 14) exit 1 }
' "$raw" || fail "BC06_RAW_TEMPLATE_INVALID"

awk -F '	' '
    NF != 6 { exit 1 }
    $1 != "{scenario}" || $4 != "{scenario}" { exit 1 }
    $2 !~ /^raw-(00[1-9]|01[0-4])$/ || $3 != "record" { exit 1 }
    $5 !~ /^obs-(00[1-9]|010)$/ || $6 != "all" { exit 1 }
    seen[$2 SUBSEP $5]++ { exit 1 }
    {
        raw_seen[$2] = 1
        count++
    }
    END {
        if (count != 17) exit 1
        for (i = 1; i <= 14; i++) {
            id = sprintf("raw-%03d", i)
            if (!raw_seen[id]) exit 1
        }
    }
' "$coverage" || fail "BC06_COVERAGE_TEMPLATE_INVALID"

awk -F '	' '
    NF != 9 { exit 1 }
    $1 != "raw-observations.tsv" || $2 != "100644" { exit 1 }
    $3 != "{sha256}" || $4 != "{bytes}" || $5 != "{run}" { exit 1 }
    $6 != "{namespace}" || $7 != "{scenario}" { exit 1 }
    $8 != "{action-receipt-sha256}" || $9 != "sealed-before-normalization" { exit 1 }
    { count++ }
    END { if (count != 1) exit 1 }
' "$raw_seal" || fail "BC06_RAW_SEAL_TEMPLATE_INVALID"

awk -F '	' '
    $1 == "oracle-bc06-observation-write" &&
        ($2 != "no-write" || $3 != "norm-bc06-observation") { exit 1 }
    $1 == "oracle-bc06-pure-zero-axes" &&
        ($2 != "exact" || $3 != "norm-bc06-observation") { exit 1 }
    $1 == "oracle-bc06-repository-unchanged" &&
        ($2 != "equality" || $3 != "inventory-repository") { exit 1 }
    $1 == "oracle-bc06-result-write" &&
        ($2 != "no-write" || $3 != "norm-bc06-observation") { exit 1 }
    $1 == "oracle-bc06-state-write" &&
        ($2 != "no-write" || $3 != "norm-bc06-observation") { exit 1 }
    $1 ~ /^oracle-bc06-/ { seen[$1]++; count++ }
    END {
        if (count != 5 ||
            seen["oracle-bc06-observation-write"] != 1 ||
            seen["oracle-bc06-pure-zero-axes"] != 1 ||
            seen["oracle-bc06-repository-unchanged"] != 1 ||
            seen["oracle-bc06-result-write"] != 1 ||
            seen["oracle-bc06-state-write"] != 1) exit 1
    }
' "$oracles" || fail "BC06_ORACLE_CONTRACT_INVALID"

echo "BC06_CONTRACT_VALID"
