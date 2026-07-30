#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
session_runner="$script_dir/run-bc06-session.sh"
run_materializer="$script_dir/materialize-bc06-run.sh"
session_sealer="$script_dir/seal-bc06-session.sh"
verifier="$script_dir/verify-sealed-session.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

"$session_runner" "$tmp/session" >/dev/null
"$run_materializer" "$tmp/session/run-a" run-a >/dev/null
"$run_materializer" "$tmp/session/run-b" run-b >/dev/null

cp -R "$tmp/session" "$tmp/preseal-extra-subtree"
mkdir "$tmp/preseal-extra-subtree/undeclared"
printf 'undeclared\n' >"$tmp/preseal-extra-subtree/undeclared/nested.tsv"
set +e
output=$("$session_sealer" "$tmp/preseal-extra-subtree" 2>&1)
status=$?
set -e
[ "$status" -ne 0 ] && [ "$output" = "BC06_SESSION_LAYOUT_INVALID" ] || {
    echo "preseal session subtree wrong result: $status $output" >&2
    exit 1
}
echo "ok BC06_SESSION_LAYOUT_INVALID"

output=$("$session_sealer" "$tmp/session")
[ "$output" = "SESSION_SEAL_VALID" ] || {
    echo "wrong session seal baseline: $output" >&2
    exit 1
}
echo "ok SESSION_SEAL_VALID"

cp -R "$tmp/session" "$tmp/run-a-tamper"
target="$tmp/run-a-tamper/run-a/bc06-state-write/raw-observations.tsv"
sed 's/public-a/public-b/' "$target" >"$tmp/run-a-tamper.tsv"
cp "$tmp/run-a-tamper.tsv" "$target"
set +e
output=$("$verifier" "$tmp/run-a-tamper" 2>&1)
status=$?
set -e
[ "$status" -ne 0 ] && [ "$output" = "SESSION_RUN_A_INVALID" ] || {
    echo "run A session tamper wrong result: $status $output" >&2
    exit 1
}
echo "ok SESSION_RUN_A_INVALID"

cp -R "$tmp/session" "$tmp/comparison-tamper"
target="$tmp/comparison-tamper/canonical-comparison.tsv"
sed '1s/[0-9a-f]/0/' "$target" >"$tmp/comparison-tamper.tsv"
cp "$tmp/comparison-tamper.tsv" "$target"
set +e
output=$("$verifier" "$tmp/comparison-tamper" 2>&1)
status=$?
set -e
[ "$status" -ne 0 ] && [ "$output" = "SESSION_SEAL_INVALID" ] || {
    echo "comparison seal tamper wrong result: $status $output" >&2
    exit 1
}
echo "ok SESSION_SEAL_INVALID"

echo "3 sealed session controls detected"
