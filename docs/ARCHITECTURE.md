# TrustAnswer OS — Public Architecture Contract v0.2

Status: **FROZEN FOR IMPLEMENTATION**

This document describes the public-safe architecture contract. Proprietary adversarial cases and detailed resolver implementation are intentionally omitted.

## 1. Workbook contract

One workbook represents one company's reusable security-response knowledge base. Multiple customer questionnaires may use that knowledge base, but customer-specific approvals and submissions remain isolated.

Required flow:

`raw question -> canonical topic -> proposed answer -> claim/evidence validation -> human review -> submission gate`

No generated or reusable answer may bypass evidence and review requirements.

## 2. Seven-sheet schema

### 01_DASHBOARD

Read-only operational view derived from authoritative sheets. It may display active questionnaire, customer, due date, question counts, answer states, evidence gaps, review status, blockers, readiness percentage, and final submission state.

Dashboard values are not authoritative facts.

### 02_QUESTIONNAIRE

One row per customer question.

Public contract fields include:

- question_id
- questionnaire_id
- customer_id
- customer_name
- product_scope
- raw_question
- normalized_topic
- canonical_answer_id
- response_type
- draft_answer
- final_answer
- answer_state
- evidence_required
- evidence_ids
- owner
- reviewer
- review_status
- scope_status
- contradiction_status
- evidence_status
- ready_state
- notes
- created_at
- last_modified

Raw imported questions must be preserved.

### 03_ANSWER_LIBRARY

One row per reusable canonical answer/claim.

Public contract fields include:

- answer_id
- topic_id
- topic
- claim_key
- claim_value
- canonical_question
- canonical_answer
- answer_state
- explicit scope dimensions
- required_evidence_type
- default_evidence_ids
- caveat
- owner
- approver
- approval_status
- revision identity
- effective date
- review dates
- retirement/supersession metadata
- authority state

A canonical answer is never equivalent to a customer-approved final answer.

### 04_EVIDENCE_REGISTER

Authoritative evidence ledger.

Public contract fields include:

- evidence_id
- evidence_revision_id
- evidence_title
- evidence_type
- control_topic
- description
- source_location
- source_owner
- revision/version metadata
- effective_at
- known_at
- verification/review dates
- freshness_state
- shareability
- explicit scope dimensions
- status
- supersession metadata

Evidence must be revision-bound. Titles are not identity.

Shareability states must distinguish public/customer-safe material from NDA-only, internal, or restricted material.

### 05_GAP_REGISTER

One row per unresolved issue.

Public gap families include:

- missing or stale evidence
- control or answer gap
- scope conflict
- contradiction
- missing owner/approval
- incompatible evidence
- shareability conflict
- invalid N/A rationale
- missing partial-answer caveat
- roadmap misrepresentation

Control gaps and evidence gaps must remain distinct.

### 06_REVIEW_QUEUE

One row per review decision.

Review records bind to the exact customer/question context, answer revision, evidence revisions, scope, and relevant validation-contract revision.

A material dependency change invalidates prior approval.

Public decision states:

- PENDING
- APPROVED
- APPROVED_WITH_CAVEAT
- REJECTED
- RETURNED

### 07_SUBMISSION_GATE

The publication boundary.

Public outputs:

- READY
- BLOCKED
- REVIEW_REQUIRED

There is no auto-approved or good-enough state.

READY requires every mandatory validation dimension to pass. Unknown, error, broken reference, ambiguity, or integrity failure cannot be interpreted as success.

## 3. State model

Question lifecycle:

`IMPORTED -> MAPPED -> DRAFTED -> VALIDATING -> BLOCKED | REVIEW_REQUIRED -> APPROVED -> READY_TO_SEND`

A dependency mutation after approval moves the item to an invalidated/review-required path. Repairing the dependency alone must not resurrect READY.

## 4. Answer states

Supported public answer states:

- UNKNOWN
- SUPPORTED
- PARTIAL
- UNSUPPORTED
- NOT_APPLICABLE
- ROADMAP
- NEEDS_REVIEW

Rules include:

- blank is not NO
- UNKNOWN cannot silently become SUPPORTED
- PARTIAL requires an explicit caveat
- NOT_APPLICABLE requires rationale
- ROADMAP must not be represented as an implemented control

## 5. Point-in-time contract

Historical submissions are evaluated using their submission/evaluation context, not today's state.

Evidence eligibility requires that it was both effective and known within the relevant evaluation context. Later knowledge must not retroactively make an earlier submission appear supported.

Submitted snapshots are immutable historical records even when the current knowledge base changes.

## 6. Scope contract

Blank is not a wildcard.

Scope dimensions must use explicit values such as a concrete scope, explicit ALL, or UNKNOWN. UNKNOWN does not match ALL.

The implementation must revalidate scope when content is reused across customers, products, plans, regions, deployments, or features.

## 7. Canonical authority

A canonical claim must not have conflicting active authoritative values for the same applicable scope and evaluation context.

Ambiguous authority blocks dependent publication rather than silently choosing a winner.

## 8. Evidence contract

Evidence identity is revision-specific.

Evidence validity and evidence shareability are separate decisions.

An answer may be internally supported while its supporting evidence remains unsuitable for customer disclosure.

Superseded, broken, stale, future-known, ambiguous, or otherwise invalid evidence cannot satisfy a required evidence gate.

## 9. Approval contract

Approval is contextual, not portable.

It is bound to the relevant customer/question context, answer revision, evidence revisions, scope and validation contract. Material dependency changes require a new review.

## 10. Formula and integrity contract

Formulas perform deterministic validation; formulas do not create facts.

Workbook integrity is itself a submission prerequisite. Missing required structure, broken references, formula errors, or an unknown integrity state must fail closed.

Exact anti-tamper implementation is private.

## 11. Submission snapshot

A submitted record must preserve sufficient immutable context to reconstruct what was actually sent, including question identity, final answer/revision, relevant canonical revision, evidence revisions, scope, review decision, timestamps, contract/schema versions, and gate result.

## 12. Master invariant

The public master invariant is:

> READY_TO_SEND exists only when required context, answer, authority, scope, evidence, review, integrity, and special-state validations all pass with no blocking ambiguity.

Absence of a detected failure is not proof of success.

## 13. Explicit v0.1 exclusions

The frozen MVP does not require:

- AI answer generation
- semantic/fuzzy matcher
- trust center
- SOC 2 automation
- document hosting
- external API
- team authentication
- automatic web crawling
- large prewritten answer corpus
- risk/compliance scoring

The MVP's primary job is to prevent an unsupported or insufficiently reviewed questionnaire response from being treated as ready to send.
