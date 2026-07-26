---
Type: DESIGN
Updated: 2026-07-26T20:00:00+09:00
Status: confirmed
Tags: licium, repository, evaluation, sqlite, lifecycle, replay
Description: English design result from the E67–E72 End-to-End Reference Execution Slice.
---

# End-to-End Reference Execution Slice

Japanese version: [REFERENCE-SLICE.ja.md](REFERENCE-SLICE.ja.md)

## Conclusion

Licium's implementation substance is neither a database schema alone nor an
empty backend interface. Its smallest executable skeleton connects immutable
and published Repository state to an Evaluation Kernel over pinned inputs.

```text
Source Pair
  -> Root
  -> Publication / Head
  -> Pinned Evaluation Request
  -> Result
  -> optional logical Effect / Decision Observation
  -> View
```

The single-SQLite-file slice completed this lifecycle without a protocol,
queue, cache, thread model, or service topology. One file does not imply a
logical monolith. The same roles may map to a single daemon or distributed
components. The SQLite tables are disposable, not the Core Tuple or wire
schema.

## Read-heavy behavior

Ordinary evaluation is write-free in the fixture. The complete persistent
content was identical before and after each of two reads. A Result or audit row
need not be written for every read.

Only a state-changing Effect connects a complete persisted Result, expected
state, transition, Decision Observation, and complete View. This supports a
read-heavy shape while retaining explicit provenance for meaningful changes.

## Publication and pinned evaluation

Storing a Root does not publish it as a Head. Rejected and unpublished Roots do
not enter the Published View. A caller with a write receipt may still request
an Exact Root explicitly.

Evaluation does not use ambient current state. The fixture pins Source Root,
Definition, Semantics, Bindings, and knowledge cut. After process restart and
advancement of current Root and Definition, those inputs reproduce the
historical Result.

## Effect boundary

Atomic Effect means logical completion inside the Repository: State
Transition, Decision Observation, View Publication, and current View pointer.
It does not claim that a SQLite transaction completes or rolls back an
external API call, device action, or message delivery.

Stale, incomplete, duplicate, and injected-failure paths return diagnostics or
fail without leaving partial logical artifacts.

## Explanation and integrity

A Decision Observation can be traced to Result, Evaluation Request, Source
Root, and selected member. The contract requires a finite complete reference
closure, not a unique path.

SQLite foreign keys are only a physical aid. Separate semantic-integrity
queries detect a missing Result referenced by an Observation, a missing Root
referenced by a View, and a Result Source Root inconsistent with its pinned
input.

## Rust boundary

No Rust source exists yet. The slice provides evidence that a future API
should not collapse at least Root, Publication, Head, Evaluation Request,
Pinned Input Closure, ephemeral outcome, persisted Result, Effect Request,
State Transition, Decision Observation, and View provenance into one type.

This is a candidate type boundary, not a published Rust API.

## References

- [E67–E72 Evidence Map](EVIDENCE.md)
- [Reproduction guide](../model/README.md)
- [Japanese version](REFERENCE-SLICE.ja.md)
