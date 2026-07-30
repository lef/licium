---
Type: README
Updated: 2026-07-31T01:10:00+09:00
Status: confirmed
Tags: licium, sample, oidc, reproduction
Description: finite Protocol Integration Proof sampleの日本語再現guide。
---

# Protocol Integration Proofを実行する

[English](README.md) |
[Proof summary](../../docs/PROTOCOL-INTEGRATION-PROOF.ja.md)

## 要件

- Linuxまたは互換POSIX environment。
- exact Node `v22.22.2`。
- setup時にregistryへ接続できるnpm。
- POSIX shell、awk、sed、sort、cmp、diff、mktemp、find、cp、mkdir、rm、
  grep、rg、uniq、test、wc、cut、tr、sha256sum、GNU stat、xargs、tar。
- committed `HEAD`を持つGit clone。
- sqlite3、curl、openssl。
- loopback port `127.0.0.1:56100`が利用可能。

`127.0.0.1:56101`はredirect identifierだけで、listenerは不要である。proof
runtimeはexternal IdPやexternal runtime network accessを必要としない。dependency
setupだけが固定npm graphを取得する。

## Setup

repository rootから実行する。

```sh
cd model/protocol-integration-proof/engine-selection/oidc-provider
npm ci --ignore-scripts --no-audit --no-fund
cd ../../../..
```

dependencyはvendorしない。`package-lock.json`が`oidc-provider` 9.11.1とdependency
graphを固定する。installはignore対象の`node_modules`を作るが、tracked sample filesを
変更してはならない。

## 実行

```sh
test "$(node --version)" = v22.22.2
NODE="$(command -v node)" sh model/protocol-integration-proof/verify-all.sh
```

expected terminal output:

```text
PROTOCOL_INTEGRATION_FULL_REGRESSION_VALID 63 suites
```

aggregateはmanifest-bound 63 suitesを実行する。suite omission、unexpected stderr、
line-count drift、output-digest driftがあれば失敗する。

## Cleanup

```sh
rm -rf model/protocol-integration-proof/engine-selection/oidc-provider/node_modules
```

key、token、cookie、session、log、temporary databaseはtemporary directoryで生成し、
runnerが削除する。

## Scope

これはdisposable synthetic proof codeである。production IdP、OIDC／security
conformance suite、general backend contract、Rust implementationではない。exact
supported／unsupported conclusionsは
[proof summary](../../docs/PROTOCOL-INTEGRATION-PROOF.ja.md)を参照する。
