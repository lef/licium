#!/bin/sh
set -eu
label=$1
expected=$2
shift 2
actual=${TMPDIR:-/tmp}/licium-reference-actual-$$
trap 'test ! -e "$actual" || rm "$actual"' 0 1 2 3 15
"$@" >"$actual"
if diff -u "$expected" "$actual"
then
    echo "ok $label"
else
    echo "not ok $label" >&2
    exit 1
fi
