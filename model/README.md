---
Type: README
Updated: 2026-07-26T20:00:00+09:00
Status: confirmed
Tags: licium, model, sqlite, reproduction, e67, e72
Description: Dependencies, command, expected output, and evidence boundary for the included E67–E72 reference slice.
---

# E67–E72 Reference Slice

[日本語版](README.ja.md)

## Requirements

- a POSIX shell;
- common Unix utilities used by the scripts, including `dirname`, `sed`,
  `awk`, `sort`, `cmp`, `diff`, `mktemp`, and file utilities;
- `sqlite3`.

No Rust, Cargo, Python, Perl, Node, network service, or package manager is
required.

## Run

From the generated repository root:

```text
sh model/run-reference-slice-tests.sh
```

The command executes six positive experiment wrappers and six mutation
self-test wrappers.

Successful completion ends with:

```text
6 reference-slice targeted tests and 25 negative identities passed
```

The positive expectations contain 30 targeted relations. The 25 negative
identities intentionally mutate behavior and pass only when the mutation
causes the fixed positive comparison to fail.

## Layout

```text
model/run-reference-slice-tests.sh    aggregate entrypoint
model/test-e*.sh                      positive wrappers
model/self-test-e*.sh                 mutation wrappers
model/reference-slice/                disposable SQLite implementation
model/tdd/e*/expected-*.tsv           fixed observations
```

The included executable closure has 64 files:

```text
33 shell files including the aggregate runner
30 expected TSV files
1 SQLite schema
```

## Interpretation

Passing the slice establishes only the finite observations in
[docs/EVIDENCE.md](../docs/EVIDENCE.md). The SQLite schema and shell scripts
are intended to be thrown away when the Rust implementation boundary is ready.
They are not a public API or production backend.
