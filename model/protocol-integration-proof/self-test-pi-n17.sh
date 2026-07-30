#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
verifier="$script_dir/verify-outcome-ephemerality.sh"
provider="$script_dir/providers/sqlite-provider-v1/run.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

"$verifier" >"$tmp/baseline.out" 2>"$tmp/baseline.err"
if [ -s "$tmp/baseline.err" ] ||
    ! grep -F -x -q OUTCOME_EPHEMERALITY_VALID "$tmp/baseline.out"
then
    echo PI_N17_BASELINE_INVALID >&2
    exit 1
fi
echo 'ok BASELINE'

cp -R "$script_dir" "$tmp/proof"
mutant="$tmp/proof/providers/sqlite-provider-v1/run.sh"
awk '
    {
        print
        if ($0 ~ /evaluate-valid[.]sql" >[/]dev[/]null/) {
            print "        \"$sqlite3\" -batch \"$db\" \"INSERT INTO persisted_result VALUES ('\''result-mutant-ordinary-v1'\'');\""
            changed = 1
        }
    }
    END { exit !changed }
' "$provider" >"$mutant.new"
mv "$mutant.new" "$mutant"
chmod +x "$mutant"

"$tmp/proof/run-protocol-neutral.sh" \
    sqlite-provider-v1 ordinary-read-counters \
    >"$tmp/reached.tsv" 2>"$tmp/reached.err"
if [ -s "$tmp/reached.err" ] ||
    ! grep -F -x -q \
        'ordinary-read	persisted_result	delta	1' "$tmp/reached.tsv" ||
    ! grep -F -x -q \
        'ordinary-read	repository_transition	delta	0' "$tmp/reached.tsv" ||
    ! grep -F -x -q \
        'ordinary-read	decision_observation	delta	0' "$tmp/reached.tsv"
then
    echo PI_N17_MUTANT_NOT_REACHED >&2
    exit 1
fi

set +e
"$verifier" "$tmp/proof/run-protocol-neutral.sh" \
    >"$tmp/mutant.out" 2>"$tmp/mutant.err"
inner_status=$?
set -e
[ "$inner_status" -ne 0 ] || {
    echo PI_N17_MUTANT_NOT_REJECTED >&2
    exit 1
}
[ "$(grep -F -x -c OUTCOME_RESULT_COLLAPSE "$tmp/mutant.err")" -eq 1 ] || {
    echo PI_N17_TARGET_MARKER_INVALID >&2
    exit 1
}
[ ! -s "$tmp/mutant.out" ] || {
    echo PI_N17_UNEXPECTED_MUTANT_STDOUT >&2
    exit 1
}

printf '%s\n' \
    "receipt control=PI-N17 class=runtime mutation=ordinary-outcome-persisted-result inner_status=$inner_status marker=OUTCOME_RESULT_COLLAPSE marker_count=1 target_gate=yes reachability=dynamic-result-delta-1 repository_transition_delta=0 decision_observation_delta=0 state_write_isolated=yes" \
    'ok PI-N17' \
    'PI_N17_SELF_TEST_VALID 1 baseline 1 control'
