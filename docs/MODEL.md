---
Type: DESIGN
Updated: 2026-07-26T20:00:00+09:00
Status: discussion-draft
Tags: licium, model, pair, tuple, source, identity, projection
Description: Public summary of the minimal Pair substrate, semantic Identity boundary, and derived projections.
---

# Licium Model Boundary

[日本語版](MODEL.ja.md)

## Identity is derived

An identifier is not an Entity, and one identifier alone is not a Digital
Identity. One Entity may be represented by multiple identities for different
purposes.

```text
Employment identity -> employee number, department, role
Login identity      -> login identifier, key, assurance
Workload identity   -> artifact digest, attestation, runtime key
Agent identity      -> model, tools, delegation, session constraints
```

Licium treats Identity as values and relations selected from explicit Source
state. Context matters because the same Entity may expose or exercise
different attributes and relations as an employee, parent, agent, or delegate.
The final Context representation remains open.

## Minimal physical substrate

The smallest physical Repository candidate remains pair-shaped.

```text
opaque key : canonical bytes
```

A key is not necessarily an Entity ID. Storage Object IDs, source-support
handles, indexes, and mutable reference names may occupy separate namespaces.
The physical Pair does not erase those distinctions.

## Semantic shape

Identity semantics are tuple-like even when stored on a Pair substrate.

```text
subject : predicate : typed value
```

Scalar values, Entity references, assertions, attestations, selectors, and
grants may require different validation. This does not adopt one universal
three-column SQL table. It states that semantic structure must not leak into
application code as unvalidated opaque bytes.

The Pair／Tuple boundary is a current candidate:

- Pair for a small replaceable physical Repository interface.
- Tuple-like typed structure for evaluation and Identity meaning.

## Relations

A relation is not inferred from byte equality alone. Treating every Value that
matches an existing ID as a reference creates spurious edges when a literal
happens to share those bytes.

Reference intent therefore belongs to typed semantics above the opaque
physical Pair. A Graph is a useful view of those references, not a mandatory
storage ontology.

## Source, Root, and knowledge cut

The reproducible input to one evaluation is Source data at a pinned knowledge
cut in a complete Root.

```text
Source objects
    -> complete Root
    -> pinned Definition / Profile / Context
    -> derived Identity Result
```

`Authoritative` does not mean one eternal global version. It means that the
pinned Source state is the identified input from which that Result can be
replayed.

## Views and directories

A Directory is a rebuildable, query-optimized materialized projection.
LDAP, GraphQL, search, authorization, and protocol-specific records may be
other projections. They can have freshness and indexing policies without
becoming the Source ontology.

## Identity roles

Licium does not assign one ID role to everything. These remain distinct design
roles:

```text
Entity ID
Storage Object ID
stable logical lineage ID
revision ID
operation ID
delivery occurrence ID
source-support ID
persisted Result ID
```

The included E64 evidence found no operation requiring a dedicated durable ID
for Evaluation logical equivalence. It did not reject stable lineage IDs for
other objects.

## Open model questions

- canonical bytes, hashes, namespaces, and identifier minting;
- the final typed Value and relation vocabulary;
- Definition, Profile, Context, delegation, and Grant semantics;
- merge and conflict behavior for each logical object;
- when a derived Identity receives a persistent identifier;
- archive, erasure, and destructive-operation semantics;
- Rust types that enforce these boundaries without exposing backend rows.

## References

- [Licium Design](DESIGN.md)
- [E67–E72 Evidence Map](EVIDENCE.md)
- [Identity and Authorization Systems](references/identity-authorization-systems.md)
