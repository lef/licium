---
Type: DESIGN
Updated: 2026-07-31T01:10:00+09:00
Status: confirmed
Tags: licium, authentication, oidc, adapter, backend, evidence
Description: Rust前の使い捨てProtocol Integration Proofを説明する公開用日本語summary。
---

# Protocol Integration Proof

[English](PROTOCOL-INTEGRATION-PROOF.md) |
[sampleを実行する](../model/protocol-integration-proof/README.ja.md)

## 結果

使い捨てのLicium backendを、OIDC serverをLicium Coreへ入れずに、実際の
Authorization Code + S256 PKCE flowへ接続できた。

```text
test client
  <-> pinned oidc-provider 9.11.1
  <-> replaceable adapter
  <-> protocol-neutral authentication backend
  <-> SQLite or flat-file / POSIX provider
```

finite candidateはlogin、token issuance、RP側ID Token validation、selected UserInfo
projectionを完了した。exact aggregateはmanifest-bound 63 suitesを全件実行した。
43 positive／boundary verifiersと20 negative self-testsである。static closureには
71 shell filesと15 project-authored ESM filesがある。

全identity、credential、client、input、expected outputはproject-authored synthetic
fixturesである。runtime-generated key、token、cookie、session、logは保持しない。

## 実証した境界

観測した境界は次である。

```text
raw OIDC request
  -> versioned adapter mapping
  -> protocol-neutral ten-role request
  -> pinned backend evaluation
  -> ephemeral authentication outcome
  -> subject decision and selected projection
  -> engine-owned claims / token flow
```

OIDC engineがprotocol state、session、token、署名を所有する。test RPがcode
verifier、state、nonce、token validationを所有する。adapterはraw OIDC fieldsを
canonical Source dataにしない。

SQLiteと独立flat-file／POSIX providersは、同じadapterの背後で同じfinite
accepted／rejected semantics、selected projection、failure categories、provenance
rolesを返した。このresultはsample内のexact二implementationとfixtureだけに適用する。

## Scenarios

finite suiteはaccepted／rejected credentials、Exact Root／Published Head source
modes、pinned Definition／Profile／Context refs、selected values／relations、separate
provenance、public／pairwise subjects、policy migration、distinct Alice／Bob subjects、
forced reauthentication、pre-claims projection equivalence、non-leakage sentinels、
十九個のreachable negative identitiesを扱う。

ordinary authenticationはこのsampleでwrite-freeである。Repository transition、
persisted Result、Decision Observationを暗黙作成しない。

## 確立していないもの

- production IdP、password system、MFA、recovery、lockout、lifecycle。
- OIDC／OAuth、FAPI、Federation、security certification。
- TLS posture、restart、scale-out、key rotation、refresh、logout。
- arbitrary backend portability、Spanner conformance、performance。
- stable Core schema、wire format、subject policy、API。
- Rust implementation、durable audit evidence、production readiness。

ten-role requestとsynthetic credentialはfinite integration fixtureであり、stable
Licium Core primitiveではない。

## 再現

[sample guide](../model/protocol-integration-proof/README.ja.md)を参照する。exact
success markerは次である。

```text
PROTOCOL_INTEGRATION_FULL_REGRESSION_VALID 63 suites
```

## References

- [sampleを実行する](../model/protocol-integration-proof/README.ja.md)
- [English summary](PROTOCOL-INTEGRATION-PROOF.md)
