---
Type: SPEC
Updated: 2026-07-26T20:30:00+09:00
Status: draft
Tags: licium, public, sample, evidence, publication
Description: Candidate public-facing requirements for publishing reproducible, evidence-bounded Licium samples.
---

# Public Sample Policy

日本語: [Public Sample Policy](PUBLIC-SAMPLES.ja.md)

## Purpose

A public Licium sample is a finite, reproducible piece of evidence. It must
help a reader inspect one claim without implying that the whole Licium design
or a production implementation is complete.

Passing the technical checks makes a sample eligible for review. It does not
by itself authorize a public commit or push.

## Required properties

### Evidence-bounded

Every material supported claim identifies:

- the public document that makes the claim;
- a positive runner and fixed oracle;
- the expected observation;
- a falsifier or negative control;
- an explicit non-conclusion and open boundary.

Hypotheses, open questions, and not-yet-implemented behavior are labelled
separately. A sample may be useful without claiming universal proof.

The profile inventories every material claim with a unique ID and classifies
it exactly once as supported, candidate, hypothesis, open, or not implemented.
Candidate means a proposed normative boundary under review, not a stable,
implemented, or evidence-confirmed claim. Supported claims and evidence-matrix
rows, and candidate claims and candidate-matrix rows, each have an exact
one-to-one correspondence. Missing and extra IDs both fail verification. A
human reviewer checks for material statements omitted from the inventory.

### Reproducible

The sample has an exact file manifest and a documented command. Two builds
from the same tracked source revision must produce the same regular files,
modes, and bytes. Runtime dependencies, expected counts, and failure markers
are stated explicitly.

Manifest paths use a fixed grammar. Only regular files with declared modes are
accepted; symbolic links, devices, FIFOs, sockets, submodules, and other
non-regular entries are rejected.

SQLite tables, shell commands, test TSV, and fixture vocabulary are reference
realizations unless a separate contract says otherwise. They are not
automatically the Licium Core, final API, or wire format.

### Safe to redistribute

Every source file has a reviewed project or third-party license, compatibility
decision, required attribution or notice, redistribution right, and data
origin. Origin is declared as synthetic, public, first-party approved, or
third-party approved. The sample contains no unreviewed third-party material,
personal data, customer data, production data, credentials, private keys,
internal paths, or private review provenance.

Synthetic fixtures record how they were generated and reviewed. Intentional
secret-like test sentinels require an exception bound to path, exact bytes or
pattern, rationale, and source blob or content digest.

License compatibility, redistribution authority, and data origin require
human review; a scanner alone is not sufficient.

### Self-contained for readers

The public entry point explains:

- purpose and scope;
- what is included;
- how to reproduce it;
- what the evidence supports;
- what it does not establish;
- current open questions.

Readers must not need a private repository or private history. If multiple
languages are claimed, the supported documents retain equivalent claim
strength, limitations, navigation, commands, and counts.

The profile fixes cold-reader questions, required answer fields, forbidden
overclaims, allowed public entry points, and a machine-recordable verdict.

### Copy-only promotion

An ordinary sample promotion may add or byte-update only paths on an exact
allowlist. It forbids deleting, renaming, archiving, changing the mode of an
existing public path, and rewriting history. Such an operation requires a
separate destructive-operation contract before it can be proposed.

The review classifies every path in the union of manifest destinations and the
live public baseline. It proves byte-identical collisions, reviews every
reader-visible retained unlisted path, and rejects retained non-regular
entries. The candidate, overlay, and reviewed commit must have identical
allowed paths, kinds, modes, and bytes, with no change outside the allowlist.

The source revision, profile revision and digest, manifest digest, target
repository and ref, live baseline commit, proposed tree, diff digest,
authorization scope, and reviewed commit range or tip are bound together. Any
bound-field change invalidates downstream approval and requires a new review.

## Review states

```text
planned
  -> candidate accepted
  -> local preparation authorized
  -> local commit reviewed
  -> public push authorized
  -> delivered and verified
```

Each transition is separate. Historical approval is evidence of a past
delivery, not reusable permission for a changed artifact.

## Not established by this policy

This policy does not certify production security, durability, performance,
privacy compliance, cryptographic correctness, distributed consensus, or
fitness for a particular deployment. Those properties require their own
requirements and evidence.

## Initial profile

The current E67–E72 SQLite and POSIX-shell reference slice is the initial
historical sample mapped to this policy. Its public evidence is available from
the repository README and evidence map. Conformance to the reusable profile
remains candidate work until the generic verifier and differential negative
suite are complete.

## References

- [Public Sample Policy in Japanese](PUBLIC-SAMPLES.ja.md)
- [Current Design](DESIGN.md)
- [Evidence Map](EVIDENCE.md)
- [Reference Slice](REFERENCE-SLICE.en.md)
