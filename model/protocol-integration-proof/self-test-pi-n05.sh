#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
verifier="$script_dir/verify-subject-stability.sh"
mapper="$script_dir/adapters/oidc-provider-v1/subject-policy.mjs"
node=${NODE:-node}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

NODE="$node" "$verifier" >"$tmp/baseline.out" 2>"$tmp/baseline.err"
if [ -s "$tmp/baseline.err" ] ||
    ! grep -F -x -q SUBJECT_STABILITY_VALID "$tmp/baseline.out"
then
    echo PI_N05_BASELINE_INVALID >&2
    exit 1
fi
echo 'ok BASELINE'

cp -R "$script_dir/adapters/oidc-provider-v1" "$tmp/adapter"
mutant="$tmp/adapter/subject-policy.mjs"
awk '
    {
        if ($0 ~ /contextRef: _contextRef,/) {
            sub(/contextRef: _contextRef,/, "contextRef,")
            changed_parameter = 1
        }
        if ($0 == "  if (exact) {") {
            print "  if (exact && contextRef === '\''context-claims-v2'\'') {"
            print "    return { disposition: '\''issued'\'', subject: '\''sub-mutant-context-b'\'' };"
            print "  }"
            changed_branch = 1
        }
        print
    }
    END { exit !(changed_parameter && changed_branch) }
' "$mapper" >"$mutant.new"
mv "$mutant.new" "$mutant"

"$node" "$script_dir/evaluate-subject-stability.mjs" "$mutant" \
    >"$tmp/reached.tsv" 2>"$tmp/reached.err"
if [ -s "$tmp/reached.err" ] ||
    ! grep -F -x -q \
        'context-b	issued	sub-mutant-context-b' "$tmp/reached.tsv"
then
    echo PI_N05_MUTANT_NOT_REACHED >&2
    exit 1
fi

set +e
NODE="$node" "$verifier" "$mutant" \
    >"$tmp/mutant.out" 2>"$tmp/mutant.err"
inner_status=$?
set -e
[ "$inner_status" -ne 0 ] || {
    echo PI_N05_MUTANT_NOT_REJECTED >&2
    exit 1
}
[ "$(grep -F -x -c SUBJECT_INSTABILITY "$tmp/mutant.err")" -eq 1 ] || {
    echo PI_N05_TARGET_MARKER_INVALID >&2
    exit 1
}
[ ! -s "$tmp/mutant.out" ] || {
    echo PI_N05_UNEXPECTED_MUTANT_STDOUT >&2
    exit 1
}
[ ! -e "$tmp/token.json" ] && [ ! -e "$tmp/id-token.jwt" ] || {
    echo PI_N05_MUTANT_TOKEN_ISSUED >&2
    exit 1
}

printf '%s\n' \
    "receipt control=PI-N05 class=runtime mutation=context-b-subject-change inner_status=$inner_status marker=SUBJECT_INSTABILITY marker_count=1 target_gate=yes reachability=dynamic-context-b-decision token_issued=no" \
    'ok PI-N05' \
    'PI_N05_SELF_TEST_VALID 1 baseline 1 control'
