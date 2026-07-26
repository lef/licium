#!/bin/sh
set -eu
here=$(CDPATH= cd "$(dirname "$0")" && pwd)
db=$1
prefix=${TMPDIR:-/tmp}/licium-e69-snapshot-$$
trap 'test ! -e "$prefix.before" || rm "$prefix.before"; test ! -e "$prefix.after" || rm "$prefix.after"; test ! -e "$prefix.read" || rm "$prefix.read"' 0 1 2 3 15
for read_ref in evaluation-read-1 evaluation-read-2
do
    sqlite3 -batch "$db" .dump | LC_ALL=C sort >"$prefix.before"
    "$here/slice.sh" ordinary-evaluate "$db" "$read_ref" >"$prefix.read"
    sqlite3 -batch "$db" .dump | LC_ALL=C sort >"$prefix.after"
    if cmp -s "$prefix.before" "$prefix.after"
    then
        printf '%s\t0\n' "$read_ref"
    else
        printf '%s\t1\n' "$read_ref"
    fi
done
