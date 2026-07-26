---
Type: DESIGN
Updated: 2026-07-26T20:00:00+09:00
Status: confirmed
Tags: licium, repository, evaluation, sqlite, lifecycle, replay, japanese
Description: E67–E72 End-to-End Reference Execution Sliceから得た日本語設計結果。
---

# End-to-End Reference Execution Slice

English version: [REFERENCE-SLICE.en.md](REFERENCE-SLICE.en.md)

## 結論

Liciumの実装実体はDB schema単体でも空のbackend interfaceでもない。最小の実行可能な
骨格は、Repositoryのimmutable／published stateと、pinned inputsを処理する
Evaluation Kernelを明示的なrefsで接続する。

```text
Source Pair
  -> Root
  -> Publication / Head
  -> Pinned Evaluation Request
  -> Result
  -> optional logical Effect / Decision Observation
  -> View
```

一個のSQLite fileによるsliceは、protocol、queue、cache、thread model、service
topologyを追加せず、このlifecycleを最後まで接続した。一fileは論理monolithを意味
しない。同じroleは、単一daemonにもdistributed componentにもmapできる。SQLite
tablesはdisposableなreference realizationであり、Core Tupleやwire schemaではない。

## Read-heavyな挙動

fixtureのordinary evaluationはwrite-freeである。二回のreadについて全persistent
contentのbefore／afterが一致した。readごとにResultやaudit rowを書く必要はない。

stateを変えるEffectだけがcomplete persisted Result、expected state、transition、
Decision Observation、complete Viewを結ぶ。read-heavyな構成と、意味ある変更の
明示的provenanceを両立できる。

## Publicationとpinned evaluation

Rootの保存はHead publicationではない。rejected／unpublished RootはPublished Viewへ
入らない。write receiptを持つcallerはExact Rootを明示的に読める。

Evaluationはambient currentを入力にしない。fixtureはSource Root、Definition、
Semantics、Bindings、knowledge cutをpinする。process restart後にcurrent Rootと
Definitionが進んでも、保存したinputsからhistorical Resultを再生成できた。

## Effectの境界

Atomic Effectが意味するのはRepository内のState Transition、Decision Observation、
View Publication、current View pointerの論理的完結である。外部API、device操作、
message deliveryの完了またはrollbackをSQLite transactionが保証するとは主張しない。

stale、incomplete、duplicate、injected failureはpartial logical artifactを残さない。

## Explanationとintegrity

Decision ObservationからResult、Evaluation Request、Source Root、selected memberへ
遡れる。unique pathではなくfinite complete reference closureを要求する。

SQLite foreign keysは物理的補助である。別のsemantic-integrity queriesがdangling
Result、dangling View Root、pinned inputと異なるcross-linked Source Rootを検出する。

## Rustへ持ち越す境界

Rust sourceはまだ存在しない。このsliceは、将来のAPIでRoot、Publication、Head、
Evaluation Request、Pinned Input Closure、ephemeral outcome、persisted Result、
Effect Request、State Transition、Decision Observation、View provenanceを一typeへ
潰さない価値を示す。

これはcandidate type boundaryであり、公開済みRust APIではない。

## References

- [E67–E72 Evidence Map](EVIDENCE.ja.md)
- [再現手順](../model/README.ja.md)
- [English version](REFERENCE-SLICE.en.md)
