#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
auth_source=${1:-"$script_dir/adapters/oidc-provider-v1/authenticate.mjs"}
node=${NODE:-node}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

"$script_dir/run-protocol-neutral.sh" sqlite-provider-v1 valid \
    >"$tmp/direct-all.tsv" 2>"$tmp/direct.err"
LICIUM_AUTH_BACKEND_COMMAND="$script_dir/auth-backend-v1.sh" \
LICIUM_AUTH_BACKEND_PROVIDER=sqlite-provider-v1 \
    "$node" "$script_dir/evaluate-adapter-semantics.mjs" "$auth_source" \
    >"$tmp/adapter-all.tsv" 2>"$tmp/adapter.err"
[ ! -s "$tmp/direct.err" ] && [ ! -s "$tmp/adapter.err" ] || {
    echo PATH_EQUIVALENCE_UNEXPECTED_STDERR >&2
    exit 1
}

awk -F '\t' '
    $1 == "value" || $1 == "relation" { print; next }
    $1 == "envelope" &&
        ($2 == "disposition" ||
         $2 == "stable_protocol_account_key" ||
         $2 == "root_ref" ||
         $2 == "definition_ref" ||
         $2 == "profile_ref" ||
         $2 == "context_ref") { print }
' "$tmp/direct-all.tsv" | LC_ALL=C sort >"$tmp/direct.tsv"
LC_ALL=C sort "$tmp/adapter-all.tsv" >"$tmp/adapter.tsv"

cmp -s "$tmp/direct.tsv" "$tmp/adapter.tsv" || {
    echo PROTOCOL_PATH_SEMANTIC_DRIFT >&2
    exit 1
}

echo DIRECT_ADAPTER_PATH_EQUIVALENCE_VALID
