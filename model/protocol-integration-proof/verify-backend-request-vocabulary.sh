#!/bin/sh
# shellcheck disable=SC1007
set -eu

[ "$#" -eq 1 ] || {
    echo 'usage: verify-backend-request-vocabulary.sh TRACE' >&2
    exit 2
}
trace=$1
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
expected="$script_dir/cases/request-envelope/expected-trace.tsv"
[ -f "$trace" ] || {
    echo BACKEND_REQUEST_TRACE_MISSING >&2
    exit 1
}

if ! awk -F '\t' '
    BEGIN {
        expected[1] = "provider_selector"
        expected[2] = "login_identifier"
        expected[3] = "proof"
        expected[4] = "context_ref"
        expected[5] = "source_mode"
        expected[6] = "source_ref"
        expected[7] = "relying_party_ref"
        expected[8] = "purpose_ref"
        expected[9] = "projection_ref"
        expected[10] = "assurance_requirement_ref"
    }
    NF != 4 || $1 != "argument" || $2 !~ /^[1-9][0-9]*$/ {
        invalid = 1
        next
    }
    {
        count++
        if (($2 + 0) != count || $3 != expected[count]) invalid = 1
    }
    END { exit !(count == 10 && !invalid) }
' "$trace"
then
    echo PROTOCOL_LEAKS_INTO_CORE >&2
    exit 1
fi

if grep -E -i \
    'client_id|scope|(^|[^[:alnum:]_])sub([^[:alnum:]_]|$)|acr|amr|nonce|redirect_uri|authorization_code|access_token|id_token|refresh_token' \
    "$trace" >/dev/null
then
    echo PROTOCOL_LEAKS_INTO_CORE >&2
    exit 1
fi
cmp -s "$expected" "$trace" || {
    echo BACKEND_REQUEST_ENVELOPE_MISMATCH >&2
    exit 1
}

echo BACKEND_REQUEST_VOCABULARY_VALID
