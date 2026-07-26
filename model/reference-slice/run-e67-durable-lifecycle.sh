#!/bin/sh
set -eu
here=$(CDPATH= cd "$(dirname "$0")" && pwd)
model=$(CDPATH= cd "$here/.." && pwd)
expected=$model/tdd/e67-durable-lifecycle
db=${TMPDIR:-/tmp}/licium-e67-$$.db
trap 'test ! -e "$db" || rm "$db"' 0 1 2 3 15

"$here/slice.sh" init "$db"
"$here/assert-tsv.sh" e67-initial "$expected/expected-initial-state.tsv" "$here/slice.sh" query-e67-initial "$db"
"$here/slice.sh" seed-e67 "$db"
if "$here/slice.sh" fail-root "$db" root-incomplete >/dev/null 2>&1
then
    echo 'fail-root unexpectedly succeeded' >&2
    exit 1
fi
"$here/slice.sh" healthy-root "$db"
"$here/assert-tsv.sh" e67-inventory "$expected/expected-ingest-inventory.tsv" "$here/slice.sh" query-e67-inventory "$db"
"$here/assert-tsv.sh" e67-members "$expected/expected-root-members.tsv" "$here/slice.sh" query-e67-members "$db"
"$here/assert-tsv.sh" e67-duplicates "$expected/expected-duplicate-outcomes.tsv" "$here/slice.sh" query-e67-duplicates "$db"
"$here/assert-tsv.sh" e67-recovery "$expected/expected-incomplete-recovery.tsv" "$here/slice.sh" query-e67-recovery "$db"
echo 'E67 durable lifecycle passed'
