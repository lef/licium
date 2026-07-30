#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

test_mutant() {
    name=$1
    file=$2
    marker=$3
    case_dir="$tmp/$name"
    cp -R "$base_dir" "$case_dir"
    printf '\n' >>"$case_dir/$file"
    output=$("$case_dir/runner/verify-bc06-contract.sh" 2>&1) && {
        echo "BC06 contract mutant unexpectedly passed: $name" >&2
        exit 1
    }
    [ "$output" = "$marker" ] || {
        echo "wrong BC06 contract marker: expected $marker, got $output" >&2
        exit 1
    }
    echo "ok $marker"
}

baseline_output=$("$script_dir/verify-bc06-contract.sh")
[ "$baseline_output" = "BC06_CONTRACT_VALID" ] || {
    echo "wrong BC06 contract baseline output: expected BC06_CONTRACT_VALID, got $baseline_output" >&2
    exit 1
}
test_mutant cases bc06-cases.tsv BC06_CASE_CONTRACT_DIGEST_INVALID
test_mutant action-receipt bc06-action-receipt-template.tsv BC06_ACTION_RECEIPT_TEMPLATE_DIGEST_INVALID
test_mutant mutants bc06-mutants.tsv BC06_MUTANT_CONTRACT_DIGEST_INVALID
test_mutant normalized bc06-normalized-contract.tsv BC06_NORMALIZED_CONTRACT_DIGEST_INVALID
test_mutant inventory bc06-inventory-template.tsv BC06_INVENTORY_TEMPLATE_DIGEST_INVALID
test_mutant raw bc06-raw-template.tsv BC06_RAW_TEMPLATE_DIGEST_INVALID
test_mutant coverage bc06-coverage-template.tsv BC06_COVERAGE_TEMPLATE_DIGEST_INVALID
test_mutant raw-seal bc06-raw-seal-template.tsv BC06_RAW_SEAL_TEMPLATE_DIGEST_INVALID
echo "8 BC06 contract mutations detected"
