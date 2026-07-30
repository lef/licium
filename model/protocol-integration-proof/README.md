---
Type: README
Updated: 2026-07-31T01:10:00+09:00
Status: confirmed
Tags: licium, sample, oidc, reproduction
Description: English reproduction guide for the finite Protocol Integration Proof sample.
---

# Run the Protocol Integration Proof

[日本語](README.ja.md) |
[Proof summary](../../docs/PROTOCOL-INTEGRATION-PROOF.md)

## Requirements

- Linux or a compatible POSIX environment;
- Node exactly `v22.22.2`;
- npm with registry access for setup;
- POSIX shell, awk, sed, sort, cmp, diff, mktemp, find, cp, mkdir, rm,
  grep, rg, uniq, test, wc, cut, tr, sha256sum, GNU stat, xargs, and tar;
- a Git clone with a committed `HEAD`;
- sqlite3, curl, and openssl;
- loopback port `127.0.0.1:56100` available.

`127.0.0.1:56101` is a redirect identifier only. No listener is required.
The proof runtime does not require an external IdP or external runtime network
access. Dependency setup retrieves the pinned npm graph.

## Setup

From the repository root:

```sh
cd model/protocol-integration-proof/engine-selection/oidc-provider
npm ci --ignore-scripts --no-audit --no-fund
cd ../../../..
```

Dependencies are not vendored. `package-lock.json` pins `oidc-provider` 9.11.1
and its dependency graph. The install creates ignored `node_modules`; it must
not change tracked sample files.

## Run

```sh
test "$(node --version)" = v22.22.2
NODE="$(command -v node)" sh model/protocol-integration-proof/verify-all.sh
```

Expected terminal output:

```text
PROTOCOL_INTEGRATION_FULL_REGRESSION_VALID 63 suites
```

The aggregate runs 63 manifest-bound suites. It fails on an omitted suite,
unexpected stderr, line-count drift, or output-digest drift.

## Cleanup

```sh
rm -rf model/protocol-integration-proof/engine-selection/oidc-provider/node_modules
```

Keys, tokens, cookies, sessions, logs, and temporary databases are generated
under temporary directories and removed by the runners.

## Scope

This is disposable synthetic proof code. It is not a production IdP, an OIDC
or security conformance suite, a general backend contract, or a Rust
implementation. Read the [proof summary](../../docs/PROTOCOL-INTEGRATION-PROOF.md)
for the exact supported and unsupported conclusions.
