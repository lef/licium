---
Type: SPEC
Updated: 2026-07-29T14:49:47+09:00
Status: draft
Tags: licium, backend, conformance, repository, evaluation
Description: Candidate black-box conformance boundary for a Licium implementation combined with an exact backend profile.
---

# Backend Conformance Contract v0

日本語: [Backend Conformance Contract v0](BACKEND-CONFORMANCE.ja.md)

## Subject under test

Conformance belongs to an exact tuple:

```text
Licium implementation revision
    + backend adapter revision
    + backend kind, version, and configuration
```

It is not a certification of SQLite, Spanner, or another database product in
isolation. A database does not itself implement Licium Evaluation, View,
replay, or explanation semantics.

The test driver may start, drive, and observe the system. Evaluation and
selection logic belong to the implementation under test. Only declared,
auditable normalization may remain in the observer.

## Contract groups

BC01–BC12 map one-to-one to CC01–CC12 in the Repository / Evaluation Lifecycle
Core Contract v0. Each BC group has multiple required positive subassertions
and counterfactual or fault controls.

| Group | Required boundary |
| --- | --- |
| BC01 | Idempotent retry without collapsing distinct delivery occurrences |
| BC02 | Complete-or-unavailable Root, full rollback, healthy retry |
| BC03 | Stored Root, Publication, and authority-scoped accepted Head remain distinct |
| BC04 | Exact stored read and published read remain explicit; no ambient fallback |
| BC05 | Complete pinned knowledge cut and dependency closure |
| BC06 | Pure Evaluation writes `0/0/0` across state, Result, and Observation axes |
| BC07 | Ordinary `0/0/0`, record-only `0/1/0`, Effect operation `1/0/1` |
| BC08 | Indivisible Result-linked transition, View, Observation, and current pointer |
| BC09 | No persistent attempt artifacts after stale, incomplete, rejected, duplicate, or injected failure |
| BC10 | Selected-closure and pinned-provenance non-leakage across all output surfaces |
| BC11 | Pinned replay, order-insensitive explanation closure, and typed integrity Findings |
| BC12 | Derived placement decision and provenance without changing canonical inventory |

These are claim groups, not necessarily twelve queries or twelve API calls.

## Subassertion inventory

The accepted requirements matrix contains the following 83 named subassertions.
The table is a review inventory, not bundled executable backend evidence.

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

## Normalized evidence

The common comparison transport is sorted, literal-tab TSV. It is test
evidence, not a Licium wire format. Raw opaque handles are compared only
through equality classes within a run. Explanations are compared as
order-insensitive logical closures, not as one required path or byte sequence.

Semantically relevant raw records and normalized rows have audited,
bidirectional coverage. Permitted physical metadata exclusions are enumerated
by field class and rationale; the observer may neither hide violation rows nor
synthesize missing semantic rows.

## Isolation, pinning, and faults

Each run uses a fresh logical namespace. A prior-run sentinel tests namespace
contamination. Same-namespace before/after checks, connection reopen, silent
latest-fallback rejection, and actual fault-trigger evidence are required
where relevant.

A fault marker is bound to the implementation revision, hook ID, phase, and
before/after effect inventory. A control that did not trigger is not a pass.

## Evidence sealing

A payload manifest lists regular payload files as:

```text
relative_path mode sha256 bytes role
```

`mode` is `100644` or `100755`. The manifest excludes itself and the final
report. The report binds the payload-manifest digest. An optional outer receipt
may seal the report and manifest without introducing self-reference.

## Dispositions

```text
PASS
FAIL
UNTESTED
UNAVAILABLE
INVALID
```

Only PASS counts as conformance. Full v0 conformance requires every BC01–BC12
positive and required control to pass in two fresh isolated runs. UNTESTED,
UNAVAILABLE, and INVALID do not become waivers.

## Initial planned-RED state (historical)

The requirements and 83-subassertion matrix are accepted. The planned harness
currently fails because the SQLite profile does not exist. No backend has a
full v0 conformance result.

The existing Spanner document remains a design-time capability mapping.
Spanner is UNTESTED until a real instance, exact profile, required fault
controls, and evidence-bound report are executed. Emulator evidence does not
establish production durability or multi-region behavior.

## Not established

- production durability, availability, scalability, or performance;
- a Rust API, production schema, or wire protocol;
- consensus or replication topology;
- canonical bytes or identifier algorithm;
- archive reconstruction, canonical deletion, or GC;
- complete Identity Definition, Context, or delegation semantics.

## References

- [Core Contract v0](CORE-CONTRACT.md)
- [Public Evidence Map](EVIDENCE.md)
- [Reference Slice](REFERENCE-SLICE.en.md)
- [Public Sample Policy](PUBLIC-SAMPLES.md)

## Correction -- SQLite reference result

The preceding historical section preserves the initial planned-RED history. A later
execution accepted the exact test-only `sqlite-reference-v0` tuple: 83/83
subassertions, BC01--BC12, and the overall report were `PASS` in two fresh
isolated sealed sessions, with zero non-PASS dispositions. The tested SUT
revision is `630adfd92cee8ce19249f401b6238e5261a4b33d`.

This result is limited to the recorded implementation, adapter, profile,
SQLite runtime, and configuration. It is not a certification of SQLite as a
product or of a production service, and it does not establish durability,
availability, security, or performance. Spanner remains `UNTESTED`.

The compact 47-file evidence reference supports a quick static integrity
check only. It omits nested scenario payload and cannot substitute for a fresh
full session. The complete 472-file replay source is included for fresh
reproduction. For the exact evidence boundary, expected markers, dependency
preflight, and multi-hour reproduction procedure, see
[SQLite Backend Conformance v0 Result](SQLITE-CONFORMANCE.md).
