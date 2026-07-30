#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
verifier="$script_dir/verify-backend-request-vocabulary.sh"
auth_source="$script_dir/adapters/oidc-provider-v1/authenticate.mjs"
node=${NODE:-node}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

cat >"$tmp/backend-spy.sh" <<'SPY'
#!/bin/sh
set -eu
: >"$PI_N03_TRACE"
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
    printf 'argument\t%s\t%s\t%s\n' "$i" "$role" "$value" >>"$PI_N03_TRACE"
    i=$((i + 1))
done
[ "$#" -ge 10 ] || exit 2
exec "$PI_N03_REAL_BACKEND" \
    "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}"
SPY
chmod +x "$tmp/backend-spy.sh"

PI_N03_TRACE="$tmp/baseline.tsv" \
PI_N03_REAL_BACKEND="$script_dir/auth-backend-v1.sh" \
LICIUM_AUTH_BACKEND_COMMAND="$tmp/backend-spy.sh" \
LICIUM_AUTH_BACKEND_PROVIDER=sqlite-provider-v1 \
    "$node" "$script_dir/invoke-adapter-pi-n03.mjs" "$auth_source" \
    >"$tmp/baseline-invoke.out" 2>"$tmp/baseline-invoke.err"
if [ -s "$tmp/baseline-invoke.err" ] ||
    ! grep -F -x -q PI_N03_ADAPTER_PATH_REACHED "$tmp/baseline-invoke.out"
then
    echo PI_N03_BASELINE_INVOCATION_INVALID >&2
    exit 1
fi
"$verifier" "$tmp/baseline.tsv" \
    >"$tmp/baseline.out" 2>"$tmp/baseline.err"
if [ -s "$tmp/baseline.err" ] ||
    ! grep -F -x -q BACKEND_REQUEST_VOCABULARY_VALID "$tmp/baseline.out"
then
    echo PI_N03_BASELINE_INVALID >&2
    exit 1
fi
echo 'ok BASELINE'

awk '
    {
        if ($0 == "      assuranceRequirementRef,") {
            print
            print "      '\''client_id=client-raw-sentinel-v1'\'',"
            changed = 1
        } else {
            print
        }
    }
    END { exit !changed }
' "$auth_source" >"$tmp/mutant.mjs"

PI_N03_TRACE="$tmp/mutant.tsv" \
PI_N03_REAL_BACKEND="$script_dir/auth-backend-v1.sh" \
LICIUM_AUTH_BACKEND_COMMAND="$tmp/backend-spy.sh" \
LICIUM_AUTH_BACKEND_PROVIDER=sqlite-provider-v1 \
    "$node" "$script_dir/invoke-adapter-pi-n03.mjs" "$tmp/mutant.mjs" \
    >"$tmp/mutant-invoke.out" 2>"$tmp/mutant-invoke.err"
if [ -s "$tmp/mutant-invoke.err" ] ||
    ! grep -F -x -q PI_N03_ADAPTER_PATH_REACHED "$tmp/mutant-invoke.out" ||
    ! grep -F -x -q \
        'argument	11	unexpected	client_id=client-raw-sentinel-v1' \
        "$tmp/mutant.tsv"
then
    echo PI_N03_MUTANT_NOT_REACHED >&2
    exit 1
fi

set +e
"$verifier" "$tmp/mutant.tsv" \
    >"$tmp/mutant.out" 2>"$tmp/mutant.err"
inner_status=$?
set -e
[ "$inner_status" -ne 0 ] || {
    echo PI_N03_MUTANT_NOT_REJECTED >&2
    exit 1
}
[ "$(grep -F -x -c PROTOCOL_LEAKS_INTO_CORE "$tmp/mutant.err")" -eq 1 ] ||
    {
        echo PI_N03_TARGET_MARKER_INVALID >&2
        exit 1
    }
[ ! -s "$tmp/mutant.out" ] || {
    echo PI_N03_UNEXPECTED_MUTANT_STDOUT >&2
    exit 1
}

printf '%s\n' \
    "receipt control=PI-N03 class=contract/runtime mutation=reachable-eleventh-client-id-argument inner_status=$inner_status marker=PROTOCOL_LEAKS_INTO_CORE marker_count=1 target_gate=yes reachability=dynamic-valid-authentication" \
    'ok PI-N03' \
    'PI_N03_SELF_TEST_VALID 1 baseline 1 control'
