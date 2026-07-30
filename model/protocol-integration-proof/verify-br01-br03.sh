#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner="$script_dir/run-protocol-neutral.sh"
vectors="$script_dir/vectors"
sqlite_dir="$script_dir/providers/sqlite-provider-v1"
flat_dir="$script_dir/providers/flatfile-posix-provider-v1"
expected_files="$script_dir/cases/br01-br03/expected-provider-files.txt"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

[ -d "$sqlite_dir" ] && [ -d "$flat_dir" ] || {
    echo BR01_DISTINCT_PROVIDER_SOURCE_MISSING >&2
    exit 1
}
[ ! "$sqlite_dir" -ef "$flat_dir" ] || {
    echo BR01_PROVIDER_SOURCE_COLLAPSED >&2
    exit 1
}

find "$flat_dir" -mindepth 1 -maxdepth 1 -type f -printf '%f\n' |
    LC_ALL=C sort >"$tmp/actual-files"
cmp -s "$expected_files" "$tmp/actual-files" || {
    echo BR01_FLATFILE_INVENTORY_MISMATCH >&2
    exit 1
}
if find "$flat_dir" -type l -print -quit | grep . >/dev/null
then
    echo BR02_FLATFILE_SYMLINK_FORBIDDEN >&2
    exit 1
fi
if grep -R -E -i \
    'sqlite3|\\.sqlite|sqlite-provider-v1|providers/sqlite-provider' \
    "$flat_dir" >/dev/null
then
    echo BR02_FLATFILE_USES_SQLITE >&2
    exit 1
fi

{
    cat "$vectors/expected-accepted.tsv"
    cat "$vectors/expected-projection.tsv"
} | LC_ALL=C sort >"$tmp/expected-valid.tsv"

for provider in sqlite-provider-v1 flatfile-posix-provider-v1
do
    "$runner" "$provider" valid \
        >"$tmp/$provider-valid.tsv" 2>"$tmp/$provider-valid.err"
    [ ! -s "$tmp/$provider-valid.err" ] || {
        echo "BR03_UNEXPECTED_STDERR $provider valid" >&2
        exit 1
    }
    cmp -s "$tmp/expected-valid.tsv" "$tmp/$provider-valid.tsv" || {
        echo "BR03_VALID_MISMATCH $provider" >&2
        exit 1
    }
    for case_id in wrong-proof unknown-login malformed-request
    do
        "$runner" "$provider" "$case_id" \
            >"$tmp/$provider-$case_id.tsv" \
            2>"$tmp/$provider-$case_id.err"
        [ ! -s "$tmp/$provider-$case_id.err" ] || {
            echo "BR03_UNEXPECTED_STDERR $provider $case_id" >&2
            exit 1
        }
        awk -F '	' -v case_id="$case_id" '$1 == case_id' \
            "$vectors/expected-rejected.tsv" \
            >"$tmp/expected-$case_id.tsv"
        cmp -s "$tmp/expected-$case_id.tsv" \
            "$tmp/$provider-$case_id.tsv" || {
            echo "BR03_REJECTED_MISMATCH $provider $case_id" >&2
            exit 1
        }
    done
done

cmp -s "$tmp/sqlite-provider-v1-valid.tsv" \
    "$tmp/flatfile-posix-provider-v1-valid.tsv" || {
    echo BR03_PROVIDER_VALID_DIFFERENCE >&2
    exit 1
}
for case_id in wrong-proof unknown-login malformed-request
do
    cmp -s "$tmp/sqlite-provider-v1-$case_id.tsv" \
        "$tmp/flatfile-posix-provider-v1-$case_id.tsv" || {
        echo "BR03_PROVIDER_REJECTED_DIFFERENCE $case_id" >&2
        exit 1
    }
done

echo 'BR01 distinct-provider-source PASS'
echo 'BR02 flatfile-provider-no-sqlite PASS'
echo 'BR03 auth-backend-v1-parity PASS'
