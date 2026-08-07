---
Type: GUIDE
Updated: 2026-08-07T11:26:24+09:00
Status: draft
Tags: licium, concept, identity, values, relations, repository, introduction
Description: 一つの具体例からLiciumの中心概念と設計上の狙いを説明する、人間向けの導入文書。
---

# 一つの例で理解するLiciumのコンセプト

English version: [Understanding Licium's Concept Through One Example](CONCEPT-GUIDE.md)

## ひとことで言うと

Liciumは、人や機械を一個の固定された「ユーザー情報」に押し込めずに、値(属性)と関係を保存し、目的に合わせて必要な組合せを後からIdentityとして構成する。

> IdentityはEntityそのものではない。ある目的のために選ばれた、値と関係の集合である。

Liciumが保存したいのは固定化されたユーザー台帳(Directory)ではない。複数のIdentityを安全に、決定論的に作り直すための、値や関係のデータと、それらを解釈する定義である。

## Aliceについて知っていること

ある組織がAliceについて、次の情報を持っているとする。

```text
社員番号:       12345
部署:           Security Operations
役職:           Analyst
勤務先メール:   alice@example.com
公開鍵:         key-7
保証レベル:     AAL2
緊急連絡先:     +81-XX-XXXX-XXXX
上司:           manager-42
```

これは説明用の表記であり、Liciumの保存形式ではない。最小のCoreから見れば、基礎にあるのは一つのIDへ複数のValueを関連付けられる構造である。

```text
alice-source-id -> employee-number:12345
alice-source-id -> department:security-operations
alice-source-id -> work-email:alice@example.com
alice-source-id -> public-key:key-7
alice-source-id -> manager-id:manager-42
...
```

一部のValueを別のIDへの参照と解釈すれば、同じデータから関係graphも見える。
ただしCoreに特別な`User`、`Employee`、`GraphEdge`という箱が保存されているとは限らない。どのValueが何を意味するかは、上位のDefinitionが与える。

## 同じAliceから別のIdentityを作る

会社員としてAliceを扱う場面では、次が必要になるかもしれない。

```text
Employment Identity
    社員番号
    部署
    役職
    上司との関係
```

ログインを確認する場面では、必要なものが異なる。

```text
Login Identity
    勤務先メール
    公開鍵
    保証レベル
```

どちらもAliceというEntityに関係するが、同じIdentityではない。緊急連絡先はどちらにも必要ないので、結果へ混入させない。

```text
Aliceに関係するSource
        │
        ├─ Employment Definition + Context
        │       └─ Employment Identity
        │
        └─ Login Definition + Context
                └─ Login Identity
```

ここでいうContextは、単なる表示filterとは限らない。「会社員として」「父親として」「特定の代理権を行使する者として」のように、どの値や関係がIdentityを構成するかに関わる。Contextの厳密なmodelはまだ設計中である。

## 選び方もdataとして保存する

`Employment Definition`や`Login Definition`をprogramの奥へhard-codeするだけでは、後から同じ判断を再現できない。Liciumでは、何を選ぶか、値をどう解釈するかというDefinitionやSchemaも、通常のRepository dataとして保存する方向にある。

```text
Source values and relations
Definition
Context bindings
Trust inputs
Evaluation semantics
```

これらを同じ時点の入力として固定すれば、後日Definitionが変更されても、当時のIdentityを当時の意味で作り直せる。新しいSchemaで古い値を勝手に読み替えない。

SchemaをどのPairへどう結び付けるか、Pairだけで十分かTupleが必要か、bytesをどう符号化するかは未決である。重要なのは、意味の定義も追跡可能なdataであり、暗黙のcurrent configurationではないという境界である。

## 「後から同じものを作れる」とは

Identityそのものをsource codeのようにversionedと呼びたいわけではない。固定するのは、
Identityを導出した入力である。

```text
complete Repository Root
        + pinned Definition
        + pinned Context／Trust inputs
        + evaluation semantics revision
        ↓
reproducible Identity Result
```

この考え方はgitやjjに似ている。現在の可変rowだけに頼らず、ある時点の入力を指し、同じalgorithmで同じ結果を再生する。ただし対象はsource treeではなく、Identityを構成する小さなValueとrelationである。

これによって、次の問いに後から答えられる。

- その時、どのSourceを見ていたか。
- どのDefinitionとContextを使ったか。
- なぜこの値が含まれ、別の値が除外されたか。
- 現在のDefinitionではなく、当時のDefinitionでもう一度評価できるか。

## SQLiteでもRustでも意味を変えない

SQLiteは型の弱いrowやblobとしてdataを保存できる。Rustは、読み込んだbytesを最初から信用せず、decode、Schema確認、参照解決、Root completeness確認を経た値だけを、検証済みの型として扱える。

```text
SQLite／KVS／networkから来たbytes
        ↓ まだ信用しない
decodeとSchema検証
        ↓
必要な参照とpinned inputの確認
        ↓
Rustで検証済みの値として扱う
```

RustのstructとSQLiteのrowを同じ形にする必要はない。両者が共有すべきものは、固定されたRepository data、Definition、検証規則、そして同じ入力から同じ結果を返すtestである。

したがって、ORMが生成した型をそのままCoreの型にはしない。Rustの型はstorage layoutの写像ではなく、「ここまでの検査を通過した」という証拠になる。

## DirectoryやOIDCは上に載る

Employment Identityを検索しやすい表へ並べればDirectory Viewを作れる。Login IdentityをOIDC claimへ写せばOIDC providerを作れる。関係を探索しやすく投影すればGraph Viewを作れる。

```text
values + relations + pinned definitions
                ↓
       reproducible Identity
                ↓
   ┌────────────┼────────────┐
Directory     OIDC／SAML    Graph／Authorization
View          adapter       View
```

これらは重要だが、Liciumの最小Coreそのものではない。LDAP、OIDC、SAMLや特定のdatabaseにCoreの意味を決めさせないから、単一SQLite daemonから分散backendまで、同じ論理modelを異なる規模で実装できる可能性が生まれる。

## LLMが参加しても、結果は再現できる

LLMは大量のactivity graphから不自然な関係を発見したり、新しいDefinitionを提案したりできる。しかし提案をそのまま暗黙の権威にはしない。

```text
LLMが関係やDefinitionを提案する
        ↓
人間またはpolicyが採否を決める
        ↓
採用したDefinitionをRepositoryへ記録する
        ↓
固定された入力に対して決定論的に評価する
```

LLMの確率的な発見能力と、Identity判断の追跡可能性を同時に持てることが、LLM Ops時代にこのmodelを使う大きな理由の一つである。

## Liciumが作ろうとしているもの

Liciumは新しい万能databaseでも、全部入りIdPでもない。

作ろうとしているのは、次の二つを中心にした小さなCoreである。

1. 値と関係、およびそれらを解釈するDefinitionを、再現可能なRepository stateとして扱う。
2. 固定した入力から、目的に応じたIdentityを決定論的に生成する。

認証protocol、Directory、risk engine、LLM detector、authorizationは、このCoreを使う交換可能なmoduleになり得る。

## まだ決めていないこと

この説明は完成仕様ではない。特に次は未決である。

- CoreをPairだけに閉じられるか、Tuple-likeなcontractが必要か。
- SchemaをValueへ結び付ける最小表現。
- Repository bytesのdeterministic encoding。
- Context、delegation、Trustの最終的な意味境界。
- 複数のHeadが収束しない場合のConflict表現。
- active storageを切り離してもaudit可能性を失わない運用model。

正確な現在地、evidence、未決の境界は[Licium Design](DESIGN.ja.md)から辿れる。
