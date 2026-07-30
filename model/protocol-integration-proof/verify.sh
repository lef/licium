#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
"$script_dir/verify-vectors.sh"
echo PROTOCOL_INTEGRATION_REQUIREMENTS_PHASE_VALID
