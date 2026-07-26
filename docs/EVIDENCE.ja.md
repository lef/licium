---
Type: EVIDENCE
Updated: 2026-07-26T20:00:00+09:00
Status: confirmed
Tags: licium, evidence, sqlite, e67, e72, replay, japanese
Description: 同梱するE67–E72 reference sliceの自己完結した公開Evidence Map。
---

# E67–E72 Evidence Map

[English version](EVIDENCE.md)

## 対象範囲

同梱するmodelは、破棄可能なSQLiteおよびPOSIX shellによるreference
realizationです。RepositoryとEvaluationの役割を一つのファイル内で接続し、
両者の参照とtransaction境界をまとめて検査できるようにしています。

```text
Pairの投入
  -> complete Root
  -> accepted Publication / Head
  -> pinned Evaluation input closure
  -> Result
  -> optional Repository Effect + Decision Observation
  -> complete View
  -> process restart
  -> historical replay and explanation
```

## 固定された観測

| 実験 | 観測 | 同梱するEvidence |
| --- | --- | --- |
| E67 | 重複配送と、payloadが等しい独立したoccurrenceは区別されたままになる。不完全なRoot構築はrollbackし、次の正常なtransactionを汚染しない。 | `model/test-e67-durable-lifecycle.sh`、E67 expected TSV、4つのnegative mutation。 |
| E68 | 保存されたRootまたは拒否されたRootはPublished Viewに入らない。明示的なreceipt evaluationは未publishのRootを指定できる。Published evaluationはaccepted Headとpinned input closureを使用する。 | `model/test-e68-published-evaluation.sh`、E68 expected TSV、4つのnegative mutation。 |
| E69 | 2回のordinary evaluationの前後で、sortした永続database contentは変化しない。complete ViewはSource Root、Head、Definitionのprovenanceを保持し、synthetic secret sentinelを漏洩しない。 | `model/test-e69-pure-read-view.sh`、E69 expected TSV、4つのnegative mutation。 |
| E70 | preconditionを満たすcomplete Resultだけが、Repository transition、Decision Observation、complete View、current pointerを一体としてcommitする。stale、incomplete、retry、injected failureの各経路は、部分的なlogical artifactを残さない。 | `model/test-e70-observed-effect.sh`、E70 expected TSV、5つのnegative mutation。 |
| E71 | 第2のprocessがファイルを開き直してcurrent RootとDefinitionを進めても、保存されたpinned closureからhistorical Resultを再現できる。 | `model/test-e71-restart-replay.sh`、E71 expected TSV、4つのnegative mutation。 |
| E72 | Explanationは有限closureを通じてResult、Request、Root、selected memberへ到達する。Semantic checkはSQLite foreign keyとは独立にdangling referenceとcross-linked referenceを検出する。 | `model/test-e72-recovery-explanation.sh`、E72 expected TSV、4つのnegative mutation。 |

## 件数

```text
targeted experiments: 6
targeted relations:   30 / 30
negative identities: 25 / 25 expected mismatches
executable closure:   64 files
```

64-file closureは、aggregate runnerを含む33個のshell file、30個のexpected
TSV file、1個のSQLite schemaから構成されます。

## 再現方法

生成されたrepositoryのrootから実行します。

```text
sh model/run-reference-slice-tests.sh
```

aggregateの末尾は、次の出力でなければなりません。

```text
6 reference-slice targeted tests and 25 negative identities passed
```

各negative identityは、positive expected comparisonを失敗させなければならない
mutationを実行します。内側のnon-zero statusをtest failureと誤認するwrapperは
false redを発生させます。同梱のself-test helperは、意図したmismatchが生じたことを
検査します。

## Claimの境界

有限fixtureの範囲で支持されること:

- complete Rootの構築と明示的なPublicationは異なる;
- ordinary evaluationはwrite-freeにできる;
- evaluationはambient current stateではなく、明示的にpinされたinputを使用する;
- Repository-localなlogical Effectは、persisted Result、transition、Decision
  Observation、complete View、current pointerをatomicallyに接続できる;
- 保存したpinned inputは、process restart後もhistorical Resultを再現する;
- 有限なexplanationとsemantic-integrity findingを表現できる。

確立していないこと:

- production durabilityまたはoperational recovery objective;
- distributed consensus、partition時の挙動、multi-region convergence;
- external API、device、message deliveryのatomicな完了またはrollback;
- performance、capacity、denial-of-service時の挙動;
- cryptographic trust、secure clock、authentication、authorization;
- 実際のSpanner adapter conformance;
- 最終的なRust type、public API、canonical encoding、storage schema。

synthetic secret sentinelは、非漏洩を証明するためのtest dataです。credentialでは
ありません。

## Modelを読む

- [Design](DESIGN.ja.md)
- [Model boundary](MODEL.ja.md)
- [日本語のreference-slice解説](REFERENCE-SLICE.ja.md)
- [English reference-slice explanation](REFERENCE-SLICE.en.md)
- [詳細な再現手順](../model/README.ja.md)
