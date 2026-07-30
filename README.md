---
Type: README
Updated: 2026-07-29T17:32:00+09:00
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
production-ready IdP.

What exists:

- public-facing design summaries;
- a disposable SQLite and POSIX-shell reference slice;
- fixed expected outputs and negative mutations for that slice.
- a finite runnable Protocol Integration Proof sample.

What does not exist:

- Rust source or a Cargo workspace;
- a production service;
- a real Spanner adapter or conformance result;
- production OIDC, SAML, LDAP, or SCIM servers;
- a completed authentication or authorization product.

### Protocol Integration Proof — finite runnable sample

- A disposable finite Protocol Integration Proof is implemented and included
  in this repository tree. Its technical presence does not record
  repository-specific review or authorization state.
- The sample runs an Authorization Code + S256 PKCE loopback flow with pinned
  `oidc-provider` 9.11.1, a replaceable adapter, and exact SQLite and
  flat-file／POSIX providers.
- The engine owns protocol flow, sessions, tokens, and signing. The test RP
  owns its verifier, state, nonce, and token validation. Licium supplies a
  protocol-neutral authentication request, pinned evaluation, subject
  decision, and selected Identity projection.
- The aggregate runner binds 63 suites: 43 positive／boundary verifiers and 20
  negative self-tests. Static closure covers 71 shell files and 15
  project-authored ESM files.
- Dependencies are not vendored. Reproduction requires exact Node v22.22.2
  and retrieves the pinned npm dependency graph from `package-lock.json`.
- The runtime uses loopback `127.0.0.1:56100`; `127.0.0.1:56101` is only a
  redirect identifier and needs no listener.
- This remains a synthetic, disposable, non-production slice. It does not make
  Licium a production IdP, put OIDC into Licium Core, certify OIDC or security,
  establish arbitrary-backend portability, or implement Spanner or Rust.
- [Read the proof summary](docs/PROTOCOL-INTEGRATION-PROOF.md) or
  [run the sample](model/protocol-integration-proof/README.md).
- Artifact review, local preparation, commit review, and push authorization are
  external operational records. Inclusion of these bytes grants no standing
  authorization for a later repository mutation or push.

### Roadmap — from disposable proof to a typed provider

- Treat this finite integration as the pre-Rust toy IdP vertical slice for
  learning the boundary, not as source code to translate line by line.
- Keep the pinned generic OIDC engine and protocol-facing adapter outside
  Licium Core. Licium continues to expose a protocol-neutral backend contract.
- In the first Rust milestone, replace exactly one protocol-neutral provider
  while leaving the OIDC engine and protocol-facing adapter unchanged.
- Keep the SQLite and flat-file／POSIX providers as comparison oracles and add
  the Rust provider as a third implementation of the same bounded contract.
- This Roadmap does not select a stable Core API, arbitrary-backend support,
  Spanner, an async runtime, an ORM, a transport, or a production IdP design.

### SQLite reference conformance update

The exact test-only `sqlite-reference-v0` tuple later recorded 83/83 `PASS` in
two fresh isolated sealed sessions. BC01--BC12 and the overall report were
`PASS`; `FAIL`, `UNTESTED`, `UNAVAILABLE`, and `INVALID` were all zero. This
result is limited to the recorded implementation, adapter, profile, SQLite
runtime, configuration, and tested SUT revision
`630adfd92cee8ce19249f401b6238e5261a4b33d`.

The accepted result also passed current-source closure, session binding,
evidence sealing, 19 run self-test controls, 6 session self-test controls, and
an independent exact-report review with disposition `ACCEPTED`. This
609-file reviewer package includes the complete 472-file SQLite replay source
used to generate a fresh full session.

Publication still has distinct states: technical acceptance, project-owner
artifact countersign, sibling local preparation, local-commit review, and
public-push authorization. Before sibling local preparation, the project owner
must countersign the exact manifest, all 609 rights/data rows, the material-claim
inventory, and the safety exceptions. That countersign permits only the bound
local preparation; it does not authorize a public push. Public push requires a
later, separate project-owner authorization after local-commit review.

Read [SQLite Backend Conformance v0 Result](docs/SQLITE-CONFORMANCE.md). It
separates the quick static integrity check of a compact 47-file evidence
reference from multi-hour fresh runtime and negative self-tests; the static
reference is not a standalone sealed session or a substitute for a fresh full
gate.

Reviewers are invited to inspect the exact tuple, evidence boundary, and
reproduction instructions, and to report reproducible counterexamples or
claims that exceed the stated boundary. This is not SQLite product or
production-service certification, and Spanner remains `UNTESTED`.
Technical review does not authorize a public push. Public GitHub publication
requires separate explicit project-owner authorization.

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
- production SQLite deployment behavior and real Spanner adapter conformance
  and performance.

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
production-ready IdPでもありません。

存在するもの:

- 公開用の設計summary;
- 使い捨てる前提のSQLite／POSIX shell reference slice;
- reference sliceに対する固定expected outputとnegative mutation。
- finite runnable Protocol Integration Proof sample。

存在しないもの:

- Rust sourceまたはCargo workspace;
- production service;
- 実際のSpanner adapterまたはconformance result;
- production OIDC、SAML、LDAP、SCIM server;
- 完成したauthentication／authorization product。

### Protocol Integration Proof — 有限のrunnable sample

- 使い捨てのfinite Protocol Integration Proofを実装し、このrepository treeへ
  含めた。技術的な存在はrepository固有のreview／authorization stateを記録しない。
- sampleは、固定した`oidc-provider` 9.11.1、交換可能なadapter、exact SQLite／
  flat-file／POSIX providersを使い、Authorization Code + S256 PKCEのloopback
  flowを実行する。
- engineがprotocol flow、session、token、署名を所有する。test RPがverifier、
  state、nonce、token validationを所有する。Liciumはprotocol-neutralな
  authentication request、pinned evaluation、subject decision、selected Identity
  projectionを供給する。
- aggregate runnerは63 suitesを固定する。43のpositive／boundary verifierと20の
  negative self-testである。static closureは71 shell filesと15 project-authored
  ESM filesをcoverする。
- dependencyはvendorしない。再現にはexact Node v22.22.2が必要で、
  `package-lock.json`から固定npm dependency graphを取得する。
- runtimeはloopback `127.0.0.1:56100`を使う。`127.0.0.1:56101`はredirect
  identifierだけで、listenerは不要である。
- これはsynthetic、disposable、non-productionのsliceである。Liciumをproduction
  IdPにせず、OIDCをLicium Coreへ入れず、OIDC／security certification、任意backend
  portability、Spanner／Rust implementationを確立しない。
- [proof summaryを読む](docs/PROTOCOL-INTEGRATION-PROOF.ja.md)、
  または[sampleを実行する](model/protocol-integration-proof/README.ja.md)。
- artifact review、local preparation、commit review、push authorizationはartifact
  外のoperational recordである。このbytesの存在は、後続repository mutation／push
  へのstanding authorizationを与えない。

### Roadmap — 使い捨てproofからtyped providerへ

- このfinite integrationを、source codeの逐語移植対象ではなく、境界を学習する
  Rust前のtoy IdP vertical sliceとして扱う。
- 固定した汎用OIDC engineとprotocol-facing adapterをLicium Core外に保つ。Liciumは
  引き続きprotocol-neutral backend contractを公開する。
- 最初のRust milestoneではOIDC engineとprotocol-facing adapterを変更せず、
  protocol-neutral provider一個だけを置換する。
- SQLite／flat-file／POSIX providersをcomparison oraclesとして保持し、同じbounded
  contractの第三implementationとしてRust providerを追加する。
- このRoadmapはstable Core API、任意backend support、Spanner、async runtime、
  ORM、transport、production IdP designを選択しない。

### SQLite reference conformance update

Backend Conformance v0 requirementsは、その後exact test-only
`sqlite-reference-v0` tupleで実行された。二つのfresh isolated sealed sessionで
83/83、BC01--BC12、overall reportは`PASS`、`FAIL`、`UNTESTED`、`UNAVAILABLE`、
`INVALID`はすべて0だった。このresultは記録されたimplementation、adapter、profile、
SQLite runtime、configuration、tested SUT revision
`630adfd92cee8ce19249f401b6238e5261a4b33d`に限られる。

accepted resultはcurrent-source closure、session binding、evidence sealing、
19 run self-test controls、6 session self-test controls、independent exact-report
reviewの`ACCEPTED`もPASSした。この609-file reviewer packageはfresh full sessionを
生成するための完全な472-file SQLite replay sourceを含む。

publicationにはtechnical acceptance、project-owner artifact countersign、
sibling local preparation、local-commit review、public-push authorizationという
別々のstateがある。sibling local preparationの前に、project ownerはexact manifest、
609件すべてのrights／data row、material-claim inventory、safety exceptionを
countersignしなければならない。このcountersignが許可するのはbindingされたlocal
preparationだけであり、public pushはauthorizeしない。public pushにはlocal-commit
review後の、project ownerによる別の明示的なauthorizationが必要である。

[SQLite Backend Conformance v0 Result](docs/SQLITE-CONFORMANCE.ja.md)は、compactな
47-file evidence referenceのquick static integrity checkとmulti-hour fresh runtime／
negative self-testを分けて説明する。static referenceはstandalone sealed sessionでも
fresh full gateの代用でもない。

reviewerはexact tuple、evidence boundary、reproduction instructionsを検査し、再現可能な
counterexampleまたは明記したboundaryを越えるclaimを報告してほしい。これはSQLite
product一般またはproduction serviceのcertificationではなく、Spannerは`UNTESTED`のままである。
technical reviewはpublic pushをauthorizeしない。public GitHubへの公開には、project
ownerによる別の明示的な許可が必要である。

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
- production SQLite deploymentのbehavior、real Spanner adapterのconformanceと
  performance。

### License

MIT Licenseです。[LICENSE](LICENSE)を参照してください。
