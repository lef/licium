---
Type: SPEC
Updated: 2026-07-29T14:49:47+09:00
Status: draft
Tags: licium, backend, conformance, repository, evaluation
Description: Licium implementationとexact backend profileの組に対するcandidate black-box conformance境界。
---

# Backend Conformance Contract v0

English: [Backend Conformance Contract v0](BACKEND-CONFORMANCE.md)

## System Under Test

conformance対象は次のexact tupleである。

```text
Licium implementation revision
    + backend adapter revision
    + backend kind、version、configuration
```

SQLite、Spanner等のdatabase product単体のcertificationではない。database自身が
LiciumのEvaluation、View、replay、explanation semanticsを実装するわけではない。

test driverはsystemの起動、操作、観測だけを行う。Evaluationとselection logicは
SUTに属する。observerへ残せるのは宣言済みで監査可能なnormalizationだけである。

## Contract Groups

BC01–BC12はRepository／Evaluation Lifecycle Core Contract v0のCC01–CC12へ
一対一に対応する。各BC groupは複数のrequired positive subassertionと
counterfactual／fault controlを持つ。

| Group | Required boundary |
| --- | --- |
| BC01 | distinct delivery occurrenceをcollapseしないretry idempotency |
| BC02 | complete-or-unavailable Root、全体rollback、healthy retry |
| BC03 | stored Root、Publication、authority-scoped accepted Headの分離 |
| BC04 | exact stored readとpublished readの明示、ambient fallback禁止 |
| BC05 | complete pinned knowledge cutとdependency closure |
| BC06 | pure Evaluationのstate／Result／Observation writesが`0/0/0` |
| BC07 | ordinary `0/0/0`、record-only `0/1/0`、Effect operation `1/0/1` |
| BC08 | Result-linked transition、View、Observation、current pointerのindivisible更新 |
| BC09 | stale、incomplete、rejected、duplicate、injected failure後のpersistent attempt artifact不在 |
| BC10 | 全output surfaceのselected-closure／pinned-provenance non-leakage |
| BC11 | pinned replay、order-insensitive explanation closure、typed integrity Finding |
| BC12 | canonical inventoryを変えないderived placement decision／provenance |

これらはclaim groupであり、必ずしも12 queriesまたは12 API callsではない。

## Subassertion inventory

accepted requirements matrixは、次の83個のnamed subassertionから構成される。
この表はreview inventoryであり、同梱されたbackend executable evidenceではない。

```text
BC01	CC01	BC01_ASSOCIATION_IDEMPOTENT	positive
BC01	CC01	BC01_DISTINCT_OCCURRENCE	positive
BC01	CC01	BC01_OCCURRENCE_COLLAPSE	control
BC01	CC01	BC01_PAYLOAD_COLLISION	control
BC01	CC01	BC01_RETRY_DUPLICATION	control
BC02	CC02	BC02_COMPLETE_AVAILABLE	positive
BC02	CC02	BC02_HEALTHY_RETRY	positive
BC02	CC02	BC02_INCOMPLETE_AS_COMPLETE	control
BC02	CC02	BC02_PARTIAL_RESIDUE	control
BC02	CC02	BC02_POISONED_RETRY	control
BC02	CC02	BC02_ROLLBACK_COMPLETE	positive
BC03	CC03	BC03_ACCEPTED_HEAD	positive
BC03	CC03	BC03_PUBLICATION_SEPARATE	positive
BC03	CC03	BC03_REJECTED_IS_HEAD	control
BC03	CC03	BC03_STORED_IS_HEAD	control
BC03	CC03	BC03_STORED_ROOT_SEPARATE	positive
BC03	CC03	BC03_WRONG_AUTHORITY_HEAD	control
BC04	CC04	BC04_AMBIENT_FALLBACK	control
BC04	CC04	BC04_EXACT_PUBLISHED_COLLAPSE	control
BC04	CC04	BC04_EXACT_READ	positive
BC04	CC04	BC04_PUBLISHED_READ	positive
BC04	CC04	BC04_UNACCEPTED_AVAILABLE	control
BC05	CC05	BC05_AMBIENT_ADVANCE	control
BC05	CC05	BC05_BINDING_OMISSION	control
BC05	CC05	BC05_COMPLETE_CLOSURE	positive
BC05	CC05	BC05_DEFINITION_OMISSION	control
BC05	CC05	BC05_MISSING_AS_EMPTY	control
BC05	CC05	BC05_PINNED_KNOWLEDGE_CUT	positive
BC05	CC05	BC05_ROOT_OMISSION	control
BC05	CC05	BC05_SEMANTICS_OMISSION	control
BC05	CC05	BC05_TRANSITIVE_OMISSION	control
BC06	CC06	BC06_OBSERVATION_WRITE	control
BC06	CC06	BC06_PURE_ZERO_AXES	positive
BC06	CC06	BC06_REPOSITORY_UNCHANGED	positive
BC06	CC06	BC06_RESULT_WRITE	control
BC06	CC06	BC06_STATE_WRITE	control
BC07	CC07	BC07_EFFECT_101	positive
BC07	CC07	BC07_OBSERVATION_WITHOUT_TRANSITION	control
BC07	CC07	BC07_ORDINARY_000	positive
BC07	CC07	BC07_RECORD_IMPLIES_EFFECT	control
BC07	CC07	BC07_RECORD_ONLY_010	positive
BC07	CC07	BC07_RESULT_REWRITE	control
BC08	CC08	BC08_COMPLETE_EFFECT	positive
BC08	CC08	BC08_MID_BOUNDARY_FAILURE	control
BC08	CC08	BC08_MISSING_CURRENT	control
BC08	CC08	BC08_MISSING_OBSERVATION	control
BC08	CC08	BC08_MISSING_RESULT	control
BC08	CC08	BC08_MISSING_TRANSITION	control
BC08	CC08	BC08_MISSING_VIEW	control
BC09	CC09	BC09_DIAGNOSTIC_EPHEMERAL	positive
BC09	CC09	BC09_DUPLICATE_PERSISTS	control
BC09	CC09	BC09_FAILPOINT_PERSISTS	control
BC09	CC09	BC09_FAILURE_NO_PERSISTENT_ARTIFACT	positive
BC09	CC09	BC09_INCOMPLETE_PERSISTS	control
BC09	CC09	BC09_REJECTED_PERSISTS	control
BC09	CC09	BC09_STALE_PERSISTS	control
BC10	CC10	BC10_EXPLANATION_CLOSED	positive
BC10	CC10	BC10_EXPLANATION_LEAK	control
BC10	CC10	BC10_REPLAY_CLOSED	positive
BC10	CC10	BC10_REPLAY_LEAK	control
BC10	CC10	BC10_RESULT_CLOSED	positive
BC10	CC10	BC10_RESULT_LEAK	control
BC10	CC10	BC10_VIEW_CLOSED	positive
BC10	CC10	BC10_VIEW_LEAK	control
BC11	CC11	BC11_EXPLANATION_CLOSURE	positive
BC11	CC11	BC11_FINDING_CROSS_LINK	positive
BC11	CC11	BC11_FINDING_DANGLING	positive
BC11	CC11	BC11_LATEST_SUBSTITUTION	control
BC11	CC11	BC11_MISSING_AS_EMPTY	control
BC11	CC11	BC11_REPLAY_RESULT	positive
BC11	CC11	BC11_SILENT_CROSS_LINK	control
BC11	CC11	BC11_SILENT_DANGLING	control
BC12	CC12	BC12_ARCHIVE_BYPASS	control
BC12	CC12	BC12_CANONICAL_UNCHANGED	positive
BC12	CC12	BC12_DECISION_PROVENANCE	positive
BC12	CC12	BC12_DERIVED_PROTECTION	positive
BC12	CC12	BC12_ELIGIBILITY_DELETE	control
BC12	CC12	BC12_FORGET_BYPASS	control
BC12	CC12	BC12_FORGET_CONSUMED	positive
BC12	CC12	BC12_NOOP_EVALUATOR	control
BC12	CC12	BC12_PLACEMENT_DECISION	positive
BC12	CC12	BC12_PROTECTION_BYPASS	control
BC12	CC12	BC12_WINDOW_BYPASS	control
```

## Normalized Evidence

common comparison transportはliteral TABのsorted TSVである。test evidenceであり、
Licium wire formatではない。raw opaque handleは一つのrun内のequality classだけで
比較する。explanationは一つのpathやbyte列でなくorder-insensitive logical closure
として比較する。

semantically relevantなraw recordとnormalized rowは監査可能な双方向coverageを
持つ。許可するphysical metadata exclusionはfield classとrationaleを列挙する。
observerは違反rowを隠したり、存在しないsemantic rowを合成できない。

## Isolation、Pin、Fault

各runはfresh logical namespaceを使う。前runだけに置いたsentinelでnamespace
contaminationを検査する。必要なscenarioではsame-namespace before／after、
connection reopen、silent latest fallback禁止、実際のfault triggerを確認する。

fault markerはimplementation revision、hook ID、phase、before／after effect
inventoryへbindingする。triggerしなかったcontrolはPASSではない。

## Evidence Sealing

payload manifestはregular payload filesを次で列挙する。

```text
relative_path mode sha256 bytes role
```

`mode`は`100644`または`100755`。manifest自身とfinal reportは除外し、reportが
payload-manifest digestをbindingする。必要なら別のouter receiptがreportと
manifestをself-referenceなしに封印する。

## Dispositions

```text
PASS
FAIL
UNTESTED
UNAVAILABLE
INVALID
```

conformanceとして数えるのはPASSだけである。full v0 conformanceには二つのfresh
isolated runでBC01–BC12の全positiveとrequired controlがPASSすることを要求する。
UNTESTED、UNAVAILABLE、INVALIDをwaiverへ変換しない。

## Initial planned-RED state（historical）

requirementsと83-subassertion matrixはacceptedである。planned harnessはSQLite
profileが存在しないため現在失敗する。full v0 conformanceを持つbackendはない。

既存Spanner documentはdesign-time capability mappingのままである。real instance、
exact profile、required fault control、evidence-bound reportを実行するまでSpannerは
UNTESTEDである。emulator evidenceはproduction durabilityやmulti-region behaviorを
確立しない。

## Not Established

- production durability、availability、scalability、performance;
- Rust API、production schema、wire protocol;
- consensusまたはreplication topology;
- canonical bytesまたはidentifier algorithm;
- archive reconstruction、canonical deletion、GC;
- complete Identity Definition、Context、delegation semantics。

## References

- [Core Contract v0](CORE-CONTRACT.ja.md)
- [Public Evidence Map](EVIDENCE.ja.md)
- [Reference Slice](REFERENCE-SLICE.ja.md)
- [Public Sample Policy](PUBLIC-SAMPLES.ja.md)

## Correction -- SQLite reference result

直前のhistorical sectionはinitial planned-RED historyを保存する。後続のexecutionはexact
test-only `sqlite-reference-v0` tupleをacceptedとした。二つのfresh isolated sealed
sessionで83/83 subassertions、BC01--BC12、overall reportは`PASS`、non-PASSは0だった。
tested SUT revisionは`630adfd92cee8ce19249f401b6238e5261a4b33d`である。

このresultは記録されたimplementation、adapter、profile、SQLite runtime、configurationに
限る。SQLite product一般またはproduction serviceのcertificationではなく、durability、
availability、security、performanceを確立しない。Spannerは`UNTESTED`のままである。

compactな47-file evidence referenceはquick static integrity checkだけを支持する。nested
scenario payloadを含まず、fresh full sessionの代用にならない。fresh reproduction用の
完全な472-file replay sourceを同梱する。exact evidence boundary、expected marker、
dependency preflight、multi-hour reproduction procedureは
[SQLite Backend Conformance v0 Result](SQLITE-CONFORMANCE.ja.md)を参照する。
