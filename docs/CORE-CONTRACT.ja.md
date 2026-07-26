---
Type: DESIGN
Updated: 2026-07-26T21:00:00+09:00
Status: draft
Tags: licium, core, repository, evaluation, contract
Description: Rust、storage、wire、deployment topologyに依存しないRepository／Evaluation lifecycleのevidence-derived Candidate Contract v0。
---

# Repository／Evaluation Lifecycle Core Contract v0

English: [Repository / Evaluation Lifecycle Core Contract v0](CORE-CONTRACT.md)

## Statusとscope

これは**Candidate Contract v0**であり、stableなpublic specification、production
guarantee、final API、完成したLicium Identity-composition contractではない。
E67–E73Rのfinite fixturesと、sliceが依存するpredecessor evidenceから、
observable boundaryを抽出したものである。

このpublic reviewer packageが同梱するのはE67–E72だけであり、全predecessor
fixturesまたはE73Rを同梱しない。

対象はRepository、Publication、Evaluation、Result、Repository Effect、View、
replay、explanation、placement eligibilityのlifecycleである。Pair／Tuple semantics、
Literal／Ref intent、Identity Definition、Profile、Context、Delegationは完成させない。

以下の`MUST`は「candidate conforming implementationがこの観測を保持する」という
意味である。Rust type、SQL schema、serialization、backend、process、queue、
network protocolを規定しない。

## Role boundaries

一実装が同じ場所へ保存しても、次のrolesをcollapseしてはならない。

```text
delivery occurrence != semantic Association / logical equivalence
delivery occurrence != Evaluation Request / Effect Request identity
same-request retry != new logical request
immutable object != complete Root
physical Pair / layout != semantic Association / Tuple-like meaning
Root existence != Publication disposition != authority-scoped Head derivation
Evaluation Request != Pinned Input Closure
ephemeral Outcome != persisted Result
persisted Result write != authoritative state transition
Effect Request != accepted Effect / State Transition
State Transition != Decision Observation
persisted Result != provenance-bearing View
complete View != current View pointer
View != authoritative Source
forget event != canonical delete
active placement != canonical object / history
release eligibility != release execution
placement release != canonical deletion
declared verified archive state != demonstrated reconstruction
```

## Candidate claims

<a id="cc01"></a>
### CC01 — Delivery retryとoccurrence

- **Precondition:** deliveryがdelivery identityとAssociation occurrenceを持つ。
- **MUST / success:** 同じdeliveryのreplayは冪等であり、意味内容が同じ異なるoccurrencesは区別される。
- **Failure observation:** delivery collision／malformed inputを成功した新occurrenceへnormalizeしない。
- **Persistent effect:** 成功した新occurrenceはRepository inputを拡張してよいが、retryは複製しない。
- **Retry:** same deliveryは新logical occurrenceではない。
- **Provenance:** accepted occurrenceからdeliveryを辿れる。
- **Evidence:** E67 inventory／member relations、`E67_DELIVERY_DUPLICATES`、`E67_OCCURRENCE_COLLAPSE`。
- **Not established:** 全Associationへのuniversal occurrence IDまたはfinal minting rule。

<a id="cc02"></a>
### CC02 — Complete Rootまたはunavailable

- **Precondition:** Root formation／resolutionがrequired inventoryを指定する。
- **MUST / success:** full inventoryをcompleteとしてcommit／resolveする。
- **Failure observation:** missing memberはrollback／unavailableとなり、partial semantic Rootを返さず、後続healthy transactionをpoisonしない。
- **Persistent effect:** failureはpartial Root artifactを残さない。
- **Retry:** 訂正された後続attemptは同じRepositoryで成功できる。
- **Provenance:** complete Rootはinventoryとancestry boundaryを保持する。
- **Evidence:** E67 incomplete injection／recoveryとE30 complete-or-unavailable layout resolution。
- **Not established:** canonical Root bytes、hashing、Merkle、distributed transaction。

<a id="cc03"></a>
### CC03 — Root、Publication、Headは別である

- **Precondition:** Rootが存在し、Authority scopeについてPublication dispositionを評価する。
- **MUST / success:** Root existence、Publication acceptance、authority-scoped Head derivationを別observationsにする。
- **Failure observation:** stored-only／rejected Rootはaccepted Head resultへ入らない。
- **Persistent effect:** Root保存だけではpublishされない。
- **Retry:** 同じaccepted stateの再観測から別logical Headを捏造しない。
- **Provenance:** derived Headからaccepted PublicationとRootを辿れる。
- **Evidence:** E68 Publication／Head relations、`E68_STORED_IS_HEAD`、`E68_REJECTED_IS_HEAD`。
- **Not established:** Authority trust correctness、consensus、Head cardinality、convergence。

<a id="cc04"></a>
### CC04 — Explicit read mode

- **Precondition:** readがexact stored stateまたはauthority-accepted published stateを指定する。
- **MUST / success:** selected modeが読めるRootを決める。
- **Failure observation:** missing／unaccepted published inputをambient currentでrepairせずunavailableにする。
- **Persistent effect:** 暗黙のpersistent effectはない。
- **Retry:** 同じpinsのreadは同じlogical inputを持つ。
- **Provenance:** resultはselected Rootとread boundaryを記録する。
- **Evidence:** E68 exact-versus-published relation、`E68_AMBIENT_INPUT`。
- **Not established:** public method名、routing policy、replica selection、freshness SLA。

<a id="cc05"></a>
### CC05 — Complete pinned input closure

- **Precondition:** Evaluation RequestがRoot、Definition、Semantics、Binding等のrequired inputsを指定する。
- **MUST / success:** pinned knowledge cut内でresolveしたcomplete closureを使う。
- **Failure observation:** missing closureはunavailableであり、ambient latestを代入しない。
- **Persistent effect:** resolutionだけではwriteを意味しない。
- **Retry:** 同じcomplete pinsはlogical replay可能だが、different pinsはsame request occurrenceではない。
- **Provenance:** Resultから全required input rolesを識別できる。
- **Evidence:** E68 input relation、E71 omission control、E61 dependency closure。
- **Not established:** closure encoding、generic recursion、termination、canonical dependency order。

<a id="cc06"></a>
### CC06 — Ordinary Evaluationはwrite-free

- **Precondition:** Repository Effect requestを持たないordinary Evaluationである。
- **MUST / success:** logical Evaluationはpersistent Repository changeなしにephemeral Outcomeを返す。
- **Failure observation:** unavailable／Finding outcomeもstate mutationを要求しない。
- **Persistent effect:** state／Result-store／Decision-Observation writesは`0/0/0`。
- **Retry:** ordinary readを繰り返してもResult artifactsを蓄積しない。
- **Provenance:** ephemeral Outcomeもpinned-input boundaryを保持する。
- **Evidence:** E69の二before／after DB comparisons、`E69_READ_WRITES_RESULT`。
- **Not established:** optional physical moduleとしてのcache、metrics、traceの有無。

<a id="cc07"></a>
### CC07 — Result記録はauthoritative state effectではない

- **Precondition:** Evaluation Outcomeがoptional persistenceの対象になり得る。
- **MUST / success:** authoritative-state write／Result-store write／Decision-Observation writeの三axesを分離する。
- **Failure observation:** Result persistenceだけをaccepted state transitionと解釈しない。
- **Persistent effect:** ordinary readは`0/0/0`、effect-targeting evaluationはaccepted Effect前に`0/1/0`となり得る。
- **Retry:** persisted Resultをtransition追加なしに再利用してよい。
- **Provenance:** persisted Resultは生成したrequestとpinned inputsを保持する。
- **Evidence:** E66 evaluation-side-effect rowsとResults Correction、E69 ordinary reads。
- **Not established:** mandatory Result retention、global Result ID、deployment persistence policy。

<a id="cc08"></a>
### CC08 — Atomic Repository Effect observation

- **Precondition:** complete persisted Result、Effect Request、expected Repository stateがpreconditionsを満たす。
- **MUST / success:** transition、Decision Observation、complete View、current pointerをResultへlinkされた一つのindivisible Repository transitionにし、partial intermediate stateをobservableにしない。
- **Failure observation:** failpoint／failed preconditionはこのobservable setの一部を残さない。
- **Persistent effect:** accepted Repository-local transition setだけがdurableになる。
- **Retry:** 同じaccepted Effectは二つ目のtransition setを作らない。
- **Provenance:** Observationがtransition、Result、source Root、View／current outcomeを結ぶ。
- **Evidence:** E70 success、final-state、link、rollback、retry relations。
- **Not established:** external API、device、message broker等とのatomicity。

<a id="cc09"></a>
### CC09 — Failed／duplicate Effectはattempt artifactを残さない

- **Precondition:** Effectがstale、incomplete、duplicate、またはRepository commit前にfailする。
- **MUST / success:** ephemeral Outcome／diagnosticを返してよいが、persistentなtransition、Observation、View、current pointer、attempt artifactを作らない。
- **Failure observation:** そのartifactは自動保存すべきaudit evidenceではなくcontract violationである。
- **Persistent effect:** 既存accepted objects以外はない。
- **Retry:** same-request retryは新logical Effect Requestではない。
- **Provenance:** diagnosticはaccepted provenanceを捏造せずfailed preconditionを識別する。
- **Evidence:** E70 outcome／rollback relationsと四negative identities。
- **Not established:** network retry transport、distributed deduplication、external delivery log policy。

<a id="cc10"></a>
### CC10 — Provenanceとselected-output closure

- **Precondition:** Evaluationがpinned Source inputからoutput closureを選択する。
- **MUST / success:** Result、View、replay、explanationはrequired provenanceを保持し、selected output closure外のValueまたはpinned Source inputにないambient executor metadataを含めない。
- **Failure observation:** missing provenance、closure外sentinel、ambient executor metadataを検出できる。
- **Persistent effect:** persisted Result／Viewも同じboundaryを保持し、persistenceでselectionを広げない。
- **Retry:** replayはprovenanceをambient current inputへ置換しない。
- **Provenance:** Source Root、Definition、request、required rolesがresolvableである。
- **Evidence:** E68／E69／E71／E72 leakage／provenance relationsとfalsifiers。
- **Not established:** general privacy、side channel、log redaction、information-flow proof。Sourceへ明示的にpinしたruntime／NHI属性は禁止しない。

<a id="cc11"></a>
### CC11 — Replay、explanation、semantic integrity

- **Precondition:** complete pinned input closureがrestart後もresolvableである。
- **MUST / success:** restartとambient-current advancementはreplayを変えず、finite explanation closureを生成し、dangling／cross-linked required refsをtyped Findingsにする。
- **Failure observation:** missing closureはunavailableであり、silent substitution／complete扱いをしない。
- **Persistent effect:** replayはwrite不要であり、accepted historical recordはpinsを保持する。
- **Retry:** 同じpinsのreplayはlogically equivalentである。
- **Provenance:** explanationはunique pathを要求せずObservation、Result、Request、Root、selected memberを結ぶ。
- **Evidence:** E71 replay／current-variationとE72 explanation／integrity relations。
- **Not established:** production durability、infinite history、unique explanation path、cryptographic audit。

<a id="cc12"></a>
### CC12 — GC-free placement eligibility

- **Precondition:** ordinary witness、Conflict state、Publication state、accepted forget event、explicit policy phase、declared archive stateがある。
- **MUST / success:** canonical inventoryを変更せずprotectionとcandidate active-placement release eligibilityを導出する。
- **Failure observation:** active protection、closed window、unverified archive stateはeligibilityを阻止する。
- **Persistent effect:** eligibility computationはwrite-freeでrelease／deletionを実行しない。
- **Retry:** 同じfactsの再評価はlogically stableである。
- **Provenance:** decisionからprotectionまたはpolicy／archive-state blockerを識別できる。
- **Evidence:** private design auditではE73R 30 accepted rows、7 controls、source assertion、same-DB inventoryを使用した。E73Rは本public packageに同梱しないため、ここでのCC12はreview可能なcandidate claimであり、publicに再現されたevidenceではない。
- **Not established:** archive reconstruction／integrity、release execution、reader coordination、GC、canonical deletion、legal erase。

## Representation independence

conformanceはobservationalである。SQLite table名、SQL row order、Rust trait、
UUID version、canonical bytes、protobuf、JSON、GraphQL、gRPC、特定backend、
process／thread／queue topologyを要求しない。

## Public Evidence Boundary

同梱したE67–E72 reference sliceは、接続されたRepository／Evaluation lifecycleの
有限なexecutable evidenceを提供する。本packageはcomplete predecessor
traceability corpusまたはE73Rを含まない。したがって本書はdesign review用であり、
CC01–CC12全てがbackend conformanceを通ったというself-contained proofではない。

## Open boundary

次はBackend Conformance Contractで、physical schemaをCoreへ漏らさず上記観測を
どう実証するかを定める。Identity composition、Trust、Context、Delegation、
cryptography、production distribution、external Effectsは別作業である。

## References

- [Public Evidence Map](EVIDENCE.ja.md)
- [Reference Slice](REFERENCE-SLICE.ja.md)
- [Model Boundary](MODEL.ja.md)
- [Backend Conformance Candidate](BACKEND-CONFORMANCE.ja.md)
