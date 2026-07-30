#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
auth_source=${1:-"$script_dir/adapters/oidc-provider-v1/authenticate.mjs"}
map_source=${2:-"$script_dir/adapters/oidc-provider-v1/map-request.mjs"}
subject_source=${3:-"$script_dir/adapters/oidc-provider-v1/subject-policy.mjs"}
server_source="$script_dir/engine-selection/oidc-provider/integration/server.mjs"

[ -f "$auth_source" ] && [ -f "$map_source" ] && [ -f "$subject_source" ] || {
    echo ADAPTER_SOURCE_CLOSURE_MISSING >&2
    exit 1
}
grep -F -q \
    "import { authenticate } from '../../../adapters/oidc-provider-v1/authenticate.mjs';" \
    "$server_source" || {
    echo ADAPTER_SOURCE_NOT_REACHABLE >&2
    exit 1
}
grep -F -q \
    "import { mapRequest } from '../../../adapters/oidc-provider-v1/map-request.mjs';" \
    "$server_source" || {
    echo ADAPTER_SOURCE_NOT_REACHABLE >&2
    exit 1
}
grep -F -q \
    "import { mapSubject } from '../../../adapters/oidc-provider-v1/subject-policy.mjs';" \
    "$server_source" || {
    echo ADAPTER_SOURCE_NOT_REACHABLE >&2
    exit 1
}

if grep -E \
    'createHmac|createSign|subtle[.]sign|SignJWT|jwt[.]sign|jsonwebtoken|BEGIN (RSA |EC |)PRIVATE KEY|token-signing-key' \
    "$auth_source" "$map_source" "$subject_source" >/dev/null
then
    echo ADAPTER_OWNS_TOKEN >&2
    exit 1
fi

echo ADAPTER_TOKEN_OWNERSHIP_BOUNDARY_VALID
