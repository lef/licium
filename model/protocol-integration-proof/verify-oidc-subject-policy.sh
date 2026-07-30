#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner="$script_dir/run-oidc-integration.sh"
case_dir="$script_dir/cases/oidc-subject"
node=${NODE:-node}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

for scenario in context-b policy-v2 pairwise-a pairwise-b distinct-account
do
    NODE="$node" "$runner" sqlite-provider-v1 "$scenario" \
        >"$tmp/$scenario.tsv" 2>"$tmp/$scenario.err"
    [ ! -s "$tmp/$scenario.err" ] || {
        echo "OIDC_SUBJECT_UNEXPECTED_STDERR $scenario" >&2
        exit 1
    }
    cmp -s "$case_dir/$scenario.tsv" "$tmp/$scenario.tsv" || {
        echo "OIDC_SUBJECT_SCENARIO_MISMATCH $scenario" >&2
        exit 1
    }
done

for scenario in pairwise-a pairwise-b
do
    NODE="$node" "$runner" sqlite-provider-v1 "$scenario" \
        >"$tmp/$scenario-rerun.tsv" 2>"$tmp/$scenario-rerun.err"
    [ ! -s "$tmp/$scenario-rerun.err" ] || {
        echo "OIDC_SUBJECT_RERUN_UNEXPECTED_STDERR $scenario" >&2
        exit 1
    }
    cmp -s "$case_dir/$scenario.tsv" "$tmp/$scenario-rerun.tsv" || {
        echo "OIDC_SUBJECT_RERUN_MISMATCH $scenario" >&2
        exit 1
    }
    cmp -s "$tmp/$scenario.tsv" "$tmp/$scenario-rerun.tsv" || {
        echo "OIDC_SUBJECT_SAME_SECTOR_INSTABILITY $scenario" >&2
        exit 1
    }
done

context_b=$(awk -F '	' '$1 == "subject" { print $2 }' \
    "$tmp/context-b.tsv")
[ "$context_b" = sub-public-alice-v1 ] || {
    echo OIDC_SUBJECT_CONTEXT_INSTABILITY >&2
    exit 1
}
pairwise_a=$(awk -F '	' '$1 == "subject" { print $2 }' \
    "$tmp/pairwise-a.tsv")
pairwise_b=$(awk -F '	' '$1 == "subject" { print $2 }' \
    "$tmp/pairwise-b.tsv")
distinct_account=$(awk -F '	' '$1 == "subject" { print $2 }' \
    "$tmp/distinct-account.tsv")
[ "$pairwise_a" != "$pairwise_b" ] || {
    echo OIDC_SUBJECT_SECTOR_COLLISION >&2
    exit 1
}
[ "$context_b" != "$distinct_account" ] || {
    echo OIDC_SUBJECT_ACCOUNT_COLLISION >&2
    exit 1
}

echo 'OIDC_SUBJECT_POLICY_SCENARIOS_VALID'
