---
Type: DESIGN
Updated: 2026-07-26T21:00:00+09:00
Status: draft
Tags: licium, core, repository, evaluation, contract
Description: Evidence-derived Candidate Contract v0 for the Repository and Evaluation lifecycle, independent of Rust, storage, wire, and deployment topology.
---

# Repository / Evaluation Lifecycle Core Contract v0

Japanese: [Repository／Evaluation Lifecycle Core Contract v0（日本語）](CORE-CONTRACT.ja.md)

## Status and scope

This is a **Candidate Contract v0**, not a stable public specification,
production guarantee, final API, or complete Licium Identity-composition
contract. It extracts observable boundaries from finite E67–E73R fixtures and
predecessor evidence. This public reviewer package bundles E67–E72 only; it
does not bundle all predecessor fixtures or E73R.

The contract covers Repository, Publication, Evaluation, Result, Repository
Effect, View, replay, explanation, and placement-eligibility lifecycle. It does
not complete Pair/Tuple semantics, Literal/Ref intent, Identity Definition,
Profile, Context, or Delegation.

`MUST` below means “a candidate conforming implementation must preserve this
observation.” It does not prescribe a Rust type, SQL schema, serialization,
backend, process, queue, or network protocol.

## Role boundaries

The following roles must not be collapsed merely because one implementation
stores them together:

```text
delivery occurrence != semantic Association / logical equivalence
delivery occurrence != Evaluation Request / Effect Request identity
same-request retry != new logical request
immutable object != complete Root
physical Pair / layout != semantic Association / Tuple-like meaning
Root existence != Publication disposition != authority-scoped Head derivation
Evaluation Request != Pinned Input Closure
ephemeral Outcome != persisted Result
persisted Result write != authoritative state transition
Effect Request != accepted Effect / State Transition
State Transition != Decision Observation
persisted Result != provenance-bearing View
complete View != current View pointer
View != authoritative Source
forget event != canonical delete
active placement != canonical object / history
release eligibility != release execution
placement release != canonical deletion
declared verified archive state != demonstrated reconstruction
```

## Candidate claims

<a id="cc01"></a>
### CC01 — Delivery retry and occurrence

- **Precondition:** A delivery carries a delivery identity and an Association occurrence.
- **MUST / success:** Replaying the same delivery is idempotent; two distinct occurrences with equal semantic content remain distinguishable.
- **Failure observation:** A delivery collision or malformed input is not normalized into a successful new occurrence.
- **Persistent effect:** A successful new occurrence may extend Repository input; a retry does not duplicate it.
- **Retry:** Same delivery is not a new logical occurrence.
- **Provenance:** The accepted occurrence remains attributable to its delivery.
- **Evidence:** E67 inventory and member relations; `E67_DELIVERY_DUPLICATES`, `E67_OCCURRENCE_COLLAPSE`.
- **Not established:** Universal occurrence IDs for every Association or a final identity-minting rule.

<a id="cc02"></a>
### CC02 — Complete Root or unavailable

- **Precondition:** A Root formation or resolution names a required inventory.
- **MUST / success:** The full inventory commits or resolves as complete.
- **Failure observation:** Missing members yield rollback or unavailable, never a partial semantic Root; a failed attempt does not poison a later healthy transaction.
- **Persistent effect:** Failure leaves no partial Root artifact.
- **Retry:** A corrected later attempt may succeed against the same Repository.
- **Provenance:** A complete Root retains its inventory and ancestry boundary.
- **Evidence:** E67 incomplete injection/recovery and E30 complete-or-unavailable layout resolution.
- **Not established:** Canonical Root bytes, hashing, Merkle structure, or distributed transaction behavior.

<a id="cc03"></a>
### CC03 — Root, Publication, and Head are distinct

- **Precondition:** A Root exists and a Publication disposition is evaluated for an Authority scope.
- **MUST / success:** Root existence, Publication acceptance, and authority-scoped Head derivation are separate observations.
- **Failure observation:** Stored-only and rejected Roots do not enter the accepted Head result.
- **Persistent effect:** Storing a Root alone does not publish it.
- **Retry:** Re-observing the same accepted state does not invent another logical Head.
- **Provenance:** A derived Head identifies the accepted Publication and Root used.
- **Evidence:** E68 publication and Head relations; `E68_STORED_IS_HEAD`, `E68_REJECTED_IS_HEAD`.
- **Not established:** Authority trust correctness, consensus, Head cardinality, or convergence.

<a id="cc04"></a>
### CC04 — Explicit read mode

- **Precondition:** A read requests exact stored state or authority-accepted published state.
- **MUST / success:** The selected mode determines which Root may be read.
- **Failure observation:** Missing or unaccepted published input is unavailable, not repaired from ambient current state.
- **Persistent effect:** None is implied.
- **Retry:** Repeating a read with the same pins has the same logical input.
- **Provenance:** The result records the selected Root and read boundary.
- **Evidence:** E68 exact-versus-published relation; `E68_AMBIENT_INPUT`.
- **Not established:** Public method names, routing policy, replica selection, or freshness SLA.

<a id="cc05"></a>
### CC05 — Complete pinned input closure

- **Precondition:** An Evaluation Request names the required Root, Definition, Semantics, Binding, and other dependencies.
- **MUST / success:** Evaluation uses the complete closure resolved in the pinned knowledge cut.
- **Failure observation:** Missing closure is unavailable; ambient latest values are not substituted.
- **Persistent effect:** Resolution alone does not imply a write.
- **Retry:** Same complete pins are logically replayable; different pins are not the same request occurrence.
- **Provenance:** The Result can identify every required input role.
- **Evidence:** E68 input relation, E71 omission control, and E61 dependency closure.
- **Not established:** Closure encoding, generic recursion, termination, or canonical dependency ordering.

<a id="cc06"></a>
### CC06 — Ordinary Evaluation is write-free

- **Precondition:** The request is an ordinary Evaluation with no Repository Effect request.
- **MUST / success:** Logical Evaluation returns an ephemeral Outcome without persistent Repository changes.
- **Failure observation:** Unavailable or Finding outcomes likewise do not require a state mutation.
- **Persistent effect:** State / Result-store / Decision-Observation writes are `0/0/0`.
- **Retry:** Repeated ordinary reads do not accumulate Result artifacts.
- **Provenance:** The ephemeral Outcome still carries its pinned-input boundary.
- **Evidence:** E69 two before/after database comparisons; `E69_READ_WRITES_RESULT`.
- **Not established:** Whether caches, metrics, or traces exist as optional physical modules.

<a id="cc07"></a>
### CC07 — Result recording is not an authoritative state effect

- **Precondition:** An Evaluation Outcome is eligible for optional persistence.
- **MUST / success:** The three axes authoritative-state write / Result-store write / Decision-Observation write remain distinct.
- **Failure observation:** Persisting a Result alone cannot be interpreted as an accepted state transition.
- **Persistent effect:** Ordinary read is `0/0/0`; an effect-targeting evaluation may be `0/1/0` before any accepted Effect.
- **Retry:** A retry may reuse a persisted Result without creating a transition.
- **Provenance:** A persisted Result retains the request and pinned inputs that produced it.
- **Evidence:** E66 evaluation-side-effect rows and the Results correction; E69 ordinary reads.
- **Not established:** Mandatory Result retention, a global Result ID, or deployment persistence policy.

<a id="cc08"></a>
### CC08 — Atomic Repository Effect observation

- **Precondition:** A complete persisted Result, Effect Request, and expected Repository state satisfy the Effect preconditions.
- **MUST / success:** Transition, Decision Observation, complete View, and current pointer form one indivisible Repository transition linked to the Result; no partial intermediate state is observable.
- **Failure observation:** A failpoint or failed precondition leaves none of that partial observable set.
- **Persistent effect:** Exactly the accepted Repository-local transition set is durable.
- **Retry:** The same accepted Effect does not create a second transition set.
- **Provenance:** Observation links transition, Result, source Root, and View/current outcome.
- **Evidence:** E70 success, final-state, link, rollback, and retry relations.
- **Not established:** Atomicity with an external API, device, message broker, or other system.

<a id="cc09"></a>
### CC09 — Failed or duplicate Effects leave no attempt artifacts

- **Precondition:** An Effect is stale, incomplete, duplicated, or fails before Repository commit.
- **MUST / success:** Failure may return an ephemeral Outcome or diagnostic, but creates no persistent transition, Observation, View, current pointer, or attempt artifact.
- **Failure observation:** Any such artifact is a contract violation, not audit evidence to preserve automatically.
- **Persistent effect:** None beyond previously accepted objects.
- **Retry:** Same-request retry is not a new logical Effect Request.
- **Provenance:** Diagnostics identify the failed precondition without fabricating accepted provenance.
- **Evidence:** E70 outcome/rollback relations and four negative identities.
- **Not established:** Network retry transport, distributed deduplication, or external delivery log policy.

<a id="cc10"></a>
### CC10 — Provenance and selected-output closure

- **Precondition:** Evaluation selects an output closure from pinned Source input.
- **MUST / success:** Result, View, replay, and explanation retain required provenance and contain no Value outside the selected output closure or ambient executor metadata absent from pinned Source input.
- **Failure observation:** Missing provenance, closure-external sentinel, or executor metadata is detectable.
- **Persistent effect:** Persisted Result or View preserves the same boundary; persistence does not broaden selection.
- **Retry:** Replay cannot replace provenance with ambient current input.
- **Provenance:** Source Root, Definition, request, and other required roles remain resolvable.
- **Evidence:** E68/E69/E71/E72 leakage and provenance relations and their falsifiers.
- **Not established:** General privacy, side-channel resistance, logging redaction, or information-flow proof. Runtime or NHI attributes explicitly pinned as Source input are not prohibited.

<a id="cc11"></a>
### CC11 — Replay, explanation, and semantic integrity

- **Precondition:** The complete pinned input closure remains resolvable after restart.
- **MUST / success:** Restart and ambient-current advancement do not change replay; a finite explanation closure is available; dangling or cross-linked required references become typed Findings.
- **Failure observation:** Missing closure is unavailable, never silently substituted or declared complete.
- **Persistent effect:** Replay need not write; an accepted historical record retains its pins.
- **Retry:** Repeated replay over the same pins is logically equivalent.
- **Provenance:** Explanation connects Observation, Result, Request, Root, and selected member without requiring a unique path.
- **Evidence:** E71 replay/current-variation and E72 explanation/integrity relations.
- **Not established:** Production durability, infinite history, unique explanation path, or cryptographic audit.

<a id="cc12"></a>
### CC12 — GC-free placement eligibility

- **Precondition:** Ordinary witnesses, Conflict state, Publication state, accepted forget event, explicit policy phase, and declared archive state are available.
- **MUST / success:** Protection and candidate active-placement release eligibility are derived without changing canonical inventory.
- **Failure observation:** Active protection, closed window, or unverified archive state prevents eligibility.
- **Persistent effect:** Eligibility computation is write-free; it does not execute release or deletion.
- **Retry:** Re-evaluation over the same facts is logically stable.
- **Provenance:** A decision identifies the protection or policy/archive-state blocker.
- **Evidence:** The private design audit used E73R 30 accepted rows, seven controls, source assertion, and same-database inventory comparison. E73R is not bundled in this public package, so CC12 remains a reviewable candidate claim here, not publicly reproduced evidence.
- **Not established:** Archive reconstruction/integrity, release execution, reader coordination, GC, canonical deletion, or legal erase.

## Representation independence

Conformance is observational. It does not require SQLite table names, SQL row
order, Rust traits, UUID versions, canonical bytes, protobuf, JSON, GraphQL,
gRPC, a particular backend, or a process/thread/queue topology.

## Public evidence boundary

The bundled E67–E72 reference slice provides finite executable evidence for
the connected Repository／Evaluation lifecycle. This package does not include
the complete predecessor traceability corpus or E73R. Therefore the document
is published for design review, not as a self-contained proof that every
CC01–CC12 claim has passed backend conformance.

## Open boundary

The next contract is backend conformance: how an implementation demonstrates
these observations without exposing its physical schema. Identity composition,
Trust, Context, Delegation, cryptography, production distribution, and external
Effects remain separate work.

## References

- [Public Evidence Map](EVIDENCE.md)
- [Reference Slice](REFERENCE-SLICE.en.md)
- [Model Boundary](MODEL.md)
- [Backend Conformance Candidate](BACKEND-CONFORMANCE.md)
