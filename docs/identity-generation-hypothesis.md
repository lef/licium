---
Type: DRAFT
Updated: 2026-07-12T15:42:03+09:00
Status: draft
Tags: licium, identity-generation, selector, rust, milestone
Description: 値と関係から目的別のDigital Identity Viewを生成する、未確定の設計仮説。
---

# Identity Generation Hypothesis

## 1. Purpose

Licium `0.1.0` の最初の意味あるmilestoneを、単なるID generationではなく **Identity generation** とする案を検討する。

この文書は仕様ではない。以下のcontract、examples、invariants、実装順序はすべて未確定であり、worked exampleと実験を通じて変更または棄却され得る。

## 2. Central Hypothesis

> Identity generationとは、あるsource Viewから、Selectorとparametersに従って、目的に応じた値と関係の集合をDigital Identity Viewとして構成する決定論的操作である。

暫定的な形は次である。

```text
GenerateIdentity(
    source_view,
    selector,
    parameters
) -> identity_view
```

この式はAPI仕様ではなく、議論対象を明らかにするための概念表現である。

## 3. Undecided Terms

### 3.1 source_view

未確定事項:

- 単なる`ID:Value`集合か。
- Operation/View modelで固定されたsnapshotか。
- relation traversalに必要な参照範囲をどう表すか。
- sourceの完全性と鮮度をどう証明するか。

### 3.2 selector

未確定事項:

- attribute/valueの列挙だけか。
- relation traversalを含むか。
- schema、issuer、validity等を解釈するか。
- Selector自体を同じ`ID:Value`構造へ保存するか。
- Rust関数、declarative data、DSLのどれとして表すか。

初期spikeではSelector languageを設計せず、固定されたRust関数またはtest fixtureで必要な表現力を観察する案が有力である。

### 3.3 parameters

候補:

- purpose
- audience
- evaluation time
- relying party
- required assurance
- disclosure constraints

これらをCore contractに含めるか、Selectorが解釈する任意Valueとするかは未確定である。

### 3.4 identity_view

未確定事項:

- 値だけか、関係も含むか。
- provenanceを含むか。
- materialized resultか、遅延評価可能なViewか。
- 新しい永続IDを持つか。
- content hashで固定できるか。
- 同じ入力に対しbyte-identicalな結果を要求するか。

## 4. Worked Example A: Human

目的は、一つのEntityに関連するデータから複数のIdentityが生成されることを確認することである。

```text
Source values and relations:
    legal/display name
    employee number
    department
    position
    email address
    public key
    assurance information
```

Employment Selector:

```text
Result:
    employee number
    department
    position
```

Login Selector:

```text
Result:
    login/email identifier
    public key
    assurance information
```

検証したい仮説:

- EntityとIdentityは同一ではない。
- 同じEntityに複数のIdentity Viewを生成できる。
- Selectorが目的ごとの境界を作る。
- 選択されなかったValueを結果へ混入させない。

## 5. Worked Example B: NHI

目的は、永続Directory Entryや安定したHuman User modelを前提にせず、短命なIdentityを生成できることを確認することである。

```text
Source values and relations:
    source commit
    build artifact
    image digest
    deployment
    process incarnation
    workload attestation
    runtime key
    agent session
    tool delegation
    invocation constraints
```

Tool Invocation Selector:

```text
Result:
    image digest
    workload attestation
    runtime key
    delegated authority
    agent session constraints
    invocation purpose
```

検証したい仮説:

- Identity Viewに永続Entry IDを必ずしも与えなくてよい。
- deployment、runtime、session、invocationを一つの恒久Entity recordへ潰さない。
- Identity generation時に必要な関係だけを構成できる。
- 短命な結果も同じ入力からreplayできる。

## 6. Worked Example C: Relation Traversal

目的は、Identity generationが単純なkey filterを超えてrelation traversalを必要とするか確認することである。

```text
workload
    -> deployment
    -> service
    -> organization
```

候補Selector:

```text
Starting from workload:
    include workload-local values
    follow deployment relation
    follow service relation
    include organization affiliation
```

検証したい仮説:

- 一部のValueを別IDへの参照として解釈できる。
- traversal depthと許可されたrelationを制限できる。
- cycleを安全に処理できる。
- backendが異なっても同じlogical snapshotから同じ結果を生成できる。

このexampleはZanzibar-style relation View、Directory projection、LDAP View等の基礎的stress testにもなる。

## 7. Candidate Invariants

以下は採用前の候補である。

```text
1. Identityは値と関係の集合として生成される。

2. 同じsource View、Selector、parametersからは
   同じIdentity Viewが生成される。

3. Identity generationはsource Viewを変更しない。

4. Selectorが採用しないValueを結果へ混入させない。

5. Relation traversalは有限であり、cycleを安全に処理する。

6. Backendが異なっても、同じlogical snapshotに対して
   同じIdentity Viewを生成する。

7. Protocol固有概念をIdentity generation contractへ入れない。

8. Failureや不完全な結果をsilent successとして扱わない。
```

特に、決定性がsemantic equalityを意味するのか、canonical bytesまでの一致を意味するのかは未決定である。

## 8. Proposed Rust Spike

初期spikeは一つのcrate、in-memory、同期処理で行う案を検討する。

```text
licium/
  src/
    id.rs
    value.rs
    snapshot.rs
    identity.rs
  tests/
    human.rs
    nhi.rs
    relations.rs
    properties.rs
```

初期段階で避ける候補:

- Tokio
- async-trait
- SQL
- gRPC
- OpenAPI
- GraphQL
- crypto
- OIDC / SAML / LDAP implementation
- Selector DSL

spikeの目的はproduct APIを確定することではなく、三つのworked exampleを最小表現で成立させ、必要なsemantic primitiveを発見することである。

## 9. Proposed Order of Experiments

```text
1. Static in-memory snapshotからIdentityを生成する。

2. Human / NHI / Relation traversal examplesを通す。

3. 候補invariantsをproperty testへ落とす。

4. SQLite backendで同じconformance suiteを通す。

5. Operation/View modelからsource snapshotを生成する。

6. 並行Operationとmergeを試す。

7. Directory indexをbuild/delete/rebuildする。

8. Reachability/GC dry-runを試す。
```

Spanner implementationは初期scopeに含めず、SQLite backendとのsemantic contractから将来必要なCapability差を抽出する。

## 10. Acceptance Question

この仮説を採用する前に、少なくとも次へ答える必要がある。

> Liciumでなければ生成できない、またはLiciumによって再現可能性・移植性が明確に改善されるIdentity Viewとは何か。

単なるmultimap lookupやattribute filterに留まる場合、Licium独自の価値はまだ証明されていない。値と関係からIdentityを生成し、backendを越えて再現できるところまでを実験対象とする。

## References

- [Licium design documentation](DESIGN.md)
- [Licium Minimal Data Model](licium-minimal-data-model.md)
- [Identity and authorization systems: primary references and comparisons](references/identity-authorization-systems.md)
