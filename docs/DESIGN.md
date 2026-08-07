---
Type: DESIGN
Updated: 2026-08-07T11:26:24+09:00
Status: discussion-draft
Tags: licium, design, identity, repository, evaluation
Description: Public start node for Licium's current design boundary, executable evidence, and open questions.
---

# Licium Design

[日本語版](DESIGN.ja.md)

## Human-Oriented Entry Point

New readers should begin with [the concept guide](CONCEPT-GUIDE.md) or its
[Japanese version](CONCEPT-GUIDE.ja.md). It explains the mental model through
one Alice example. This document remains the precise public index of current
contracts, evidence, and open boundaries.

## Position

Licium is still before a stable specification. Its current implementation
substance is a small executable model, not a production service.

The central direction is:

> Identity emerges from values and relations.

The smallest useful architecture has two connected roles.

```text
Source and Repository
    immutable inputs, complete Roots, explicit Publication

Evaluation
    pinned inputs -> Result -> optional Repository Effect -> View
```

A backend may map those roles into one SQLite daemon or several distributed
components. Deployment topology is not part of the logical data model.

## Current contract boundary

| Question | Current answer | Evidence level | Open |
| --- | --- | --- | --- |
| Is every association a durable semantic object? | No. Occurrence, Result, lineage, revision, operation, and storage identities serve different roles. E64 did not reject stable lineage outside Evaluation equivalence. | Finite E64 fixture plus current scope correction; E64 is not included in the E67–E72 executable slice. | Which logical objects require lineage and how it merges. |
| Does computing a Result change Repository state? | No. Ordinary evaluation can be write-free. An effect-targeting evaluation may persist a Result before an accepted Effect links it to a transition and Decision Observation. | E69 and E70 in the included slice. | Recording policy and external-effect delivery. |
| Has Spanner conformance been demonstrated? | No. Spanner is a design and scalability stress test; no real adapter run exists. | Design-time mapping only, not included as executable evidence. | Schema, retries, knowledge-cut mapping, cost, and multi-region behavior. |
| Where is authoritative input? | In Source data at the pinned knowledge cut of a complete Repository state／Root. Identity is a derived set of values and relations; directories and protocol forms are projections. | E68, E69, and E71 plus the current conceptual model. | Final Source taxonomy and Definition／Profile／Context semantics. |
| Does normal Core operation require reachability GC? | The current candidate is canonically GC-free: canonical archives are not pruned or swept. Active replica release after verified archive is a placement transition. | Separate Pair／Tuple and Epoch experiments, summarized here as design context but not included in the executable slice. | Archive capacity, legal erase, and distributed reclaim. |

`Not supported by an experiment` means that finite evidence did not establish
a claim. It does not automatically mean that the idea was rejected or is
impossible.

## Candidate contracts for review

These documents are published now because the lifecycle roles and
backend-independent observations have become concrete enough to critique
without selecting a Rust API or database schema.

- [Repository / Evaluation Lifecycle Core Contract v0](CORE-CONTRACT.md) /
  [日本語](CORE-CONTRACT.ja.md) extracts twelve observable candidate
  boundaries. The public package bundles E67–E72 but not all predecessor
  evidence or E73R.
- [Backend Conformance Contract v0](BACKEND-CONFORMANCE.md) /
  [日本語](BACKEND-CONFORMANCE.ja.md) defines requirements for an exact Licium
  implementation plus backend profile. The exact test-only
  `sqlite-reference-v0` tuple has an accepted result; Spanner remains
  `UNTESTED`.
- [Public Sample Policy](PUBLIC-SAMPLES.md) /
  [日本語](PUBLIC-SAMPLES.ja.md) separates reproducible technical eligibility
  from commit and push authorization.

Useful feedback concerns role separation, evidence-to-claim ceilings,
backend-independent observability, and missing Identity Definition, Context,
delegation, or lineage semantics. The shortest path is
README → Core Contract → Backend Conformance → Evidence／runner.

## Repository and publication

Immutable objects belong to complete Roots. Creating a Root is not the same as
publishing it as a Head. Evaluation may explicitly address a Root for which the
caller has a receipt, while a Published View includes only accepted
Publications.

This separation permits offline or distributed creation without silently
promoting every stored object into current authoritative state.

## Pinned evaluation

Evaluation must not substitute ambient current state for replay inputs. The
reference slice pins Source Root, Definition, Semantics, Bindings, and
knowledge cut. After process restart and current-state advancement, those
inputs reproduce the historical Result.

## Result and Effect

Computation, optional persistence, and state effect are distinct.

```text
Pinned inputs -> compute Result
Result -> optional persistence
persisted Result + valid precondition -> State Transition
State Transition -> Decision Observation + complete View
```

A Decision Observation links an accepted Repository state transition to the
persisted Result used for that decision. This is current conceptual
terminology, not a final Rust type or legal-audit definition.

## Read-heavy operation

Ordinary evaluation need not write a Result or audit row. Immutable Roots and
complete Views can therefore support read-heavy operation while meaningful
state changes retain explicit provenance.

Stale reads, replicas, queues, caches, and process separation are replaceable
deployment capabilities. They must preserve pinned logical results when
introduced, but they are not mandatory Core primitives.

## Evidence boundary

The included reference slice supports a finite SQLite realization of the
Repository／Evaluation lifecycle. Its exact observations and limitations are
listed in [Evidence](EVIDENCE.md).

The schema is intentionally disposable. No production API, canonical encoding,
network protocol, or distributed transaction follows merely from the tests.

## References

- [Model boundary](MODEL.md)
- [Evidence](EVIDENCE.md)
- [Candidate Core Contract](CORE-CONTRACT.md)
- [Candidate Backend Conformance](BACKEND-CONFORMANCE.md)
- [Public Sample Policy](PUBLIC-SAMPLES.md)
- [Reference slice in English](REFERENCE-SLICE.en.md)
- [Reference slice in Japanese](REFERENCE-SLICE.ja.md)
- [Primary references and comparisons](references/identity-authorization-systems.md)

## SQLite reference conformance update

The candidate Backend Conformance v0 boundary has one accepted execution result:
the exact test-only `sqlite-reference-v0` tuple recorded 83/83 `PASS` in two
fresh isolated sealed sessions, with BC01--BC12 and the overall report `PASS`.
It is evidence about that bound tuple, not a stable Licium specification or a
database-product certification. See [SQLite Backend Conformance v0 Result](SQLITE-CONFORMANCE.md).

The 47-file evidence reference is a compact, digest-checked reference slice.
It is useful for a quick static integrity check, but it omits nested scenario
payload and is not input to a standalone sealed-session verifier. Reproducing
the result requires the complete published 472-file replay source and the
multi-hour fresh runtime, full gate, and negative self-tests described there.

SQLite product behavior, production durability, availability, security, and
performance are not established. Spanner remains `UNTESTED`.
