#!/bin/sh
set -eu
db=$1
sqlite3 -batch -noheader -tabs "$db" "SELECT 'effect-1',2,COUNT(*),(SELECT COUNT(*) FROM decision_observation WHERE transition_ref='transition-1') FROM state_transition WHERE effect_ref='effect-1';"
