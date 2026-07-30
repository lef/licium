---
Type: RESULT
Updated: 2026-07-29T14:49:47+09:00
Status: confirmed
Tags: licium, sqlite, backend, conformance, evidence
Description: 一つのexact test-only SQLite reference tupleに対するaccepted result。
---

# SQLite Backend Conformance v0 Result

English: [SQLite Backend Conformance v0 Result](SQLITE-CONFORMANCE.md)

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

完全な59-value compile-option identityは
[`run-a/run-metadata.tsv`](../evidence/sqlite-reference-v0/session-b/run-a/run-metadata.tsv)に記録し、
同fileを各値のauthorityとする。

二つのfresh isolated sealed sessionで全83 subassertionsが`PASS`だった。BC01からBC12と
overall reportは`PASS`、`FAIL`、`UNTESTED`、`UNAVAILABLE`、`INVALID`はすべて0である。
このresultにはcurrent-source closure check、session binding、evidence sealing、19 run
self-test controls、6 session self-test controls、`ACCEPTED`となったindependent
exact-report reviewも含む。

## Quick static integrity check

`evidence/sqlite-reference-v0/session-b/`はcompactな47-file reference sliceである。
quick static integrity checkには次を実行する。

```sh
sh evidence/sqlite-reference-v0/verify.sh
```

expected markerは`SQLITE_REFERENCE_EVIDENCE_VALID`である。
このv3 candidateをpreparation hostで実測したdurationは1.08 secondsだった。

これはcopyしたpath、mode、byte count、digestを検証する。83 assertionsを再実行せず、
nested scenario payloadを意図的に含まないため、full sealed sessionを検証できない。

## Full fresh reproduction

完全な472-file replay sourceを`model/backend-conformance-v0/`へ同梱する。これは
compact evidence referenceとともに、この609-file reviewer packageの一部である。

fresh reproductionはmulti-hour acceptance workである。`sh`、`awk`、`sed`、`sort`、`cmp`、
`grep`、`find`、`mktemp`、file utilities、GNU-compatible `sha256sum`／`stat -c`、`sqlite3`
に加え、exact tested BC09 verifierが使用する`rg`をpreflightする。SQLite versionと
compile optionsをpublished runtime metadataと比較する。不一致は別のcandidate tuple
であり、このresultのreproductionではない。

long runの開始前に、次のfail-fast checkを実行する。

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

required markerは`SQLITE_REFERENCE_TUPLE_VALID`である。
`NEW_CANDIDATE_TUPLE`は異なるruntime tupleのevidenceであり、accepted resultの
reproductionへ混在させてはならない。

freshかつ存在しないoutput directoryを使う。

```sh
sh model/backend-conformance-v0/runner/run-sqlite-partial-session.sh SESSION_DIR
sh model/backend-conformance-v0/runner/verify-sqlite-partial-session.sh SESSION_DIR sealed
sh model/backend-conformance-v0/runner/verify-full-gate.sh SESSION_DIR
sh model/backend-conformance-v0/runner/self-test-sqlite-partial-run.sh
sh model/backend-conformance-v0/runner/self-test-sqlite-partial-session.sh
```

sealed verifierは`SQLITE_PARTIAL_SESSION_VALID`、full gateは
`SQLITE_FULL_CONFORMANCE_VALID`を出力しなければならない。exit statusとpost-run
source-hash checkがない中断runをPASS／FAILへ分類しない。

記録済みrun self-test durationは1,412 seconds、session self-test durationは
3,014,276 msだった。全sequenceにはmultiple hoursを確保する。

## Claim boundaryとreview invitation

これはSQLite product一般、production Licium service、durability、availability、security、
performanceのcertificationではない。Spanner conformanceを確立せず、Spannerは`UNTESTED`
のままである。TSV schema、fault hook、SQLite schemaはtest fixtureであり、final API、
storage schema、wire formatではない。

technical acceptanceはpublic pushをauthorizeしない。public GitHubへの公開には、
project ownerによる別の明示的な許可が必要である。

reviewerはexact tuple、evidence boundary、reproduction procedureを検査できる。再現可能な
counterexampleまたはこのboundaryを越えるclaimを報告してほしい。

## Related documents

- [Backend Conformance Contract](BACKEND-CONFORMANCE.ja.md)
- [Design](DESIGN.ja.md)
- [Public sample policy](PUBLIC-SAMPLES.ja.md)
