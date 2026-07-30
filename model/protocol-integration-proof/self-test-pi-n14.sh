#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
verifier="$script_dir/verify-provider-independence.sh"
provider="$script_dir/providers/flatfile-posix-provider-v1"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

before=$(
    find "$provider" -type f -print0 |
        LC_ALL=C sort -z |
        xargs -0 sha256sum |
        sha256sum |
        cut -d' ' -f1
)
"$verifier" >"$tmp/baseline.out" 2>"$tmp/baseline.err"
if [ -s "$tmp/baseline.err" ] ||
    ! grep -F -x -q \
        NON_SQLITE_PROVIDER_INDEPENDENCE_VALID "$tmp/baseline.out"
then
    echo PI_N14_BASELINE_INVALID >&2
    exit 1
fi
echo 'ok BASELINE'

cp -R "$provider" "$tmp/provider"
mutant="$tmp/provider/run.sh"
awk '
    {
        print
        if ($0 == "case_id=$1") {
            print "\"$PI_N14_SQLITE3\" :memory: '\''select 1'\''"
            changed = 1
        }
    }
    END { exit !changed }
' "$provider/run.sh" >"$mutant.new"
mv "$mutant.new" "$mutant"
chmod +x "$mutant"

cat >"$tmp/sqlite3" <<'WRAPPER'
#!/bin/sh
set -eu
: >"$PI_N14_REACHABILITY_MARKER"
exit 0
WRAPPER
chmod +x "$tmp/sqlite3"

PI_N14_SQLITE3="$tmp/sqlite3" \
PI_N14_REACHABILITY_MARKER="$tmp/reached" \
    "$mutant" valid >"$tmp/reached.tsv" 2>"$tmp/reached.err"
if [ -s "$tmp/reached.err" ] || [ ! -f "$tmp/reached" ] ||
    ! grep -F -x -q 'envelope	disposition	accepted' "$tmp/reached.tsv"
then
    echo PI_N14_MUTANT_NOT_REACHED >&2
    exit 1
fi

set +e
"$verifier" "$tmp/provider" >"$tmp/mutant.out" 2>"$tmp/mutant.err"
inner_status=$?
set -e
[ "$inner_status" -ne 0 ] || {
    echo PI_N14_MUTANT_NOT_REJECTED >&2
    exit 1
}
[ "$(grep -F -x -c NON_SQLITE_PROVIDER_USES_SQLITE \
    "$tmp/mutant.err")" -eq 1 ] || {
    echo PI_N14_TARGET_MARKER_INVALID >&2
    exit 1
}
[ ! -s "$tmp/mutant.out" ] || {
    echo PI_N14_UNEXPECTED_MUTANT_STDOUT >&2
    exit 1
}

after=$(
    find "$provider" -type f -print0 |
        LC_ALL=C sort -z |
        xargs -0 sha256sum |
        sha256sum |
        cut -d' ' -f1
)
[ "$before" = "$after" ] || {
    echo PI_N14_PROVIDER_A_OR_REAL_SOURCE_CHANGED >&2
    exit 1
}

printf '%s\n' \
    "receipt control=PI-N14 class=static/runtime mutation=provider-b-invokes-sqlite inner_status=$inner_status marker=NON_SQLITE_PROVIDER_USES_SQLITE marker_count=1 target_gate=yes reachability=dynamic-valid-provider-b source_unchanged=yes" \
    'ok PI-N14' \
    'PI_N14_SELF_TEST_VALID 1 baseline 1 control'
