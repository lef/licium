#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

[ "$#" -eq 1 ] || {
    echo 'usage: run.sh CASE' >&2
    exit 2
}
case_id=$1
case "$case_id" in
    valid|valid-bob|valid-context-b|wrong-proof|unknown-login|malformed-request) ;;
    *)
        echo "unsupported case: $case_id" >&2
        exit 2
        ;;
esac

case "$case_id" in
    valid|valid-context-b)
        login_identifier=login-alice
        synthetic_proof=toy-password-v1
        ;;
    valid-bob)
        login_identifier=login-bob
        synthetic_proof=toy-password-bob-v1
        ;;
    wrong-proof)
        login_identifier=login-alice
        synthetic_proof=toy-password-wrong
        ;;
    unknown-login)
        login_identifier=login-unknown
        synthetic_proof=toy-password-v1
        ;;
    malformed-request)
        login_identifier=
        synthetic_proof=toy-password-v1
        ;;
esac

account=$(awk -F '	' -v login="$login_identifier" \
    '$1 == login { print $2; exit }' "$script_dir/credential.tsv")
stored_proof=$(awk -F '	' -v login="$login_identifier" \
    '$1 == login { print $3; exit }' "$script_dir/credential.tsv")

if [ "$case_id" != valid ] &&
    [ "$case_id" != valid-bob ] &&
    [ "$case_id" != valid-context-b ]
then
    if [ -z "$login_identifier" ]
    then
        failure=malformed_request
    elif [ -z "$account" ]
    then
        failure=unknown_login
    elif [ "$stored_proof" != "$synthetic_proof" ]
    then
        failure=invalid_proof
    else
        failure=invalid_fixture
    fi
    printf '%s\t%s\t%s\n' "$case_id" rejected "$failure"
    exit 0
fi

[ -n "$account" ] && [ "$stored_proof" = "$synthetic_proof" ] || {
    echo 'valid fixture authentication failed' >&2
    exit 1
}

{
    if [ "$case_id" = valid-context-b ]
    then
        context_ref=context-claims-v2
    else
        context_ref=context-claims-v1
    fi
    awk -F '	' -v context_ref="$context_ref" '
        {
            print "envelope\tcontext_ref\t" context_ref
            print "envelope\tdefinition_ref\t" $2
            print "envelope\tprofile_ref\t" $3
            print "envelope\troot_ref\t" $1
        }
    ' "$script_dir/evaluation-pin.tsv"
    printf '%s\n' \
        'envelope	credential_authority_ref	cred-auth-v1' \
        'envelope	credential_store_revision	credential-store-v1' \
        'envelope	disposition	accepted' \
        'envelope	outcome_persistence	ephemeral' \
        "envelope	stable_protocol_account_key	$account"
    awk -F '	' -v account="$account" \
        '$2 == account && $5 == 1 {
            print "relation\t" $3 "\t" $4
        }' "$script_dir/selected-relations.tsv"
    awk -F '	' -v account="$account" \
        '$2 == account && $5 == 1 {
            print "value\t" $3 "\t" $4
        }' "$script_dir/selected-values.tsv"
} | LC_ALL=C sort
