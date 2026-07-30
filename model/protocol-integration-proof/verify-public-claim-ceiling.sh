#!/bin/sh
# shellcheck disable=SC1007,SC2016
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
roadmap_readme="$script_dir/../../publication/protocol-integration-roadmap/source/README.md"
sample_readme="$script_dir/../../README.md"
if [ "$#" -eq 1 ]
then
    readme=$1
elif [ "$#" -eq 0 ] && [ -f "$roadmap_readme" ]
then
    readme=$roadmap_readme
elif [ "$#" -eq 0 ]
then
    readme=$sample_readme
else
    echo 'usage: verify-public-claim-ceiling.sh [README]' >&2
    exit 2
fi

[ -f "$readme" ] || {
    echo PUBLIC_CLAIM_SOURCE_MISSING >&2
    exit 1
}
if grep -E -i \
    'production-ready OIDC|production IdP commitment[.]?$|OIDC-certified|OIDC certified|security-certified|security certified' \
    "$readme" |
    grep -E -v -i \
        'not (a )?production|ではない|does not|non-production' >/dev/null
then
    echo PUBLIC_OVERCLAIM >&2
    exit 1
fi
if grep -E -i \
    'Rust is a current implementation|current Rust implementation|Rust implementation is (currently )?(present|implemented)|Rust実装(が|は)(現在|現時点で)?存在する' \
    "$readme" >/dev/null
then
    echo RUST_EXISTENCE_OVERCLAIM >&2
    exit 1
fi
if grep -E -i \
    'not yet (present|published)|not authorized for public push|still requires artifact-bound owner approval|まだpublic repositoryには存在せず|public pushも承認されていない' \
    "$readme" >/dev/null
then
    echo VOLATILE_PUBLICATION_STATE >&2
    exit 1
fi

if grep -F -q '### Protocol Integration Proof — planned' "$readme"
then
    for statement in \
        'Protocol Integration Proof is planned and is not currently implemented.' \
        'The planned milestone is not a production IdP commitment.' \
        'The planned milestone is not an OIDC certification commitment.' \
        'The planned milestone is not a security certification commitment.' \
        'Protocol Integration Proofは`planned`／`計画中`であり、現在は実装されていない。' \
        'このmilestoneはproduction IdPのコミットメントではない。' \
        'このmilestoneはOIDC certificationのコミットメントではない。' \
        'このmilestoneはsecurity certificationのコミットメントではない。' \
        'Rust is a future replacement after boundary validation and is not currently' \
        'Rustは境界検証後のfuture replacementであり、現時点では存在しない。'
    do
        grep -F -q "$statement" "$readme" || {
            echo PUBLIC_CLAIM_CEILING_MISSING >&2
            exit 1
        }
    done
elif grep -F -q \
    '### Protocol Integration Proof — finite runnable sample' "$readme"
then
    for statement in \
        'implemented and included' \
        'repository-specific review or authorization state.' \
        'This remains a synthetic, disposable, non-production slice. It does not make' \
        'or implement Spanner or Rust.' \
        'external operational records. Inclusion of these bytes grants no standing' \
        'finite Protocol Integration Proofを実装し、このrepository treeへ' \
        'repository固有のreview／authorization stateを記録しない。' \
        'これはsynthetic、disposable、non-productionのsliceである。Liciumをproduction' \
        'へのstanding authorizationを与えない。'
    do
        grep -F -q "$statement" "$readme" || {
            echo PUBLIC_CLAIM_CEILING_MISSING >&2
            exit 1
        }
    done
else
    echo PUBLIC_CLAIM_CEILING_MISSING >&2
    exit 1
fi

echo PUBLIC_CLAIM_CEILING_VALID
