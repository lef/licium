#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

[ "$#" -eq 2 ] || {
    echo 'usage: run-protocol-neutral.sh PROVIDER CASE' >&2
    exit 2
}

provider=$1
case_id=$2
case "$provider:$case_id" in
    sqlite-provider-v1:valid|\
    sqlite-provider-v1:valid-bob|\
    sqlite-provider-v1:valid-context-b|\
    sqlite-provider-v1:valid-published-head|\
    sqlite-provider-v1:wrong-proof|\
    sqlite-provider-v1:unknown-login|\
    sqlite-provider-v1:malformed-request|\
    sqlite-provider-v1:exact-root|\
    sqlite-provider-v1:published-head|\
    sqlite-provider-v1:pinned-closure|\
    sqlite-provider-v1:historical-replay|\
    sqlite-provider-v1:surface-bundle|\
    sqlite-provider-v1:ordinary-read-counters|\
    sqlite-provider-v1:credential-source-stability|\
    sqlite-provider-v1:record-only|\
    sqlite-provider-v1:ephemeral-provenance)
        exec "$script_dir/providers/sqlite-provider-v1/run.sh" "$case_id"
        ;;
    flatfile-posix-provider-v1:valid|\
    flatfile-posix-provider-v1:valid-bob|\
    flatfile-posix-provider-v1:valid-context-b|\
    flatfile-posix-provider-v1:wrong-proof|\
    flatfile-posix-provider-v1:unknown-login|\
    flatfile-posix-provider-v1:malformed-request)
        exec "$script_dir/providers/flatfile-posix-provider-v1/run.sh" "$case_id"
        ;;
    *)
        echo "unsupported provider/case: $provider/$case_id" >&2
        exit 2
        ;;
esac
