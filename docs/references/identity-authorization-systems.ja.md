---
Type: REFERENCE
Updated: 2026-07-26T20:00:00+09:00
Status: active
Tags: licium, identity, rebac, zanzibar, macaroons, storage, references, japanese
Description: 認可システム全体をLicium Coreへ持ち込まずに設計をstress-testするための一次資料。
---

# IdentityとAuthorizationのシステム

英語版: [identity-authorization-systems.md](identity-authorization-systems.md)

## 目的

これらの資料は、Liciumの最小モデルへ問いかける問題を明確にするためのものである。
feature checklistではなく、採用を意味するものでもない。以下の比較はLiciumにおける
設計上の解釈であり、引用した各システム自身による主張ではない。

## Identityの用語

ISO/IEC 24760-1は、Entityに関連する属性を用いてidentityを定義している。この区別は
ここで重要である。identifierはEntityではなく、Digital Identityも単一のidentifier
だけではない。一つのEntityが、目的ごとに複数のidentityを持つことがある。

- [ISO/IEC 24760-1:2025](https://www.iso.org/obp/ui/#iso:std:iso-iec:24760:-1:ed-3:v1:en)

## ReBACとZanzibar

Relationship-Based Access Controlは、Entity間の関係から認可を評価する。Gatesは2007年に
この用語を用い、Fongは形式モデルとpolicy languageを発展させた。Zanzibarはrelation
tuple、userset、configuration、global consistency contractを用いるproduction
authorization systemである。ZanzibarはReBACの定義でも起源でもない。

Liciumにとって、これらのシステムは、authorization engineを最小substrateの一部に
せずに関係を表現できるかを検証するものである。Zanzibar風のtupleはLicium data上の
projectionになり得る。したがって、Zanzibarのpolicy language、consistency contract、
Check APIがLicium Coreのprimitiveになるわけではない。

- [Gates, “Access Control Requirements for Web 2.0 Security and Privacy”](https://www.ieee-security.org/TC/W2SP/2007/)
- [Fong, “Relationship-Based Access Control”](https://pages.cpsc.ucalgary.ca/~pwlfong/Pub/codaspy2011.pdf)
- [Pang et al., “Zanzibar”](https://www.usenix.org/conference/atc19/presentation/pang)

## Macaroons

Macaroonsは、contextual caveatと分散attenuationを支えるauthorization credentialである。
中心的な問題はauthorityの安全な委譲であり、Digital Identityの構成ではない。

LiciumにとってMacaroonsは、credentialやcryptographic semanticsを最小substrateへ
強制せずに、delegation constraint、provenance、Contextが派生Identityを参照できるかを
検証するものである。将来のadapterがmacaroonを利用または発行することはあり得るが、
Core自体がmacaroonである必要はない。

- [Birgisson et al., “Macaroons”](https://research.google/pubs/macaroons-cookies-with-contextual-caveats-for-decentralized-authorization-in-the-cloud/)

## Repositoryの類比

SQLiteとSpannerは、異なるbackend capabilityをstress-testする。Jujutsuのoperationと
conflict model、およびresticにおけるretentionとphysical pruningの区別は、immutable
state、reconstruction、historyを考えるうえで有用な類比である。いずれもIdentity
modelではなく、Liciumでは実際のSpanner conformanceもまだ実行されていない。

- [SQLite isolation](https://www.sqlite.org/isolation.html)
- [Spanner paper](https://research.google/pubs/spanner-googles-globally-distributed-database-2/)
- [Jujutsu concurrency and operation log](https://jj-vcs.github.io/jj/latest/technical/concurrency/)
- [restic design](https://restic.readthedocs.io/en/stable/design.html)
- [restic forget and prune](https://restic.readthedocs.io/en/stable/060_forget.html)

## Identifier generation

UUIDv7は、localに生成できるidentifierの候補になり得るが、Identityの定義でも
確定済みのCore mandateでもない。

- [RFC 9562 — UUIDs](https://www.rfc-editor.org/rfc/rfc9562.html)

## Liciumの文書

- [Design](../DESIGN.ja.md)
- [Model boundary](../MODEL.ja.md)
- [Evidence](../EVIDENCE.ja.md)
