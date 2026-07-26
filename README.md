---
Type: README
Updated: 2026-07-26T21:30:00+09:00
Status: discussion-draft
Tags: licium, digital-identity, authentication, repository, evaluation, sqlite
Description: A minimal substrate and executable reference model for composing digital identities from values and relations.
---

# Licium

[English](#english) | [日本語](#日本語)

## English

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

### Current status

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

### Review this candidate

The Repository／Evaluation lifecycle boundary and its backend-independent
conformance questions are now concrete enough for external review.

Feedback is especially useful on:

- whether Root, Publication, Head, Result, Effect, View, and Observation remain
  cleanly separated;
- whether the candidate claims stay within the included evidence;
- whether the Backend Conformance observations are independent of SQLite;
- which Identity Definition, Context, delegation, and lineage semantics are
  still missing.

The shortest review path is:

```text
README
  -> Candidate Core Contract
  -> Candidate Backend Conformance Contract
  -> Evidence Map / executable reference slice
```

The candidate contracts are proposed requirements. The included executable
evidence remains E67–E72; predecessor evidence and E73R are not bundled.

### Executable evidence

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

### What the evidence does not prove

The reference slice does not establish production durability, distributed
consensus, external-effect atomicity, performance, cryptographic trust,
authorization correctness, real Spanner conformance, a final Rust API, or a
final storage schema. SQLite tables are a disposable realization, not the
Licium Core or a wire format.

### Read next

- [Current design](docs/DESIGN.md) /
  [日本語](docs/DESIGN.ja.md)
- [Model boundary](docs/MODEL.md) /
  [日本語](docs/MODEL.ja.md)
- [Evidence and non-conclusions](docs/EVIDENCE.md) /
  [日本語](docs/EVIDENCE.ja.md)
- [Candidate Repository / Evaluation Lifecycle Core Contract](docs/CORE-CONTRACT.md) /
  [日本語](docs/CORE-CONTRACT.ja.md)
- [Candidate Backend Conformance Contract](docs/BACKEND-CONFORMANCE.md) /
  [日本語](docs/BACKEND-CONFORMANCE.ja.md)
- [Public Sample Policy](docs/PUBLIC-SAMPLES.md) /
  [日本語](docs/PUBLIC-SAMPLES.ja.md)
- [Reference slice in English](docs/REFERENCE-SLICE.en.md)
- [Reference slice in Japanese](docs/REFERENCE-SLICE.ja.md)
- [Comparisons with Zanzibar, Macaroons, and related systems](docs/references/identity-authorization-systems.md) /
  [日本語](docs/references/identity-authorization-systems.ja.md)
- [Reproduction guide](model/README.md) /
  [日本語](model/README.ja.md)

The two superseded historical records are already written primarily in
Japanese and remain at their original paths:
[Identity Generation Hypothesis](docs/identity-generation-hypothesis.md) and
[Licium Minimal Data Model](docs/licium-minimal-data-model.md).

### Open questions

- the exact Pair／Tuple boundary between physical storage and semantic data;
- which logical objects require stable lineage identifiers;
- final Definition, Profile, Context, delegation, and Grant semantics;
- distributed publication and convergence;
- archive capacity, legal erasure, and an explicit destructive protocol;
- Rust type boundaries and backend capability contracts;
- actual SQLite and Spanner adapter conformance and performance.

### License

MIT License. See [LICENSE](LICENSE).

## 日本語

> アイデンティティは、値と関係から立ち現れる。

Liciumは、デジタルアイデンティティを構成するための、意図的に小さい基盤を
探究しています。Directory、protocol、application固有のidentity objectより下に
位置する、多値のID–Value associationが出発点です。

```text
ID -> { Value, Value, Value, ... }
```

デジタルアイデンティティはEntityそのものでも、永続的なuser entryでも
ありません。明示的に固定されたSource dataから導出される、目的別の値と関係の
集合です。

```text
固定されたknowledge cut上のSource data
    -> 完全なRepository state / Root
    -> Definition / Profile / Context evaluation
    -> 導出されたIdentityの値と関係
    -> 任意のmaterialized projection
```

Directory、LDAP、GraphQL、SCIM、OIDC、SAML、authorization system、credentialは、
このdataを利用またはprojectionできます。これらはminimal substrateの必須
primitiveではありません。

### 現在の状態

Liciumは設計とmodel-validationのprojectであり、stable specificationでも
production Identity Providerでもありません。

存在するもの:

- 公開用の設計summary;
- 使い捨てる前提のSQLite／POSIX shell reference slice;
- reference sliceに対する固定expected outputとnegative mutation。

存在しないもの:

- Rust sourceまたはCargo workspace;
- production service;
- 実際のSpanner adapterまたはconformance result;
- OIDC、SAML、LDAP、SCIM server;
- 完成したauthentication／authorization product。

### CandidateへのReview

Repository／Evaluation lifecycleの境界とbackend-independentなconformanceの問いが、
external review可能な具体性を持つ段階になりました。

特に次のfeedbackを求めています。

- Root、Publication、Head、Result、Effect、View、Observationの分離が明確か;
- candidate claimsが同梱evidenceの範囲を越えていないか;
- Backend Conformanceの観測がSQLiteから独立しているか;
- Identity Definition、Context、delegation、lineage semanticsに何が不足するか。

最短のreview path:

```text
README
  -> Candidate Core Contract
  -> Candidate Backend Conformance Contract
  -> Evidence Map / executable reference slice
```

candidate contractsは提案中のrequirementsです。同梱するexecutable evidenceは
E67–E72のままであり、predecessor evidenceとE73Rは含みません。

### 実行可能なevidence

収録されたE67–E72 reference sliceは、一つの小さなlifecycleを接続します。

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

必要なのはPOSIX shell、一般的なUnix utility、`sqlite3`です。

```text
sh model/run-reference-slice-tests.sh
```

aggregateの成功は、6個のtargeted experiment、30個のtargeted relation、25個の
negative identityを対象とします。詳細は
[再現手順](model/README.ja.md)と
[evidence map](docs/EVIDENCE.ja.md)を参照してください。

### このevidenceが証明しないもの

reference sliceは、production durability、distributed consensus、external-effect
atomicity、performance、cryptographic trust、authorization correctness、実際の
Spanner conformance、最終的なRust API、最終的なstorage schemaを確立しません。
SQLite tableは使い捨てのrealizationであり、Licium Coreでもwire formatでも
ありません。

### 次に読む文書

- [現在の設計](docs/DESIGN.ja.md) /
  [English](docs/DESIGN.md)
- [Model boundary](docs/MODEL.ja.md) /
  [English](docs/MODEL.md)
- [Evidenceと非結論](docs/EVIDENCE.ja.md) /
  [English](docs/EVIDENCE.md)
- [Repository／Evaluation Lifecycle Core Contract候補](docs/CORE-CONTRACT.ja.md) /
  [English](docs/CORE-CONTRACT.md)
- [Backend Conformance Contract候補](docs/BACKEND-CONFORMANCE.ja.md) /
  [English](docs/BACKEND-CONFORMANCE.md)
- [Public Sample Policy](docs/PUBLIC-SAMPLES.ja.md) /
  [English](docs/PUBLIC-SAMPLES.md)
- [Reference slice日本語版](docs/REFERENCE-SLICE.ja.md)
- [Reference slice English version](docs/REFERENCE-SLICE.en.md)
- [Zanzibar、Macaroons、関連systemとの比較](docs/references/identity-authorization-systems.ja.md) /
  [English](docs/references/identity-authorization-systems.md)
- [再現手順](model/README.ja.md) /
  [English](model/README.md)

supersededとなった次の二つのhistorical recordは、もともと主に日本語で書かれており、
元のpathに保存されています:
[Identity Generation Hypothesis](docs/identity-generation-hypothesis.md)、
[Licium Minimal Data Model](docs/licium-minimal-data-model.md)。

### 未決事項

- physical storageとsemantic dataの間の正確なPair／Tuple境界;
- stable lineage identifierを必要とするlogical object;
- 最終的なDefinition、Profile、Context、delegation、Grant semantics;
- distributed publicationとconvergence;
- archive capacity、legal erasure、明示的なdestructive protocol;
- Rust type boundaryとbackend capability contract;
- 実際のSQLite／Spanner adapter conformanceとperformance。

### License

MIT Licenseです。[LICENSE](LICENSE)を参照してください。
