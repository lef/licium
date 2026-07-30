#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
materializer="$script_dir/materialize-bc02-gates.sh"
scenario=bc02-partial-residue--case-bc02-after-root-header
revision=$(sha256sum "$materializer" | awk '{ print $1 }')

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
artifacts="$tmp/artifacts"
mkdir "$artifacts"

awk -F '	' -v scenario="$scenario" '$1 == scenario { print $5 }' \
    "$base_dir/bc02-gate-results-template.tsv" |
    tr '+' '\n' | LC_ALL=C sort -u |
while IFS= read -r name
do
    : > "$artifacts/$name"
done

"$materializer" "$artifacts" "$scenario" "$revision" > "$tmp/baseline.tsv"
awk -F '	' -v scenario="$scenario" -v revision="$revision" '
    NF != 9 || $1 != scenario || $7 != "PASS" || $8 != "-" ||
        $9 != revision { exit 1 }
    END { if (NR != 12) exit 1 }
' "$tmp/baseline.tsv" || {
    echo BC02_GATE_MATERIALIZATION_INVALID >&2
    exit 1
}

printf 'tamper\n' > "$artifacts/fault-trigger-receipts.tsv"
"$materializer" "$artifacts" "$scenario" "$revision" > "$tmp/tampered.tsv"
baseline_sha=$(awk -F '	' '$4 == "exact-error-identity" { print $6 }' \
    "$tmp/baseline.tsv")
tampered_sha=$(awk -F '	' '$4 == "exact-error-identity" { print $6 }' \
    "$tmp/tampered.tsv")
[ "$baseline_sha" != "$tampered_sha" ] || {
    echo BC02_GATE_EVIDENCE_DIGEST_INSENSITIVE >&2
    exit 1
}

mv "$artifacts/fault-trigger-receipts.tsv" "$tmp/missing"
set +e
"$materializer" "$artifacts" "$scenario" "$revision" \
    >"$tmp/missing.out" 2>"$tmp/missing.err"
missing_status=$?
set -e
[ "$missing_status" -ne 0 ] || {
    echo BC02_GATE_MISSING_EVIDENCE_ACCEPTED >&2
    exit 1
}

echo "1 BC02 gate baseline"
echo "2 BC02 gate controls detected"
