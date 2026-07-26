#!/bin/sh
set -eu
here=$(CDPATH= cd "$(dirname "$0")" && pwd)
model=$(CDPATH= cd "$here/.." && pwd)
expected=$model/tdd/e70-observed-effect
db=${TMPDIR:-/tmp}/licium-e70-$$.db
trap 'test ! -e "$db" || rm "$db"' 0 1 2 3 15
"$here/prepare-e69.sh" "$db"
"$here/assert-tsv.sh" e70-outcomes "$expected/expected-effect-outcomes.tsv" "$here/run-e70-outcomes.sh" "$db"
"$here/assert-tsv.sh" e70-final "$expected/expected-final-state.tsv" "$here/slice.sh" query-e70-final "$db"
"$here/assert-tsv.sh" e70-links "$expected/expected-observation-links.tsv" "$here/slice.sh" query-e70-links "$db"
"$here/assert-tsv.sh" e70-rollbacks "$expected/expected-rollback-summaries.tsv" "$here/run-e70-rollbacks.sh"
"$here/assert-tsv.sh" e70-retry "$expected/expected-retry.tsv" "$here/query-e70-retry.sh" "$db"
echo 'E70 observed effect passed'
