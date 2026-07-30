#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
verifier="$script_dir/verify-root-pinning.sh"
query="$script_dir/providers/sqlite-provider-v1/evaluate-root-mode.sql"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

before=$(sha256sum "$query" | awk '{ print $1 }')
"$verifier" >"$tmp/baseline.out" 2>"$tmp/baseline.err"
if [ -s "$tmp/baseline.err" ] ||
    ! grep -F -x -q ROOT_PINNING_VALID "$tmp/baseline.out"
then
    echo PI_N04_BASELINE_INVALID >&2
    exit 1
fi
echo 'ok BASELINE'

cp -R "$script_dir" "$tmp/proof"
mutant_query="$tmp/proof/providers/sqlite-provider-v1/evaluate-root-mode.sql"
awk '
    $0 == "    SELECT @case_id, '\''exact_root'\'', exact_root_ref," {
        print "    SELECT @case_id, '\''exact_root'\'',"
        print "           (SELECT root_ref FROM publication"
        print "            WHERE scope_ref = '\''identity-login-scope-v1'\''),"
        changed = 1
        next
    }
    { print }
    END { exit !changed }
' "$query" >"$mutant_query.new"
mv "$mutant_query.new" "$mutant_query"

"$tmp/proof/run-protocol-neutral.sh" sqlite-provider-v1 exact-root \
    >"$tmp/reached.tsv" 2>"$tmp/reached.err"
if [ -s "$tmp/reached.err" ] ||
    ! grep -F -x -q 'exact-root	envelope	root_ref	root-auth-v2' \
        "$tmp/reached.tsv" ||
    ! grep -F -x -q 'exact-root	value	display-name	Alice Updated' \
        "$tmp/reached.tsv"
then
    echo PI_N04_MUTANT_NOT_REACHED >&2
    exit 1
fi

set +e
"$verifier" "$tmp/proof/run-protocol-neutral.sh" \
    >"$tmp/mutant.out" 2>"$tmp/mutant.err"
inner_status=$?
set -e
[ "$inner_status" -ne 0 ] || {
    echo PI_N04_MUTANT_NOT_REJECTED >&2
    exit 1
}
[ "$(grep -F -x -c AMBIENT_ROOT_SUBSTITUTION "$tmp/mutant.err")" -eq 1 ] ||
    {
        echo PI_N04_TARGET_MARKER_INVALID >&2
        exit 1
    }
[ ! -s "$tmp/mutant.out" ] || {
    echo PI_N04_UNEXPECTED_MUTANT_STDOUT >&2
    exit 1
}

after=$(sha256sum "$query" | awk '{ print $1 }')
[ "$before" = "$after" ] || {
    echo PI_N04_REAL_SOURCE_CHANGED >&2
    exit 1
}

printf '%s\n' \
    "receipt control=PI-N04 class=runtime mutation=exact-root-resolver-uses-published-head inner_status=$inner_status marker=AMBIENT_ROOT_SUBSTITUTION marker_count=1 target_gate=yes reachability=dynamic-root-auth-v2 source_unchanged=yes" \
    'ok PI-N04' \
    'PI_N04_SELF_TEST_VALID 1 baseline 1 control'
