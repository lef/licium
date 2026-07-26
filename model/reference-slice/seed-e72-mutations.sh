#!/bin/sh
set -eu
db=$1
sqlite3 -batch -bail "$db" <<'SQL'
PRAGMA foreign_keys=OFF;
INSERT INTO evaluation_result VALUES ('result-cross','request-published','persisted','complete','accepted','public-a','root-unpublished');
INSERT INTO state_transition VALUES ('transition-dangling','scope-main','state-1','state-x','missing-result','effect-dangling');
INSERT INTO decision_observation VALUES ('observation-dangling','transition-dangling','missing-result','root-1');
INSERT INTO view_publication VALUES ('view-dangling','missing-root','root-1','definition-main','complete');
SQL
