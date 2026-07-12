---
Type: README
Updated: 2026-07-12T00:00+09:00
Status: discussion-draft
Tags: licium, digital-identity, attributes, nhi, llm, authorization
Description: A minimal data structure for composing digital identities from values and relations.
---

# Licium

> **Identity emerges from values and relations.**

Licium is an experiment in reducing digital identity to its smallest useful
shape: a multivalued **ID–Value structure** from which purpose-specific sets
of values and relations can be composed as digital identities.

```text
ID → { Value, Value, Value, ... }
```

No mandatory User object. No canonical directory tree. No protocol-specific
claims in the core.

Just a tiny substrate on which human identities, workloads, short-lived
processes, AI agents, credentials, relationships, and authorization views can
be composed.

## The idea

A digital identity is not the Entity itself. It is a particular set of values
and relations associated with an Entity and composed for a purpose.

The same Entity may therefore have many identities:

```text
Employment identity  → employee number, department, position
Login identity       → login identifier, key, assurance
Workload identity    → image digest, attestation, runtime key
Agent identity       → model, tools, delegation, session constraints
```

Licium keeps the substrate deliberately smaller than those concepts. Meaning
is introduced by selectors and profiles above the core.

```text
Raw ID–Value data
        ↓ selector
Purpose-specific set of values and relations
        ↓
Digital Identity View
```

## Why this shape?

Traditional identity systems tend to begin with a durable entry: a user row,
an LDAP object, a device record, or a service account. That model becomes
awkward for non-human identities whose useful boundaries may be a deployment,
a process incarnation, an attestation, an agent session, or a single tool
invocation.

Licium starts below the entry.

- An **Identity** is a composed set of values and relations, not a permanent box.
- A **Relation** is an interpretation of one value as a reference to another ID.
- A **Graph** is a view over ID–Value data, not a required core ontology.
- A **Directory** is a rebuildable, query-optimized materialized view, not the
  source of truth.
- LDAP, GraphQL, SCIM, OIDC, SAML, Zanzibar-style ReBAC, and Macaroon-style
  delegation belong above the same substrate.

## One model, different scales

The logical model is intentionally small enough to map to a local SQLite
database and to a globally distributed store such as Spanner without claiming
that both provide the same operational guarantees.

```text
                     ┌─ LDAP Directory View
ID–Value Repository ─┼─ Graph / GraphQL View
                     ├─ Search Index
                     ├─ Authorization View
                     └─ Protocol Projection
```

SQLite and Spanner may differ in transaction time, concurrency, availability,
and throughput. They should not differ in what an ID–Value pair means or in
the result of a deterministic selector over the same snapshot.

## History without making history the schema

The emerging repository model draws inspiration from mature content-addressed
and version-control systems:

- **restic / rustic** for immutable objects, snapshots, rebuildable indexes,
  consistency checks, retention, and prune;
- **git / jj** for operations, views, merge, conflict, undo, and reachability;
- **SQLite → Spanner** as the portability and scalability stress test.

Logical removal, concurrent change, retention, and physical garbage collection
are therefore treated as repository operations—not as an eager `DELETE` from
the identity model.

## LLMs and deterministic identity

LLMs may be useful for discovering relationships, mapping unfamiliar schemas,
and proposing selectors. They should not silently become the final authority
on a hot authorization path.

```text
LLM                      Deterministic evaluator
proposes semantics   →   executes an approved selector
maps schemas         →   reads a fixed snapshot
explains results     →   produces a reproducible view
```

Licium aims to preserve both sides: flexible semantic discovery and
deterministic, replayable evaluation.

## What Licium is not

Licium is not:

- a traditional IdP;
- an LDAP replacement;
- an authorization policy language;
- a universal root of trust;
- a new JWT, VC, X.509, SAML, or Macaroon format;
- a canonical registry of all Entities;
- a claim that every backend has Spanner-level guarantees.

Those systems and formats may be sources, projections, evaluators, or
interfaces over Licium data.

## Status

Licium is at the design and model-validation stage. The current direction is a
discussion draft, not a stable specification.

Start with [the design documentation](docs/DESIGN.md) for the current model,
open hypotheses, and comparisons with ReBAC, Zanzibar, and Macaroons.

## Road to 0.1.0

The first meaningful milestone is **Identity generation**, not merely ID
generation or another protocol implementation.

```text
ID–Value substrate
        ↓ selector
Identity generation
        ↓
Reproducible Identity View
```

The initial release is intended to provide:

- Identity generation from values and relations;
- explicit multivalue semantics;
- deterministic selection;
- reproducible Identity Views;
- property-tested merge behavior.

It is intentionally not intended to provide authentication, authorization,
protocol servers, or networking. Those belong in independently replaceable
components above the backend semantics.

The immediate questions are intentionally fundamental:

1. Are values a set or a bag?
2. Must the core distinguish literal values from references?
3. How are selectors represented, versioned, and replayed?
4. When does a selected Identity View receive a persistent identifier?
5. How do operation merge, retention roots, and physical GC interact?
6. Which guarantees are portable from SQLite to Spanner, and which must remain
   explicit backend capabilities?

The repository will grow from those invariants outward—not from a checklist of
identity protocols inward.

## License

MIT License. See [LICENSE](https://github.com/lef/licium/blob/main/LICENSE).
