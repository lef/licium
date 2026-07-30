#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
verifier="$script_dir/verify-raw-protocol-alias.sh"
adapter="$script_dir/adapters/oidc-provider-v1"
auth_source="$adapter/authenticate.mjs"
node=${NODE:-node}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

cat >"$tmp/backend-spy.sh" <<'SPY'
#!/bin/sh
set -eu
: >"$PI_N19_TRACE"
i=1
for value
do
    case "$i" in
        1) role=provider_selector ;;
        2) role=login_identifier ;;
        3) role=proof ;;
        4) role=context_ref ;;
        5) role=source_mode ;;
        6) role=source_ref ;;
        7) role=relying_party_ref ;;
        8) role=purpose_ref ;;
        9) role=projection_ref ;;
        10) role=assurance_requirement_ref ;;
        *) role=unexpected ;;
    esac
    printf 'argument\t%s\t%s\t%s\n' "$i" "$role" "$value" >>"$PI_N19_TRACE"
    i=$((i + 1))
done
printf 'accepted\troot-auth-v1\n' >"$PI_N19_BACKEND_LOG"
[ "$#" -eq 10 ] || exit 2
exec "$PI_N19_REAL_BACKEND" \
    "$1" "$2" "$3" "$4" "$5" "$6" \
    rp-proof-v1 "$8" "$9" "${10}"
SPY
chmod +x "$tmp/backend-spy.sh"

PI_N19_TRACE="$tmp/baseline.tsv" \
PI_N19_BACKEND_LOG="$tmp/baseline.log" \
PI_N19_REAL_BACKEND="$script_dir/auth-backend-v1.sh" \
LICIUM_AUTH_BACKEND_COMMAND="$tmp/backend-spy.sh" \
LICIUM_AUTH_BACKEND_PROVIDER=sqlite-provider-v1 \
    "$node" "$script_dir/invoke-mapped-authentication.mjs" \
    "$adapter/map-request.mjs" "$auth_source" \
    >"$tmp/baseline-invoke.out" 2>"$tmp/baseline-invoke.err"
if [ -s "$tmp/baseline-invoke.err" ] ||
    ! grep -F -x -q PI_N19_MAPPED_AUTHENTICATION_REACHED \
        "$tmp/baseline-invoke.out"
then
    echo PI_N19_BASELINE_INVOCATION_INVALID >&2
    exit 1
fi
"$verifier" "$tmp/baseline.tsv" "$tmp/baseline.log" \
    >"$tmp/baseline.out" 2>"$tmp/baseline.err"
if [ -s "$tmp/baseline.err" ] ||
    ! grep -F -x -q RAW_PROTOCOL_ALIAS_BOUNDARY_VALID "$tmp/baseline.out"
then
    echo PI_N19_BASELINE_INVALID >&2
    exit 1
fi
echo 'ok BASELINE'

cp -R "$adapter" "$tmp/adapter"
mutant="$tmp/adapter/map-request.mjs"
awk '
    $0 == "  return {" {
        in_return = 1
    }
    in_return && $0 == "    relyingPartyRef," {
        print "    relyingPartyRef: clientId,"
        changed = 1
        next
    }
    { print }
    END { exit !changed }
' "$adapter/map-request.mjs" >"$mutant.new"
mv "$mutant.new" "$mutant"

PI_N19_TRACE="$tmp/mutant.tsv" \
PI_N19_BACKEND_LOG="$tmp/mutant.log" \
PI_N19_REAL_BACKEND="$script_dir/auth-backend-v1.sh" \
LICIUM_AUTH_BACKEND_COMMAND="$tmp/backend-spy.sh" \
LICIUM_AUTH_BACKEND_PROVIDER=sqlite-provider-v1 \
    "$node" "$script_dir/invoke-mapped-authentication.mjs" \
    "$mutant" "$auth_source" \
    >"$tmp/mutant-invoke.out" 2>"$tmp/mutant-invoke.err"
if [ -s "$tmp/mutant-invoke.err" ] ||
    ! grep -F -x -q PI_N19_MAPPED_AUTHENTICATION_REACHED \
        "$tmp/mutant-invoke.out" ||
    ! grep -F -x -q \
        'argument	7	relying_party_ref	client-raw-sentinel-v1' \
        "$tmp/mutant.tsv"
then
    echo PI_N19_MUTANT_NOT_REACHED >&2
    exit 1
fi

set +e
"$verifier" "$tmp/mutant.tsv" "$tmp/mutant.log" \
    >"$tmp/mutant.out" 2>"$tmp/mutant.err"
inner_status=$?
set -e
[ "$inner_status" -ne 0 ] || {
    echo PI_N19_MUTANT_NOT_REJECTED >&2
    exit 1
}
[ "$(grep -F -x -c RAW_PROTOCOL_VALUE_ALIAS "$tmp/mutant.err")" -eq 1 ] || {
    echo PI_N19_TARGET_MARKER_INVALID >&2
    exit 1
}
[ ! -s "$tmp/mutant.out" ] ||
    {
        echo PI_N19_UNEXPECTED_MUTANT_STDOUT >&2
        exit 1
    }
! grep -F -q client-raw-sentinel-v1 "$tmp/mutant.log" ||
    {
        echo PI_N19_BACKEND_LOG_CONTAMINATED >&2
        exit 1
    }

printf '%s\n' \
    "receipt control=PI-N19 class=contract/runtime mutation=raw-client-as-relying-party-ref inner_status=$inner_status marker=RAW_PROTOCOL_VALUE_ALIAS marker_count=1 target_gate=yes reachability=dynamic-backend-request-role-7 valid_outcome=yes canonical_source_raw=0 backend_log_raw=0" \
    'ok PI-N19' \
    'PI_N19_SELF_TEST_VALID 1 baseline 1 control'
