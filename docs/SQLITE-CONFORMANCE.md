---
Type: RESULT
Updated: 2026-07-29T14:49:47+09:00
Status: confirmed
Tags: licium, sqlite, backend, conformance, evidence
Description: Accepted result for one exact test-only SQLite reference tuple.
---

# SQLite Backend Conformance v0 Result

日本語: [SQLite Backend Conformance v0 Result](SQLITE-CONFORMANCE.ja.md)

## Accepted scope

```text
profile:              sqlite-reference-v0
tested SUT revision:  630adfd92cee8ce19249f401b6238e5261a4b33d
backend kind:         sqlite
execution status:     bc01-bc12-supported
SQLite runtime:       3.46.1 2024-08-13 09:16:08 c9c2ab54ba1f5f46360f1b4f35d849cd3f080e6fc2b6c60e91b16c63f69aalt1 (64-bit)
adapter closure:      6b481579f0617248d394f2dd787ed0e068c63214003f809f3afd8a151a1bd53e
profile closure:      0792e5a4be76455ed1c390f4b9a2eb1a595efd5d367bfd250a3dbd0333ffcad4
runner closure:       9db523a23a3fe07778d3fb32d6cd4a0b27caa3ad4b4b4c091d59539b6c2919b8
SUT closure:          1481cc0ea0120ce645a17f14e1a25b7abe7cb9f7e0732426d1f74c7213e0255e
```

The complete 59-value compile-option identity is recorded in
[`run-a/run-metadata.tsv`](../evidence/sqlite-reference-v0/session-b/run-a/run-metadata.tsv),
which is the authority for those values.

Two fresh isolated sealed sessions recorded all 83 subassertions as `PASS`.
BC01 through BC12 and the overall report were `PASS`; `FAIL`, `UNTESTED`,
`UNAVAILABLE`, and `INVALID` counts were zero. The result includes current-source
closure checks, session bindings, evidence sealing, 19 run self-test controls,
6 session self-test controls, and an independent exact-report review `ACCEPTED`.

## Quick static integrity check

`evidence/sqlite-reference-v0/session-b/` is a compact 47-file reference
slice. Run a quick static integrity check with:

```sh
sh evidence/sqlite-reference-v0/verify.sh
```

The expected marker is `SQLITE_REFERENCE_EVIDENCE_VALID`.
The observed duration for this v3 candidate on the preparation host was
1.08 seconds.

It checks copied paths, modes, byte counts, and digests. It does not rerun the
83 assertions or verify a full sealed session because nested scenario payload
is intentionally absent.

## Full fresh reproduction

The complete 472-file replay source is included under
`model/backend-conformance-v0/`. It and the compact evidence reference are
parts of this 609-file reviewer package.

Fresh reproduction is multi-hour acceptance work. Preflight `sh`, `awk`, `sed`,
`sort`, `cmp`, `grep`, `find`, `mktemp`, file utilities, GNU-compatible
`sha256sum` and `stat -c`, `sqlite3`, and `rg` (used by the exact tested BC09
verifier). Compare the SQLite version and compile options with the published
runtime metadata. A difference is a new candidate tuple, not reproduction of
this result.

Run this fail-fast check before starting the long run:

```sh
(
set -eu
LC_ALL=C
export LC_ALL
for name in sh awk sed sort cmp grep find mktemp cp mkdir rm chmod \
    test wc cut tr sha256sum stat sqlite3 rg
do
    command -v "$name" >/dev/null 2>&1 || {
        echo "MISSING_COMMAND $name" >&2
        exit 1
    }
done
preflight=$(mktemp -d "${TMPDIR:-/tmp}/licium-sqlite-tuple.XXXXXX")
trap 'status=$?; rm -rf "$preflight"; exit "$status"' 0 1 2 15
metadata=evidence/sqlite-reference-v0/session-b/run-a/run-metadata.tsv
awk -F '	' \
    '$1 == "meta" && $2 == "runtime" && $3 == "sqlite-version" { print $4 }' \
    "$metadata" >"$preflight/expected-version"
awk -F '	' \
    '$1 == "meta" && $2 == "runtime" &&
     $3 ~ /^sqlite-compile-option-/ { print $4 }' \
    "$metadata" | sort >"$preflight/expected-options"
sqlite3 --version >"$preflight/actual-version"
sqlite3 :memory: 'PRAGMA compile_options;' |
    sort >"$preflight/actual-options"
if [ "$(wc -l <"$preflight/expected-options" | tr -d ' ')" -ne 59 ] ||
    [ "$(wc -l <"$preflight/actual-options" | tr -d ' ')" -ne 59 ] ||
    ! cmp "$preflight/expected-version" "$preflight/actual-version" ||
    ! cmp "$preflight/expected-options" "$preflight/actual-options"
then
    echo NEW_CANDIDATE_TUPLE >&2
    exit 1
fi
stat -c '%a' "$metadata" >/dev/null
sha256sum "$metadata" >/dev/null
echo SQLITE_REFERENCE_TUPLE_VALID
)
```

The required marker is `SQLITE_REFERENCE_TUPLE_VALID`. Any
`NEW_CANDIDATE_TUPLE` result is evidence for a different runtime tuple and must
not be mixed into reproduction of the accepted result.

Use a fresh, nonexistent output directory:

```sh
sh model/backend-conformance-v0/runner/run-sqlite-partial-session.sh SESSION_DIR
sh model/backend-conformance-v0/runner/verify-sqlite-partial-session.sh SESSION_DIR sealed
sh model/backend-conformance-v0/runner/verify-full-gate.sh SESSION_DIR
sh model/backend-conformance-v0/runner/self-test-sqlite-partial-run.sh
sh model/backend-conformance-v0/runner/self-test-sqlite-partial-session.sh
```

The sealed verifier must print `SQLITE_PARTIAL_SESSION_VALID`; the full gate
must print `SQLITE_FULL_CONFORMANCE_VALID`. An interrupted run without an exit
status and post-run source-hash check is neither PASS nor FAIL.

The recorded run self-test duration was 1,412 seconds, and the recorded session
self-test duration was 3,014,276 ms. Budget multiple hours for the complete
sequence.

## Claim boundary and review invitation

This is not SQLite product certification, a production Licium service claim,
or evidence of durability, availability, security, or performance. It does not
establish Spanner conformance; Spanner remains `UNTESTED`. TSV schemas, fault
hooks, and the SQLite schema are test fixtures, not a final API, storage schema,
or wire format.

Technical acceptance does not authorize a public push. Public GitHub
publication requires separate explicit project-owner authorization.

Reviewers are invited to inspect the exact tuple, evidence boundary, and
reproduction procedure. Please report reproducible counterexamples or claims
that exceed this boundary.

## Related documents

- [Backend Conformance Contract](BACKEND-CONFORMANCE.md)
- [Design](DESIGN.md)
- [Public sample policy](PUBLIC-SAMPLES.md)
