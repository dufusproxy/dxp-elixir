# 17 — Phase 4: Differentiation

**Priority:** Phase 4 (Q4 / Y2 H1) · **Spec:** §8.5, §11 · **Depends on:** 16 · **Blocks:** —

## Goal

The bets that separate the platform from both Squiz and the headless field: agentic authoring, estate-wide content intelligence, compliance certification, an open component ecosystem, and self-host distribution.

## Tasks

- [ ] **Agentic authoring**: file-to-DXP (PDF/Figma → draft page using existing components); conversational page building. Rides on the manifest contract — props JSON Schemas make components machine-composable.
- [ ] **Content Intelligence crawler**: accessibility, SEO, broken links, AI-discoverability across the customer's whole estate (not just DXP-hosted pages).
- [ ] **ISO 27001 certification**: formalise the compliance work planned from Q1 (audit log, RBAC, encryption at rest, secrets management — spec §10). Certification lands here; the controls exist from PR #1.
- [ ] **Public component registry** + **plugin SDK**; Vite plugin adapters for Svelte, Lit, etc. (community-extensible against the published contract).
- [ ] **Self-host distribution** for customers who require it (helm charts in `infrastructure/k8s/`). Resolve the distribution-model open question first: open core vs fully OSS + paid hosting vs source-available (spec §11 — decide before Phase 4).

## Open questions falling due by this phase (spec §11)

- Self-host distribution model (before Phase 4 starts).
- Pricing model (before second customer — likely earlier).
- Squiz Matrix migration tooling: initial position is a content export bridge, not full automated migration; revisit when the first Squiz customer asks.
- Scoped slots in contract v2 — revisit when a real component needs them.
- Project naming.
