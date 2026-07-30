#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
matrix="$base_dir/scenarios.tsv"
cases="$base_dir/bc06-cases.tsv"
execution_map="$base_dir/execution-map.tsv"
adapter="$base_dir/profiles/sqlite-reference/run.sh"
assertion_materializer="$script_dir/materialize-bc06-assertions.sh"
control_materializer="$script_dir/materialize-bc06-run-controls.sh"
manifest_builder="$script_dir/build-payload-manifest.sh"
report_builder="$script_dir/materialize-report.sh"
outer_builder="$script_dir/build-outer-receipt.sh"
seal_verifier="$script_dir/verify-sealed-run.sh"
layout_verifier="$script_dir/verify-bc06-run-layout.sh"

[ "$#" -eq 2 ] || {
    echo "usage: materialize-bc06-run.sh RUN_DIR RUN_ID" >&2
    exit 2
}

run_dir=$1
run_id=$2
[ -d "$run_dir" ] || exit 2

for relation in \
    raw-observations.tsv \
    normalized-observations.tsv \
    coverage.tsv \
    exclusions.tsv \
    fault-markers.tsv \
    inventory-before.tsv \
    inventory-after.tsv \
    action-receipts.tsv \
    command-receipts.tsv \
    pragma.tsv \
    oracle-result.tsv
do
    : >"$run_dir/$relation"
done

while IFS='	' read -r assertion kind normal_mode control_mode count disposition
do
    name=$(printf '%s' "$assertion" | tr 'A-Z_' 'a-z-')
    scenario_dir="$run_dir/$name"
    for relation in \
        raw-observations.tsv \
        normalized-observations.tsv \
        coverage.tsv \
        exclusions.tsv \
        fault-markers.tsv \
        inventory-before.tsv \
        inventory-after.tsv \
        action-receipts.tsv \
        command-receipts.tsv \
        pragma.tsv \
        oracle-result.tsv
    do
        cat "$scenario_dir/$relation" >>"$run_dir/$relation"
    done
done <"$cases"

"$control_materializer" "$run_dir" "$run_id" "$run_dir/control-receipts.tsv"

"$adapter" describe >"$run_dir/run-metadata.tsv"
printf 'meta\tglobal\tartifact-kind\tbc06-partial-run\n' \
    >>"$run_dir/run-metadata.tsv"
for contract in \
    scenarios.tsv \
    execution-map.tsv \
    bc06-cases.tsv \
    bc06-action-receipt-template.tsv \
    bc06-mutants.tsv \
    bc06-normalized-contract.tsv \
    bc06-inventory-template.tsv \
    bc06-raw-template.tsv \
    bc06-coverage-template.tsv \
    bc06-raw-seal-template.tsv \
    bc06-runtime-artifacts.tsv
do
    sha=$(sha256sum "$base_dir/$contract" | awk '{ print $1 }')
    name=$(printf '%s' "$contract" | tr 'A-Z_.' 'a-z---')
    printf 'binding\tcontract\t%s\t%s\n' "$name" "$sha" \
        >>"$run_dir/run-metadata.tsv"
done

"$assertion_materializer" "$run_dir/assertions.tsv"

"$layout_verifier" "$run_dir" preseal >/dev/null
"$manifest_builder" "$run_dir" "$run_dir/payload-manifest.tsv"
"$report_builder" "$run_dir/assertions.tsv" "$run_dir/report.tsv"
cat "$run_dir/run-metadata.tsv" >>"$run_dir/report.tsv"
manifest_sha=$(sha256sum "$run_dir/payload-manifest.tsv" | awk '{ print $1 }')
printf 'binding\tevidence\tpayload-manifest-sha256\t%s\n' "$manifest_sha" \
    >>"$run_dir/report.tsv"
"$outer_builder" "$run_dir"
"$seal_verifier" "$run_dir"
