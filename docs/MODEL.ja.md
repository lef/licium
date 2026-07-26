---
Type: DESIGN
Updated: 2026-07-26T20:00:00+09:00
Status: discussion-draft
Tags: licium, model, pair, tuple, source, identity, projection, japanese
Description: 最小Pair substrate、semantic Identity境界、derived projectionの公開用概要。
---

# Licium Model Boundary

[English version](MODEL.md)

## Identityはderivedである

identifierはEntityではなく、一つのidentifierだけではDigital Identityでは
ありません。一つのEntityは、異なる目的のための複数のidentityによって表現される
場合があります。

```text
Employment identity -> employee number, department, role
Login identity      -> login identifier, key, assurance
Workload identity   -> artifact digest, attestation, runtime key
Agent identity      -> model, tools, delegation, session constraints
```

Liciumは、Identityを明示的なSource stateから選択されたvaluesとrelationsとして
扱います。同じEntityでもemployee、parent、agent、delegateとして異なるattributeや
relationを公開または行使し得るため、Contextは重要です。最終的なContext表現は
未決です。

## 最小のphysical substrate

最小のphysical Repository candidateは、引き続きpair-shapedです。

```text
opaque key : canonical bytes
```

keyは必ずしもEntity IDではありません。Storage Object ID、source-support handle、
index、mutable reference nameは、別々のnamespaceに属する場合があります。
physical Pairは、それらの区別を消去しません。

## Semantic shape

Pair substrateに保存される場合でも、Identity semanticsはtuple-likeです。

```text
subject : predicate : typed value
```

scalar value、Entity reference、assertion、attestation、selector、grantには、
それぞれ異なるvalidationが必要な場合があります。これは、一つのuniversalな
three-column SQL tableを採用するという意味ではありません。semantic structureを、
validationされていないopaque bytesとしてapplication codeへ漏出させてはならない
という意味です。

Pair／Tuple境界は、現在のcandidateです。

- 小さく交換可能なphysical Repository interfaceにはPair。
- evaluationとIdentityのmeaningにはTuple-like typed structure。

## Relations

relationはbyte equalityだけから推論されるものではありません。既存IDと一致する
すべてのValueをreferenceとして扱うと、literalが偶然同じbytesを持つ場合に
spurious edgeが生じます。

したがって、reference intentはopaqueなphysical Pairより上位のtyped semanticsに
属します。Graphはそれらのreferenceに対する有用なviewですが、mandatory storage
ontologyではありません。

## Source、Root、knowledge cut

一つのevaluationを再現するためのinputは、complete Root内のpinned knowledge cutに
あるSource dataです。

```text
Source objects
    -> complete Root
    -> pinned Definition / Profile / Context
    -> derived Identity Result
```

`Authoritative`は、一つの永遠にglobalなversionを意味しません。そのResultを
replayするための特定されたinputが、pinned Source stateであることを意味します。

## Viewsとdirectories

Directoryは、rebuild可能でquery-optimizedなmaterialized projectionです。
LDAP、GraphQL、search、authorization、protocol-specific recordも、別のprojectionに
なり得ます。それらはSource ontologyになることなく、freshness policyとindexing
policyを持てます。

## Identity role

Liciumは、すべてに一つのID roleを割り当てません。以下は互いに異なるdesign role
として残ります。

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

同梱のE64 evidenceでは、Evaluation logical equivalenceのためにdedicated durable
IDを必要とするoperationは見つかりませんでした。これは、他のobjectに対する
stable lineage IDを否定したものではありません。

## 未決のmodel question

- canonical bytes、hash、namespace、identifier minting。
- 最終的なtyped Valueとrelation vocabulary。
- Definition、Profile、Context、delegation、Grant semantics。
- logical objectごとのmergeとconflict behavior。
- derived Identityがpersistent identifierを受け取る時点。
- archive、erasure、destructive-operation semantics。
- backend rowを露出せずにこれらの境界をenforceするRust type。

## References

- [Licium Design](DESIGN.ja.md)
- [E67–E72 Evidence Map](EVIDENCE.ja.md)
- [Identity and Authorization Systems](references/identity-authorization-systems.ja.md)
