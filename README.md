# TrustAnswer OS

TrustAnswer is an evidence-first SaaS for small B2B software teams responding to customer security questionnaires.

**Core promise:** help teams identify what is not safe to send before a questionnaire leaves the company.

## Product model

TrustAnswer is a membership SaaS, not a paid spreadsheet. The MVP follows:

`question -> canonical topic -> proposed response -> evidence -> validation -> human review -> submission gate`

The application is multi-tenant. Validation and entitlement authority remain server-side.

## Core modules

1. Dashboard
2. Questionnaires
3. Answer Library
4. Evidence Registry
5. Gap Register
6. Review Queue
7. Submission Gate

## MVP principles

- Unknown is not Yes.
- A claim is not evidence.
- Evidence existence does not imply evidence validity.
- Current knowledge must not rewrite historical submissions.
- Fixing a dependency does not restore an old approval.
- Approval belongs to an exact context and revisions.
- Tenant authorization is explicit and fail-closed.
- Browser state cannot grant paid capability.
- Ambiguity at the submission boundary fails closed.

MVP evidence is metadata/reference-first; TrustAnswer does not initially host confidential evidence documents.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/SAAS-ADVERSARIAL-GATE.md](docs/SAAS-ADVERSARIAL-GATE.md), and [docs/CURRENT.md](docs/CURRENT.md).

## Security / IP boundary

This public repository documents guarantees and public-safe architecture. Detailed adversarial recipes, resolver internals, proprietary heuristics, and private fixtures remain private. See [docs/PUBLIC-PRIVATE-BOUNDARY.md](docs/PUBLIC-PRIVATE-BOUNDARY.md).

## Status

**SaaS Architecture v0.3 Migration — P0 security gate defined; not yet closed.**

UI/UX is blocked until tenant isolation, billing entitlement, and inherited validation gates pass.
