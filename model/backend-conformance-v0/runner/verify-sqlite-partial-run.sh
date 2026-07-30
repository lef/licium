#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
scenarios="$base_dir/sqlite-partial-scenarios.tsv"
bc02_artifacts="$base_dir/bc02-runtime-artifacts.tsv"
bc01_artifacts="$base_dir/bc01-runtime-artifacts.tsv"
bc03_artifacts="$base_dir/bc03-runtime-artifacts.tsv"
bc04_artifacts="$base_dir/bc04-runtime-artifacts.tsv"
bc05_artifacts="$base_dir/bc05-runtime-artifacts.tsv"
bc06_artifacts="$base_dir/bc06-runtime-artifacts.tsv"
bc07_artifacts="$base_dir/bc07-runtime-artifacts.tsv"
bc08_artifacts="$base_dir/bc08-runtime-artifacts.tsv"
bc09_artifacts="$base_dir/bc09-runtime-artifacts.tsv"
bc10_artifacts="$base_dir/bc10-runtime-artifacts.tsv"
bc11_artifacts="$base_dir/bc11-runtime-artifacts.tsv"
bc12_artifacts="$base_dir/bc12-runtime-artifacts.tsv"
negative_runner="$script_dir/run-bc02-negative-runtime.sh"
bc06_controls="$script_dir/materialize-bc06-run-controls.sh"
bc01_controls="$script_dir/materialize-bc01-run-controls.sh"
bc03_controls="$script_dir/materialize-bc03-run-controls.sh"
bc04_controls="$script_dir/materialize-bc04-run-controls.sh"
bc05_controls="$script_dir/materialize-bc05-run-controls.sh"
bc07_controls="$script_dir/materialize-bc07-run-controls.sh"
bc08_controls="$script_dir/materialize-bc08-run-controls.sh"
bc09_controls="$script_dir/materialize-bc09-run-controls.sh"
bc10_controls="$script_dir/materialize-bc10-run-controls.sh"
bc11_controls="$script_dir/materialize-bc11-run-controls.sh"
bc12_controls="$script_dir/materialize-bc12-run-controls.sh"
assertion_materializer="$script_dir/materialize-sqlite-partial-assertions.sh"
sealed_verifier="$script_dir/verify-sealed-run.sh"
adapter="$base_dir/profiles/sqlite-reference/run.sh"

[ "$#" -eq 5 ] || {
    echo "usage: verify-sqlite-partial-run.sh RUN_DIR RUN_ID SIDE LIFECYCLE_DIR preseal|sealed" >&2
    exit 2
}

run_dir=$1
run_id=$2
side=$3
lifecycle=$4
stage=$5
case "$side:$stage" in
    a:preseal|a:sealed|b:preseal|b:sealed) ;;
    *) exit 2 ;;
esac

fail()
{
    echo "$1" >&2
    exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

find "$run_dir" -type l -print | awk 'NR == 1 { exit 1 }' ||
    fail SQLITE_PARTIAL_RUN_LAYOUT_INVALID

{
    printf '%s\n' assertions.tsv bc01-control-receipts.tsv \
        bc02-negative-receipts.tsv bc03-control-receipts.tsv \
        bc04-control-receipts.tsv bc05-control-receipts.tsv \
        bc06-control-receipts.tsv bc07-control-receipts.tsv \
        bc08-control-receipts.tsv bc09-control-receipts.tsv \
        bc10-control-receipts.tsv \
        bc11-control-receipts.tsv \
        bc12-control-receipts.tsv \
        namespace-inventory.tsv \
        run-metadata.tsv runtime-status.tsv
    [ "$stage" = preseal ] ||
        printf '%s\n' outer-receipt.tsv payload-manifest.tsv report.tsv
    while IFS='	' read -r ordinal suite assertion case_id scenario \
        runner_path verifier_path evidence_policy
    do
        case "$suite" in
            BC01) registry=$bc01_artifacts ;;
            BC02) registry=$bc02_artifacts ;;
            BC03) registry=$bc03_artifacts ;;
            BC04) registry=$bc04_artifacts ;;
            BC05) registry=$bc05_artifacts ;;
            BC06) registry=$bc06_artifacts ;;
            BC07) registry=$bc07_artifacts ;;
            BC08) registry=$bc08_artifacts ;;
            BC09) registry=$bc09_artifacts ;;
            BC10) registry=$bc10_artifacts ;;
            BC11) registry=$bc11_artifacts ;;
            BC12) registry=$bc12_artifacts ;;
            *) exit 1 ;;
        esac
        while IFS='	' read -r artifact fields cardinality kind source
        do
            printf '%s/%s\n' "$scenario" "$artifact"
        done <"$registry"
    done <"$scenarios"
} | LC_ALL=C sort >"$tmp/expected-files"

find "$run_dir" -type f -print |
    while IFS= read -r file
    do
        printf '%s\n' "${file#"$run_dir"/}"
    done | LC_ALL=C sort >"$tmp/actual-files"
cmp -s "$tmp/expected-files" "$tmp/actual-files" ||
    fail SQLITE_PARTIAL_RUN_LAYOUT_INVALID

{
    printf '.\n'
    cut -f5 "$scenarios"
} | LC_ALL=C sort >"$tmp/expected-dirs"
find "$run_dir" -type d -print |
    while IFS= read -r directory
    do
        relative=${directory#"$run_dir"}
        [ -n "$relative" ] || relative=.
        relative=${relative#/}
        printf '%s\n' "$relative"
    done | LC_ALL=C sort >"$tmp/actual-dirs"
cmp -s "$tmp/expected-dirs" "$tmp/actual-dirs" ||
    fail SQLITE_PARTIAL_RUN_LAYOUT_INVALID

{
    "$adapter" describe
    printf 'meta\tglobal\tartifact-kind\tsqlite-partial-run\n'
    printf 'meta\tglobal\trun-id\t%s\n' "$run_id"
    printf 'meta\tglobal\tside\t%s\n' "$side"
    for contract in \
        scenarios.tsv \
        execution-map.tsv \
        sqlite-partial-scenarios.tsv \
        sqlite-partial-bc02-negative-execution.tsv \
        sqlite-partial-canonical.tsv \
        sqlite-partial-run-artifacts.tsv \
        bc02-runtime-artifacts.tsv \
        bc01-runtime-artifacts.tsv \
        bc03-runtime-artifacts.tsv \
        bc03-mutants.tsv \
        bc04-runtime-artifacts.tsv \
        bc04-mutants.tsv \
        bc05-runtime-artifacts.tsv \
        bc05-mutants.tsv \
        bc06-runtime-artifacts.tsv \
        bc07-runtime-artifacts.tsv \
        bc07-mutants.tsv \
        bc08-runtime-artifacts.tsv \
        bc08-mutants.tsv \
        bc09-runtime-artifacts.tsv \
        bc09-mutants.tsv \
        bc10-runtime-artifacts.tsv \
        bc10-mutants.tsv \
        bc11-runtime-artifacts.tsv \
        bc11-mutants.tsv \
        bc12-runtime-artifacts.tsv \
        bc12-mutants.tsv
    do
        contract_name=$(printf '%s' "$contract" | tr 'A-Z_.' 'a-z---')
        printf 'binding\tcontract\t%s\t%s\n' \
            "$contract_name" \
            "$(sha256sum "$base_dir/$contract" | awk '{ print $1 }')"
    done
} >"$tmp/expected-run-metadata.tsv"
cmp -s "$tmp/expected-run-metadata.tsv" "$run_dir/run-metadata.tsv" ||
    fail SQLITE_PARTIAL_RUN_METADATA_CLOSURE_INVALID

awk -F '	' '
    NR == FNR {
        expected[$1] = $2 FS $5
        next
    }
    NF != 4 || !($1 in expected) ||
        ($2 FS $3) != expected[$1] ||
        $4 !~ /^(BC01|BC02|BC03|BC04|BC05|BC06|BC07|BC08|BC09|BC10|BC11|BC12)_RUNTIME_VALID$/ { exit 1 }
    seen[$1]++ { exit 1 }
    { count++ }
    END { if (count != 87) exit 1 }
' "$scenarios" "$run_dir/runtime-status.tsv" ||
    fail SQLITE_PARTIAL_RUNTIME_STATUS_INVALID

"$assertion_materializer" "$tmp/assertions.tsv"
cmp -s "$tmp/assertions.tsv" "$run_dir/assertions.tsv" ||
    fail SQLITE_PARTIAL_ASSERTIONS_INVALID

"$negative_runner" "$tmp/negative" "$run_id" "negative-$side" \
    "$tmp/bc02-negative-receipts.tsv" >/dev/null
cmp -s "$tmp/bc02-negative-receipts.tsv" \
    "$run_dir/bc02-negative-receipts.tsv" ||
    fail SQLITE_PARTIAL_BC02_NEGATIVE_RECEIPTS_INVALID

"$bc06_controls" "$run_dir" "$run_id" "$tmp/bc06-control-receipts.tsv"
cmp -s "$tmp/bc06-control-receipts.tsv" \
    "$run_dir/bc06-control-receipts.tsv" ||
    fail SQLITE_PARTIAL_BC06_CONTROL_RECEIPTS_INVALID
"$bc01_controls" "$run_dir" "$run_id" "$tmp/bc01-control-receipts.tsv"
cmp -s "$tmp/bc01-control-receipts.tsv" \
    "$run_dir/bc01-control-receipts.tsv" ||
    fail SQLITE_PARTIAL_BC01_CONTROL_RECEIPTS_INVALID
"$bc03_controls" "$run_dir" "$run_id" "$tmp/bc03-control-receipts.tsv"
cmp -s "$tmp/bc03-control-receipts.tsv" \
    "$run_dir/bc03-control-receipts.tsv" ||
    fail SQLITE_PARTIAL_BC03_CONTROL_RECEIPTS_INVALID
"$bc04_controls" "$run_dir" "$run_id" "$tmp/bc04-control-receipts.tsv"
cmp -s "$tmp/bc04-control-receipts.tsv" \
    "$run_dir/bc04-control-receipts.tsv" ||
    fail SQLITE_PARTIAL_BC04_CONTROL_RECEIPTS_INVALID
"$bc05_controls" "$run_dir" "$run_id" "$tmp/bc05-control-receipts.tsv"
cmp -s "$tmp/bc05-control-receipts.tsv" \
    "$run_dir/bc05-control-receipts.tsv" ||
    fail SQLITE_PARTIAL_BC05_CONTROL_RECEIPTS_INVALID
"$bc07_controls" "$run_dir" "$run_id" "$tmp/bc07-control-receipts.tsv"
cmp -s "$tmp/bc07-control-receipts.tsv" \
    "$run_dir/bc07-control-receipts.tsv" ||
    fail SQLITE_PARTIAL_BC07_CONTROL_RECEIPTS_INVALID
"$bc08_controls" "$run_dir" "$run_id" "$tmp/bc08-control-receipts.tsv"
cmp -s "$tmp/bc08-control-receipts.tsv" \
    "$run_dir/bc08-control-receipts.tsv" ||
    fail SQLITE_PARTIAL_BC08_CONTROL_RECEIPTS_INVALID
"$bc09_controls" "$run_dir" "$run_id" "$tmp/bc09-control-receipts.tsv"
cmp -s "$tmp/bc09-control-receipts.tsv" \
    "$run_dir/bc09-control-receipts.tsv" ||
    fail SQLITE_PARTIAL_BC09_CONTROL_RECEIPTS_INVALID
"$bc10_controls" "$run_dir" "$run_id" "$tmp/bc10-control-receipts.tsv"
cmp -s "$tmp/bc10-control-receipts.tsv" \
    "$run_dir/bc10-control-receipts.tsv" ||
    fail SQLITE_PARTIAL_BC10_CONTROL_RECEIPTS_INVALID
"$bc11_controls" "$run_dir" "$run_id" "$tmp/bc11-control-receipts.tsv"
cmp -s "$tmp/bc11-control-receipts.tsv" \
    "$run_dir/bc11-control-receipts.tsv" ||
    fail SQLITE_PARTIAL_BC11_CONTROL_RECEIPTS_INVALID
"$bc12_controls" "$run_dir" "$run_id" "$tmp/bc12-control-receipts.tsv"
cmp -s "$tmp/bc12-control-receipts.tsv" \
    "$run_dir/bc12-control-receipts.tsv" ||
    fail SQLITE_PARTIAL_BC12_CONTROL_RECEIPTS_INVALID

while IFS='	' read -r ordinal suite assertion case_id scenario \
    runner_path verifier_path evidence_policy
do
    scenario_dir="$run_dir/$scenario"
    namespace="ns-$side-$scenario"
    case "$suite" in
        BC01)
            "$base_dir/$verifier_path" "$scenario_dir" "$run_id" \
                "$namespace" "$assertion" "$case_id" "$scenario" \
                "$scenario_dir/nonexistent.db" >/dev/null
            ;;
        BC02)
            "$base_dir/$verifier_path" "$scenario_dir" "$run_id" \
                "$namespace" "$assertion" "$case_id" >/dev/null
            ;;
        BC03)
            "$base_dir/$verifier_path" "$scenario_dir" "$run_id" \
                "$namespace" "$assertion" "$case_id" "$scenario" \
                "$scenario_dir/nonexistent.db" >/dev/null
            ;;
        BC04)
            "$base_dir/$verifier_path" "$scenario_dir" "$run_id" \
                "$namespace" "$assertion" "$case_id" "$scenario" \
                "$scenario_dir/nonexistent.db" ordinary >/dev/null
            ;;
        BC05)
            "$base_dir/$verifier_path" "$scenario_dir" "$run_id" \
                "$namespace" "$assertion" "$case_id" "$scenario" \
                "$scenario_dir/nonexistent.db" ordinary >/dev/null
            ;;
        BC06)
            "$base_dir/$verifier_path" "$scenario_dir" "$run_id" \
                "$namespace" "$assertion" "$scenario_dir/$namespace.db" \
                >/dev/null
            ;;
        BC07)
            "$base_dir/$verifier_path" "$scenario_dir" "$run_id" \
                "$namespace" "$assertion" "$case_id" "$scenario" \
                "$scenario_dir/nonexistent.db" ordinary >/dev/null
            ;;
        BC08)
            "$base_dir/$verifier_path" "$scenario_dir" "$run_id" \
                "$namespace" "$assertion" "$case_id" "$scenario" \
                "$scenario_dir/nonexistent.db" ordinary >/dev/null
            ;;
        BC09)
            "$base_dir/$verifier_path" "$scenario_dir" "$run_id" \
                "$namespace" "$assertion" "$scenario" >/dev/null
            ;;
        BC10)
            "$base_dir/$verifier_path" "$scenario_dir" "$run_id" \
                "$namespace" "$assertion" "$scenario" >/dev/null
            ;;
        BC11)
            "$base_dir/$verifier_path" "$scenario_dir" "$run_id" \
                "$namespace" "$assertion" "$scenario" >/dev/null
            ;;
        BC12)
            "$base_dir/$verifier_path" "$scenario_dir" "$run_id" \
                "$namespace" "$assertion" "$scenario" >/dev/null
            ;;
    esac
done <"$scenarios"

"$adapter" lifecycle-sentinel "$lifecycle" observe "$run_id" sentinel-a \
    >"$tmp/namespace-inventory.tsv"
cmp -s "$tmp/namespace-inventory.tsv" "$run_dir/namespace-inventory.tsv" ||
    fail SQLITE_PARTIAL_NAMESPACE_INVENTORY_INVALID

[ "$stage" = preseal ] ||
    LICIUM_PARTIAL_ENVELOPE_ONLY=1 \
        "$sealed_verifier" "$run_dir" >/dev/null

echo SQLITE_PARTIAL_RUN_VALID
