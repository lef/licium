---
Type: DESIGN
Updated: 2026-07-12T15:42:03+09:00
Status: draft
Tags: licium, identity, data-model, relations, views, operations
Description: Liciumの意味的な最小核と、その上に構成されるIdentity、Directory、Authorization、Repository operationの設計仮説。
---

# Licium Minimal Data Model: Discussion Draft

## 1. この文書の位置づけ

Licium は IdP、Directory、Authorization Engine、Credential Format のいずれか一つではない。
現時点の中心仮説は、Licium を **デジタルアイデンティティを構成するための極小データ構造** として捉えることである。

この文書は確定仕様ではない。これまでの設計議論を踏まえた現在の文脈を記録し、次の設計作業の出発点を作ることを目的とする。

今回の議論では、以前の設計で導入していた `Statement`、`Evidence`、`Attestation`、`Bundle` などを、Licium の意味的 primitive として本当に必要か再検討した。その結果、意味的な最小核はそれらより大幅に小さくできる可能性が高まった。

## 2. 出発点: ISO の Identity 定義

ISO/IEC 24760-1 は identity を、おおむね「Entity に関連する属性の集合」と定義する。

重要なのは以下である。

- Identity は Entity そのものではない。
- 一つの Entity は複数の Identity を持ち得る。
- 複数の Entity が同じ Identity を持つこともあり得る。
- Identifier と Identity は異なる。
- Identifier は Identity を指し示すための属性または属性集合であり、Identity 本体ではない。

Licium はこの定義を可能な限り直接的にデータ構造へ写像する。

> Digital Identity は、ある Entity に関連する特定の属性の集合である。

ただし Licium Core が Entity を常に永続ノードとして実体化する必要はない。Entity との関連や、複数 Identity が同じ Entity に関係するという判断も、上位層の意味論として表現できる余地を残す。

## 3. 最小核: 多値の ID–Value 二項構造

現時点での最小候補は次である。

```text
ID → Bag<Value>
```

または、より平たく書けば、保存されるデータは `ID:Value` のペアだけである。

```text
x:y1
x:y2
x:y3
```

必要な基本操作も小さい。

```text
put(ID, Value)
get(ID) -> Values
contains(ID, Value)
```

`Set` ではなく暫定的に `Bag` と書くのは、同一 `ID:Value` の重複を意味的に潰すか、物理的な複数出現を保持するかが未決定だからである。Berkeley DB の duplicate values のように、一つの key に複数 value を持つ実装は自然な候補となる。

### 3.1 Core に持ち込まない概念

最小 Core は、少なくとも初期仮説として以下を特権フィールドにしない。

- Entity
- Identity
- Subject
- Predicate
- Claim
- Statement
- Issuer
- Evidence
- Attestation
- Time
- Validity
- Revocation
- Schema
- Directory Entry
- Graph Node / Graph Edge

これらは `ID:Value` の集合へ上位層が与える意味論として表現する。

## 4. ID と Value

### 4.1 ID

ID は Licium の一つの識別系の中で一意であるべき内部識別子である。人間向けの `alice`、メールアドレス、DN、SPIFFE ID などを、そのまま Core ID とする必要はない。それらは Value として関連づけられる。

ID の生成形式として UUIDv7 は有力候補である。

- 中央採番を必要としない。
- NHI が大量かつ分散して生成できる。
- 128 bit 固定長で扱える。
- 時系列に近い格納局所性を得られる。
- SQLite と Spanner の双方で扱いやすい。

ただし UUIDv7 の生成時刻を、assertion time、observation time、valid-from、transaction time などの意味的時刻として使用してはならない。また UUID は秘密 token ではない。

UUIDv7 を Core 仕様へ固定するか、単に推奨生成方式とするかは未決定である。

### 4.2 Value

Value を Core が typed value として解釈するかも未決定である。

一つの候補は次である。

```text
Value = Literal(bytes) | Ref(ID)
```

しかし、さらに小さくするなら Core は `Literal` と `Ref` すら区別せず、Value が別の ID を指すかどうかを上位Schema/Profileが判断できる。

この選択は、Core 自身が relation traversal、reachability、GC dependency をどこまで理解すべきかに直結する。

## 5. Graph は Core ではなく View

`ID:x` が `Value:y` への接続を持つとき、それを有向グラフとして解釈することはできる。

```text
x -> y
```

しかし、Core を次のように定義すると、二項の KVS からはみ出す。

```text
G = (Nodes, DirectedEdges, Payloads)
```

この定義は Node、Edge、Payload という ontology を Core へ導入するため、現時点では採用しない。

より小さい整理は次である。

```text
Core:
    ID:Value の多値二項構造

Graph View:
    一部の Value を別 ID への参照として解釈した結果
```

したがって、Licium Core は有向グラフそのものではない。有向グラフは `ID:Value` に対する有力な解釈または View の一つである。

## 6. Selector と Identity View

基底Storeに `ID:Value` が存在するだけでは、それはまだデジタルアイデンティティではない。

上位層は、目的に応じて特定の属性集合を選ぶ必要がある。

```text
Raw ID:Value Store
        ↓ Selector
Selected Attribute Set
        = Digital Identity View
```

概念的には次の操作となる。

```text
IdentityView = Select(StoreSnapshot, Selector, Context)
```

同じ Entity に関係するデータから、異なる Identity を構成できる。

```text
Employment Identity
    { employee number, department, position }

Login Identity
    { login identifier, public key, assurance }

External Presentation Identity
    { display name, organization }

Workload Identity
    { image digest, service account, attestation, runtime key }
```

Selector は単純な属性filterに限らない。上位Schemaに従った relation traversal、時点、audience、purpose、issuer、validity 等の判断を含み得る。

### 6.1 Selector と View の区別

```text
Selector:
    何を選ぶかという規則

View:
    選択した結果の属性集合
```

Selector の定義自体も外部Registryへ置かず、同じ `ID:Value` 構造へ保存できる可能性がある。Core はそれを Selector として知らず、Selector Evaluator が解釈する。

Identity View に新しい永続IDを必ず与えるかは未決定である。短命なNHIを考えると、通常は派生Viewとし、保存が必要な場合だけsnapshotまたはcontent hashで固定する案が有力である。

## 7. NHI がもたらした修正

以前は各attribute entry自身にIDを付けるモデルを検討していた。しかしNHIを考えると、各entryの恒久的な実体化は問題を生む。

- 数秒だけ存在するprocessやinvocationが大量に発生する。
- workload、session、key、attestation、artifactの境界が用途ごとに変わる。
- relation自体へIDを振ることで、本来存在しなかったentry lifecycleが生まれる。
- entry identity、version、ownership、deletion、deduplicationの管理が膨張する。

このため、すべてのattribute/relation occurrenceへsemantic IDを強制しない。

一方、永続化時のcontent hashは持ち得る。以下は分離する。

```text
Logical ID:
    Value集合を参照するための識別子

Content/Storage ID:
    immutable bytesを取得・検証するためのhash
```

Storage IDがあることは、すべてのentryが意味上のIdentityを持つことを意味しない。

## 8. Directory の再定義

LDAP/AD型のlegacy Directoryは、Identityと永続Entry、DN、DIT、Object Class、mutable current state、検索、管理境界を強く結合する。

NHIでは、次の問いが不自然になる。

- 一時workloadのDNは何か。
- 再起動したworkloadは同じEntryか。
- deployment、runtime、session、keyをどのEntryへ集約するか。
- 一時的属性集合ごとにObject Classを作るのか。

しかしDirectoryの機能、特に属性からの逆引き、検索、列挙は不可欠である。ID point lookupだけでは、大規模StoreやLLM利用時にfull scanを避けられない。

したがってDirectoryを廃止するのではなく、正本から降格させる。

> Directory は、選択されたデジタルアイデンティティを検索・列挙するための、再構築可能なmaterialized viewである。

```text
Canonical ID:Value Store
          ↓ compile / index
Materialized Directory View
          ↓
lookup / search / enumerate
```

意味上は `Materialized Directory View`、物理的性質としては `rebuildable cache/index` である。単なるbest-effort cacheではなく、どのSource View、Selector、Schemaから作られ、どの程度最新かを検証できる必要がある。

### 8.1 LDAP Interface

LDAP Interfaceを提供しても、LDAP Directoryを正本にする必要はない。

```text
LDAP Search
    -> LDAP Directory Viewを検索
    -> LDAP Entryとして応答

LDAP Modify
    -> Commandへ変換
    -> Operationを生成
    -> Viewを更新
    -> LDAP Directory Viewを再materialize
```

Readはprojectionから行い、Writeは正本のOperationへ変換する。この非対称性を維持する。

### 8.2 GraphQL

既存議論ではGraphQLを正本APIではなく、attribute graph explorationのためのread-oriented query façadeとして位置づけている。

```text
GraphQL = attribute graph exploration / read model
Command API = state transition
```

GraphQL resolverが生Storeを無制限に探索するのではなく、Directory、relationship index、attribute index等のprojectionを照会する。

なお、Microsoft GraphとGraphQLは別物である。保存済み設計対話には「MicrosoftですらGraphQL」という記録は確認できなかった。

## 9. SQLite から Spanner まで

目標は、SQLiteにSpannerの全保証を模倣させることではない。

> 同じID–Value論理モデルと決定論的Selectorを、異なる保証レベルのBackend上で実行できること。

単純なSet semanticsを採用する場合、SQLへの概念的写像は小さい。

```sql
CREATE TABLE licium (
    id    BLOB NOT NULL,
    value BLOB NOT NULL,
    PRIMARY KEY (id, value)
);
```

これは重複を潰すSetモデルの例であり、Bag semanticsを採用する場合は物理的なoccurrence管理が別途必要になる。

SQLiteとSpannerで共通にしたいものは以下である。

- ID:Valueの意味
- Selectorの意味
- 同じsnapshotに対するViewの決定性
- OperationとMergeの意味
- Bundle/content hashの検証規則

共通にしないものは以下である。

- 可用性
- transaction timeの強さ
- multi-writer concurrency
- 分散transaction
- 鮮度
- throughputとlatency

Backend差は隠さず、CapabilityまたはGuarantee Profileとして表す。

```text
local_transaction
global_transaction
trusted_transaction_time
multi_writer
offline_merge
```

## 10. Operation、View、jj、GC

削除はStoreからの即時 `DELETE` として扱わない。

既存議論の中心は以下である。

```text
ID:Valueの追加・除外
    -> Operation

Operationの適用結果
    -> View

並行View
    -> Merge / Conflict Resolution

保持対象Viewから到達不能な物理データ
    -> Epoch / Reachability Check
    -> Purge / GC
```

`jj`から借りるのは、operation log、repository view、undo/restore、conflictを第一級に扱う発想である。GCも単なるbackground delete jobではなく、並行する追加・削除操作をmergeして安全な削除状態へ収束させるoperationとして考える。

```text
View A: x:yを含む
View B: x:yを除外する
View C: x:yへ新たに依存する
```

View Bだけを見て物理削除してはならない。保持対象root、並行View、retention、audit requirementsを考慮し、到達不能性が確定した後にのみpurgeできる。

## 11. restic / rustic との対応

`restic` / `rustic` は意味モデルではなく、content-addressed repositoryの物理モデルとテスト思想の参考になる。

```text
Licium                         restic/rustic

Immutable ID:Value data       blob / tree
Published View                snapshot
Directory projection          index
Directory rebuild             index rebuild
View retention                forget
Physical deletion             prune
Repository verification       check
```

特に重要なのは、indexを正本にしないことである。Directory、GraphQL projection、search index等は壊れても正本から再構築できなければならない。

暗号、hash、低レベルrepository操作は実績ある実装へ寄せ、Licium固有のSelector、Operation、View、Identity semanticsを自作するという境界を維持する。

## 12. Zanzibarとの関係

Zanzibar型ReBACはLicium Coreではなく、ID:Valueからrelation viewを構成して評価する上位層である。

```text
Licium ID:Value
    -> relation projection
    -> Zanzibar-style check
    -> Decision record
```

Zanzibarのrelation tupleが「現在どの関係が成立しているか」を効率的に評価するのに対し、Liciumはその関係がどの属性、証拠、変換、Viewから構成されたかを保持できる。

## 13. Macaroonsとの関係

Macaroonsは、権限をcaveatによって単調に狭めながら分散委譲するcredential方式である。

LiciumはMacaroonそのものではない。Macaroon、caveat、third-party discharge、およびその検証結果をID:Valueへ写像し、上位Evaluatorが意味を与える。

Macaroonsから得られる重要な設計原則は以下である。

```text
authority(derived) <= authority(parent)
```

ただし、権限減衰、別issuerによるattestation、既存情報のprojection、新属性のderivationは意味が異なる。これらをCoreの型に固定する必要はないが、上位Operation semanticsでは区別する必要がある。

## 14. LLMとの関係

LLMは、固定Schemaを前提としない属性の山から、目的に応じたSelector候補を作り、未知Schema間の対応やrelation候補を発見するControl Planeとして有望である。

一方、LLMをHot Pathの最終認可判断に直接置かない。

```text
LLM:
    Selectorを提案
    Schema対応を提案
    Relation候補を発見
    判断を説明

Deterministic Evaluator:
    承認済みSelectorを実行
    固定snapshotを参照
    同じ入力から同じViewを生成
    Policyを評価
```

Selector、使用したsnapshot、承認、評価結果を同じrepository modelで記録すれば、LLMが関与したIdentity constructionもreplay可能になる。

## 15. 現時点のレイヤー整理

```text
L0  Minimal Data
    ID -> Bag<Value>

L1  Repository State
    Operation / View / Merge / Snapshot

L2  Interpretation
    Schema / Selector / Relation View

L3  Materialization and Discovery
    Directory / Search Index / Graph Projection

L4  Interfaces and Evaluators
    LDAP / GraphQL / SCIM / Zanzibar / Macaroon / OIDC / SAML

L5  Consumers
    Authentication / Authorization / Presentation / Audit / LLM Agent
```

L0だけがLiciumの意味的最小核なのか、L1の一部までをLicium Coreと呼ぶのかは、今後明確化する必要がある。

## 16. 現時点の短い定義案

英語:

> Licium is a multivalued ID–Value structure from which purpose-specific attribute sets are selected as digital identities.

日本語:

> Liciumは、目的に応じた特定の属性集合をデジタルアイデンティティとして選択するための、多値ID–Valueデータ構造である。

この定義では、Directory、Graph、Entity、Credential、AuthorizationをCore primitiveにしない。それらを同じ基底構造から構成可能にすることがLiciumの価値となる。

## 17. Backend-first Architecture

Licium の価値は、OIDC、SAML、LDAP 等のprotocol implementationを多数内蔵することではない。中心となる価値は、デジタルアイデンティティを生成・保存・再現・merge・materializeするbackend semanticsにある。

理想的には、OIDC、SAML、LDAP、WebAuthn等はLiciumを知らない汎用crateである。Liciumとの接続は、小さなintegration adapterが担う。

```text
Generic Protocol Engine
        ↕ protocol-neutral contract
Licium Integration Adapter
        ↕
Licium Backend
```

Protocol固有のauthorization code、session、request correlation等はprotocol componentが所有する。Licium CoreへOIDC claim、SAML assertion、LDAP DN等の固有ontologyを持ち込まない。

次を交換可能にする。

- protocol implementation
- storage backend
- projection implementation
- transport binding
- deployment topology

Protocol componentを削除または交換してもLicium repositoryは完全であり、同じsnapshotとSelectorに対するIdentity generationの意味が変わってはならない。

## 18. 「疎」の定義

Liciumにおける疎結合は、すべてをmicroserviceとして配備することではない。

> 「疎」とは、microserviceとして切り出しても意味が壊れない境界を持つことである。

同一processに配置されたcomponentも疎結合にできる。逆に、別processへ分けてもshared database、private schema、同時release、巨大な共通DTOに依存していれば密結合である。

### 18.1 疎結合の判定基準

- componentは他componentのprivate storage schemaを参照しない。
- componentは他componentの内部Rust型に依存しない。
- componentを独立して交換できる。
- bindingを変更してもsemantic resultが変わらない。
- protocol変更がCoreや無関係なadapterへ波及しない。
- storage変更がprotocol componentへ波及しない。
- failure、deadline、consistency requirementをcontract上で表現できる。
- protocol固有概念がCoreへ逆流しない。

変更の伝播範囲は次のように閉じる。

```text
OIDC specification change
    -> OIDC component / integration adapter

SQLite schema change
    -> SQLite backend

gRPC version change
    -> gRPC binding

Selector semantic change
    -> semantic contractとして明示的にversioning
```

## 19. Contract と Binding

component設計は次の順序で行う。

```text
1. Semantic Contract
   何を意味し、何を保証するか

2. Interface Contract
   どのoperationを提供するか

3. Transport Binding
   in-process / gRPC / HTTP-OpenAPI / event等

4. Facade
   GraphQL / REST-HATEOAS / CLI / Admin UI等
```

protobuf、OpenAPI、Rust traitを先にdomain modelとしない。最初に文章、不変条件、conformance testでsemantic contractを固定する。

例えばIdentity generationという同じsemantic operationを、異なるbindingへ写像できる。

```text
Semantic:
    GenerateIdentity(selector, source_view, parameters)
        -> IdentityView

In-process Rust:
    generator.generate(...)

gRPC:
    rpc GenerateIdentity(...)

HTTP/OpenAPI:
    POST /v1/identities:generate
```

共有するのは入力、結果、failure、precondition、idempotency、consistencyの意味である。protobuf layout、HTTP header、Rust lifetime、stream encoding等を無理に共通化しない。

### 19.1 Bindingの位置づけ

```text
In-process Rust:
    reference implementation、local deployment、semantic test

gRPC:
    高頻度の内部経路、deadline、cancellation、streaming

HTTP/OpenAPI:
    外部integration、低頻度command、debug可能なHTTP RPC

REST/HATEOAS:
    human/agentが状態と可能な操作を探索するControl Plane

GraphQL:
    materialized projectionに対するquery facade

Async events:
    Directory rebuild、projection、index、audit export
```

OpenAPIとRESTを同一視しない。HTTP/OpenAPI bindingはRPC/command/queryをHTTPへ写像するものとして扱い、RESTを名乗る場合はhypermedia constraintを別途考慮する。

### 19.2 Deployment-neutral

```text
Small:
    application -> in-process Licium -> SQLite

Medium:
    protocol adapter -> local IPC -> Licium daemon -> SQLite

Large:
    protocol service -> gRPC -> Licium service -> Spanner

Offline:
    import/export tool -> Bundle/File -> Licium repository
```

> Liciumのcomponent boundaryはdeployment形態に依存しない。同一process内での結合と別processへの分離のいずれでも意味論が変わってはならない。接続方式は交換可能な実装上の選択である。

## 20. Anti-Keycloak / Anti-OpenAM Principles

KeycloakやOpenAM型の複雑性は、protocol数の多さだけではない。Realm、Client、User、Group、Role、Federation、Directory、Authorization、Session、Admin UI、Plugin SPI、cluster stateを一つのproduct ontologyとlifecycleへ結合することで生まれる。

Liciumは複雑性を消すのではなく、所有すべきcomponentへ隔離する。

```text
1. Core SHALL NOT contain protocol-specific fields.

2. Core SHALL NOT require User, Realm, Client, Role, Group,
   Session, or Directory Entry as ontology.

3. Protocol components SHALL NOT own canonical identity data.

4. Protocol components SHALL NOT access backend-private storage.

5. Directory, Graph, Search, and protocol claims SHALL be projections.

6. Every materialized projection SHALL declare its source View
   and SHALL be rebuildable.

7. Semantic contracts SHALL precede transport bindings.

8. In-process and remote bindings SHALL pass the same semantic
   conformance tests.

9. Monolithic and distributed deployment SHALL both remain possible.

10. Adding a protocol SHALL NOT require changing Licium Core.
```

## 21. 最初の意味あるMilestone

UUID等のID generationは内部primitiveであり、Liciumの提供価値そのものではない。最初の意味あるmilestoneは **Identity generation** である。

```text
ID-Value substrate
        ↓ Selector
Identity generation
        ↓
Reproducible Identity View
```

`licium 0.1.0` の候補scopeは次である。

```text
Implemented:
- Identity generation from values and relations
- explicit multivalue semantics
- deterministic selection
- reproducible Identity Views
- property-tested merge behavior

Not implemented:
- authentication
- authorization
- protocol servers
- networking
```

単なるmultimapではなく、値と関係からIdentityを決定論的に生成し、同じ入力から同じViewを再現できるところまでを最初のmilestoneとする。

## 22. 未解決事項

1. `Bag<Value>`か`Set<Value>`か。
2. Coreは`Literal`と`Ref(ID)`を区別するか。
3. UUIDv7を仕様へ固定するか、推奨に留めるか。
4. Selector languageの最小要件は何か。
5. Selector resultへ永続IDを与える条件は何か。
6. Entityとの関連をどの層で表現・検証するか。
7. Directory Viewの鮮度、完全性、source checkpointをどう証明するか。
8. LDAP WriteをどのOperation semanticsへ写像するか。
9. SQLiteとSpannerのGuarantee Profileをどう定義するか。
10. 並行するadd/removeのmerge規則をどうするか。
11. GC root、Epoch、retention、audit preservationをどう定義するか。
12. canonical bytesとexternal Value encodingの境界をどこに置くか。
13. LLM提案Selectorの承認、固定、replayをどう設計するか。

## References

- [Licium design documentation](DESIGN.md)
- [Identity Generation Hypothesis](identity-generation-hypothesis.md)
- [Identity and authorization systems: primary references and comparisons](references/identity-authorization-systems.md)

The raw design discussions and their retrieval index are retained separately
as private provenance. They are not normative project documentation.
