#!/bin/sh
set -eu

[ "$#" -eq 7 ] || {
    echo "usage: fault-bc09.sh DB VERB HOOK PHASE NONCE REVISION EFFECT" >&2
    exit 2
}

db=$1
verb=$2
hook=$3
phase=$4
nonce=$5
revision=$6
effect=$7

token()
{
    case "$1" in ''|*[!a-zA-Z0-9._-]*) return 1 ;; *) return 0 ;; esac
}
for value in "$verb" "$hook" "$phase" "$nonce" "$revision" "$effect"
do
    token "$value" || exit 2
done

case "$hook:$phase" in
    hook-bc09-accepted-write:accepted-write|\
    hook-bc09-rejection-stale:rejection-stale|\
    hook-bc09-rejection-incomplete:rejection-incomplete|\
    hook-bc09-rejection-rejected:rejection-rejected|\
    hook-bc09-rejection-duplicate:rejection-duplicate) ;;
    *) exit 2 ;;
esac

case "$verb" in
    activate)
        sqlite3 -batch -bail -noheader -tabs "$db" "
PRAGMA foreign_keys=ON;
INSERT INTO fault_activation
VALUES ('$nonce','$hook','$phase','$effect','$revision',1);
"
        printf 'status\tfault-activate\taccepted\t%s\n' "$nonce"
        ;;
    clear)
        changed=$(sqlite3 -batch -bail -noheader -tabs "$db" "
PRAGMA foreign_keys=ON;
DELETE FROM fault_activation
 WHERE fault_nonce='$nonce' AND hook_id='$hook' AND phase='$phase'
   AND effect_ref='$effect' AND implementation_revision='$revision'
   AND armed=1;
SELECT changes();
")
        [ "$changed" = 1 ] || {
            echo BC09_FAULT_CLEAR_MISSING >&2
            exit 1
        }
        printf 'status\tfault-clear\taccepted\t%s\n' "$nonce"
        ;;
    *)
        exit 2
        ;;
esac
printf 'pragma\tforeign-keys\t1\n' >&2
