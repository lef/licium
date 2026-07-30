#!/bin/sh
set -eu

[ "$#" -eq 2 ] || {
    echo "usage: verify-bc06-session-layout.sh SESSION_DIR preseal|sealed" >&2
    exit 2
}

session_dir=$1
stage=$2
case "$stage" in preseal|sealed) ;; *) exit 2 ;; esac

fail()
{
    echo "$1" >&2
    exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

find "$session_dir" -type l -print | awk 'NR == 1 { exit 1 }' ||
    fail BC06_SESSION_LAYOUT_INVALID

{
    printf '%s\n' \
        aggregate-dispositions.tsv \
        assertions.tsv \
        canonical-comparison.tsv \
        control-receipts.tsv \
        lifecycle-command-receipt.tsv \
        run-metadata.tsv
    [ "$stage" != "sealed" ] || printf '%s\n' \
        outer-receipt.tsv payload-manifest.tsv report.tsv
    printf '%s\n' lifecycle/run-a/sentinel-a
} | LC_ALL=C sort >"$tmp/expected"

{
    find "$session_dir" -maxdepth 1 -type f -print
    find "$session_dir/lifecycle" -type f -print
} |
    while IFS= read -r file
    do
        printf '%s\n' "${file#"$session_dir"/}"
    done |
    LC_ALL=C sort >"$tmp/actual"
cmp -s "$tmp/expected" "$tmp/actual" ||
    fail BC06_SESSION_LAYOUT_INVALID

printf '%s\n' \
    . \
    lifecycle \
    lifecycle/run-a \
    lifecycle/run-b \
    run-a \
    run-b |
    LC_ALL=C sort >"$tmp/expected-dirs"
{
    find "$session_dir" -mindepth 1 -maxdepth 1 -type d -print
    find "$session_dir/lifecycle" -mindepth 1 -type d -print
} |
    while IFS= read -r directory
    do
        relative=${directory#"$session_dir"}
        [ -n "$relative" ] || relative=.
        relative=${relative#/}
        printf '%s\n' "$relative"
    done |
    {
        printf '.\n'
        cat
    } |
    LC_ALL=C sort >"$tmp/actual-dirs"
cmp -s "$tmp/expected-dirs" "$tmp/actual-dirs" ||
    fail BC06_SESSION_LAYOUT_INVALID

echo BC06_SESSION_LAYOUT_VALID
