#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
verifier="$script_dir/verify-protocol-nonleakage.sh"
provider="$script_dir/providers/sqlite-provider-v1/run.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

before=$(sha256sum "$provider" | awk '{ print $1 }')
"$verifier" >"$tmp/baseline.out" 2>"$tmp/baseline.err"
if [ -s "$tmp/baseline.err" ] ||
    ! grep -F -x -q PROTOCOL_NONLEAKAGE_VALID "$tmp/baseline.out" ||
    grep -F -q secret-never-project-v1 "$tmp/baseline.out"
then
    echo PI_N07_BASELINE_INVALID >&2
    exit 1
fi
echo 'ok BASELINE'

cp -R "$script_dir" "$tmp/proof"
mutant="$tmp/proof/providers/sqlite-provider-v1/run.sh"
awk '
    $0 == "            '\''case=surface-bundle disposition=accepted root_ref=root-auth-v1'\'' \\" {
        print "            '\''case=surface-bundle disposition=accepted root_ref=root-auth-v1 secret=secret-never-project-v1'\'' \\"
        changed = 1
        next
    }
    { print }
    END { exit !changed }
' "$provider" >"$mutant.new"
mv "$mutant.new" "$mutant"
chmod +x "$mutant"

mkdir "$tmp/reached-surfaces"
PROTOCOL_SURFACE_DIR="$tmp/reached-surfaces" \
    "$tmp/proof/run-protocol-neutral.sh" \
    sqlite-provider-v1 surface-bundle \
    >"$tmp/reached.out" 2>"$tmp/reached.err"
if [ -s "$tmp/reached.err" ] ||
    ! grep -F -q secret-never-project-v1 \
        "$tmp/reached-surfaces/provider.log"
then
    echo PI_N07_MUTANT_NOT_REACHED >&2
    exit 1
fi

set +e
"$verifier" "$tmp/proof/run-protocol-neutral.sh" \
    >"$tmp/mutant.out" 2>"$tmp/mutant.err"
inner_status=$?
set -e
[ "$inner_status" -ne 0 ] || {
    echo PI_N07_MUTANT_NOT_REJECTED >&2
    exit 1
}
[ "$(grep -F -x -c PROTOCOL_SECRET_LEAK "$tmp/mutant.err")" -eq 1 ] || {
    echo PI_N07_TARGET_MARKER_INVALID >&2
    exit 1
}
[ ! -s "$tmp/mutant.out" ] || {
    echo PI_N07_UNEXPECTED_MUTANT_STDOUT >&2
    exit 1
}

after=$(sha256sum "$provider" | awk '{ print $1 }')
[ "$before" = "$after" ] || {
    echo PI_N07_REAL_SOURCE_CHANGED >&2
    exit 1
}

printf '%s\n' \
    "receipt control=PI-N07 class=runtime/safety mutation=provider-log-secret inner_status=$inner_status marker=PROTOCOL_SECRET_LEAK marker_count=1 target_gate=yes reachability=dynamic-provider-log retained_positive_secret_occurrences=0 source_unchanged=yes" \
    'ok PI-N07' \
    'PI_N07_SELF_TEST_VALID 1 baseline 1 control'
