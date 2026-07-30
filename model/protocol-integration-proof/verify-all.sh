#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
manifest="$script_dir/cases/full-regression/suites.tsv"
node=${NODE:-node}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

awk -F '	' '
    NF != 3 ||
    $1 !~ /^(verify|self-test)/ ||
    $2 !~ /^[0-9]+$/ ||
    $3 !~ /^[0-9a-f]{64}$/ ||
    seen[$1]++ {
        exit 1
    }
' "$manifest" || {
    echo FULL_REGRESSION_MANIFEST_INVALID >&2
    exit 1
}

find "$script_dir" -maxdepth 1 -type f \
    \( -name 'verify*.sh' -o -name 'self-test*.sh' \) \
    ! -name verify-all.sh \
    ! -name verify-backend-request-vocabulary.sh \
    -exec basename {} .sh \; |
    LC_ALL=C sort >"$tmp/actual-suites"
cut -f 1 "$manifest" | LC_ALL=C sort >"$tmp/expected-suites"
cmp -s "$tmp/expected-suites" "$tmp/actual-suites" || {
    echo FULL_REGRESSION_SUITE_CLOSURE_MISMATCH >&2
    exit 1
}

count=0
while IFS='	' read -r suite expected_lines expected_digest
do
    count=$((count + 1))
    if NODE="$node" sh "$script_dir/$suite.sh" \
        >"$tmp/$suite.out" 2>"$tmp/$suite.err"
    then
        :
    else
        echo "FULL_REGRESSION_SUITE_FAILED $suite" >&2
        exit 1
    fi
    [ ! -s "$tmp/$suite.err" ] || {
        echo "FULL_REGRESSION_UNEXPECTED_STDERR $suite" >&2
        exit 1
    }
    actual_lines=$(wc -l <"$tmp/$suite.out" | tr -d ' ')
    [ "$actual_lines" = "$expected_lines" ] || {
        echo "FULL_REGRESSION_LINE_COUNT_MISMATCH $suite" >&2
        exit 1
    }
    actual_digest=$(sha256sum "$tmp/$suite.out" | awk '{ print $1 }')
    [ "$actual_digest" = "$expected_digest" ] || {
        echo "FULL_REGRESSION_DIGEST_MISMATCH $suite" >&2
        exit 1
    }
done <"$manifest"

[ "$count" -eq 63 ] || {
    echo FULL_REGRESSION_COUNT_MISMATCH >&2
    exit 1
}

echo 'PROTOCOL_INTEGRATION_FULL_REGRESSION_VALID 63 suites'
