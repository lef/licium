#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner="$script_dir/run-bc02-negative-runtime.sh"
verifier="$script_dir/verify-bc02-negative-runtime.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

baseline="$tmp/baseline"
mkdir -p "$baseline"
"$runner" "$baseline/evidence" run-negative ns-negative \
    "$baseline/receipts.tsv" >/dev/null

controls=0

rewrite()
{
    expression=$1
    file=$2
    sed "$expression" "$file" >"$file.new"
    mv "$file.new" "$file"
}

expect_rejected()
{
    name=$1
    expected=$2
    mutation=$3
    dir="$tmp/$name"
    cp -R "$baseline" "$dir"
    "$mutation" "$dir"
    set +e
    output=$(
        "$verifier" "$dir/evidence" "$dir/receipts.tsv" \
            run-negative ns-negative 2>&1
    )
    status=$?
    set -e
    [ "$status" -ne 0 ] || {
        echo "BC02_NEGATIVE_CONTROL_ACCEPTED: $name" >&2
        exit 1
    }
    [ "$output" = "$expected" ] || {
        printf '%s\n' "$output" >&2
        echo "BC02_NEGATIVE_CONTROL_MARKER_INVALID: $name" >&2
        exit 1
    }
    controls=$((controls + 1))
}

mutate_drop_row()
{
    rewrite '$d' "$1/receipts.tsv"
}

mutate_extra_row()
{
    first_row=$(sed -n '1p' "$1/receipts.tsv")
    printf '%s\n' "$first_row" >>"$1/receipts.tsv"
}

mutate_marker()
{
    rewrite '1s/BC02_COMPLETE_ROOT_REQUIRED/BC02_FORGED_MARKER/' \
        "$1/receipts.tsv"
}

mutate_status()
{
    rewrite '1s/	1	/	0	/' "$1/receipts.tsv"
}

mutate_digest()
{
    rewrite '1s/[0-9a-f][0-9a-f]*$/0000/' "$1/receipts.tsv"
}

mutate_runtime_marker()
{
    file="$1/evidence/neg-bc02-complete-available/runtime-result.tsv"
    rewrite 's/BC02_ORACLE_MISMATCH/BC02_FORGED_RUNTIME_RESULT/' "$file"
}

mutate_complete_semantics()
{
    file="$1/evidence/neg-bc02-complete-available/action-receipts.tsv"
    rewrite 's/root-unavailable/complete/' "$file"
}

mutate_partial_semantics()
{
    evidence="$1/evidence/neg-bc02-partial-residue/inventory-rollback-after.tsv"
    rewrite 's#root-02/0001#root-02/9999#' "$evidence"
    digest=$(sha256sum "$evidence" | awk '{ print $1 }')
    awk -F '	' -v OFS='	' -v digest="$digest" '
        $1 == "neg-bc02-partial-residue" { $8 = digest }
        { print }
    ' "$1/receipts.tsv" >"$1/receipts.new"
    mv "$1/receipts.new" "$1/receipts.tsv"
}

mutate_namespace()
{
    file="$1/evidence/neg-bc02-complete-available/action-receipts.tsv"
    rewrite 's/ns-negative-neg-bc02-complete-available/ns-negative-forged/' \
        "$file"
}

expect_rejected row-drop BC02_NEGATIVE_RECEIPT_SHAPE_INVALID mutate_drop_row
expect_rejected row-extra BC02_NEGATIVE_RECEIPT_SHAPE_INVALID mutate_extra_row
expect_rejected marker BC02_NEGATIVE_RECEIPT_SHAPE_INVALID mutate_marker
expect_rejected status BC02_NEGATIVE_RECEIPT_SHAPE_INVALID mutate_status
expect_rejected digest BC02_NEGATIVE_EVIDENCE_DIGEST_INVALID mutate_digest
expect_rejected runtime-marker BC02_NEGATIVE_EXECUTION_RESULT_INVALID \
    mutate_runtime_marker
expect_rejected complete-semantics BC02_NEGATIVE_SEMANTIC_EVIDENCE_INVALID \
    mutate_complete_semantics
expect_rejected partial-semantics BC02_NEGATIVE_SEMANTIC_EVIDENCE_INVALID \
    mutate_partial_semantics
expect_rejected namespace BC02_NEGATIVE_SEMANTIC_EVIDENCE_INVALID \
    mutate_namespace

set +e
fresh_output=$(
    "$runner" "$baseline/evidence" run-negative ns-negative \
        "$baseline/receipts-second.tsv" 2>&1
)
fresh_status=$?
set -e
[ "$fresh_status" -ne 0 ] &&
    [ "$fresh_output" = "BC02_NEGATIVE_WORKDIR_NOT_FRESH" ] || {
    echo BC02_NEGATIVE_FRESHNESS_CONTROL_INVALID >&2
    exit 1
}
controls=$((controls + 1))

printf '%s BC02 negative runtime controls detected\n' "$controls"
