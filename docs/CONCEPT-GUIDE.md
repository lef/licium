---
Type: GUIDE
Updated: 2026-08-07T11:26:24+09:00
Status: draft
Tags: licium, concept, identity, values, relations, repository, introduction
Description: A human-oriented introduction to Licium's central idea and design intent through one concrete example.
---

# Understanding Licium's Concept Through One Example

Japanese version: [一つの例で理解するLiciumのコンセプト](CONCEPT-GUIDE.ja.md)

## In One Sentence

Instead of forcing a person or machine into one permanent “user record,”
Licium stores values and relations and later composes the combination needed
for a particular purpose as an Identity.

> An Identity is not the Entity itself. It is a set of values and relations
> selected for a purpose.

Licium is not trying to store a fixed Directory of users. It stores the values
and relations, together with the definitions that interpret them, needed to
reconstruct multiple identities safely and deterministically.

## What We Know About Alice

Suppose an organization knows the following about Alice:

```text
Employee number:  12345
Department:       Security Operations
Position:         Analyst
Work email:       alice@example.com
Public key:       key-7
Assurance level:  AAL2
Emergency phone:  +81-XX-XXXX-XXXX
Manager:          manager-42
```

This is explanatory notation, not Licium's storage format. At the smallest
Core boundary, the substrate only needs to associate multiple Values with an
ID:

```text
alice-source-id -> employee-number:12345
alice-source-id -> department:security-operations
alice-source-id -> work-email:alice@example.com
alice-source-id -> public-key:key-7
alice-source-id -> manager-id:manager-42
...
```

If some Values are interpreted as references to other IDs, the same data
can produce a relationship graph. That does not require the Core to store
privileged `User`, `Employee`, or `GraphEdge` boxes. An upper-layer Definition
provides the meaning of each Value.

## Different Identities From the Same Alice

When Alice acts as an employee, the organization may need:

```text
Employment Identity
    employee number
    department
    position
    relation to manager
```

For a login, it needs a different selection:

```text
Login Identity
    work email
    public key
    assurance level
```

Both relate to the same Entity, but they are not the same Identity. The
emergency phone belongs in neither result and must not leak into either one.

```text
Source related to Alice
        │
        ├─ Employment Definition + Context
        │       └─ Employment Identity
        │
        └─ Login Definition + Context
                └─ Login Identity
```

Context can be more than a display filter. “As an employee,” “as a parent,” or
“while exercising a particular delegation” may change which values and
relations constitute an Identity. The exact Context model is still under
design.

## Store the Selection Rules as Data Too

If `Employment Definition` and `Login Definition` exist only as hard-coded
program logic, reproducing an old decision becomes difficult. Licium's current
direction is to store Definitions and Schemas—the rules that select and
interpret values—as ordinary Repository data too.

```text
Source values and relations
Definition
Context bindings
Trust inputs
Evaluation semantics
```

Pinning these inputs together allows an Identity to be reconstructed with its
original meaning after a Definition changes. A current Schema must not silently
reinterpret an old value.

How a Schema binds to a Pair, whether Pair alone is enough or a Tuple is
needed, and how bytes are encoded remain open questions. The important
boundary is that meaning is traceable data, not implicit current
configuration.

## What “Reconstruct It Later” Means

This does not require calling Identity itself versioned like source code. What
is fixed is the input from which the Identity was derived:

```text
complete Repository Root
        + pinned Definition
        + pinned Context／Trust inputs
        + evaluation semantics revision
        ↓
reproducible Identity Result
```

The idea resembles git and jj: point to the inputs at a particular state and
run the same algorithm to reproduce the result, rather than relying only on
today's mutable rows. The subject here is not a source tree but the Values and
relations used to compose Identity.

This makes later questions answerable:

- Which Source did the decision observe?
- Which Definition and Context did it use?
- Why was this value included and another excluded?
- Can it be evaluated again under the old Definition rather than today's one?

## Keep the Meaning Across SQLite and Rust

SQLite can store data as weakly typed rows or blobs. Rust can treat bytes read
from storage as untrusted, then expose a checked type only after decoding,
Schema validation, reference resolution, and Root-completeness checks.

```text
bytes from SQLite／KVS／network
        ↓ not trusted yet
decode and validate against Schema
        ↓
check references and pinned inputs
        ↓
use as a checked Rust value
```

Rust structs and SQLite rows do not need the same shape. They need to share
fixed Repository data, Definitions, validation rules, and tests proving that
the same inputs produce the same results.

An ORM-generated type therefore does not become a Core type directly. A Rust
type is evidence that specific checks have passed, not a mirror of storage
layout.

## Directory and OIDC Sit Above the Core

Arrange Employment Identities for search and they can form a Directory View.
Project Login Identities into OIDC claims and they can feed an OIDC provider.
Project relations for traversal and they can form Graph and Authorization
Views.

```text
values + relations + pinned definitions
                ↓
       reproducible Identity
                ↓
   ┌────────────┼────────────┐
Directory     OIDC／SAML    Graph／Authorization
View          adapter       View
```

These systems matter, but they are not the minimal Licium Core. Keeping LDAP,
OIDC, SAML, and any particular database from defining Core meaning leaves room
to implement the same logical model at different scales, from one SQLite
daemon to a distributed backend.

## Let LLMs Participate Without Losing Replay

An LLM can discover unusual relationships in a large activity graph or propose
a new Definition. Its proposal need not become implicit authority:

```text
LLM proposes a relation or Definition
        ↓
a person or policy decides whether to accept it
        ↓
the accepted Definition is recorded in the Repository
        ↓
fixed inputs are evaluated deterministically
```

Combining probabilistic discovery with traceable Identity decisions is one
reason this model matters for LLM-era operations.

## What Licium Is Trying to Build

Licium is neither a universal new database nor an all-in-one IdP. Its small
Core centers on two responsibilities:

1. Treat values, relations, and their interpreting Definitions as reproducible
   Repository state.
2. Deterministically generate a purpose-specific Identity from fixed inputs.

Authentication protocols, Directories, risk engines, LLM detectors, and
authorization can be replaceable modules that use this Core.

## What Is Still Open

This guide is not a completed specification. Major open questions include:

- whether the Core can remain Pair-only or needs a Tuple-like contract;
- the smallest way to bind a Schema to a Value;
- deterministic encoding for Repository bytes;
- the final boundaries of Context, delegation, and Trust;
- Conflict representation when multiple Heads do not converge;
- an operational model that can release active storage without losing audit
  capability.

The precise current state, evidence graph, and open boundaries begin at
[Licium Design](DESIGN.md).
