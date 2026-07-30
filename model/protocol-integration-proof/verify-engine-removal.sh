#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(CDPATH= cd -- "$script_dir/../.." && pwd)

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
tree="$tmp/tree"
mkdir "$tree"

source_commit=$(git -C "$repo" rev-parse HEAD)
git -C "$repo" archive "$source_commit" | tar -x -C "$tree"

manifest()
{
    root=$1
    (
        cd "$root"
        find model/protocol-integration-proof/providers \
            model/protocol-integration-proof/vectors \
            -type f -print |
            LC_ALL=C sort |
            xargs sha256sum
    )
}

manifest "$repo" >"$tmp/provider-before.sha256"

rm -rf \
    "$tree/model/protocol-integration-proof/engine-selection" \
    "$tree/model/protocol-integration-proof/adapters/oidc-provider-v1" \
    "$tree/model/protocol-integration-proof/cases/oidc-integration" \
    "$tree/model/protocol-integration-proof/cases/oi06-pn15"
rm -f \
    "$tree/model/protocol-integration-proof/invoke-adapter.mjs" \
    "$tree/model/protocol-integration-proof/run-oidc-integration.sh" \
    "$tree/model/protocol-integration-proof/self-test-pi-n01.sh" \
    "$tree/model/protocol-integration-proof/verify-adapter-boundary.sh" \
    "$tree/model/protocol-integration-proof/verify-oidc-integration.sh" \
    "$tree/model/protocol-integration-proof/verify-oidc-backend-parity.sh" \
    "$tree/model/protocol-integration-proof/verify-oi06-pn15.sh"

if [ -e "$tree/model/protocol-integration-proof/engine-selection" ] ||
    [ -e "$tree/model/protocol-integration-proof/adapters/oidc-provider-v1" ]
then
    echo ENGINE_REMOVAL_INCOMPLETE >&2
    exit 1
fi

manifest "$tree" >"$tmp/provider-after.sha256"
cmp -s "$tmp/provider-before.sha256" "$tmp/provider-after.sha256" || {
    echo ENGINE_REMOVAL_CHANGED_PROVIDER_SOURCE >&2
    exit 1
}

for n in 01 02 03 04 05 06 07 08 09 10 11 12
do
    sh "$tree/model/protocol-integration-proof/verify-pn$n.sh" \
        >"$tmp/pn$n.out" 2>"$tmp/pn$n.err"
    [ ! -s "$tmp/pn$n.err" ] || {
        echo "ENGINE_REMOVAL_PN_REGRESSION PN$n" >&2
        exit 1
    }
done
sh "$tree/model/protocol-integration-proof/verify-br01-br03.sh" \
    >"$tmp/br.out" 2>"$tmp/br.err"
[ ! -s "$tmp/br.err" ] || {
    echo ENGINE_REMOVAL_BR_REGRESSION >&2
    exit 1
}

printf '%s\n' \
    'engine-artifacts	ABSENT' \
    'provider-source-manifest	UNCHANGED' \
    'PN01-PN12	PASS' \
    'BR01-BR03	PASS' \
    'ENGINE_REMOVAL_VALID'
