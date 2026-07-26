---
Type: EVIDENCE
Updated: 2026-07-26T20:00:00+09:00
Status: confirmed
Tags: licium, evidence, sqlite, e67, e72, replay
Description: Self-contained public evidence map for the included E67–E72 reference slice.
---

# E67–E72 Evidence Map

[日本語版](EVIDENCE.ja.md)

## Scope

The included model is a disposable SQLite and POSIX-shell reference
realization. It connects the Repository and Evaluation roles in one file so
their references and transaction boundaries can be tested together.

```text
Pair ingest
  -> complete Root
  -> accepted Publication / Head
  -> pinned Evaluation input closure
  -> Result
  -> optional Repository Effect + Decision Observation
  -> complete View
  -> process restart
  -> historical replay and explanation
```

## Fixed observations

| Experiment | Observation | Included evidence |
| --- | --- | --- |
| E67 | Duplicate delivery and equal-payload independent occurrences remain distinguishable. Incomplete Root construction rolls back without poisoning the next healthy transaction. | `model/test-e67-durable-lifecycle.sh`, E67 expected TSV, and four negative mutations. |
| E68 | Stored or rejected Roots do not enter the Published View. Explicit receipt evaluation may address an unpublished Root. Published evaluation uses an accepted Head and pinned input closure. | `model/test-e68-published-evaluation.sh`, E68 expected TSV, and four negative mutations. |
| E69 | Two ordinary evaluations leave the sorted persistent database content unchanged. A complete View retains Source Root, Head, and Definition provenance without leaking the synthetic secret sentinel. | `model/test-e69-pure-read-view.sh`, E69 expected TSV, and four negative mutations. |
| E70 | Only a complete Result with a satisfied precondition commits the Repository transition, Decision Observation, complete View, and current pointer together. Stale, incomplete, retry, and injected failure paths do not leave partial logical artifacts. | `model/test-e70-observed-effect.sh`, E70 expected TSV, and five negative mutations. |
| E71 | A second process reopens the file, advances current Root and Definition, and still reproduces the historical Result from the saved pinned closure. | `model/test-e71-restart-replay.sh`, E71 expected TSV, and four negative mutations. |
| E72 | Explanation reaches Result, Request, Root, and selected member through a finite closure. Semantic checks detect dangling and cross-linked references independently of SQLite foreign keys. | `model/test-e72-recovery-explanation.sh`, E72 expected TSV, and four negative mutations. |

## Counts

```text
targeted experiments: 6
targeted relations:   30 / 30
negative identities: 25 / 25 expected mismatches
executable closure:   64 files
```

The 64-file closure contains 33 shell files including the aggregate runner,
30 expected TSV files, and one SQLite schema.

## Reproduction

From the generated repository root:

```text
sh model/run-reference-slice-tests.sh
```

The aggregate must end with:

```text
6 reference-slice targeted tests and 25 negative identities passed
```

Each negative identity runs a mutation that must make the positive expected
comparison fail. A wrapper that mistakes the inner non-zero status for test
failure would produce a false red; the included self-test helper checks for
the intended mismatch.

## Claim boundary

Supported within the finite fixture:

- complete Root construction and explicit Publication are distinct;
- ordinary evaluation can be write-free;
- evaluation uses explicit pinned inputs rather than ambient current state;
- a Repository-local logical Effect can atomically connect a persisted Result,
  transition, Decision Observation, complete View, and current pointer;
- saved pinned inputs reproduce a historical Result after process restart;
- finite explanation and semantic-integrity findings are expressible.

Not established:

- production durability or operational recovery objectives;
- distributed consensus, partition behavior, or multi-region convergence;
- atomic completion or rollback of external APIs, devices, or message delivery;
- performance, capacity, or denial-of-service behavior;
- cryptographic trust, secure clock, authentication, or authorization;
- real Spanner adapter conformance;
- final Rust types, public API, canonical encoding, or storage schema.

The synthetic secret sentinel is test data used to prove non-leakage. It is not
a credential.

## Reading the model

- [Design](DESIGN.md)
- [Model boundary](MODEL.md)
- [English reference-slice explanation](REFERENCE-SLICE.en.md)
- [Japanese reference-slice explanation](REFERENCE-SLICE.ja.md)
- [Detailed reproduction guide](../model/README.md)
