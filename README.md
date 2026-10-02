# TrustAnswer OS

TrustAnswer is an evidence-first workspace for small B2B SaaS teams responding to customer security questionnaires.

**Core promise:** help teams identify what is not safe to send before a questionnaire leaves the company.

## Product direction

TrustAnswer is not a generic questionnaire template and does not treat generated text as evidence. The public MVP is designed around a deterministic workflow:

`question -> canonical topic -> proposed response -> evidence -> human review -> submission gate`

Key principles:

- Unknown is not Yes.
- A claim is not evidence.
- Evidence existence does not imply evidence validity.
- Current knowledge must not rewrite historical submissions.
- Fixing a dependency does not restore an old approval.
- Approval belongs to a specific context and revision set.
- Ambiguity at the submission boundary fails closed.

## MVP workbook

The initial implementation uses seven sheets:

1. Dashboard
2. Questionnaire
3. Answer Library
4. Evidence Register
5. Gap Register
6. Review Queue
7. Submission Gate

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the public architecture contract and [docs/CURRENT.md](docs/CURRENT.md) for project status.

## Security / IP boundary

This public repository intentionally excludes detailed adversarial recipes, internal resolver logic, anti-tamper implementation details, private test fixtures, and other proprietary validation internals. See [docs/PUBLIC-PRIVATE-BOUNDARY.md](docs/PUBLIC-PRIVATE-BOUNDARY.md).

## Status

Architecture v0.2: **P0 closed / frozen for implementation**.

Next gate: Workbook Engine v0.1 must satisfy the public contract and the private acceptance suite before UI/UX work begins.
