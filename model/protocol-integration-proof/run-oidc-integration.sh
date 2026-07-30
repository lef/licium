#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
engine_dir="$script_dir/engine-selection/oidc-provider"
integration_dir="$engine_dir/integration"
adapter_dir="$script_dir/adapters/oidc-provider-v1"
backend_command="$script_dir/auth-backend-v1.sh"
server_source=${LICIUM_OIDC_SERVER_SOURCE:-"$integration_dir/server.mjs"}
node=${NODE:-node}
curl=${CURL:-curl}

[ "$#" -eq 1 ] || [ "$#" -eq 2 ] || {
    echo 'usage: run-oidc-integration.sh PROVIDER [SUBJECT_SCENARIO]' >&2
    exit 2
}
backend_provider=$1
subject_scenario=${2:-default}
case "$backend_provider" in
    sqlite-provider-v1|flatfile-posix-provider-v1) ;;
    *)
        echo "unsupported backend provider: $backend_provider" >&2
        exit 2
        ;;
esac

claim_context=context-claims-v1
subject_type=public
subject_semantics=public-v1
subject_revision=subject-policy-v1
subject_sector=-
expected_subject=sub-public-alice-v1
login_identifier=login-alice
synthetic_proof=toy-password-v1
expected_account=account-alice
entity_ref=entity-alice
source_mode=exact_root
source_ref=write-receipt-v1
expected_root=root-auth-v1
expected_display_name='Alice Example'
require_relation=yes
report_source=no
forced_reauth=no
engine_decoy=-
expect_migration=no
expected_login_status=303
case "$subject_scenario" in
    default) ;;
    context-b)
        claim_context=context-claims-v2
        ;;
    policy-v2)
        subject_revision=subject-policy-v2
        expect_migration=yes
        expected_login_status=409
        ;;
    pairwise-a)
        subject_type=pairwise
        subject_semantics=pairwise-v1
        subject_sector=https://rp-a.invalid
        expected_subject=sub-pairwise-alice-a-v1
        ;;
    pairwise-b)
        subject_type=pairwise
        subject_semantics=pairwise-v1
        subject_sector=https://rp-b.invalid
        expected_subject=sub-pairwise-alice-b-v1
        ;;
    distinct-account)
        login_identifier=login-bob
        synthetic_proof=toy-password-bob-v1
        expected_account=account-bob
        entity_ref=entity-bob
        expected_subject=sub-public-bob-v1
        expected_display_name='Bob Example'
        require_relation=no
        ;;
    exact-root)
        report_source=yes
        ;;
    published-head)
        source_mode=published_head
        source_ref=publication-auth-v2
        expected_root=root-auth-v2
        expected_display_name='Alice Updated'
        require_relation=no
        report_source=yes
        ;;
    forced-reauth)
        forced_reauth=yes
        engine_decoy=sub-decoy-engine-v1
        ;;
    *)
        echo "unsupported subject scenario: $subject_scenario" >&2
        exit 2
        ;;
esac

[ "$("$node" --version)" = v22.22.2 ] || {
    echo OIDC_INTEGRATION_NODE_VERSION_INVALID >&2
    exit 1
}
[ -d "$engine_dir/node_modules/oidc-provider" ] || {
    echo OIDC_INTEGRATION_DEPENDENCIES_MISSING >&2
    exit 1
}
[ -f "$server_source" ] || {
    echo OIDC_INTEGRATION_SERVER_SOURCE_MISSING >&2
    exit 1
}
if grep -E -i \
    'sqlite3|\.sqlite|sqlite-provider-v1|selected_value|credential[[:space:]]*\(' \
    "$adapter_dir/authenticate.mjs" >/dev/null
then
    echo ADAPTER_BACKEND_SCHEMA_COUPLING >&2
    exit 1
fi
if grep -E \
    'account-alice|login-alice|toy-password|Synthetic Alice|const accounts' \
    "$integration_dir/server.mjs" >/dev/null
then
    echo ENGINE_CANONICAL_USER_RECORD_PRESENT >&2
    exit 1
fi

tmp=$(mktemp -d)
runtime_evidence="$tmp/runtime-evidence"
mkdir "$runtime_evidence"
server_pid=
cleanup()
{
    if [ -n "$server_pid" ]; then
        kill "$server_pid" 2>/dev/null || true
        wait "$server_pid" 2>/dev/null || true
    fi
    rm -rf "$tmp"
}
trap cleanup EXIT HUP INT TERM

LICIUM_AUTH_BACKEND_COMMAND="$backend_command" \
LICIUM_AUTH_BACKEND_PROVIDER="$backend_provider" \
LICIUM_ADAPTER_RECEIPT="$runtime_evidence/adapter-receipt.tsv" \
LICIUM_EVIDENCE_DIR="$runtime_evidence" \
LICIUM_CLAIM_CONTEXT="$claim_context" \
LICIUM_SUBJECT_TYPE="$subject_type" \
LICIUM_SUBJECT_SEMANTICS="$subject_semantics" \
LICIUM_SUBJECT_REVISION="$subject_revision" \
LICIUM_SUBJECT_SECTOR="$subject_sector" \
LICIUM_ENTITY_REF="$entity_ref" \
LICIUM_SOURCE_MODE="$source_mode" \
LICIUM_SOURCE_REF="$source_ref" \
LICIUM_ENGINE_DECOY_SUBJECT="$engine_decoy" \
    "$node" "$server_source" \
    >"$tmp/server.out" 2>"$tmp/server.err" &
server_pid=$!

i=0
while [ "$i" -lt 10 ]
do
    if "$curl" -fsS \
        http://127.0.0.1:56100/.well-known/openid-configuration \
        >"$tmp/discovery.json" 2>/dev/null
    then
        break
    fi
    kill -0 "$server_pid" 2>/dev/null || {
        cat "$tmp/server.err" >&2
        exit 1
    }
    i=$((i + 1))
    sleep 1
done
[ "$i" -lt 10 ] || {
    echo OIDC_INTEGRATION_SERVER_NOT_READY >&2
    exit 1
}

verifier=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~ABCD
challenge=$(
    printf '%s' "$verifier" |
        openssl dgst -sha256 -binary |
        openssl base64 -A |
        tr '+/' '-_' |
        tr -d '='
)

auth_url="http://127.0.0.1:56100/auth?client_id=client-raw-sentinel-v1&redirect_uri=http%3A%2F%2F127.0.0.1%3A56101%2Fcb&response_type=code&scope=openid%20profile&acr_values=acr-raw-sentinel-v1&state=synthetic-state-v1&nonce=synthetic-nonce-v1&code_challenge=$challenge&code_challenge_method=S256"
"$curl" -sS -D "$tmp/auth.headers" -o "$tmp/auth.body" \
    -c "$tmp/cookies" "$auth_url"
location=$(
    awk 'BEGIN { IGNORECASE=1 }
        /^location:/ { sub(/\r$/, ""); print substr($0, index($0, ":") + 2) }' \
        "$tmp/auth.headers"
)
case "$location" in /interaction/*) ;; *) exit 1 ;; esac

"$curl" -sS -o "$tmp/login.body" \
    -b "$tmp/cookies" -c "$tmp/cookies" \
    "http://127.0.0.1:56100$location"
"$curl" -sS -D "$tmp/login-submit.headers" \
    -o "$tmp/login-submit.body" \
    -b "$tmp/cookies" -c "$tmp/cookies" \
    -X POST \
    --data-urlencode login="$login_identifier" \
    --data-urlencode password="$synthetic_proof" \
    "http://127.0.0.1:56100$location"
resume=$(
    awk 'BEGIN { IGNORECASE=1 }
        /^location:/ { sub(/\r$/, ""); print substr($0, index($0, ":") + 2) }' \
        "$tmp/login-submit.headers"
)
login_status=$(awk 'NR == 1 { print $2 }' "$tmp/login-submit.headers")
[ "$login_status" = "$expected_login_status" ] || exit 1
if [ "$expect_migration" = yes ]
then
    [ -z "$resume" ] || exit 1
    grep -F -q 'subject migration required' "$tmp/login-submit.body"
    grep -F -q 'migration_required' \
        "$runtime_evidence/adapter-receipt.tsv"
    printf '%s\n' \
        "backend-provider	$backend_provider" \
        'engine	oidc-provider	9.11.1' \
        'no-token-issued	PASS' \
        'subject-policy-migration-required	PASS' \
        "subject-policy-scenario	$subject_scenario" \
        'OIDC_SUBJECT_MIGRATION_VALID'
    exit 0
fi
[ -n "$resume" ] || exit 1

"$curl" -sS -D "$tmp/resume.headers" -o "$tmp/resume.body" \
    -b "$tmp/cookies" -c "$tmp/cookies" "$resume"
consent_location=$(
    awk 'BEGIN { IGNORECASE=1 }
        /^location:/ { sub(/\r$/, ""); print substr($0, index($0, ":") + 2) }' \
        "$tmp/resume.headers"
)
case "$consent_location" in /interaction/*) ;; *) exit 1 ;; esac

"$curl" -sS -o "$tmp/consent.body" \
    -b "$tmp/cookies" -c "$tmp/cookies" \
    "http://127.0.0.1:56100$consent_location"
"$curl" -sS -D "$tmp/consent-submit.headers" \
    -o "$tmp/consent-submit.body" \
    -b "$tmp/cookies" -c "$tmp/cookies" \
    -X POST "http://127.0.0.1:56100$consent_location"
final_resume=$(
    awk 'BEGIN { IGNORECASE=1 }
        /^location:/ { sub(/\r$/, ""); print substr($0, index($0, ":") + 2) }' \
        "$tmp/consent-submit.headers"
)
[ -n "$final_resume" ] || exit 1

"$curl" -sS -D "$tmp/final.headers" -o "$tmp/final.body" \
    -b "$tmp/cookies" -c "$tmp/cookies" "$final_resume"
callback=$(
    awk 'BEGIN { IGNORECASE=1 }
        /^location:/ { sub(/\r$/, ""); print substr($0, index($0, ":") + 2) }' \
        "$tmp/final.headers"
)
query=$(printf '%s' "$callback" | cut -d'?' -f2-)
code=$(
    printf '%s' "$query" |
        tr '&' '\n' |
        awk -F= '$1 == "code" { print substr($0, 6) }'
)
state=$(
    printf '%s' "$query" |
        tr '&' '\n' |
        awk -F= '$1 == "state" { print substr($0, 7) }'
)
[ -n "$code" ] && [ "$state" = synthetic-state-v1 ] || exit 1

"$curl" -sS -D "$tmp/token.headers" -o "$tmp/token.json" \
    -X POST http://127.0.0.1:56100/token \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode grant_type=authorization_code \
    --data-urlencode client_id=client-raw-sentinel-v1 \
    --data-urlencode redirect_uri=http://127.0.0.1:56101/cb \
    --data-urlencode code="$code" \
    --data-urlencode code_verifier="$verifier"
grep -q '^HTTP/.* 200 ' "$tmp/token.headers"

"$curl" -sS http://127.0.0.1:56100/jwks >"$tmp/jwks.json"
"$node" "$integration_dir/verify-token.mjs" \
    "$tmp/token.json" "$tmp/jwks.json" "$expected_subject" \
    >"$tmp/verified.json"
access_token=$(sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p' \
    "$tmp/token.json")
[ -n "$access_token" ] || exit 1
"$curl" -sS -H "Authorization: Bearer $access_token" \
    http://127.0.0.1:56100/me >"$tmp/userinfo.json"

awk -v expected_subject="$expected_subject" \
    -v expected_display_name="$expected_display_name" \
    -v require_relation="$require_relation" '
    index($0, "\"sub\":\"" expected_subject "\"") { has_sub = 1 }
    index($0, "\"name\":\"" expected_display_name "\"") { has_name = 1 }
    /"member_of":"team-blue"/ { has_relation = 1 }
    END {
        if (require_relation == "yes")
            exit !(has_sub && has_name && has_relation)
        exit !(has_sub && has_name)
    }
' "$tmp/userinfo.json"

grep -F -q \
    "accepted	$backend_provider	$expected_account	$expected_subject	$expected_root	definition-auth-v1	profile-login-v1	$claim_context	ephemeral" \
    "$runtime_evidence/adapter-receipt.tsv"

invalid_url="http://127.0.0.1:56100/auth?client_id=client-raw-sentinel-v1&redirect_uri=http%3A%2F%2F127.0.0.1%3A56101%2Fcb&response_type=code&scope=openid%20profile&acr_values=acr-raw-sentinel-v1&state=invalid-state-v1&nonce=invalid-nonce-v1&prompt=login&code_challenge=$challenge&code_challenge_method=S256"
invalid_cookies="$tmp/invalid-cookies"
if [ "$forced_reauth" = yes ]
then
    invalid_cookies="$tmp/cookies"
else
    : >"$invalid_cookies"
fi
"$curl" -sS -D "$tmp/invalid-auth.headers" \
    -o "$tmp/invalid-auth.body" \
    -b "$invalid_cookies" -c "$invalid_cookies" "$invalid_url"
invalid_location=$(
    awk 'BEGIN { IGNORECASE=1 }
        /^location:/ { sub(/\r$/, ""); print substr($0, index($0, ":") + 2) }' \
        "$tmp/invalid-auth.headers"
)
case "$invalid_location" in /interaction/*) ;; *) exit 1 ;; esac
invalid_status=$(
    "$curl" -sS -o "$tmp/invalid-login.body" \
        -b "$invalid_cookies" -c "$invalid_cookies" \
        -X POST \
        --data-urlencode login="$login_identifier" \
        --data-urlencode password=toy-password-wrong \
        -w '%{http_code}' \
        "http://127.0.0.1:56100$invalid_location"
)
[ "$invalid_status" = 401 ] || exit 1
grep -F -q 'authentication rejected' "$tmp/invalid-login.body"
grep -F -q 'rejected' "$runtime_evidence/adapter-receipt.tsv"
grep -F -q 'invalid_proof' "$runtime_evidence/adapter-receipt.tsv"

if [ "$forced_reauth" = yes ]
then
    "$curl" -sS -D "$tmp/reauth-submit.headers" \
        -o "$tmp/reauth-submit.body" \
        -b "$invalid_cookies" -c "$invalid_cookies" \
        -X POST \
        --data-urlencode login="$login_identifier" \
        --data-urlencode password="$synthetic_proof" \
        "http://127.0.0.1:56100$invalid_location"
    reauth_status=$(awk 'NR == 1 { print $2 }' \
        "$tmp/reauth-submit.headers")
    if [ "$reauth_status" = 409 ] &&
        grep -F -q 'engine user override rejected' "$tmp/reauth-submit.body"
    then
        [ ! -e "$tmp/reauth-token.json" ] || exit 1
        echo ENGINE_USER_OVERRIDE >&2
        exit 1
    fi
    [ "$reauth_status" = 303 ] || exit 1
    reauth_resume=$(
        awk 'BEGIN { IGNORECASE=1 }
            /^location:/ {
                sub(/\r$/, "")
                print substr($0, index($0, ":") + 2)
            }' "$tmp/reauth-submit.headers"
    )
    [ -n "$reauth_resume" ] || exit 1
    "$curl" -sS -D "$tmp/reauth-resume.headers" \
        -o "$tmp/reauth-resume.body" \
        -b "$invalid_cookies" -c "$invalid_cookies" "$reauth_resume"
    reauth_next=$(
        awk 'BEGIN { IGNORECASE=1 }
            /^location:/ {
                sub(/\r$/, "")
                print substr($0, index($0, ":") + 2)
            }' "$tmp/reauth-resume.headers"
    )
    case "$reauth_next" in
        /interaction/*)
            "$curl" -sS -o "$tmp/reauth-consent.body" \
                -b "$invalid_cookies" -c "$invalid_cookies" \
                "http://127.0.0.1:56100$reauth_next"
            "$curl" -sS -D "$tmp/reauth-consent-submit.headers" \
                -o "$tmp/reauth-consent-submit.body" \
                -b "$invalid_cookies" -c "$invalid_cookies" \
                -X POST "http://127.0.0.1:56100$reauth_next"
            reauth_final_resume=$(
                awk 'BEGIN { IGNORECASE=1 }
                    /^location:/ {
                        sub(/\r$/, "")
                        print substr($0, index($0, ":") + 2)
                    }' "$tmp/reauth-consent-submit.headers"
            )
            [ -n "$reauth_final_resume" ] || exit 1
            "$curl" -sS -D "$tmp/reauth-final.headers" \
                -o "$tmp/reauth-final.body" \
                -b "$invalid_cookies" -c "$invalid_cookies" \
                "$reauth_final_resume"
            reauth_callback=$(
                awk 'BEGIN { IGNORECASE=1 }
                    /^location:/ {
                        sub(/\r$/, "")
                        print substr($0, index($0, ":") + 2)
                    }' "$tmp/reauth-final.headers"
            )
            ;;
        http://127.0.0.1:56101/cb?*)
            reauth_callback=$reauth_next
            ;;
        *)
            exit 1
            ;;
    esac
    reauth_query=$(printf '%s' "$reauth_callback" | cut -d'?' -f2-)
    reauth_code=$(
        printf '%s' "$reauth_query" |
            tr '&' '\n' |
            awk -F= '$1 == "code" { print substr($0, 6) }'
    )
    reauth_state=$(
        printf '%s' "$reauth_query" |
            tr '&' '\n' |
            awk -F= '$1 == "state" { print substr($0, 7) }'
    )
    [ -n "$reauth_code" ] &&
        [ "$reauth_state" = invalid-state-v1 ] || exit 1
    "$curl" -sS -D "$tmp/reauth-token.headers" \
        -o "$tmp/reauth-token.json" \
        -X POST http://127.0.0.1:56100/token \
        -H 'Content-Type: application/x-www-form-urlencoded' \
        --data-urlencode grant_type=authorization_code \
        --data-urlencode client_id=client-raw-sentinel-v1 \
        --data-urlencode redirect_uri=http://127.0.0.1:56101/cb \
        --data-urlencode code="$reauth_code" \
        --data-urlencode code_verifier="$verifier"
    grep -q '^HTTP/.* 200 ' "$tmp/reauth-token.headers"
    "$node" "$integration_dir/verify-token.mjs" \
        "$tmp/reauth-token.json" "$tmp/jwks.json" "$expected_subject" \
        invalid-nonce-v1 \
        >"$tmp/reauth-verified.json"
    reauth_access_token=$(
        sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p' \
            "$tmp/reauth-token.json"
    )
    [ -n "$reauth_access_token" ] || exit 1
    "$curl" -sS -H "Authorization: Bearer $reauth_access_token" \
        http://127.0.0.1:56100/me >"$tmp/reauth-userinfo.json"
    awk -v expected_subject="$expected_subject" '
        index($0, "\"sub\":\"" expected_subject "\"") { has_sub = 1 }
        /"name":"Alice Example"/ { has_name = 1 }
        /"member_of":"team-blue"/ { has_relation = 1 }
        END { exit !(has_sub && has_name && has_relation) }
    ' "$tmp/reauth-userinfo.json"
fi

no_pkce="http://127.0.0.1:56100/auth?client_id=client-raw-sentinel-v1&redirect_uri=http%3A%2F%2F127.0.0.1%3A56101%2Fcb&response_type=code&scope=openid%20profile&acr_values=acr-raw-sentinel-v1&state=no-pkce-state&nonce=no-pkce-nonce"
"$curl" -sS -D "$tmp/no-pkce.headers" \
    -o "$tmp/no-pkce.body" "$no_pkce"
grep -q 'error=invalid_request' "$tmp/no-pkce.headers"

for evidence_file in adapter-receipt.tsv backend-request.tsv backend.log \
    outcome.tsv projection-receipt.tsv
do
    LC_ALL=C sort -o "$runtime_evidence/$evidence_file" \
        "$runtime_evidence/$evidence_file"
done

external_evidence=${OIDC_EVIDENCE_DIR:-}
if [ -n "$external_evidence" ]
then
    [ -d "$external_evidence" ] || {
        echo OIDC_EVIDENCE_DIR_INVALID >&2
        exit 1
    }
    [ -z "$(find "$external_evidence" -mindepth 1 -maxdepth 1 \
        -print -quit)" ] || {
        echo OIDC_EVIDENCE_DIR_NOT_EMPTY >&2
        exit 1
    }
    for evidence_file in adapter-receipt.tsv backend-request.tsv backend.log \
        outcome.tsv projection-receipt.tsv
    do
        cp "$runtime_evidence/$evidence_file" \
            "$external_evidence/$evidence_file"
    done
fi

if grep -R -F 'secret-never-project-v1' "$tmp" >/dev/null
then
    echo OIDC_SECRET_LEAK >&2
    exit 1
fi
if [ "${OIDC_REPORT_SURFACE_SCAN:-no}" = yes ]
then
    printf '%s\n' 'oidc-all-surfaces-nonleakage	PASS'
fi

printf '%s\n' \
    'adapter-backend-contract	auth-backend-v1' \
    'authorization-code-pkce	PASS' \
    'backend-invalid-rejection	PASS' \
    "backend-provider	$backend_provider" \
    'canonical-engine-user-record	ABSENT' \
    'engine	oidc-provider	9.11.1' \
    'id-token-verification	PASS' \
    'no-pkce-rejection	PASS'
if [ "$subject_scenario" != default ]
then
    if [ "$forced_reauth" = yes ]
    then
        printf '%s\n' \
            'engine-decoy-ignored	PASS' \
            'forced-reauthentication	PASS' \
            "reauth-subject	$expected_subject"
    elif [ "$report_source" = yes ]
    then
        printf '%s\n' \
            "root-ref	$expected_root" \
            "source-mode	$source_mode" \
            "source-ref	$source_ref" \
            "userinfo-display-name	$expected_display_name"
    else
        printf '%s\n' \
            "subject	$expected_subject" \
            "subject-policy-scenario	$subject_scenario"
    fi
fi
printf '%s\n' \
    'userinfo-selected-claims	PASS' \
    'OIDC_INTEGRATION_VALID'
