# Licium

Licium is an attribute-thread framework for identity-like trust records.

It does not require a stable Entity. Instead, it binds externally established attributes, claims, and evidence into a portable thread that can be verified, transformed, and presented to relying parties.

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
