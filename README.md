---
Type: README
Updated: 2026-07-26T20:00:00+09:00
Status: discussion-draft
Tags: licium, digital-identity, authentication, repository, evaluation, sqlite
Description: A minimal substrate and executable reference model for composing digital identities from values and relations.
---

# Licium

> Identity emerges from values and relations.

Licium explores a deliberately small substrate for composing Digital Identity:
multivalued ID–Value associations below directories, protocols, and
application-specific identity objects.

```text
ID -> { Value, Value, Value, ... }
```

A Digital Identity is not an Entity or a permanent user entry. It is a
purpose-specific set of values and relations derived from explicitly pinned
Source data.

```text
Source data at a pinned knowledge cut
    -> complete Repository state / Root
    -> Definition / Profile / Context evaluation
    -> derived Identity values and relations
    -> optional materialized projection
```

Directory, LDAP, GraphQL, SCIM, OIDC, SAML, authorization systems, and
credentials may consume or project this data. They are not mandatory
primitives in the minimal substrate.

## Current status

Licium is a design and model-validation project, not a stable specification or
production Identity Provider.

What exists:

- public-facing design summaries;
- a disposable SQLite and POSIX-shell reference slice;
- fixed expected outputs and negative mutations for that slice.

What does not exist:

- Rust source or a Cargo workspace;
- a production service;
- a real Spanner adapter or conformance result;
- OIDC, SAML, LDAP, or SCIM servers;
- a completed authentication or authorization product.

## Executable evidence

The included E67–E72 reference slice connects one small lifecycle:

```text
Pair ingest
  -> complete Root
  -> accepted Publication / Head
  -> pinned Evaluation
  -> Result
  -> optional Repository Effect + Decision Observation
  -> View
  -> restart / historical replay / explanation
```

Requirements are a POSIX shell, common Unix utilities, and `sqlite3`.

```text
sh model/run-reference-slice-tests.sh
```

The successful aggregate covers six targeted experiments, 30 targeted
relations, and 25 negative identities. See the
[reproduction guide](model/README.md) and
[evidence map](docs/EVIDENCE.md).

## What the evidence does not prove

The reference slice does not establish production durability, distributed
consensus, external-effect atomicity, performance, cryptographic trust,
authorization correctness, real Spanner conformance, a final Rust API, or a
final storage schema. SQLite tables are a disposable realization, not the
Licium Core or a wire format.

## Read next

- [Current design](docs/DESIGN.md)
- [Model boundary](docs/MODEL.md)
- [Evidence and non-conclusions](docs/EVIDENCE.md)
- [Reference slice in English](docs/REFERENCE-SLICE.en.md)
- [Reference slice in Japanese](docs/REFERENCE-SLICE.ja.md)
- [Comparisons with Zanzibar, Macaroons, and related systems](docs/references/identity-authorization-systems.md)

## Open questions

- the exact Pair／Tuple boundary between physical storage and semantic data;
- which logical objects require stable lineage identifiers;
- final Definition, Profile, Context, delegation, and Grant semantics;
- distributed publication and convergence;
- archive capacity, legal erasure, and an explicit destructive protocol;
- Rust type boundaries and backend capability contracts;
- actual SQLite and Spanner adapter conformance and performance.

## License

MIT License. See [LICENSE](LICENSE).
