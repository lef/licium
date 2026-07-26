#!/bin/sh
set -eu
here=$(CDPATH= cd "$(dirname "$0")" && pwd)
model=$(CDPATH= cd "$here/.." && pwd)
expected=$model/tdd/e72-recovery-explanation
db=${TMPDIR:-/tmp}/licium-e72-$$.db
trap 'test ! -e "$db" || rm "$db"' 0 1 2 3 15
"$here/process-a-e71.sh" "$db"
"$here/assert-tsv.sh" e72-explanation "$expected/expected-explanation-closure.tsv" "$here/slice.sh" query-e72-explanation "$db"
"$here/assert-tsv.sh" e72-linkage "$expected/expected-linkage-completeness.tsv" "$here/slice.sh" query-e72-linkage "$db"
"$here/assert-tsv.sh" e72-failures "$expected/expected-failure-recovery.tsv" "$here/run-e72-failures.sh"
"$here/seed-e72-mutations.sh" "$db"
"$here/assert-tsv.sh" e72-integrity "$expected/expected-integrity-findings.tsv" "$here/slice.sh" query-e72-integrity "$db"
"$here/assert-tsv.sh" e72-secret-leaks "$expected/expected-secret-leaks.tsv" "$here/slice.sh" query-e72-secret-leaks "$db"
echo 'E72 recovery and explanation passed'
