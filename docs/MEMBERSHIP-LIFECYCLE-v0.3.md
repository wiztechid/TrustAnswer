# Membership Lifecycle v0.3

Membership is not generic CRUD.

Allowed controlled actions are INVITE, ACTIVATE, CHANGE_ROLE, SUSPEND and REMOVE. Every successful transition writes an immutable membership event.

OWNER/ADMIN may manage ordinary memberships. Only OWNER authority may create/change/remove OWNER authority. The final active OWNER cannot be demoted, suspended or removed.

INVITE cannot directly create an OWNER. Removed membership does not silently resurrect through ACTIVATE; a new reviewed onboarding path is required.

Status: **IMPLEMENTED / RUNTIME RLS + CONCURRENCY QC PENDING**.
