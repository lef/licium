---
Type: DESIGN
Updated: 2026-07-31T01:10:00+09:00
Status: confirmed
Tags: licium, authentication, oidc, adapter, backend, evidence
Description: Public summary of the disposable pre-Rust Protocol Integration Proof.
---

# Protocol Integration Proof

[日本語](PROTOCOL-INTEGRATION-PROOF.ja.md) |
[Run the sample](../model/protocol-integration-proof/README.md)

## Result

A disposable Licium backend participated in a real Authorization Code + S256
PKCE flow without making an OIDC server part of Licium Core.

```text
test client
  <-> pinned oidc-provider 9.11.1
  <-> replaceable adapter
  <-> protocol-neutral authentication backend
  <-> SQLite or flat-file / POSIX provider
```

The finite candidate completed login, token issuance, RP-side ID Token
validation, and selected UserInfo projection. Its exact aggregate ran 63 of 63
manifest-bound suites: 43 positive／boundary verifiers and 20 negative
self-tests. Static closure contains 71 shell files and 15 project-authored ESM
files.

All identities, credentials, clients, inputs, and expected outputs are
project-authored synthetic fixtures. Runtime-generated keys, tokens, cookies,
sessions, and logs are not retained.

## Boundary Demonstrated

The observed boundary is:

```text
raw OIDC request
  -> versioned adapter mapping
  -> protocol-neutral ten-role request
  -> pinned backend evaluation
  -> ephemeral authentication outcome
  -> subject decision and selected projection
  -> engine-owned claims / token flow
```

The OIDC engine owns protocol state, sessions, tokens, and signing. The test RP
owns its code verifier, state, nonce, and token validation. The adapter does
not make raw OIDC fields canonical Source data.

SQLite and independent flat-file／POSIX providers returned the same finite
accepted／rejected semantics, selected projection, failure categories, and
provenance roles behind the same adapter. This result applies only to the exact
two implementations and fixtures in the sample.

## Scenarios

The finite suite covers accepted／rejected credentials, Exact Root／Published
Head source modes, pinned Definition／Profile／Context references, selected
values and relations, separate provenance, public and pairwise subjects,
policy migration, distinct Alice／Bob subjects, forced reauthentication,
pre-claims projection equivalence, non-leakage sentinels, and nineteen
reachable negative identities.

Ordinary authentication remains write-free in this sample. It does not
implicitly create a Repository transition, persisted Result, or Decision
Observation.

## Not Established

- a production IdP, password system, MFA, recovery, lockout, or lifecycle;
- OIDC／OAuth, FAPI, Federation, or security certification;
- TLS posture, restart, scale-out, key rotation, refresh, or logout;
- arbitrary backend portability, Spanner conformance, or performance;
- a stable Core schema, wire format, subject policy, or API;
- a Rust implementation, durable audit evidence, or production readiness.

The ten-role request and synthetic credentials are finite integration fixtures,
not stable Licium Core primitives.

## Reproduce

See the [sample guide](../model/protocol-integration-proof/README.md). The exact
success marker is:

```text
PROTOCOL_INTEGRATION_FULL_REGRESSION_VALID 63 suites
```

## References

- [Run the sample](../model/protocol-integration-proof/README.md)
- [Japanese summary](PROTOCOL-INTEGRATION-PROOF.ja.md)
