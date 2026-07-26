#!/bin/sh
set -eu
here=$(CDPATH= cd "$(dirname "$0")" && pwd)
model=$(CDPATH= cd "$here/.." && pwd)
group=$1
db=${TMPDIR:-/tmp}/licium-negative-$group-$$.db
actual=${TMPDIR:-/tmp}/licium-negative-$group-$$.actual
trap 'test ! -e "$db" || rm "$db"; test ! -e "$actual" || rm "$actual"' 0 1 2 3 15

prepare()
{
    test ! -e "$db" || rm "$db"
    case $group in
        E67) "$here/prepare-e67.sh" "$db" ;;
        E68) "$here/prepare-e68.sh" "$db" ;;
        E69) "$here/prepare-e68.sh" "$db"; "$here/slice.sh" seed-e69 "$db" ;;
        E70) "$here/prepare-e69.sh" "$db"; "$here/slice.sh" apply-effect "$db" effect-1 state-0 result-1 transition-1 observation-1 state-1 view-effect-1 none >/dev/null ;;
        E71) "$here/process-a-e71.sh" "$db"; "$here/process-b-e71.sh" "$db" ;;
        E72) "$here/process-a-e71.sh" "$db"; "$here/seed-e72-mutations.sh" "$db" ;;
    esac
}

check()
{
    marker=$1; sql=$2; op=$3; expected=$4
    prepare
    sqlite3 -batch -bail "$db" "$sql"
    "$here/slice.sh" "$op" "$db" >"$actual"
    if diff -u "$expected" "$actual" >/dev/null
    then
        echo "negative identity did not fail: $marker" >&2
        exit 1
    fi
    echo "ok $marker"
}

case $group in
E67)
    e=$model/tdd/e67-durable-lifecycle
    check E67_DELIVERY_DUPLICATES "UPDATE delivery_attempt SET outcome='inserted' WHERE delivery_ref='delivery-public-a-retry';" query-e67-duplicates "$e/expected-duplicate-outcomes.tsv"
    check E67_OCCURRENCE_COLLAPSE "PRAGMA foreign_keys=OFF; DELETE FROM root_member WHERE root_ref='root-1' AND object_ref='obj-public-b';" query-e67-members "$e/expected-root-members.tsv"
    check E67_PARTIAL_ROOT "INSERT INTO root VALUES ('root-incomplete','complete');" query-e67-recovery "$e/expected-incomplete-recovery.tsv"
    check E67_INGEST_EVALUATES "INSERT INTO repository_object VALUES ('obj-evaluation-leak','evaluation','unexpected');" query-e67-inventory "$e/expected-ingest-inventory.tsv"
    ;;
E68)
    e=$model/tdd/e68-published-evaluation
    check E68_STORED_IS_HEAD "UPDATE head SET root_ref='root-unpublished',publication_ref='publication-1';" query-e68-heads "$e/expected-heads.tsv"
    check E68_REJECTED_IS_HEAD "UPDATE head SET root_ref='root-rejected',publication_ref='publication-rejected';" query-e68-heads "$e/expected-heads.tsv"
    check E68_AMBIENT_INPUT "UPDATE evaluation_input SET input_ref='root-unpublished' WHERE request_ref='request-published' AND input_role='root';" query-e68-inputs "$e/expected-evaluation-inputs.tsv"
    check E68_SECRET_LEAK "INSERT INTO evaluation_result VALUES ('result-secret','request-published','persisted','complete','accepted','SECRET-E67','root-1');" query-e68-secret-leaks "$e/expected-secret-leaks.tsv"
    ;;
E69)
    e=$model/tdd/e69-pure-read-view
    check E69_READ_WRITES_RESULT "INSERT INTO evaluation_result VALUES ('result-read-write','request-published','persisted','complete','accepted','public-a','root-1'); INSERT INTO evaluation_run VALUES ('evaluation-read-1','request-published','persisted','result-read-write');" query-e69-results "$e/expected-evaluation-results.tsv"
    check E69_PARTIAL_VIEW "UPDATE view_publication SET status='incomplete' WHERE view_ref='view-1';" query-e69-view-provenance "$e/expected-view-provenance.tsv"
    check E69_VIEW_PROVENANCE_LOSS "UPDATE view_publication SET definition_ref='-' WHERE view_ref='view-1';" query-e69-view-provenance "$e/expected-view-provenance.tsv"
    check E69_VIEW_SECRET_LEAK "INSERT INTO view_row VALUES ('view-1','alice','SECRET-E67');" query-e69-secret-leaks "$e/expected-secret-leaks.tsv"
    ;;
E70)
    e=$model/tdd/e70-observed-effect
    check E70_STALE_APPLIED "UPDATE state_current SET state_ref='state-2' WHERE scope_ref='scope-main';" query-e70-final "$e/expected-final-state.tsv"
    check E70_INCOMPLETE_APPLIED "INSERT INTO state_transition VALUES ('transition-incomplete','scope-main','state-1','state-2','result-incomplete','effect-incomplete'); INSERT INTO decision_observation VALUES ('observation-incomplete','transition-incomplete','result-incomplete','root-1');" query-e70-links "$e/expected-observation-links.tsv"
    check E70_RETRY_DUPLICATES "INSERT INTO state_transition VALUES ('transition-retry','scope-main','state-1','state-2','result-1','effect-retry'); INSERT INTO decision_observation VALUES ('observation-retry','transition-retry','result-1','root-1');" query-e70-links "$e/expected-observation-links.tsv"
    check E70_SPLIT_OBSERVATION "DELETE FROM decision_observation WHERE observation_ref='observation-1';" query-e70-links "$e/expected-observation-links.tsv"
    check E70_FAILED_ATTEMPT_WRITE "INSERT INTO state_transition VALUES ('transition-failed-attempt','scope-main','state-1','state-2','result-1','effect-failed-attempt'); INSERT INTO decision_observation VALUES ('observation-failed-attempt','transition-failed-attempt','result-1','root-1');" query-e70-links "$e/expected-observation-links.tsv"
    ;;
E71)
    e=$model/tdd/e71-restart-replay
    check E71_CURRENT_ROOT_SUBSTITUTION "UPDATE evaluation_result SET selected_value='public-v2',source_root_ref='root-2' WHERE result_ref='replay-result-1';" query-e71-equivalence "$e/expected-replay-equivalence.tsv"
    check E71_CURRENT_DEFINITION_SUBSTITUTION "UPDATE evaluation_result SET selected_value='public-v2' WHERE result_ref='replay-result-1';" query-e71-equivalence "$e/expected-replay-equivalence.tsv"
    check E71_OMISSION_COMPLETE "DELETE FROM evaluation_input WHERE request_ref='request-published' AND input_role='binding'; UPDATE evaluation_result SET disposition='unavailable' WHERE result_ref='replay-result-1';" query-e71-equivalence "$e/expected-replay-equivalence.tsv"
    check E71_EXECUTOR_METADATA "UPDATE evaluation_result SET selected_value='pid-123' WHERE result_ref='replay-result-1';" query-e71-executor-leaks "$e/expected-executor-leaks.tsv"
    ;;
E72)
    e=$model/tdd/e72-recovery-explanation
    check E72_DANGLING_SILENT "PRAGMA foreign_keys=OFF; DELETE FROM decision_observation WHERE observation_ref='observation-dangling';" query-e72-integrity "$e/expected-integrity-findings.tsv"
    check E72_CROSS_LINK_REPAIR "UPDATE evaluation_result SET source_root_ref='root-1' WHERE result_ref='result-cross';" query-e72-integrity "$e/expected-integrity-findings.tsv"
    check E72_PARTIAL_COMPLETE "INSERT INTO evaluation_result VALUES ('result-partial','request-published','persisted','complete','accepted','public-a','root-unpublished');" query-e72-integrity "$e/expected-integrity-findings.tsv"
    check E72_EXPLANATION_SECRET "UPDATE evaluation_result SET selected_value='SECRET-E67' WHERE result_ref='result-cross';" query-e72-secret-leaks "$e/expected-secret-leaks.tsv"
    ;;
*) echo "unknown group: $group" >&2; exit 2 ;;
esac
