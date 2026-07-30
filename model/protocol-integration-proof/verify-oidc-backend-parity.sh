#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
oidc_runner="$script_dir/run-oidc-integration.sh"
direct_runner="$script_dir/run-protocol-neutral.sh"
case_dir="$script_dir/cases/oidc-integration"
vectors="$script_dir/vectors"
node=${NODE:-node}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

shared_manifest()
{
    {
        printf '%s\n' \
            "$script_dir/adapters/oidc-provider-v1/authenticate.mjs" \
            "$script_dir/adapters/oidc-provider-v1/map-request.mjs" \
            "$script_dir/adapters/oidc-provider-v1/mapping-policy.tsv" \
            "$script_dir/adapters/oidc-provider-v1/subject-mapping.tsv" \
            "$script_dir/adapters/oidc-provider-v1/subject-policy.mjs" \
            "$script_dir/adapters/oidc-provider-v1/subject-policy.tsv" \
            "$script_dir/auth-backend-v1.sh" \
            "$script_dir/engine-selection/oidc-provider/integration/select-login-subject.mjs" \
            "$script_dir/engine-selection/oidc-provider/integration/server.mjs" \
            "$script_dir/engine-selection/oidc-provider/integration/verify-token.mjs" \
            "$script_dir/engine-selection/oidc-provider/package-lock.json" \
            "$script_dir/run-oidc-integration.sh"
        find "$vectors" -type f -print
    } | LC_ALL=C sort | xargs sha256sum
}

shared_manifest >"$tmp/shared-before.sha256"

NODE="$node" "$oidc_runner" sqlite-provider-v1 \
    >"$tmp/sqlite.tsv" 2>"$tmp/sqlite.err"
NODE="$node" "$oidc_runner" flatfile-posix-provider-v1 \
    >"$tmp/flatfile.tsv" 2>"$tmp/flatfile.err"

[ ! -s "$tmp/sqlite.err" ] && [ ! -s "$tmp/flatfile.err" ] || {
    echo BR06_OIDC_UNEXPECTED_STDERR >&2
    exit 1
}
cmp -s "$case_dir/expected-sqlite.tsv" "$tmp/sqlite.tsv" || {
    echo BR06_SQLITE_OIDC_MISMATCH >&2
    exit 1
}
cmp -s "$case_dir/expected-flatfile.tsv" "$tmp/flatfile.tsv" || {
    echo BR06_FLATFILE_OIDC_MISMATCH >&2
    exit 1
}

sed 's/^backend-provider	.*/backend-provider	<provider>/' \
    "$tmp/sqlite.tsv" >"$tmp/sqlite-normalized.tsv"
sed 's/^backend-provider	.*/backend-provider	<provider>/' \
    "$tmp/flatfile.tsv" >"$tmp/flatfile-normalized.tsv"
cmp -s "$tmp/sqlite-normalized.tsv" "$tmp/flatfile-normalized.tsv" || {
    echo BR06_OIDC_PROVIDER_DIFFERENCE >&2
    exit 1
}

if grep -E \
    'sqlite-provider-v1|flatfile-posix-provider-v1|sqlite3|\.sqlite' \
    "$script_dir/adapters/oidc-provider-v1/authenticate.mjs" >/dev/null
then
    echo BR05_PROVIDER_SPECIFIC_ADAPTER_BRANCH >&2
    exit 1
fi

for provider in sqlite-provider-v1 flatfile-posix-provider-v1
do
    "$direct_runner" "$provider" valid >"$tmp/$provider-direct.tsv"
    awk -F '	' '$1 == "value" || $1 == "relation"' \
        "$tmp/$provider-direct.tsv" >"$tmp/$provider-projection.tsv"
    cmp -s "$vectors/expected-projection.tsv" \
        "$tmp/$provider-projection.tsv" || {
        echo "BR07_DIRECT_PROJECTION_MISMATCH $provider" >&2
        exit 1
    }
done
cmp -s "$tmp/sqlite-provider-v1-projection.tsv" \
    "$tmp/flatfile-posix-provider-v1-projection.tsv" || {
    echo BR07_DIRECT_PROVIDER_DIFFERENCE >&2
    exit 1
}

shared_manifest >"$tmp/shared-after.sha256"
cmp -s "$tmp/shared-before.sha256" "$tmp/shared-after.sha256" || {
    echo BR04_SHARED_SOURCE_CHANGED >&2
    exit 1
}

echo 'BR04 shared-source-byte-stable PASS'
echo 'BR05 provider-selection-only PASS'
echo 'BR06 oidc-semantic-parity PASS'
echo 'BR07 direct-oidc-projection-parity PASS'
