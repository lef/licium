#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
verifier="$script_dir/verify-login-read-purity.sh"
provider="$script_dir/providers/sqlite-provider-v1/run.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

"$verifier" >"$tmp/baseline.out" 2>"$tmp/baseline.err"
if [ -s "$tmp/baseline.err" ] ||
    ! grep -F -x -q LOGIN_READ_PURITY_VALID "$tmp/baseline.out"
then
    echo PI_N08_BASELINE_INVALID >&2
    exit 1
fi
echo 'ok BASELINE'

cp -R "$script_dir" "$tmp/proof"
mutant="$tmp/proof/providers/sqlite-provider-v1/run.sh"
awk '
    {
        print
        if ($0 ~ /evaluate-valid[.]sql" >[/]dev[/]null/) {
            print "        \"$sqlite3\" -batch \"$db\" \"INSERT INTO repository_transition VALUES ('\''transition-mutant-login-v1'\'');\""
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
        'ordinary-read	repository_transition	delta	1' "$tmp/reached.tsv"
then
    echo PI_N08_MUTANT_NOT_REACHED >&2
    exit 1
fi

set +e
"$verifier" "$tmp/proof/run-protocol-neutral.sh" \
    >"$tmp/mutant.out" 2>"$tmp/mutant.err"
inner_status=$?
set -e
[ "$inner_status" -ne 0 ] || {
    echo PI_N08_MUTANT_NOT_REJECTED >&2
    exit 1
}
[ "$(grep -F -x -c LOGIN_READ_WRITES_STATE "$tmp/mutant.err")" -eq 1 ] || {
    echo PI_N08_TARGET_MARKER_INVALID >&2
    exit 1
}
[ ! -s "$tmp/mutant.out" ] || {
    echo PI_N08_UNEXPECTED_MUTANT_STDOUT >&2
    exit 1
}

printf '%s\n' \
    "receipt control=PI-N08 class=runtime mutation=ordinary-login-repository-transition inner_status=$inner_status marker=LOGIN_READ_WRITES_STATE marker_count=1 target_gate=yes reachability=dynamic-transition-delta-1 state_write_isolated=yes" \
    'ok PI-N08' \
    'PI_N08_SELF_TEST_VALID 1 baseline 1 control'
