---
Type: SPEC
Updated: 2026-07-26T20:30:00+09:00
Status: draft
Tags: licium, public, sample, evidence, publication
Description: 再現可能でevidence境界の明確なLicium sampleをpublicへ公開するためのcandidate要件。
---

# Public Sample Policy

English: [Public Sample Policy](PUBLIC-SAMPLES.md)

## 目的

Liciumのpublic sampleは、有限で再現可能なevidenceである。一つのclaimをreaderが
検査できるようにしつつ、Licium設計全体やproduction implementationが完成したとは
示唆しない。

technical checkを通ることはreview可能性を意味するが、それだけでpublic commitや
pushをauthorizeしない。

## 必須特性

### Evidence境界

各material supported claimは次を特定する。

- claimを記載するpublic document;
- positive runnerとfixed oracle;
- expected observation;
- falsifierまたはnegative control;
- 明示したnon-conclusionとopen boundary。

hypothesis、open question、未実装behaviorは別にlabelする。sampleは普遍的証明を
主張しなくても有用であり得る。

profileは全material claimをunique IDでinventoryし、supported、candidate、
hypothesis、open、not implementedのいずれかへexactly once分類する。candidateは
review対象のnormative boundary候補であり、stable、implemented、evidence-confirmedな
claimではない。supported claim／evidence matrix rowとcandidate claim／candidate
matrix rowは、それぞれ一対一に対応する。missing IDとextra IDをどちらも
verification failureとする。human reviewerはinventoryから漏れたmaterial
statementがないか検査する。

### 再現可能性

sampleはexact file manifestと実行commandを持つ。同じtracked source revisionから
二回buildしたとき、regular file、mode、bytesが一致しなければならない。runtime
dependency、expected count、failure markerを明示する。

manifest pathはfixed grammarに従う。declared modeを持つregular fileだけを許し、
symlink、device、FIFO、socket、submodule等のnon-regular entryをrejectする。

別contractが定めない限り、SQLite table、shell command、test TSV、fixture
vocabularyはreference realizationである。自動的にLicium Core、final API、
wire formatにはならない。

### 再配布の安全性

全source fileについてproject／third-party license、compatibility decision、
required attribution／notice、redistribution right、data originをreviewする。
originはsynthetic、public、first-party approved、third-party approvedのいずれかを
宣言する。unreviewed third-party material、personal data、customer data、
production data、credential、private key、internal path、private review
provenanceを含めない。

synthetic fixtureは生成方法とreview provenanceを記録する。意図的なsecret-like
test sentinelには、path、exact bytes／pattern、rationale、source blobまたは
content digestへbindingしたexceptionを必要とする。

license compatibility、redistribution authority、data originはhuman reviewを
必要とし、scannerだけでは完了しない。

### Readerに対する自己完結性

public entry pointは次を説明する。

- purposeとscope;
- 同梱内容;
- reproduction方法;
- evidenceが支持すること;
- evidenceが確立しないこと;
- current open questions。

readerにprivate repositoryやprivate historyを要求しない。複数言語をclaimする場合、
claim strength、limitations、navigation、commands、countsを同じ強度で保持する。

profileはcold-readerの固定question、required answer fields、forbidden overclaims、
allowed public entry points、machine-recordable verdictを定める。

### Copy-only promotion

通常のsample promotionはexact allowlist上のpathだけを追加またはbyte-updateする。
既存public pathのdelete、rename、archive、mode change、history rewriteを禁止する。
必要な場合は、提案前に別のdestructive-operation contractを作る。

reviewはmanifest destinationとlive public baseline pathのunion全体を分類する。
byte-identical collisionを証明し、reader-visibleなretained-unlisted pathを全て
reviewし、retained non-regular entryをrejectする。candidate、overlay、review済み
commitはallowed path、kind、mode、bytesが一致し、allowlist外changeは0とする。

source revision、profile revision／digest、manifest digest、target repository／ref、
live baseline commit、proposed tree、diff digest、authorization scope、review済み
commit range／tipを一つのartifactとしてbindingする。bound fieldが変われば後段の
approvalは失効し、新しいreviewを必要とする。

## Review states

```text
planned
  -> candidate accepted
  -> local preparation authorized
  -> local commit reviewed
  -> public push authorized
  -> delivered and verified
```

各transitionは独立である。historical approvalは過去のdelivery evidenceであり、
変更されたartifactへの再利用可能なpermissionではない。

## このPolicyが確立しないこと

本policyはproduction security、durability、performance、privacy compliance、
cryptographic correctness、distributed consensus、特定deploymentへの適合性を
certifyしない。それぞれに独立したrequirementsとevidenceが必要である。

## Initial Profile

現在のE67–E72 SQLite／POSIX shell reference sliceを、本policyへ対応づける最初の
historical sampleとする。public evidenceはrepository READMEとevidence mapから
参照できる。generic verifierとdifferential negative suiteが完成するまで、
reusable profileへのconformanceはcandidate workである。

## References

- [Public Sample Policy English version](PUBLIC-SAMPLES.md)
- [Current Design](DESIGN.md)
- [Evidence Map](EVIDENCE.ja.md)
- [Reference Slice](REFERENCE-SLICE.ja.md)
