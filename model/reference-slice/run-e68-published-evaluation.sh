#!/bin/sh
set -eu
here=$(CDPATH= cd "$(dirname "$0")" && pwd)
model=$(CDPATH= cd "$here/.." && pwd)
expected=$model/tdd/e68-published-evaluation
db=${TMPDIR:-/tmp}/licium-e68-$$.db
trap 'test ! -e "$db" || rm "$db"' 0 1 2 3 15
"$here/prepare-e67.sh" "$db"
"$here/slice.sh" seed-e68 "$db"
"$here/assert-tsv.sh" e68-publications "$expected/expected-publication-decisions.tsv" "$here/slice.sh" query-e68-publications "$db"
"$here/assert-tsv.sh" e68-heads "$expected/expected-heads.tsv" "$here/slice.sh" query-e68-heads "$db"
"$here/assert-tsv.sh" e68-inputs "$expected/expected-evaluation-inputs.tsv" "$here/slice.sh" query-e68-inputs "$db"
"$here/assert-tsv.sh" e68-exact-published "$expected/expected-exact-published.tsv" "$here/slice.sh" query-e68-exact-published "$db"
"$here/assert-tsv.sh" e68-secret-leaks "$expected/expected-secret-leaks.tsv" "$here/slice.sh" query-e68-secret-leaks "$db"
echo 'E68 published evaluation passed'
