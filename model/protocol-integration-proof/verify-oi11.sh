#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
oidc_runner="$script_dir/run-oidc-integration.sh"
direct_runner="$script_dir/run-protocol-neutral.sh"
expected_projection="$script_dir/vectors/expected-projection.tsv"
node=${NODE:-node}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

for provider in sqlite-provider-v1 flatfile-posix-provider-v1
do
    evidence="$tmp/$provider-evidence"
    mkdir "$evidence"

    "$direct_runner" "$provider" valid \
        >"$tmp/$provider-direct-all.tsv" \
        2>"$tmp/$provider-direct.err"
    OIDC_EVIDENCE_DIR="$evidence" NODE="$node" \
        "$oidc_runner" "$provider" \
        >"$tmp/$provider-oidc.tsv" \
        2>"$tmp/$provider-oidc.err"
    [ ! -s "$tmp/$provider-direct.err" ] &&
        [ ! -s "$tmp/$provider-oidc.err" ] || {
        echo "OI11_UNEXPECTED_STDERR $provider" >&2
        exit 1
    }

    awk -F '	' '
        $1 == "value" || $1 == "relation" { print }
    ' "$tmp/$provider-direct-all.tsv" |
        LC_ALL=C sort >"$tmp/$provider-direct.tsv"

    awk -F '	' '
        $1 == "projection-receipt-v1" && NF == 9 {
            print "value\t" $6 "\t" $7
            if ($9 != "" && $9 != "undefined")
                print "relation\t" $8 "\t" $9
            count++
        }
        END { exit count != 1 }
    ' "$evidence/projection-receipt.tsv" |
        LC_ALL=C sort >"$tmp/$provider-pre-claims.tsv" || {
        echo "OI11_PROJECTION_RECEIPT_INVALID $provider" >&2
        exit 1
    }

    cmp -s "$expected_projection" "$tmp/$provider-direct.tsv" || {
        echo "OI11_DIRECT_PROJECTION_MISMATCH $provider" >&2
        exit 1
    }
    cmp -s "$expected_projection" "$tmp/$provider-pre-claims.tsv" || {
        echo "OI11_PRE_CLAIMS_PROJECTION_MISMATCH $provider" >&2
        exit 1
    }
    cmp -s "$tmp/$provider-direct.tsv" \
        "$tmp/$provider-pre-claims.tsv" || {
        echo "OI11_DIRECT_OIDC_DIFFERENCE $provider" >&2
        exit 1
    }
    printf 'OI11 %s direct-pre-claims-difference-zero PASS\n' "$provider"
done

cmp -s "$tmp/sqlite-provider-v1-pre-claims.tsv" \
    "$tmp/flatfile-posix-provider-v1-pre-claims.tsv" || {
    echo OI11_PROVIDER_PROJECTION_DIFFERENCE >&2
    exit 1
}

echo 'OI11_ACTUAL_OIDC_PROJECTION_EQUIVALENCE_VALID'
