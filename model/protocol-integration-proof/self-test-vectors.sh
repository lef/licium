#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
verifier="$script_dir/verify-vectors.sh"
source_vectors="$script_dir/vectors"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

"$verifier" >"$tmp/positive.out" 2>"$tmp/positive.err"
[ "$(cat "$tmp/positive.out")" = PROTOCOL_INTEGRATION_VECTORS_VALID ] &&
    [ ! -s "$tmp/positive.err" ] || {
    echo VECTOR_SELF_TEST_BASELINE_INVALID >&2
    exit 1
}
echo 'ok BASELINE'

rebind()
{
    vectors=$1
    tmp_bindings=$2
    while IFS='	' read -r name _old_digest
    do
        digest=$(sha256sum "$vectors/$name" | awk '{ print $1 }')
        printf '%s\t%s\n' "$name" "$digest"
    done <"$vectors/vector-bindings.tsv" >"$tmp_bindings"
    mv "$tmp_bindings" "$vectors/vector-bindings.tsv"
    (
        cd "$vectors"
        sha256sum vector-bindings.tsv >vector-bindings.sha256
    )
}

run_control()
{
    id=$1
    expected=$2
    vectors="$tmp/$id/vectors"
    mkdir -p "$tmp/$id"
    cp -R "$source_vectors" "$vectors"

    case "$id" in
        V-N01)
            sed 's/Alice Example/Alice Mutant/' \
                "$vectors/expected-projection.tsv" \
                >"$tmp/$id/mutated.tsv"
            mv "$tmp/$id/mutated.tsv" "$vectors/expected-projection.tsv"
            ;;
        V-N02)
            cut -f1,2 "$vectors/credential-store.tsv" \
                >"$tmp/$id/mutated.tsv"
            mv "$tmp/$id/mutated.tsv" "$vectors/credential-store.tsv"
            rebind "$vectors" "$tmp/$id/rebound.tsv"
            ;;
        V-N03)
            {
                sed -n '2p' "$vectors/expected-projection.tsv"
                sed -n '1p' "$vectors/expected-projection.tsv"
            } >"$tmp/$id/mutated.tsv"
            mv "$tmp/$id/mutated.tsv" "$vectors/expected-projection.tsv"
            rebind "$vectors" "$tmp/$id/rebound.tsv"
            ;;
        V-N04)
            rm "$vectors/credential-store.tsv"
            ;;
        V-N05)
            printf 'extra\tunbound\n' >"$vectors/extra.tsv"
            ;;
        V-N06)
            sed '1s/	[0-9a-f]/	0/' "$vectors/vector-bindings.tsv" \
                >"$tmp/$id/mutated.tsv"
            if cmp -s "$tmp/$id/mutated.tsv" "$vectors/vector-bindings.tsv"
            then
                sed '1s/	[0-9a-f]/	1/' "$vectors/vector-bindings.tsv" \
                    >"$tmp/$id/mutated.tsv"
            fi
            mv "$tmp/$id/mutated.tsv" "$vectors/vector-bindings.tsv"
            ;;
        *) exit 1 ;;
    esac

    set +e
    VECTORS_DIR="$vectors" "$verifier" \
        >"$tmp/$id/stdout" 2>"$tmp/$id/stderr"
    status=$?
    set -e
    [ "$status" -ne 0 ] || {
        echo "not ok $id status-zero" >&2
        exit 1
    }
    [ ! -s "$tmp/$id/stdout" ] || {
        echo "not ok $id unexpected-stdout" >&2
        exit 1
    }
    [ "$(cat "$tmp/$id/stderr")" = "$expected" ] || {
        echo "not ok $id marker-mismatch" >&2
        cat "$tmp/$id/stderr" >&2
        exit 1
    }
    printf 'ok %s %s\n' "$id" "$expected"
}

while IFS='	' read -r id _class _mutation marker
do
    run_control "$id" "$marker"
done <"$source_vectors/vector-controls.tsv"

echo 'PROTOCOL_INTEGRATION_VECTOR_SELF_TEST_VALID 1 baseline 6 controls'
