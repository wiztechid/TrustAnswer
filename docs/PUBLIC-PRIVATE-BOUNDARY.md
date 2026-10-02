# Public / Private Boundary

This repository is public. Treat this file as a mandatory publication boundary.

## Safe to publish

- product positioning and user-facing concepts
- seven-sheet workbook structure
- public state names
- public field/schema contract
- high-level deterministic validation principles
- fictional/demo data that reveals no private resolver behavior
- user documentation
- public release notes
- tests that demonstrate ordinary expected behavior without exposing the private attack suite

## Keep private

Do **not** commit:

- full adversarial acceptance-suite recipes
- exploit sequences or bypass recipes
- internal resolver precedence logic
- exact contradiction-resolution algorithms
- detailed anti-tamper signatures/check algorithms
- private formula hardening internals when they expose bypass conditions
- proprietary evidence/claim matching heuristics
- hidden calibration or scoring logic
- private fixtures specifically designed to reveal validator weaknesses
- private commercial research datasets
- credentials, customer data, real security evidence, or confidential questionnaires

## Development rule

Public implementation may expose what the product guarantees, but it should not unnecessarily expose the complete catalogue of how those guarantees are attacked internally.

Before every public commit involving validation internals, ask:

1. Is this required for users to understand or run the product?
2. Does it reveal a bypass recipe or proprietary resolver behavior?
3. Can the same public contract be expressed without disclosing the private test mechanism?

If (2) is yes, keep the detail private.

## Architecture status

The public architecture contract is v0.2 and frozen for Workbook Engine v0.1 implementation.

The private acceptance suite remains the authoritative adversarial gate.
