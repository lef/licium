#!/bin/sh
set -eu
here=$(CDPATH= cd "$(dirname "$0")" && pwd)
prefix=${TMPDIR:-/tmp}/licium-e72-failure-$$
trap 'for f in "$prefix".*.db; do test ! -e "$f" || rm "$f"; done' 0 1 2 3 15

for failpoint in effect-after-observation effect-after-transition
do
    db=$prefix.$failpoint.db
    "$here/prepare-e69.sh" "$db"
    point=${failpoint#effect-}
    if "$here/slice.sh" apply-effect "$db" effect-fail state-0 result-1 transition-fail observation-fail state-1 view-fail "$point" >/dev/null 2>&1
    then exit 1; fi
    "$here/slice.sh" query-e72-failure-state "$db" "$failpoint"
done

db=$prefix.publication-after-head.db
"$here/prepare-e67.sh" "$db"
"$here/slice.sh" seed-e72-publication-base "$db"
if "$here/slice.sh" fail-publication "$db" >/dev/null 2>&1; then exit 1; fi
"$here/slice.sh" query-e72-failure-state "$db" publication-after-head

db=$prefix.root-after-root.db
"$here/prepare-e67.sh" "$db"
"$here/slice.sh" seed-e72-publication-base "$db"
if "$here/slice.sh" fail-root "$db" root-fail >/dev/null 2>&1; then exit 1; fi
"$here/slice.sh" query-e72-failure-state "$db" root-after-root
