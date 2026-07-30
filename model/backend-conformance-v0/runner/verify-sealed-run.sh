#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
verify_manifest="$script_dir/verify-payload-manifest.sh"
verify_report="$script_dir/verify-report.sh"
runtime_verifier="$script_dir/verify-bc06-runtime.sh"
control_verifier="$script_dir/verify-bc06-run-controls.sh"
assertion_materializer="$script_dir/materialize-bc06-assertions.sh"
run_layout_verifier="$script_dir/verify-bc06-run-layout.sh"
session_layout_verifier="$script_dir/verify-bc06-session-layout.sh"
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
cases="$base_dir/bc06-cases.tsv"

[ "$#" -eq 1 ] || {
    echo "usage: verify-sealed-run.sh RUN_DIR" >&2
    exit 2
}

run_dir=$1
manifest="$run_dir/payload-manifest.tsv"
report="$run_dir/report.tsv"
outer="$run_dir/outer-receipt.tsv"
metadata="$run_dir/run-metadata.tsv"

fail()
{
    echo "$1" >&2
    exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

if ! "$verify_manifest" "$run_dir" >/dev/null 2>&1; then
    fail PAYLOAD_MANIFEST_INVALID
fi
if ! "$verify_report" "$run_dir" >/dev/null 2>&1; then
    fail RUN_REPORT_INVALID
fi

[ -f "$metadata" ] && [ -f "$outer" ] ||
    fail RUN_SEAL_ARTIFACT_MISSING

for reserved in "$manifest" "$report" "$outer"
do
    find "$reserved" -prune -type f -perm 0644 |
        awk 'NR == 1 { found = 1 } END { exit !found }' ||
        fail RUN_RESERVED_MODE_INVALID
done

manifest_sha=$(sha256sum "$manifest" | awk '{ print $1 }')
manifest_bytes=$(wc -c <"$manifest" | tr -d ' ')
report_sha=$(sha256sum "$report" | awk '{ print $1 }')
report_bytes=$(wc -c <"$report" | tr -d ' ')

awk -F '	' -v manifest_sha="$manifest_sha" -v manifest_bytes="$manifest_bytes" \
    -v report_sha="$report_sha" -v report_bytes="$report_bytes" '
    $0 == "payload-manifest.tsv\t100644\t" manifest_sha "\t" manifest_bytes "\tpayload-manifest" { manifest++ }
    $0 == "report.tsv\t100644\t" report_sha "\t" report_bytes "\treport" { report++ }
    { count++ }
    END { if (count != 2 || manifest != 1 || report != 1) exit 1 }
' "$outer" || fail RUN_OUTER_RECEIPT_INVALID

awk -F '	' -v manifest_sha="$manifest_sha" '
    $1 == "binding" && $2 == "evidence" &&
        $3 == "payload-manifest-sha256" && $4 == manifest_sha { found++ }
    END { if (found != 1) exit 1 }
' "$report" || fail RUN_REPORT_MANIFEST_BINDING_INVALID

awk -F '	' '
    NR == FNR { required[$0]++; next }
    $1 == "meta" || $1 == "binding" { actual[$0]++ }
    END {
        for (row in required) if (actual[row] != required[row]) exit 1
    }
' "$metadata" "$report" || fail RUN_REPORT_METADATA_BINDING_INVALID

artifact_kind=$(
    awk -F '	' '
        $1 == "meta" && $2 == "global" && $3 == "artifact-kind" {
            print $4
            found++
        }
        END { if (found != 1) exit 1 }
    ' "$metadata"
) || fail RUN_ARTIFACT_KIND_INVALID

case "$artifact_kind" in
    bc06-partial-run)
        "$run_layout_verifier" "$run_dir" sealed >/dev/null ||
            fail BC06_RUN_LAYOUT_INVALID
        run_id=$(
            find "$run_dir" -mindepth 2 -maxdepth 2 \
                -name action-receipts.tsv -type f -print |
                LC_ALL=C sort |
                while IFS= read -r receipt
                do
                    sed -n '1p' "$receipt"
                    break
                done |
                awk -F '	' 'NF == 11 { print $1 }'
        )
        [ -n "$run_id" ] || fail BC06_RUNTIME_EVIDENCE_INVALID
        while IFS='	' read -r assertion kind normal_mode control_mode count disposition
        do
            name=$(printf '%s' "$assertion" | tr 'A-Z_' 'a-z-')
            scenario_dir="$run_dir/$name"
            namespace=$(
                awk -F '	' '
                    NF != 11 { exit 1 }
                    NR == 1 { value = $2 }
                    $2 != value { exit 1 }
                    END { if (NR != 2) exit 1; print value }
                ' "$scenario_dir/action-receipts.tsv"
            ) || fail BC06_RUNTIME_EVIDENCE_INVALID
            "$runtime_verifier" "$scenario_dir" "$run_id" "$namespace" \
                "$assertion" "$scenario_dir/$namespace.db" >/dev/null 2>&1 ||
                fail BC06_RUNTIME_EVIDENCE_INVALID
        done <"$cases"

        "$assertion_materializer" "$tmp/assertions.expected.tsv"
        cmp -s "$run_dir/assertions.tsv" "$tmp/assertions.expected.tsv" ||
            fail BC06_ASSERTION_DERIVATION_INVALID

        "$control_verifier" "$run_dir" "$run_id" >/dev/null 2>&1 ||
            fail BC06_RUN_CONTROL_RECEIPT_INVALID
        ;;
    bc06-partial-session)
        "$session_layout_verifier" "$run_dir" sealed >/dev/null ||
            fail BC06_SESSION_LAYOUT_INVALID
        ;;
    sqlite-partial-run)
        if [ "${LICIUM_PARTIAL_ENVELOPE_ONLY:-0}" -ne 1 ]; then
            run_id=$(awk -F '	' '
                $1 == "meta" && $2 == "global" && $3 == "run-id" {
                    print $4
                    found++
                }
                END { if (found != 1) exit 1 }
            ' "$metadata") || fail SQLITE_PARTIAL_RUN_METADATA_INVALID
            side=$(awk -F '	' '
                $1 == "meta" && $2 == "global" && $3 == "side" {
                    value = $4
                    print value
                    found++
                }
                END {
                    if (found != 1 || (value != "a" && value != "b"))
                        exit 1
                }
            ' "$metadata") || fail SQLITE_PARTIAL_RUN_METADATA_INVALID
            "$script_dir/verify-sqlite-partial-run.sh" \
                "$run_dir" "$run_id" "$side" \
                "$(dirname "$run_dir")/lifecycle" sealed >/dev/null ||
                fail SQLITE_PARTIAL_RUN_INVALID
        fi
        ;;
    sqlite-partial-session)
        if [ "${LICIUM_PARTIAL_ENVELOPE_ONLY:-0}" -ne 1 ]; then
            "$script_dir/verify-sqlite-partial-session.sh" \
                "$run_dir" sealed >/dev/null ||
                fail SQLITE_PARTIAL_SESSION_INVALID
        fi
        ;;
    *)
        fail RUN_ARTIFACT_KIND_INVALID
        ;;
esac

echo RUN_SEAL_VALID
