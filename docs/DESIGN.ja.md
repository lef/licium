---
Type: DESIGN
Updated: 2026-07-26T21:30:00+09:00
Status: discussion-draft
Tags: licium, design, identity, repository, evaluation, japanese
Description: Liciumの現在の設計境界、実行可能な証拠、未決事項を示す公開用の起点。
---

# Licium Design

[English version](DESIGN.md)

## 現在地

Liciumは、まだ安定仕様になる前の段階にあります。現在の実装上の実体は、
小さな実行可能モデルであり、production serviceではありません。

中心となる方向性は、次のとおりです。

> Identityはvaluesとrelationsから立ち現れる。

有用な最小architectureには、接続された二つのroleがあります。

```text
Source and Repository
    immutable inputs, complete Roots, explicit Publication

Evaluation
    pinned inputs -> Result -> optional Repository Effect -> View
```

backendは、これらのroleを一つのSQLite daemonにも、複数の分散componentにも
mapできます。deployment topologyは、論理data modelの一部ではありません。

## 現在のcontract境界

| 問い | 現在の回答 | 証拠のlevel | 未決事項 |
| --- | --- | --- | --- |
| すべてのassociationは永続的なsemantic objectか？ | いいえ。Occurrence、Result、lineage、revision、operation、storage identityは、それぞれ異なるroleを担います。E64は、Evaluation equivalenceの外側にあるstable lineageを否定していません。 | 有限のE64 fixtureと現在のscope correction。E64はE67–E72 executable sliceに含まれません。 | どのlogical objectがlineageを必要とし、それがどのようにmergeされるか。 |
| Resultの計算はRepository stateを変更するか？ | いいえ。通常のevaluationはwrite-freeにできます。effectを対象とするevaluationは、accepted EffectがResultをtransitionおよびDecision Observationへ結びつける前に、Resultをpersistする場合があります。 | 同梱sliceのE69とE70。 | recording policyとexternal-effect delivery。 |
| Spanner conformanceは実証済みか？ | いいえ。Spannerは設計とscalabilityのstress testであり、実adapterによる実行は存在しません。 | 設計時のmappingのみであり、実行可能な証拠には含まれません。 | schema、retry、knowledge-cut mapping、cost、multi-region behavior。 |
| authoritative inputはどこにあるか？ | complete Repository state／Rootのpinned knowledge cutにあるSource dataです。Identityはvaluesとrelationsからなるderived setであり、directoryとprotocol形式はprojectionです。 | E68、E69、E71と現在のconceptual model。 | 最終的なSource taxonomyとDefinition／Profile／Context semantics。 |
| 通常のCore operationはreachability GCを必要とするか？ | 現在のcandidateはcanonically GC-freeです。canonical archiveはpruneもsweepもされません。verified archive後のactive replica releaseはplacement transitionです。 | 別のPair／TupleおよびEpoch実験。ここでは設計contextとして要約していますが、実行可能sliceには含めていません。 | archive capacity、legal erase、distributed reclaim。 |

`Not supported by an experiment`とは、有限の証拠がそのclaimを確立しなかった
という意味です。そのideaが否定された、または不可能であることを自動的に
意味するものではありません。

## Review対象のCandidate Contracts

lifecycle rolesとbackend-independentなobservationsが、Rust APIやdatabase schemaを
選ばずに批評できる具体性を持ったため、現時点で公開review対象とします。

- [Repository／Evaluation Lifecycle Core Contract v0](CORE-CONTRACT.ja.md) /
  [English](CORE-CONTRACT.md)は12個のobservable candidate boundaryを抽出します。
  public packageはE67–E72を含みますが、全predecessor evidenceまたはE73Rは
  含みません。
- [Backend Conformance Contract v0](BACKEND-CONFORMANCE.ja.md) /
  [English](BACKEND-CONFORMANCE.md)はexact Licium implementation＋backend
  profileのrequirementsを定めます。SQLite／Spannerのfull conformanceはどちらも
  UNTESTEDです。
- [Public Sample Policy](PUBLIC-SAMPLES.ja.md) /
  [English](PUBLIC-SAMPLES.md)はreproducible technical eligibilityとcommit／push
  authorizationを分離します。

role separation、evidence-to-claim ceiling、backend-independent observability、
不足するIdentity Definition、Context、delegation、lineage semanticsへのfeedbackを
求めています。最短pathはREADME → Core Contract → Backend Conformance →
Evidence／runnerです。

## Repositoryとpublication

immutable objectはcomplete Rootに属します。Rootを作ることと、それをHeadとして
publishすることは同じではありません。Evaluationは、callerがreceiptを持つRootを
明示的にaddressできますが、Published Viewに含まれるのはaccepted Publication
だけです。

この分離により、保存されたすべてのobjectを暗黙のうちにcurrent authoritative
stateへ昇格させることなく、offlineまたはdistributedな作成が可能になります。

## Pinned evaluation

Evaluationは、replay inputをambient current stateで置き換えてはなりません。
reference sliceは、Source Root、Definition、Semantics、Bindings、knowledge cutを
pinします。process restartとcurrent-state advancementの後でも、これらのinputは
historical Resultを再現します。

## ResultとEffect

計算、任意のpersistence、state effectはそれぞれ別のものです。

```text
Pinned inputs -> compute Result
Result -> optional persistence
persisted Result + valid precondition -> State Transition
State Transition -> Decision Observation + complete View
```

Decision Observationは、accepted Repository state transitionと、そのdecisionに
使われたpersisted Resultを結びつけます。これは現在のconceptual terminologyであり、
最終的なRust typeでもlegal-audit definitionでもありません。

## Read-heavy operation

通常のevaluationはResultやaudit rowを書き込む必要がありません。したがって、
immutable Rootとcomplete Viewはread-heavyなoperationを支えられ、その一方で
意味のあるstate changeには明示的なprovenanceを保持できます。

stale read、replica、queue、cache、process separationは、交換可能なdeployment
capabilityです。導入する場合はpinned logical resultを保たなければなりませんが、
mandatory Core primitiveではありません。

## 証拠の境界

同梱のreference sliceが支持するのは、Repository／Evaluation lifecycleの有限な
SQLite realizationです。その正確な観測結果と限界は
[Evidence](EVIDENCE.ja.md)に記載されています。

schemaは意図的にdisposableです。testだけを根拠としてproduction API、canonical
encoding、network protocol、distributed transactionを導くことはできません。

## References

- [Model boundary](MODEL.ja.md)
- [Evidence](EVIDENCE.ja.md)
- [Candidate Core Contract](CORE-CONTRACT.ja.md)
- [Candidate Backend Conformance](BACKEND-CONFORMANCE.ja.md)
- [Public Sample Policy](PUBLIC-SAMPLES.ja.md)
- [Reference slice日本語版](REFERENCE-SLICE.ja.md)
- [Reference slice English version](REFERENCE-SLICE.en.md)
- [一次資料と比較](references/identity-authorization-systems.ja.md)
