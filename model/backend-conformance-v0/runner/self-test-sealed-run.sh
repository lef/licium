#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
session_runner="$script_dir/run-bc06-session.sh"
materialize="$script_dir/materialize-bc06-run.sh"
verifier="$script_dir/verify-sealed-run.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

"$session_runner" "$tmp/session" >/dev/null

cp -R "$tmp/session/run-b" "$tmp/preseal-extra"
printf 'undeclared\n' >"$tmp/preseal-extra/undeclared-preseal.tsv"
set +e
output=$("$materialize" "$tmp/preseal-extra" run-b 2>&1)
status=$?
set -e
[ "$status" -ne 0 ] && [ "$output" = "BC06_RUN_LAYOUT_INVALID" ] || {
    echo "preseal extra wrong result: $status $output" >&2
    exit 1
}
echo "ok BC06_RUN_LAYOUT_INVALID"

cp -R "$tmp/session/run-b" "$tmp/semantic-forgery"
target="$tmp/semantic-forgery/bc06-pure-zero-axes/normalized-observations.tsv"
sed '1s/accepted/rejected/' "$target" >"$tmp/semantic-forgery.tsv"
cp "$tmp/semantic-forgery.tsv" "$target"
set +e
output=$("$materialize" "$tmp/semantic-forgery" run-b 2>&1)
status=$?
set -e
[ "$status" -ne 0 ] && [ "$output" = "BC06_RUNTIME_EVIDENCE_INVALID" ] || {
    echo "resealed semantic forgery wrong result: $status $output" >&2
    exit 1
}
echo "ok BC06_RUNTIME_EVIDENCE_INVALID"

"$materialize" "$tmp/session/run-a" run-a >/dev/null

output=$("$verifier" "$tmp/session/run-a")
[ "$output" = "RUN_SEAL_VALID" ] || {
    echo "wrong sealed run baseline: $output" >&2
    exit 1
}
echo "ok RUN_SEAL_VALID"

expect_marker()
{
    name=$1
    marker=$2
    set +e
    output=$("$verifier" "$tmp/$name" 2>&1)
    status=$?
    set -e
    [ "$status" -ne 0 ] && [ "$output" = "$marker" ] || {
        echo "sealed run mutant wrong result: $name $status $output" >&2
        exit 1
    }
    echo "ok $marker"
}

cp -R "$tmp/session/run-a" "$tmp/payload-tamper"
target="$tmp/payload-tamper/bc06-pure-zero-axes/raw-observations.tsv"
sed 's/public-a/public-b/' "$target" >"$tmp/payload-tamper.tsv"
cp "$tmp/payload-tamper.tsv" "$target"
expect_marker payload-tamper PAYLOAD_MANIFEST_INVALID

cp -R "$tmp/session/run-a" "$tmp/manifest-tamper"
target="$tmp/manifest-tamper/payload-manifest.tsv"
sed '1s/evidence/tampered/' "$target" >"$tmp/manifest-tamper.tsv"
cp "$tmp/manifest-tamper.tsv" "$target"
expect_marker manifest-tamper PAYLOAD_MANIFEST_INVALID

cp -R "$tmp/session/run-a" "$tmp/report-tamper"
target="$tmp/report-tamper/report.tsv"
sed 's/meta	global	execution-status	bc06-supported/meta	global	execution-status	tampered/' \
    "$target" >"$tmp/report-tamper.tsv"
cp "$tmp/report-tamper.tsv" "$target"
expect_marker report-tamper RUN_OUTER_RECEIPT_INVALID

cp -R "$tmp/session/run-a" "$tmp/extra-payload"
printf 'undeclared\n' >"$tmp/extra-payload/extra.tsv"
expect_marker extra-payload PAYLOAD_MANIFEST_INVALID

cp -R "$tmp/session/run-a" "$tmp/mode-drift"
chmod 0600 "$tmp/mode-drift/assertions.tsv"
expect_marker mode-drift PAYLOAD_MANIFEST_INVALID

cp -R "$tmp/session/run-a" "$tmp/reserved-mode-drift"
chmod 0600 "$tmp/reserved-mode-drift/report.tsv"
expect_marker reserved-mode-drift RUN_RESERVED_MODE_INVALID

cp -R "$tmp/session/run-a" "$tmp/symlink"
ln -s assertions.tsv "$tmp/symlink/assertions-link.tsv"
expect_marker symlink PAYLOAD_MANIFEST_INVALID

echo "9 sealed run controls detected"
