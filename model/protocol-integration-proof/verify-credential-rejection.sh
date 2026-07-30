#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
backend=${1:-"$script_dir/auth-backend-v1.sh"}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

"$backend" sqlite-provider-v1 login-alice toy-password-v1 \
    context-claims-v1 >"$tmp/valid.tsv" 2>"$tmp/valid.err"
"$backend" sqlite-provider-v1 login-alice toy-password-wrong \
    context-claims-v1 >"$tmp/wrong.tsv" 2>"$tmp/wrong.err"
[ ! -s "$tmp/valid.err" ] && [ ! -s "$tmp/wrong.err" ] || {
    echo CREDENTIAL_REJECTION_UNEXPECTED_STDERR >&2
    exit 1
}
grep -F -x -q 'envelope	disposition	accepted' "$tmp/valid.tsv" || {
    echo CREDENTIAL_REJECTION_PRECONDITION_INVALID >&2
    exit 1
}
if grep -F -x -q 'envelope	disposition	accepted' "$tmp/wrong.tsv"
then
    echo INVALID_PROOF_ACCEPTED >&2
    exit 1
fi
grep -F -x -q 'wrong-proof	rejected	invalid_proof' "$tmp/wrong.tsv" || {
    echo CREDENTIAL_REJECTION_OUTCOME_INVALID >&2
    exit 1
}

echo CREDENTIAL_REJECTION_VALID
