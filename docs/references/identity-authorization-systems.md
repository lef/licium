---
Type: REFERENCE
Updated: 2026-07-26T20:00:00+09:00
Status: active
Tags: licium, identity, rebac, zanzibar, macaroons, storage, references
Description: Primary references used to stress-test Licium's design without importing whole authorization systems into its core.
---

# Identity and Authorization Systems

## Purpose

These references sharpen questions asked of Licium's minimal model. They are
not a feature checklist and do not imply adoption. Comparisons below are
Licium design interpretations, not claims made by the cited systems.

## Identity terminology

ISO/IEC 24760-1 defines identity using attributes related to an entity. That
distinction matters here: an identifier is not an Entity, and a Digital
Identity is not merely one identifier. One Entity may have several
purpose-specific identities.

- [ISO/IEC 24760-1:2025](https://www.iso.org/obp/ui/#iso:std:iso-iec:24760:-1:ed-3:v1:en)

## ReBAC and Zanzibar

Relationship-Based Access Control evaluates authorization from relationships
between entities. Gates used the term in 2007; Fong developed a formal model
and policy language; Zanzibar is a production authorization system using
relation tuples, usersets, configuration, and a global consistency contract.
Zanzibar is not the definition or origin of ReBAC.

For Licium, these systems test whether relationships can be represented
without making an authorization engine part of the minimal substrate. A
Zanzibar-like tuple may be a projection over Licium data. Zanzibar's policy
language, consistency contract, and Check API do not therefore become Licium
Core primitives.

- [Gates, “Access Control Requirements for Web 2.0 Security and Privacy”](https://www.ieee-security.org/TC/W2SP/2007/)
- [Fong, “Relationship-Based Access Control”](https://pages.cpsc.ucalgary.ca/~pwlfong/Pub/codaspy2011.pdf)
- [Pang et al., “Zanzibar”](https://www.usenix.org/conference/atc19/presentation/pang)

## Macaroons

Macaroons are authorization credentials supporting contextual caveats and
decentralized attenuation. Their central problem is safe delegation of
authority, not construction of Digital Identity.

For Licium, Macaroons test whether delegation constraints, provenance, and
Context can refer to derived Identity without forcing credential or
cryptographic semantics into the minimal substrate. A future adapter may
consume or issue macaroons; the Core need not be one.

- [Birgisson et al., “Macaroons”](https://research.google/pubs/macaroons-cookies-with-contextual-caveats-for-decentralized-authorization-in-the-cloud/)

## Repository analogies

SQLite and Spanner stress different backend capabilities. Jujutsu's operation
and conflict model, and restic's distinction between retention and physical
pruning, are useful analogies for immutable state, reconstruction, and
history. None is an Identity model, and no real Spanner conformance has yet
been executed for Licium.

- [SQLite isolation](https://www.sqlite.org/isolation.html)
- [Spanner paper](https://research.google/pubs/spanner-googles-globally-distributed-database-2/)
- [Jujutsu concurrency and operation log](https://jj-vcs.github.io/jj/latest/technical/concurrency/)
- [restic design](https://restic.readthedocs.io/en/stable/design.html)
- [restic forget and prune](https://restic.readthedocs.io/en/stable/060_forget.html)

## Identifier generation

UUIDv7 is a plausible locally generated identifier, not the definition of
Identity or a settled Core mandate.

- [RFC 9562 — UUIDs](https://www.rfc-editor.org/rfc/rfc9562.html)

## Licium documents

- [Design](../DESIGN.md)
- [Model boundary](../MODEL.md)
- [Evidence](../EVIDENCE.md)
