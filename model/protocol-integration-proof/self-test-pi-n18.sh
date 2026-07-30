#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
verifier="$script_dir/verify-oracle-independence.sh"
vectors="$script_dir/vectors"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

before=$(
    for name in expected-accepted.tsv expected-projection.tsv \
        expected-rejected.tsv
    do
        sha256sum "$vectors/$name"
    done | sha256sum | cut -d' ' -f1
)
"$verifier" >"$tmp/baseline.out" 2>"$tmp/baseline.err"
if [ -s "$tmp/baseline.err" ] ||
    ! grep -F -x -q ORACLE_INDEPENDENCE_VALID "$tmp/baseline.out"
then
    echo PI_N18_BASELINE_INVALID >&2
    exit 1
fi
echo 'ok BASELINE'

cp -R "$script_dir" "$tmp/proof"
mutant="$tmp/proof/mutant-oracle-generator.sh"
cat >"$mutant" <<'MUTANT'
#!/bin/sh
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
"$script_dir/run-protocol-neutral.sh" sqlite-provider-v1 valid \
    >"$script_dir/vectors/expected-accepted.tsv"
: >"$PI_N18_REACHABILITY_MARKER"
MUTANT
chmod +x "$mutant"
old_mutant_expected=$(sha256sum \
    "$tmp/proof/vectors/expected-accepted.tsv" | cut -d' ' -f1)
PI_N18_REACHABILITY_MARKER="$tmp/reached" "$mutant"
new_mutant_expected=$(sha256sum \
    "$tmp/proof/vectors/expected-accepted.tsv" | cut -d' ' -f1)
[ -f "$tmp/reached" ] &&
    [ "$old_mutant_expected" != "$new_mutant_expected" ] || {
    echo PI_N18_MUTANT_NOT_REACHED >&2
    exit 1
}

set +e
"$verifier" "$mutant" >"$tmp/mutant.out" 2>"$tmp/mutant.err"
inner_status=$?
set -e
[ "$inner_status" -ne 0 ] || {
    echo PI_N18_MUTANT_NOT_REJECTED >&2
    exit 1
}
[ "$(grep -F -x -c ORACLE_DERIVED_FROM_SUT "$tmp/mutant.err")" -eq 1 ] || {
    echo PI_N18_TARGET_MARKER_INVALID >&2
    exit 1
}
[ ! -s "$tmp/mutant.out" ] || {
    echo PI_N18_UNEXPECTED_MUTANT_STDOUT >&2
    exit 1
}

after=$(
    for name in expected-accepted.tsv expected-projection.tsv \
        expected-rejected.tsv
    do
        sha256sum "$vectors/$name"
    done | sha256sum | cut -d' ' -f1
)
[ "$before" = "$after" ] || {
    echo PI_N18_REAL_ORACLE_CHANGED >&2
    exit 1
}

printf '%s\n' \
    "receipt control=PI-N18 class=harness mutation=sut-output-redirected-to-expected inner_status=$inner_status marker=ORACLE_DERIVED_FROM_SUT marker_count=1 target_gate=yes reachability=invoked-expected-bytes-changed original_expected_unchanged=yes" \
    'ok PI-N18' \
    'PI_N18_SELF_TEST_VALID 1 baseline 1 control'
