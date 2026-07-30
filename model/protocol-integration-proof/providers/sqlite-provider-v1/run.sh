#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
sqlite3=${SQLITE3:-sqlite3}

[ "$#" -eq 1 ] || {
    echo 'usage: run.sh CASE' >&2
    exit 2
}
case_id=$1
case "$case_id" in
    valid|valid-bob|valid-context-b|valid-published-head|wrong-proof|unknown-login|malformed-request|\
    exact-root|published-head|pinned-closure|historical-replay|\
    surface-bundle|ordinary-read-counters|credential-source-stability|\
    record-only|ephemeral-provenance) ;;
    *)
        echo "unsupported case: $case_id" >&2
        exit 2
        ;;
esac

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
db="$tmp/provider.sqlite"

"$sqlite3" -batch "$db" <"$script_dir/schema.sql"
case "$case_id" in
    valid)
        "$sqlite3" -batch -noheader -tabs "$db" \
            <"$script_dir/evaluate-valid.sql"
        ;;
    valid-bob)
        "$sqlite3" -batch -noheader -tabs \
            -cmd '.parameter init' \
            -cmd ".parameter set @login_identifier 'login-bob'" \
            -cmd ".parameter set @synthetic_proof 'toy-password-bob-v1'" \
            "$db" <"$script_dir/evaluate-valid.sql"
        ;;
    valid-context-b)
        "$sqlite3" -batch -noheader -tabs \
            -cmd '.parameter init' \
            -cmd ".parameter set @context_ref 'context-claims-v2'" \
            "$db" <"$script_dir/evaluate-valid.sql"
        ;;
    valid-published-head)
        "$sqlite3" -batch -noheader -tabs "$db" \
            <"$script_dir/evaluate-valid-published-head.sql"
        ;;
    wrong-proof|unknown-login|malformed-request)
        "$sqlite3" -batch -noheader -tabs \
            -cmd '.parameter init' \
            -cmd ".parameter set @case_id '$case_id'" \
            "$db" <"$script_dir/evaluate-rejected.sql"
        ;;
    exact-root|published-head)
        "$sqlite3" -batch -noheader -tabs \
            -cmd '.parameter init' \
            -cmd ".parameter set @case_id '$case_id'" \
            "$db" <"$script_dir/evaluate-root-mode.sql"
        ;;
    pinned-closure)
        "$sqlite3" -batch -noheader -tabs "$db" \
            <"$script_dir/evaluate-closure.sql"
        ;;
    historical-replay)
        "$sqlite3" -batch -noheader -tabs "$db" \
            <"$script_dir/evaluate-historical-replay.sql"
        ;;
    surface-bundle)
        surface_dir=${PROTOCOL_SURFACE_DIR:-}
        [ -n "$surface_dir" ] && [ -d "$surface_dir" ] || {
            echo 'surface-bundle requires PROTOCOL_SURFACE_DIR' >&2
            exit 2
        }
        [ -z "$(find "$surface_dir" -mindepth 1 -maxdepth 1 -print -quit)" ] || {
            echo 'surface-bundle directory must be empty' >&2
            exit 2
        }
        "$sqlite3" -batch -noheader -tabs "$db" \
            <"$script_dir/evaluate-valid.sql" >"$surface_dir/result.tsv"
        "$sqlite3" -batch -noheader -tabs "$db" \
            <"$script_dir/evaluate-explanation.sql" \
            >"$surface_dir/explanation.tsv"
        printf '%s\n' \
            'case=surface-bundle disposition=accepted root_ref=root-auth-v1' \
            >"$surface_dir/provider.log"
        cat "$surface_dir/result.tsv"
        ;;
    ordinary-read-counters)
        "$sqlite3" -batch -noheader -tabs "$db" \
            <"$script_dir/evaluate-counters.sql" >"$tmp/before.tsv"
        "$sqlite3" -batch -noheader -tabs "$db" \
            <"$script_dir/evaluate-valid.sql" >/dev/null
        "$sqlite3" -batch -noheader -tabs "$db" \
            <"$script_dir/evaluate-counters.sql" >"$tmp/after.tsv"
        awk -F '	' '
            NR == FNR {
                before[$1] = $2
                next
            }
            {
                print "ordinary-read\t" $1 "\tafter\t" $2
                print "ordinary-read\t" $1 "\tbefore\t" before[$1]
                print "ordinary-read\t" $1 "\tdelta\t" ($2 - before[$1])
            }
        ' "$tmp/before.tsv" "$tmp/after.tsv"
        ;;
    credential-source-stability)
        "$sqlite3" -batch -noheader -tabs "$db" \
            <"$script_dir/export-source.sql" >"$tmp/source-before.tsv"
        "$sqlite3" -batch -noheader -tabs "$db" \
            <"$script_dir/evaluate-valid.sql" >"$tmp/valid.tsv"
        "$sqlite3" -batch -noheader -tabs \
            -cmd '.parameter init' \
            -cmd ".parameter set @case_id 'wrong-proof'" \
            "$db" <"$script_dir/evaluate-rejected.sql" \
            >"$tmp/invalid.tsv"
        "$sqlite3" -batch -noheader -tabs "$db" \
            <"$script_dir/export-source.sql" >"$tmp/source-after.tsv"
        if cmp -s "$tmp/source-before.tsv" "$tmp/source-after.tsv"
        then
            source_equality=equal
        else
            source_equality=different
        fi
        valid_disposition=$(awk -F '	' \
            '$2 == "disposition" { print $3 }' "$tmp/valid.tsv")
        invalid_disposition=$(awk -F '	' \
            '$1 == "wrong-proof" { print $2 }' "$tmp/invalid.tsv")
        source_rows=$(wc -l <"$tmp/source-after.tsv" | tr -d ' ')
        sentinel_rows=$(grep -F -c 'secret-never-project-v1' \
            "$tmp/source-after.tsv")
        printf '%s\n' \
            "credential-source-stability	credential	invalid_disposition	$invalid_disposition" \
            "credential-source-stability	credential	valid_disposition	$valid_disposition" \
            "credential-source-stability	source	equality	$source_equality" \
            "credential-source-stability	source	row_count	$source_rows" \
            "credential-source-stability	source	secret_sentinel_rows	$sentinel_rows"
        ;;
    record-only)
        "$sqlite3" -batch -noheader -tabs "$db" \
            <"$script_dir/evaluate-counters.sql" >"$tmp/before.tsv"
        "$sqlite3" -batch "$db" <"$script_dir/record-result.sql"
        "$sqlite3" -batch -noheader -tabs "$db" \
            <"$script_dir/evaluate-counters.sql" >"$tmp/after.tsv"
        awk -F '	' '
            NR == FNR {
                before[$1] = $2
                next
            }
            {
                print "record-only\t" $1 "\tafter\t" $2
                print "record-only\t" $1 "\tbefore\t" before[$1]
                print "record-only\t" $1 "\tdelta\t" ($2 - before[$1])
                if ($1 == "persisted_result")
                    print "record-only\tpersisted_result\tresult_ref\tresult-record-only-v1"
            }
        ' "$tmp/before.tsv" "$tmp/after.tsv"
        ;;
    ephemeral-provenance)
        "$sqlite3" -batch -noheader -tabs "$db" \
            <"$script_dir/evaluate-ephemeral-provenance.sql"
        ;;
esac
