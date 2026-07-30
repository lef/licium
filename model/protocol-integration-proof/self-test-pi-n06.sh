#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
verifier="$script_dir/verify-credential-rejection.sh"
backend="$script_dir/auth-backend-v1.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

before=$(sha256sum "$backend" | awk '{ print $1 }')
"$verifier" >"$tmp/baseline.out" 2>"$tmp/baseline.err"
if [ -s "$tmp/baseline.err" ] ||
    ! grep -F -x -q CREDENTIAL_REJECTION_VALID "$tmp/baseline.out"
then
    echo PI_N06_BASELINE_INVALID >&2
    exit 1
fi
echo 'ok BASELINE'

cp -R "$script_dir" "$tmp/proof"
mutant="$tmp/proof/auth-backend-v1.sh"
awk '
    $0 == "        [ \"$synthetic_proof\" != toy-password-v1 ]" {
        print "        [ \"$synthetic_proof\" = toy-password-impossible ]"
        changed = 1
        next
    }
    { print }
    END { exit !changed }
' "$backend" >"$mutant.new"
mv "$mutant.new" "$mutant"
chmod +x "$mutant"

"$mutant" sqlite-provider-v1 login-alice toy-password-wrong \
    context-claims-v1 >"$tmp/reached.tsv" 2>"$tmp/reached.err"
if [ -s "$tmp/reached.err" ] ||
    ! grep -F -x -q 'envelope	disposition	accepted' "$tmp/reached.tsv"
then
    echo PI_N06_MUTANT_NOT_REACHED >&2
    exit 1
fi

set +e
"$verifier" "$mutant" >"$tmp/mutant.out" 2>"$tmp/mutant.err"
inner_status=$?
set -e
[ "$inner_status" -ne 0 ] || {
    echo PI_N06_MUTANT_NOT_REJECTED >&2
    exit 1
}
[ "$(grep -F -x -c INVALID_PROOF_ACCEPTED "$tmp/mutant.err")" -eq 1 ] || {
    echo PI_N06_TARGET_MARKER_INVALID >&2
    exit 1
}
[ ! -s "$tmp/mutant.out" ] || {
    echo PI_N06_UNEXPECTED_MUTANT_STDOUT >&2
    exit 1
}

after=$(sha256sum "$backend" | awk '{ print $1 }')
[ "$before" = "$after" ] || {
    echo PI_N06_REAL_SOURCE_CHANGED >&2
    exit 1
}

printf '%s\n' \
    "receipt control=PI-N06 class=runtime mutation=wrong-proof-comparison-bypass inner_status=$inner_status marker=INVALID_PROOF_ACCEPTED marker_count=1 target_gate=yes reachability=dynamic-accepted-outcome source_unchanged=yes" \
    'ok PI-N06' \
    'PI_N06_SELF_TEST_VALID 1 baseline 1 control'
