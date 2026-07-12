---
Type: REFERENCE
Updated: 2026-07-12T15:42:03+09:00
Status: active
Tags: licium, identity, rebac, zanzibar, macaroons, storage, references
Description: Liciumの設計を評価するための一次資料と、採用を前提としない比較メモ。
---

# Identity and Authorization Systems: References and Comparisons

## Purpose

This is not a list of features Licium intends to implement. It records primary
sources that sharpen the questions asked of Licium's minimal data structure.
The comparisons are design interpretations, not claims made by the cited work.

## Identity Terminology

ISO/IEC 24760-1 defines identity in terms of a set of attributes related to an
entity. That distinction is foundational here: an identifier is not an Entity,
and a Digital Identity is not merely one identifier. One Entity can be
represented by multiple purpose-specific identities.

- [ISO/IEC 24760-1:2025 — Framework for identity management, Part 1](https://www.iso.org/obp/ui/#iso:std:iso-iec:24760:-1:ed-3:v1:en)

## ReBAC and Zanzibar

Relationship-Based Access Control (ReBAC) evaluates authorization from
relationships between entities. Gates coined the term in a 2007 position
paper; Fong later developed a formal protection model and policy language.
Zanzibar is a production authorization
system with relation tuples, usersets, a configuration language, external
consistency, and global-scale evaluation. Zanzibar should not be treated as the
definition or origin of ReBAC.

For Licium, these works are stress tests for whether relations can be expressed
without making an authorization engine part of the core. A Zanzibar-like tuple
may be a projection over Licium data; Zanzibar's policy language, consistency
contract, and check API do not therefore become Licium primitives.

- [Gates, “Access Control Requirements for Web 2.0 Security and Privacy” (W2SP 2007 program)](https://www.ieee-security.org/TC/W2SP/2007/)
- [Gates publication index and author PDF](https://web.cs.dal.ca/~gates/publications.html)
- [Fong, “Relationship-Based Access Control: Protection Model and Policy Language” (CODASPY 2011)](https://pages.cpsc.ucalgary.ca/~pwlfong/Pub/codaspy2011.pdf)
- [Pang et al., “Zanzibar: Google's Consistent, Global Authorization System” (USENIX ATC 2019)](https://www.usenix.org/conference/atc19/presentation/pang)
- [Zanzibar paper (PDF)](https://www.usenix.org/system/files/atc19-pang.pdf)

## Macaroons

Macaroons are authorization credentials supporting contextual caveats and
decentralized attenuation. Their central problem is safe delegation of
authority, not construction of Digital Identity.

For Licium, Macaroons test whether delegation constraints, provenance, and
context can refer to identity views without forcing credential or cryptographic
semantics into the minimal ID–Value substrate. A future adapter may issue or
consume macaroons; the core need not be one.

- [Birgisson et al., “Macaroons: Cookies with Contextual Caveats for Decentralized Authorization in the Cloud” (NDSS 2014)](https://research.google/pubs/macaroons-cookies-with-contextual-caveats-for-decentralized-authorization-in-the-cloud/)
- [Macaroons paper (PDF)](https://research.google.com/pubs/archive/41892.pdf)

## Backend and Operation Models

SQLite and Spanner represent very different physical deployments. The design
question is not how to hide that difference, but which semantic guarantees are
required by Licium and which capabilities a backend may declare. Spanner is a
benchmark for global consistency concerns, not an initial implementation plan.

The operation-log and snapshot models of Jujutsu, and restic's separation of
logical retention from physical pruning, are useful analogies for immutable
history, reconstruction, concurrency, and GC. They are not identity models.

- [SQLite isolation](https://www.sqlite.org/isolation.html)
- [SQLite write-ahead logging](https://www.sqlite.org/wal.html)
- [Corbett et al., “Spanner: Google's Globally-Distributed Database”](https://research.google/pubs/spanner-googles-globally-distributed-database-2/)
- [Jujutsu concurrency and the operation log](https://jj-vcs.github.io/jj/latest/technical/concurrency/)
- [restic design](https://restic.readthedocs.io/en/stable/design.html)
- [restic forget and prune](https://restic.readthedocs.io/en/stable/060_forget.html)

## Identifier Generation

UUIDv7 is a plausible locally generated identifier because it combines
practical uniqueness with time ordering. It remains an implementation choice
under discussion, not the definition of identity or a settled core mandate.

- [RFC 9562 — Universally Unique IDentifiers (UUIDs)](https://www.rfc-editor.org/rfc/rfc9562.html)

## References

- [Licium design documentation](../DESIGN.md)
- [Licium Minimal Data Model](../licium-minimal-data-model.md)
- [Identity Generation Hypothesis](../identity-generation-hypothesis.md)
