#!/bin/sh
set -eu
here=$(CDPATH= cd "$(dirname "$0")" && pwd)
model=$(CDPATH= cd "$here/.." && pwd)
expected=$model/tdd/e69-pure-read-view
db=${TMPDIR:-/tmp}/licium-e69-$$.db
trap 'test ! -e "$db" || rm "$db"' 0 1 2 3 15
"$here/prepare-e68.sh" "$db"
"$here/slice.sh" seed-e69 "$db"
"$here/assert-tsv.sh" e69-results "$expected/expected-evaluation-results.tsv" "$here/slice.sh" query-e69-results "$db"
"$here/assert-tsv.sh" e69-writefree "$expected/expected-read-write-diff.tsv" "$here/check-e69-writefree.sh" "$db"
"$here/assert-tsv.sh" e69-view-provenance "$expected/expected-view-provenance.tsv" "$here/slice.sh" query-e69-view-provenance "$db"
"$here/assert-tsv.sh" e69-view-rows "$expected/expected-view-rows.tsv" "$here/slice.sh" query-e69-view-rows "$db"
"$here/assert-tsv.sh" e69-secret-leaks "$expected/expected-secret-leaks.tsv" "$here/slice.sh" query-e69-secret-leaks "$db"
echo 'E69 pure read and view passed'
