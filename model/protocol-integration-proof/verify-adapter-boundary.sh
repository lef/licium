#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
auth_source=${1:-"$script_dir/adapters/oidc-provider-v1/authenticate.mjs"}
map_source=${2:-"$script_dir/adapters/oidc-provider-v1/map-request.mjs"}
server_source="$script_dir/engine-selection/oidc-provider/integration/server.mjs"

[ -f "$auth_source" ] && [ -f "$map_source" ] || {
    echo ADAPTER_SOURCE_CLOSURE_MISSING >&2
    exit 1
}
grep -F -q \
    "import { authenticate } from '../../../adapters/oidc-provider-v1/authenticate.mjs';" \
    "$server_source" || {
    echo ADAPTER_SOURCE_NOT_REACHABLE >&2
    exit 1
}
if grep -E -i \
    'sqlite3|\.sqlite|sqlite-provider-v1|flatfile-posix-provider-v1|selected_value|selected_relation|evaluation_pin|CREATE[[:space:]]+TABLE|SELECT[[:space:]].*FROM' \
    "$auth_source" "$map_source" >/dev/null
then
    echo ADAPTER_BACKEND_SCHEMA_COUPLING >&2
    exit 1
fi

echo ADAPTER_BOUNDARY_VALID
