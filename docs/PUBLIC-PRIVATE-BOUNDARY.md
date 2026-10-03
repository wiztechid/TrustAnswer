# Public / Private Boundary

This repository is public. Treat this file as a mandatory publication boundary.

## Safe to publish

- product positioning and user-facing concepts
- logical module structure
- public state names
- public-safe schema and API contracts
- high-level tenant-isolation and entitlement guarantees
- high-level deterministic validation principles
- fictional/demo data that reveals no private resolver behavior
- ordinary expected-behavior tests
- public release notes and user documentation

## Keep private

Do **not** commit:

- full adversarial acceptance-suite recipes or executable bypass recipes
- resolver precedence/decision internals
- proprietary contradiction/evidence matching heuristics
- detailed anti-tamper or anti-bypass mechanisms beyond necessary public guarantees
- privileged operational runbooks that materially aid bypass
- service-role keys, Paddle secrets, signing secrets, API credentials
- private fixtures designed to reveal validator weaknesses
- private commercial research datasets
- real customer questionnaires, evidence, security documents, or confidential tenant data

## SaaS-specific rule

Public documentation may state that RLS, server-side entitlement enforcement, signature verification, idempotency, and fail-closed validation are required. Exact private adversarial sequences and proprietary detection/resolution internals remain outside this repository.

Never place privileged secrets or a service-role credential in client code, public examples, fixtures, logs, screenshots, or commits.

## Architecture status

v0.2 remains the inherited validation contract.

v0.3 migrates TrustAnswer to multi-tenant SaaS and adds tenant-isolation and billing-entitlement security boundaries.

The private acceptance suites remain authoritative release gates.
