#!/bin/sh
set -eu
here=$(CDPATH= cd "$(dirname "$0")" && pwd)
prefix=${TMPDIR:-/tmp}/licium-e70-rollback-$$
trap 'test ! -e "$prefix.after-transition.db" || rm "$prefix.after-transition.db"; test ! -e "$prefix.after-observation.db" || rm "$prefix.after-observation.db"' 0 1 2 3 15
for failpoint in after-observation after-transition
do
    db=$prefix.$failpoint.db
    "$here/prepare-e69.sh" "$db"
    if "$here/slice.sh" apply-effect "$db" effect-fail state-0 result-1 transition-fail observation-fail state-1 view-fail "$failpoint" >/dev/null 2>&1
    then
        echo "$failpoint unexpectedly succeeded" >&2
        exit 1
    fi
    "$here/slice.sh" query-e70-rollback "$db" "$failpoint"
done
