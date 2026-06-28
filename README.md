---
Type: README
Updated: 2026-06-29T03:55+09:00
Status: draft
Tags: licium, identity, attributes, trust, llmops, public-snapshot
Description: Licium is an attribute-thread framework for identity-like trust records.
---

# Licium

Licium is an attribute-thread framework for identity-like trust records.

It does not require a stable Entity. Instead, it binds externally established attributes, claims, and evidence into a portable thread that can be verified, transformed, and presented to relying parties.

## 日本語概要

Licium は、Identity 的な信頼記録を扱う attribute-thread framework です。

安定した Entity の存在を前提にせず、外部で確立された属性・claim・証拠を、検証・変換・提示可能な thread として束ねます。

中心にある考えは、Entity / Identity / Privacy を単一の箱として扱うのではなく、属性とその制御へ分解し、それらを失われない context として RP (Relying Party) へ渡すことです。

## Why

Traditional identity systems often start from a durable subject: a user, device, service account, or workload identity. Licium starts one layer lower.

Human users, devices, workloads, LLM agents, and short-lived processes may all receive trust from different enrollment or registration processes. Licium does not define those trust anchors. It records their results, preserves their context, and provides a format-agnostic way to present them downstream.

## Core Idea

Licium treats identity-like records as threads of attributes.

- Attributes and claims may come from different issuers.
- Evidence may use different formats, such as JWT, X.509, SAML, VDC, or project-specific records.
- The relying party should receive a coherent presentation without losing the original context.
- A stable Entity is allowed, but not required.

## Non-Goals

Licium is not:

- a traditional IdP
- a universal root of trust
- a replacement for JWT, X.509, SAML, or VDC
- an Entity registry
- a single canonical identity database

## Early Model

The initial model is expected to define:

- thread identity
- subject binding
- attributes and claims
- issuers and attestors
- evidence
- audience and scope
- expiration and revocation
- presentation to relying parties

This repository is currently at the concept/bootstrap stage.

## Current Status

This repository is a bootstrap snapshot. The data model and terminology are not stable yet.

The next useful work is to define the core model before implementing components:

1. Scope and non-goals
2. Thread, subject binding, attribute, claim, evidence
3. Issuer, attestor, audience, scope, expiry, revocation
4. Lifecycle: issue, verify, refresh, revoke, compose, present
5. Format boundary: JWT, X.509, SAML, VDC, CS-MD, and project-specific records

## License

MIT License. See [LICENSE](https://github.com/lef/licium/blob/main/LICENSE).
