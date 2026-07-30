#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
auth_source=${1:-"$script_dir/adapters/oidc-provider-v1/authenticate.mjs"}
node=${NODE:-node}

[ -f "$auth_source" ] || {
    echo ADAPTER_PROVIDER_NEUTRALITY_SOURCE_MISSING >&2
    exit 1
}
if grep -E \
    'sqlite-provider-v1|flatfile-posix-provider-v1|providers/sqlite|providers/flatfile' \
    "$auth_source" >/dev/null
then
    echo PROVIDER_SPECIFIC_ADAPTER_BRANCH >&2
    exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
for provider in sqlite-provider-v1 flatfile-posix-provider-v1
do
    LICIUM_AUTH_BACKEND_COMMAND="$script_dir/auth-backend-v1.sh" \
    LICIUM_AUTH_BACKEND_PROVIDER="$provider" \
        "$node" "$script_dir/evaluate-adapter-semantics.mjs" "$auth_source" \
        >"$tmp/$provider.tsv" 2>"$tmp/$provider.err"
    [ ! -s "$tmp/$provider.err" ] || {
        echo ADAPTER_PROVIDER_NEUTRALITY_UNEXPECTED_STDERR >&2
        exit 1
    }
done
cmp -s "$tmp/sqlite-provider-v1.tsv" \
    "$tmp/flatfile-posix-provider-v1.tsv" || {
    echo PROVIDER_SPECIFIC_ADAPTER_BRANCH >&2
    exit 1
}

echo ADAPTER_PROVIDER_NEUTRALITY_VALID
