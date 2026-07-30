#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
mutants="$base_dir/sqlite-partial-session-mutants.tsv"
core_verifier="$script_dir/verify-sqlite-partial-session-core.sh"

[ "$#" -eq 2 ] || {
    echo "usage: materialize-sqlite-partial-session-controls.sh SESSION_DIR OUTPUT" >&2
    exit 2
}

session_dir=$1
output=$2
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
: >"$output"

while IFS='	' read -r id class mutation target
do
    case_dir="$tmp/$id"
    cp -R "$session_dir" "$case_dir"
    case "$mutation" in
        copied-run)
            cp -R "$case_dir/run-a/." "$case_dir/run-b/"
            evidence="$case_dir/run-b/outer-receipt.tsv"
            ;;
        bc01-semantic-drift)
            evidence="$case_dir/run-b/bc01-distinct-occurrence--case-bc01-distinct/normalized-observations.tsv"
            sed 's/public-a/public-b/' "$evidence" >"$tmp/mutated.tsv"
            cp "$tmp/mutated.tsv" "$evidence"
            ;;
        bc02-semantic-drift)
            evidence="$case_dir/run-b/bc02-complete-available--case-bc02-complete/normalized-observations.tsv"
            sed 's/available/forged/' "$evidence" >"$tmp/mutated.tsv"
            cp "$tmp/mutated.tsv" "$evidence"
            ;;
        bc03-semantic-drift)
            evidence="$case_dir/run-b/bc03-accepted-head--case-bc03-accepted/normalized-observations.tsv"
            sed 's/root-accepted/root-forged/' "$evidence" \
                >"$tmp/mutated.tsv"
            cp "$tmp/mutated.tsv" "$evidence"
            ;;
        bc04-semantic-drift)
            evidence="$case_dir/run-b/bc04-exact-read--case-bc04-exact/normalized-observations.tsv"
            sed 's/exact-value/forged-value/' "$evidence" \
                >"$tmp/mutated.tsv"
            cp "$tmp/mutated.tsv" "$evidence"
            ;;
        bc05-semantic-drift)
            evidence="$case_dir/run-b/bc05-complete-closure--case-bc05-complete/normalized-observations.tsv"
            sed 's/department:engineering/department:forged/' "$evidence" \
                >"$tmp/mutated.tsv"
            cp "$tmp/mutated.tsv" "$evidence"
            ;;
        bc06-semantic-drift)
            evidence="$case_dir/run-b/bc06-pure-zero-axes/normalized-observations.tsv"
            sed 's/public-a/public-b/' "$evidence" >"$tmp/mutated.tsv"
            cp "$tmp/mutated.tsv" "$evidence"
            ;;
        bc07-semantic-drift)
            evidence="$case_dir/run-b/bc07-effect-101--case-bc07-effect/normalized-observations.tsv"
            sed 's/axis-vector	101/axis-vector	100/' "$evidence" \
                >"$tmp/mutated.tsv"
            cp "$tmp/mutated.tsv" "$evidence"
            ;;
        bc08-semantic-drift)
            evidence="$case_dir/run-b/bc08-complete-effect--case-bc08-complete/normalized-observations.tsv"
            sed 's/digest-result-1/digest-forged/' "$evidence" \
                >"$tmp/mutated.tsv"
            cp "$tmp/mutated.tsv" "$evidence"
            ;;
        bc09-semantic-drift)
            evidence="$case_dir/run-b/bc09-stale-persists--case-bc09-stale/normalized-observations.tsv"
            sed 's/stale/unexpected/' "$evidence" >"$tmp/mutated.tsv"
            cp "$tmp/mutated.tsv" "$evidence"
            ;;
        bc10-semantic-drift)
            evidence="$case_dir/run-b/bc10-result-closed--case-bc10-result-closed/normalized-observations.tsv"
            sed 's/public-a/public-forged/' "$evidence" >"$tmp/mutated.tsv"
            cp "$tmp/mutated.tsv" "$evidence"
            ;;
        bc11-semantic-drift)
            evidence="$case_dir/run-b/bc11-replay-result--case-bc11-replay-result/normalized-observations.tsv"
            sed 's/public-a/public-forged/' "$evidence" >"$tmp/mutated.tsv"
            cp "$tmp/mutated.tsv" "$evidence"
            ;;
        bc12-semantic-drift)
            evidence="$case_dir/run-b/bc12-placement-decision--case-bc12-placement-decision/normalized-observations.tsv"
            sed 's/release-eligible:-/retain:forged/' "$evidence" \
                >"$tmp/mutated.tsv"
            cp "$tmp/mutated.tsv" "$evidence"
            ;;
        cross-namespace-sentinel)
            cp "$case_dir/lifecycle/run-a/sentinel-a" \
                "$case_dir/lifecycle/run-b/sentinel-a"
            evidence="$case_dir/lifecycle/run-b/sentinel-a"
            ;;
        *)
            exit 1
            ;;
    esac
    verification_stage=preseal
    [ ! -f "$case_dir/outer-receipt.tsv" ] ||
        verification_stage=sealed
    set +e
    # These are session-level mutation probes over a session whose ordinary
    # verifier already replays both sealed runs.  Avoid replaying every
    # scenario control inside each copied probe; the probe still validates
    # run-bound receipts, canonical bytes, assertions, and namespace isolation.
    observed=$(
        "$core_verifier" "$case_dir" "$verification_stage" control-probe 2>&1
    )
    status=$?
    set -e
    [ "$status" -ne 0 ] && [ "$observed" = "$target" ] || {
        echo SQLITE_PARTIAL_SESSION_CONTROL_EXECUTION_INVALID >&2
        exit 1
    }
    printf '%s\t%s\t%s\tsession\t%s\t%s\t%s\t%s\n' \
        "$id" "$class" "$mutation" "$target" "$observed" "$status" \
        "$(sha256sum "$evidence" | awk '{ print $1 }')" >>"$output"
done <"$mutants"

awk -F '	' 'NF != 8 || seen[$1]++ { exit 1 } { count++ }
    END { if (count != 14) exit 1 }' "$output" ||
    { echo SQLITE_PARTIAL_SESSION_CONTROL_RECEIPT_INVALID >&2; exit 1; }
