#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
node=${NODE:-node}
curl=${CURL:-curl}

[ "$($node --version)" = v22.22.2 ] || {
    echo OIDC_SELECTION_NODE_VERSION_INVALID >&2
    exit 1
}

tmp=$(mktemp -d)
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

cd "$script_dir"
"$node" server.mjs >"$tmp/server.out" 2>"$tmp/server.err" &
server_pid=$!

i=0
while [ "$i" -lt 10 ]
do
    if "$curl" -fsS http://127.0.0.1:56000/.well-known/openid-configuration \
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
    echo OIDC_SELECTION_SERVER_NOT_READY >&2
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

auth_url="http://127.0.0.1:56000/auth?client_id=toy-rp&redirect_uri=http%3A%2F%2F127.0.0.1%3A56001%2Fcb&response_type=code&scope=openid%20profile&state=synthetic-state-v1&nonce=synthetic-nonce-v1&code_challenge=$challenge&code_challenge_method=S256"
"$curl" -sS -D "$tmp/auth.headers" -o "$tmp/auth.body" \
    -c "$tmp/cookies" "$auth_url"
location=$(
    awk 'BEGIN { IGNORECASE=1 }
        /^location:/ { sub(/\r$/, ""); print substr($0, index($0, ":") + 2) }' \
        "$tmp/auth.headers"
)
case "$location" in /interaction/*) ;; *) exit 1 ;; esac

"$curl" -sS -D "$tmp/login.headers" -o "$tmp/login.html" \
    -b "$tmp/cookies" -c "$tmp/cookies" \
    "http://127.0.0.1:56000$location"
"$curl" -sS -D "$tmp/login-submit.headers" -o "$tmp/login-submit.body" \
    -b "$tmp/cookies" -c "$tmp/cookies" \
    -X POST \
    --data-urlencode prompt=login \
    --data-urlencode login=account-alice \
    --data-urlencode password=synthetic-selection-only \
    "http://127.0.0.1:56000$location"
resume=$(
    awk 'BEGIN { IGNORECASE=1 }
        /^location:/ { sub(/\r$/, ""); print substr($0, index($0, ":") + 2) }' \
        "$tmp/login-submit.headers"
)
"$curl" -sS -D "$tmp/resume.headers" -o "$tmp/resume.body" \
    -b "$tmp/cookies" -c "$tmp/cookies" "$resume"
consent_location=$(
    awk 'BEGIN { IGNORECASE=1 }
        /^location:/ { sub(/\r$/, ""); print substr($0, index($0, ":") + 2) }' \
        "$tmp/resume.headers"
)
case "$consent_location" in /interaction/*) ;; *) exit 1 ;; esac

"$curl" -sS -D "$tmp/consent.headers" -o "$tmp/consent.html" \
    -b "$tmp/cookies" -c "$tmp/cookies" \
    "http://127.0.0.1:56000$consent_location"
"$curl" -sS -D "$tmp/consent-submit.headers" \
    -o "$tmp/consent-submit.body" \
    -b "$tmp/cookies" -c "$tmp/cookies" \
    -X POST --data-urlencode prompt=consent \
    "http://127.0.0.1:56000$consent_location"
final_resume=$(
    awk 'BEGIN { IGNORECASE=1 }
        /^location:/ { sub(/\r$/, ""); print substr($0, index($0, ":") + 2) }' \
        "$tmp/consent-submit.headers"
)
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
    -X POST http://127.0.0.1:56000/token \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode grant_type=authorization_code \
    --data-urlencode client_id=toy-rp \
    --data-urlencode redirect_uri=http://127.0.0.1:56001/cb \
    --data-urlencode code="$code" \
    --data-urlencode code_verifier="$verifier"
grep -q '^HTTP/.* 200 ' "$tmp/token.headers"

"$curl" -sS http://127.0.0.1:56000/jwks >"$tmp/jwks.json"
"$node" verify-token.mjs "$tmp/token.json" "$tmp/jwks.json" \
    >"$tmp/verified.json"
access_token=$(sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p' "$tmp/token.json")
[ -n "$access_token" ] || exit 1
"$curl" -sS -H "Authorization: Bearer $access_token" \
    http://127.0.0.1:56000/me >"$tmp/userinfo.json"

awk '
    /"sub":"account-alice"/ { has_sub = 1 }
    /"name":"Synthetic Alice"/ { has_name = 1 }
    /"preferred_username":"alice.synthetic"/ { has_username = 1 }
    END { exit !(has_sub && has_name && has_username) }
' "$tmp/userinfo.json"

no_pkce="http://127.0.0.1:56000/auth?client_id=toy-rp&redirect_uri=http%3A%2F%2F127.0.0.1%3A56001%2Fcb&response_type=code&scope=openid%20profile&state=no-pkce-state&nonce=no-pkce-nonce"
"$curl" -sS -D "$tmp/no-pkce.headers" -o "$tmp/no-pkce.body" "$no_pkce"
grep -q 'error=invalid_request' "$tmp/no-pkce.headers"

printf 'engine\toidc-provider\t9.11.1\n'
printf 'node\t%s\n' "$($node --version)"
printf 'authorization-code-pkce\tPASS\n'
printf 'id-token-verification\tPASS\n'
printf 'userinfo-selected-claims\tPASS\n'
printf 'no-pkce-rejection\tPASS\n'
printf 'OIDC_PROVIDER_SELECTION_SPIKE_VALID\n'
