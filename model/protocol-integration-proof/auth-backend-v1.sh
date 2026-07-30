#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

[ "$#" -eq 3 ] || [ "$#" -eq 4 ] || [ "$#" -eq 10 ] || {
    echo 'usage: auth-backend-v1.sh PROVIDER LOGIN PROOF [CONTEXT] or ten-role request envelope' >&2
    exit 2
}
provider=$1
login_identifier=$2
synthetic_proof=$3
context_ref=${4:-context-claims-v1}
source_mode=${5:-exact_root}
source_ref=${6:-write-receipt-v1}
relying_party_ref=${7:-rp-proof-v1}
purpose_ref=${8:-interactive-login-v1}
projection_ref=${9:-projection-basic-v1}
assurance_requirement_ref=${10:-assurance-password-fixture-v1}

case "$source_mode:$source_ref" in
    exact_root:write-receipt-v1|published_head:publication-auth-v2) ;;
    *)
        echo 'unsupported protocol-neutral source tuple' >&2
        exit 2
        ;;
esac
[ "$relying_party_ref" = rp-proof-v1 ] &&
    [ "$purpose_ref" = interactive-login-v1 ] &&
    [ "$projection_ref" = projection-basic-v1 ] &&
    [ "$assurance_requirement_ref" = assurance-password-fixture-v1 ] || {
    echo 'unsupported protocol-neutral mapping tuple' >&2
    exit 2
}

if [ -z "$login_identifier" ]
then
    case_id=malformed-request
elif [ "$login_identifier" != login-alice ] &&
    [ "$login_identifier" != login-bob ]
then
    case_id=unknown-login
elif {
    [ "$login_identifier" = login-alice ] &&
        [ "$synthetic_proof" != toy-password-v1 ]
} || {
    [ "$login_identifier" = login-bob ] &&
        [ "$synthetic_proof" != toy-password-bob-v1 ]
}
then
    case_id=wrong-proof
elif [ "$login_identifier" = login-bob ]
then
    case "$context_ref:$source_mode:$source_ref" in
        context-claims-v1:exact_root:write-receipt-v1)
            case_id=valid-bob
            ;;
        *)
            echo 'unsupported protocol-neutral evaluation tuple' >&2
            exit 2
            ;;
    esac
else
    case "$context_ref:$source_mode:$source_ref" in
        context-claims-v1:exact_root:write-receipt-v1) case_id=valid ;;
        context-claims-v2:exact_root:write-receipt-v1)
            case_id=valid-context-b
            ;;
        context-claims-v1:published_head:publication-auth-v2)
            case_id=valid-published-head
            ;;
        *)
            echo 'unsupported protocol-neutral evaluation tuple' >&2
            exit 2
            ;;
    esac
fi

exec "$script_dir/run-protocol-neutral.sh" "$provider" "$case_id"
