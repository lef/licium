#!/bin/sh
set -eu
here=$(CDPATH= cd "$(dirname "$0")" && pwd)
model=$(CDPATH= cd "$here/.." && pwd)
expected=$model/tdd/e71-restart-replay
db=${TMPDIR:-/tmp}/licium-e71-$$.db
trap 'test ! -e "$db" || rm "$db"' 0 1 2 3 15
"$here/process-a-e71.sh" "$db"
"$here/process-b-e71.sh" "$db"
"$here/assert-tsv.sh" e71-equivalence "$expected/expected-replay-equivalence.tsv" "$here/slice.sh" query-e71-equivalence "$db"
"$here/assert-tsv.sh" e71-current-variation "$expected/expected-current-variation.tsv" "$here/slice.sh" query-e71-current-variation "$db"
"$here/assert-tsv.sh" e71-omissions "$expected/expected-omission-results.tsv" "$here/slice.sh" query-e71-omissions "$db"
"$here/assert-tsv.sh" e71-reopen "$expected/expected-reopen-summary.tsv" "$here/slice.sh" query-e71-reopen "$db"
"$here/assert-tsv.sh" e71-executor-leaks "$expected/expected-executor-leaks.tsv" "$here/slice.sh" query-e71-executor-leaks "$db"
echo 'E71 restart replay passed'
