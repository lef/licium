#!/bin/sh
set -eu
here=$(CDPATH= cd "$(dirname "$0")" && pwd)
db=$1
"$here/slice.sh" init "$db"
"$here/slice.sh" seed-e67 "$db"
if "$here/slice.sh" fail-root "$db" root-incomplete >/dev/null 2>&1
then
    echo 'fail-root unexpectedly succeeded' >&2
    exit 1
fi
"$here/slice.sh" healthy-root "$db"
