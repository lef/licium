---
Type: README
Updated: 2026-07-26T20:00:00+09:00
Status: confirmed
Tags: licium, model, sqlite, reproduction, e67, e72, japanese
Description: 同梱するE67–E72 reference sliceの依存関係、command、expected output、Evidence境界。
---

# E67–E72 Reference Slice

[English version](README.md)

## 必要なもの

- POSIX shell;
- scriptが使用する一般的なUnix utility。`dirname`、`sed`、`awk`、`sort`、
  `cmp`、`diff`、`mktemp`、file utilityを含む;
- `sqlite3`。

Rust、Cargo、Python、Perl、Node、network service、package managerは不要です。

## 実行

生成されたrepositoryのrootから実行します。

```text
sh model/run-reference-slice-tests.sh
```

このcommandは、6個のpositive experiment wrapperと6個のmutation self-test
wrapperを実行します。

正常に完了すると、末尾に次のように出力されます。

```text
6 reference-slice targeted tests and 25 negative identities passed
```

positive expectationには30個のtargeted relationが含まれます。25個のnegative
identityは意図的に挙動を変異させ、そのmutationによって固定されたpositive
comparisonが失敗した場合にのみpassします。

## 配置

```text
model/run-reference-slice-tests.sh    aggregate entrypoint
model/test-e*.sh                      positive wrappers
model/self-test-e*.sh                 mutation wrappers
model/reference-slice/                disposable SQLite implementation
model/tdd/e*/expected-*.tsv           fixed observations
```

同梱するexecutable closureは64 filesです。

```text
33 shell files including the aggregate runner
30 expected TSV files
1 SQLite schema
```

## 解釈

このsliceのpassによって確立されるのは、[docs/EVIDENCE.ja.md](../docs/EVIDENCE.ja.md)
に記録された有限の観測だけです。SQLite schemaとshell scriptは、Rustの実装境界を
用意できた時点で破棄することを意図しています。これらはpublic APIでもproduction
backendでもありません。
