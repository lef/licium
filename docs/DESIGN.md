---
Type: DESIGN
Updated: 2026-07-12T15:42:03+09:00
Status: draft
Tags: licium, design, identity, architecture, documentation
Description: Liciumの設計文書を読み始めるための現在地と文書グラフ。
---

# Licium Design Documentation

## Status

Licium is still before a stable specification. This document is the start node
for the current design context; it records how to read the documents without
pretending that unresolved hypotheses are decisions.

The central direction is deliberately small:

> Identity emerges from values and relations.

Licium explores an ID–Value substrate from which purpose-specific sets of
values and relations can be composed as Digital Identity Views. Directory,
authorization, and protocol interfaces are consumers or projections of that
substrate, not mandatory objects in the core.

## Document Graph

1. [Licium Minimal Data Model](licium-minimal-data-model.md) is the current
   broad design snapshot. It covers the minimal substrate, relations, views,
   operations, backend guarantees, directory projections, and GC boundaries.
2. [Identity Generation Hypothesis](identity-generation-hypothesis.md) narrows
   the first possible Rust milestone. It remains exploratory and may be
   disproved by worked examples.
3. [Identity and authorization systems](references/identity-authorization-systems.md)
   records primary references and compares their concerns with Licium.

The documents form a directed context graph rather than chapters of one final
specification. When the design context changes materially, prefer a new linked
document over silently rewriting history into an artificial consensus.

## Current Boundaries

The core is being designed independently of OIDC, SAML, LDAP, REST, gRPC,
OpenAPI, and GraphQL. Those can be adapters, services, or views. A deployment
may join components however it prefers; the architectural boundary matters
more than the transport.

The current model also keeps these questions separate:

- Logical operations and immutable/replayable views versus physical deletion
  and garbage collection.
- Identity composition versus authentication and authorization decisions.
- Semantic guarantees versus a particular backend, from in-memory and SQLite
  implementations to a future globally distributed store.
- A directory as a rebuildable query view versus a canonical tree of entities.

## Publication Boundary

This design node, its linked design hypothesis, and its external-reference
index are intended to be publishable. Raw transcripts and discussion-package
indexes remain private provenance because they preserve conversational context
rather than define the public project.

## References

- [Licium Minimal Data Model](licium-minimal-data-model.md)
- [Identity Generation Hypothesis](identity-generation-hypothesis.md)
- [Identity and authorization systems: primary references and comparisons](references/identity-authorization-systems.md)
- [CS-MD](https://github.com/lef/contextus/blob/main/specs/CS-MD.md)
